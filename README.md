
##Notes
The paths are all relative so it matters where the files are located.
Don't need to worry about including CUDACopyTo or CUDACopyFrom in the pipeline; they are automatically included.

##Files
 
###bashEnroll.sh
- use for enrolling
- right now, there is no gallery output
- example: ./bashEnroll.sh -a CPUCVT+CUDALBP+CUDAPCA -n 1,2,3 -e /data/MEDS/img/
- example: ./bashEnroll.sh -a trainedAlgFile.alg -n 1,2,4

| Flags    | Required | Parameter          | Desc      |
|----------|----------|--------------------|-----------|
| a        | yes      | name of the trained algorithm or pipeline of plugins | specify the trained algorithm file or pipeline to enroll; the pipeline can use key words |
| b        | no       | relative path to 'br' executable | default path is "openbr/build/app/br/br" |
| e        | no       | directory of images to enroll with | default database is "/data/ATT/img/" |
| g        | no       | name of the outputted gallery file | default base name is enrolledGallery.gal; the image dimensions, type of algorithm, and number of copies used for enrolling get incorporated into the gallery name; final name follows convention: [name inputted]_[database image dimensions]_[CUDA/CPU type]_[number of copies for training]_[number of copies for enrolling].[extension] |
| h        | no       |                    | help |
| n        | yes      | comma separated sequence of numbers | specify the number of copies of the enrolling image directory to use; numbers need to be in increasing order |
| o        | no       | output filename for timing data | default name is "timingEnroll.csv" |



###bashTrain.sh
- use for training
- example: ./bashTrain.sh -p CPUCVT+CUDALBP+CUDAPCA -n 1,2,3 -t /data/MEDS/img/

| Flags    | Required | Parameter          | Desc      |
|----------|----------|--------------------|-----------|
| a        | no       | name of the trained algorithm | default base name is trainedAlgorithm.alg; final name follows convention: [name inputted]_[database image dimensions]_[CUDA/CPU type]_[number of copies].[extension] |
| b        | no       | relative path to 'br' executable | default path is "openbr/build/app/br/br" |
| h        | no       |                    | help |
| n        | yes      | comma separated sequence of numbers | specify the number of copies of the enrolling image directory to use; numbers need to be in increasing order |
| o        | no       | output filename for timing data | default name is "timingTrain.csv" |
| p        | yes      | specify the algorithm pipeline either with keywords or have full pipeline inside of quotes
| t        | no       | directory of images to train with | default database is "/data/ATT/img/" |



###Key Words
| Word    | Meaning           |
|---------|-------------------|
| CPUCVT  | Use the CPU version of the Cvt plugin: "Cvt(Gray)"      |
| CPULBP  | Use the CPU version of the LBP plugin: "LBP"            |
| CPUPCA  | Use the CPU version of the PCA plugin: "PCA"            |
| CUDACVT | Use the CUDA version of the Cvt plugin: "CUDARGB2GrayScale" |
| CUDALBP | Use the CUDA version of the LBP plugin: "CUDALBP"       |
| CUDAPCA | Use the CUDA version of the PCA plugin: "CUDAPCA"       |