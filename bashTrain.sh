#!/bin/bash

# REQUIRED FLAGS: -n, -p
# EXAMPLE: ./bashTrain.sh -n 1,2,3,4 -p CPUPCA -a algorithmName.alg -t /data/ATT/img/

helpDisplay="

The outputted algorithm name follows the convention:
  [name inputted]_[database image dimensions]_[CUDA/CPU]_[number of copies].[extension]

The timing information is in timingTrain.csv or the specified output name.

The input flags are as such:
  -a [name]                   specify the name of the algorithm
  -b [path]                   specify the path to the br program
  -h                          display help information
  -n [num, num, ...]          specify a the number of copies of the image database to use, comma separated;
                              the numbers should be in increasing order
  -o [name]                   specify the output file name
  -p [pipeline]               specify the either with keyword or have full pipeline inside of quotes
                              keywords: 'CPULBP', 'CPUPCA', 'CPULBP+CPUPCA', 'CUDALBP', 'CUDAPCA', 'CUDALBP+CUDAPCA', 
  -t [directory]              train with the images in the specified directory path

EXAMPLE: ./bashTrain.sh -n 1,2,3,4 -p CPUPCA -a algorithmName.alg -t /data/ATT/img/  
"


# variables for training mode
trainPipeline=""
trainDirectory="/data/ATT/img/"
outputFile="timingTrain.csv"
algorithmName="trainedAlgorithm.alg"
currentDirectory=`pwd`
trainingSetArray=()
tempDirectories=()
algorithmType=""
br="openbr/build/app/br/br"


# Deletes the directories in the list tempDirectories
function cleanup {
    for dir in "${tempDirectories[@]}"
    do
	rm -rf "$dir"
	echo "Deleted temp working directory $dir"
    done
}

# get the dimensions of the first pgm image file found
function getDimensions {
    local dimensions="92x112"

    output=$(find $trainDirectory -type f -name '*.pgm' | head -1)
    dimensions=$(file $output | grep -o -P '(?<=size = ).*(?=, rawbits)' | tr -d '[[:space:]]')
    echo "$dimensions" 
}



# parse input into pipeline
function parseInput {
    local pipeline=""

    input=$OPTARG
    OIFS=$IFS
    IFS='+'
    arrayInput=()
    for x in $input; do
	arrayInput+=($x)
    done
    IFS=$OIFS

    cudaBefore=false
    for plugin in "${arrayInput[@]}"
    do
	case $plugin in
	    CPUCVT|cpucvt|Cvt)
		pipeline+="Open+Cvt(Gray)"
		;;
	    CPULBP|cpulbp|LBP)
		if $cudaBefore
		then
		    pipeline+="+CUDACopyFrom+LBP"
		    cudaBefore=false
		else
		    pipeline+="+LBP"
		fi
		;;
	    CPUPCA|cpupca|PCA)
		if $cudaBefore
		then
		    pipeline+="+CUDACopyFrom+CvtFloat+PCA"
		    cudaBefore=false
		else
		    pipeline+="+CvtFloat+PCA"
		fi
		;;
            CUDACVT|cudacvt)
		pipeline+="Open+CUDACopyTo+CUDARGB2GrayScale"
		cudaBefore=true
		;;
	    CUDALBP|cudalbp)
		if $cudaBefore
		then
		    pipeline+="+CUDALBP"
		else
		    pipeline+="+CUDACopyTo+CUDALBP"
		fi
		cudaBefore=true
		;;
	    CUDAPCA|cudapca)
		if $cudaBefore
		then
		    pipeline+="+CUDAPCA"
		else
		    pipeline+="+CUDACopyTo+CUDAPCA"
		fi
		cudaBefore=true
	        ;;
            *)
		if $cudaBefore
		then
		    if [[ $plugin == *"CUDA"* ]]
		    then
			pipeline+="+$plugin"
		    else
			pipeline+="+CUDACopyFrom+$plugin"
			cudaBefore=false
		    fi
		else
		    if [[ $plugin == *"CUDA"* ]]
		    then
			pipeline+="+CUDACopyTo+$plugin"
			cudaBefore=true
		    else
			pipeline+="+$plugin"
		    fi
		fi
		;;
	esac
    done

    # take out extra "+" in front when user inputs the entire pipeline path
    if [[ $pipeline == "+"* ]]
    then
	pipeline=${pipeline:1}
    fi

    # add the final CUDACopyFrom plugin
    if $cudaBefore
    then
	pipeline+="+CUDACopyFrom"
    fi

    # add the dist plugin to use for comparing
    if [[ $pipeline != *":Dist(L2)" ]]
    then
	pipeline+=":Dist(L2)"
    fi

    echo "$pipeline"
}



# flags for training mode
nflag=false
pflag=false
while getopts ":a:b:hn:o:p:t:" opt; do
    case $opt in
        a)
            if [ -n "$OPTARG" ]; then
                algorithmName=$OPTARG
            else
                echo "ERROR: -algorithm flag requires the algorithm name" >&2
                exit 1
            fi
            ;;
	b)
	    if [ -n "$OPTARG" ]; then
		br=$OPTARG
	    else
		echo "ERROR: -b flag requires the path to the br executable program" >&2
		exit 1
	    fi
	    ;;
        h)
            echo "$help"
            exit
            ;;
        n)
	    nflag=true
	    OIFS=$IFS
	    IFS=','
	    for x in $OPTARG; do
		trainingSetArray+=($x)
	    done
	    IFS=$OIFS
            ;;
        o)
            if [ -n "$OPTARG" ]; then
		echo "-o input: $OPTARG"
                outputFile=$OPTARG
            else
                echo "ERROR: -out flag requires the output file name" >&2
                exit 1
            fi
            ;;
        p)
	    pflag=true
            if [ -n "$OPTARG" ]; then
		algorithmType="$OPTARG"
	        trainPipeline=$(parseInput)
            else
                echo "ERROR: -pipe flag requires an the full pipeline" >&2
                exit 1
            fi
            ;;
        t)
           if [ -n "$OPTARG" ]; then
                trainDirectory=$OPTARG
            else
                echo "ERROR: -train flag requires the training set database of images" >&2
                exit 1
            fi
            ;;
       \?)
	    echo "Invalid flag: -$OPTARG" >&2
	    exit 1
	    ;;
	:)
	    echo "Option -$OPTARG requires an argument; missing argument" >&2
	    exit 1
	    ;;   
    esac
done

# require the n flag
if ! $nflag
then
    echo "The -n flag must be included with the numbers for copies"
    exit 1
fi

# require the p flag
if ! $pflag
then
    echo "The -p flag must be included for the pipeline"
    exit 1
fi

# print out some stuff
echo "Pipeline for training: $trainPipeline"
echo "Image set for training: $trainDirectory"
echo "Output timing data: $outputFile"
echo "Pipeline format: $algorithmType"


# empty file before adding data
> $outputFile
echo "Number of files,Time in seconds" >> $outputFile


# first copy the images and then do training and timing
previousNumber=0
for num in "${trainingSetArray[@]}"
do
    echo "------Creating $num Copies-----"

    # create temp directory if first time
    if [ "$previousNumber" -eq "0" ]
    then
	tempTrainDir=`mktemp -d -p $currentDirectory`
    else
	tempTrainDir="${tempTrainDir::-1}"
    fi
    
    # copy the images over the correct number of times
    cd $tempTrainDir
    for (( i=$previousNumber; i<$num; i++))
    do
	for file in $trainDirectory/*
	do
	    dir=$(dirname -- "$file")
	    dir=${dir:1}
	    base=$(basename -- "$file")
	    name=${base%.*}
	    name=${name:-$base}
	    ext=${base#"$name"}
	    cp -r $file ${name}_copy{$i}$ext
	done
    done

    # other stuff for use later
    numFiles=`find . -type f | wc -l`
    previousNumber=$num
    
    cd ..
    echo "-----Done Creating $num Copies-----"

    tempTrainDir=$tempTrainDir"/"

    # separate out components of the algorithm name to correspond to its parameters
    base=$(basename -- "$algorithmName")
    name=${base%.*}
    name=${name:-$base}
    ext=${base#"$name"}

    # get the dimensions and combine all parts to create the algorithm name
    dimResult=$(getDimensions)
    finalAlgName="${name}_${dimResult}_${algorithmType}_${num}T$ext"

    # train the algorithm
    echo "-----Training Algorithm-----"
    startTime=$(($(date +%s%N)/1000000))
    output=$(./$br -algorithm $trainPipeline -train $tempTrainDir $finalAlgName)
    endTime=$(($(date +%s%N)/1000000))
    echo "-----Done Training-----"
    
    # calculate execution time in seconds and convert to 3 decimal places
    totalTime=`expr $endTime - $startTime`
    while [[ ${#totalTime} -lt 3 ]]
    do
	totalTime="0${totalTime}"
    done
    totalTime="${totalTime%???}.${totalTime: -3}"
    echo "totalTime: $totalTime"

    # write time value to the timing csv document
    echo $numFiles","$totalTime >> $outputFile
done


# add temporary directory to list of files to delete
tempDirectories+=($tempTrainDir)


# Register the cleanup function to be called on the EXIT signal
trap cleanup EXIT

