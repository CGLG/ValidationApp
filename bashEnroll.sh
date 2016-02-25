#!/bin/bash

# REQUIRED FLAGS: -a, -n
# EXAMPLE: ./bashEnroll -n 1,2,3,4 -a algorithName.alg -g galleryName.gal

helpDisplay="Help
The input flags are as such:
  -a [name]                specify the name of the trained algorithm or the pipeline for an untrained algorithm
  -b [path]                specify the path to the br executable program
  -e [dir]                 enroll with the images in the specified directory
  -g [name]                specify the gallery name
  -h                       display help information
  -n [num, num, ...]       specify a the number of copies of the image database to use, comma separated
                           the numbers should should be in increasing order
  -o [name]                specify the output file name

EXAMPLE: ./bashEnroll -n 1,2,3,4 -a algorithName.alg -g galleryName.gal
"


# variables for enrollinging mode
enrollDirectory="/data/ATT/img/" # relative or absolute path?
outputFile="timingEnroll.csv"
algorithm=""
galleryName="enrolledGallery.gal"
currentDirectory=`pwd`
enrollingSetArray=()
tempDirectories=()
br="openbr/build/app/br/br"

# Deletes the directories in the list $WORK_DIRS
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

    local output=$(find $trainDirectory -type f -name '*.pgm' | head -1)
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



# flags for enrolling mode
aflag=false
nflag=false
while getopts ":a:b:e:g:hn:o:" opt; do
    case $opt in
        a)
	    aflag=true
            if [ -n "$OPTARG" ]; then
		if [ -e "$OPTARG" ]; then
		    algorithm=$OPTARG
		else
		    algorithm=$(parseInput)
                fi
		echo "algorithm: $algorithm"
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
	e)
           if [ -n "$OPTARG" ]; then
                enrollDirectory=$OPTARG
            else
                echo "ERROR: -enroll flag requires the enrolling set database of images" >&2
                exit 1
            fi
           ;;
	g)
	    if [ -n "$OPTARG" ]; then
		galleryName=$OPTARG
	    else
		echo "ERROR: -gallery flag requires the gallery name" >&2
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
		enrollingSetArray+=($x)
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

# require the a flag
if ! $aflag
then
    echo "The -a flag must be included with the name of the trained algorithm"
    exit 1
fi

# require the n flag
if ! $nflag
then
    echo "The -n flag must be included with the numbers for copies"
    exit 1
fi


# empty file before adding data
> $outputFile
echo "Number of files,Time in seconds" >> $outputFile


# first copy the images and then do enrolling and timing
previousNumber=0
for num in "${enrollingSetArray[@]}"
do
    echo "------Creating $num Copies-----"

    # create temp directory if first time
    if [ "$previousNumber" -eq "0" ]
    then
	tempEnrollDir=`mktemp -d -p $currentDirectory`
    else
	tempEnrollDir="${tempEnrollDir::-1}"
    fi
    
    # copy the images over the correct number of times
    cd $tempEnrollDir
    for (( i=$previousNumber; i < $num; i++))
    do
	for file in $enrollDirectory/*
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

    tempEnrollDir=$tempEnrollDir"/"

    # split up gallery name to modify it based on criteria
    base=$(basename -- "$galleryName")
    name=${base%.*}
    name=${name:-$base}
    ext=${base#"$name"}

    # split up algorithm name to get the pipeline type and number of copies used for training
    fullBase=$(basename -- "$algorithm")
    fullName=${fullBase%.*}
    fullName=${fullName:-$fullBase}
    fullName=$(echo $fullName | grep -o '_.*')
    fullName=$(echo $fullName | grep -o 'C.*')

    # get the dimensions of an image
    dimResult=$(getDimensions)

    # combine everything in to a new name
    finalGalName="${name}_${dimResult}_${fullName}_${num}E$ext"

    # enroll the images and time it
    echo "-----Enrolling Algorithm-----"
    startTime=$(($(date +%s%N)/1000000))
    output=$(./$br -algorithm $algorithm -enroll $tempEnrollDir )
    endTime=$(($(date +%s%N)/1000000))
    echo "-----Done Enrolling-----"


    # try other way of timing
    #output=$(time ./openbr/build/app/br/br -algorithm $algorithm -enroll $tempEnrollDir $finalGalName | grep -o -P '(?<=real ).*(?=user)')
    #echo "output: $output"
    

    # calculate execution time in seconds and convert to 3 decimal places
    totalTime=`expr $endTime - $startTime`
    while [[ ${#totalTime} -lt 3 ]]
    do
	totalTime="0${totalTime}"
    done
    echo "totalTime: $totalTime"
    totalTime="${totalTime%???}.${totalTime: -3}"

    echo $numFiles","$totalTime >> $outputFile
    
done

# add created temp directory to list of files that will be deleted
tempDirectories+=($tempEnrollDir)


# Register the cleanup function to be called on the EXIT signal
trap cleanup EXIT
