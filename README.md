I'll make the README more defined and have all the information soon

##Notes
This repository should be part of the directory that has the entire openbr repository

##Files
 
###bashEnroll.sh
- use for enrolling
- right now, there is no gallery output
- example: ./bashEnroll.sh -a CPUCVT+CUDALBP+CUDAPCA -n 1,2,3 -e /data/MEDS/img/
- example: ./bashEnroll.sh -a trainedAlgFile.alg -n 1,2,4

| Flags    | Required | Parameter          | Desc      |
|----------|----------|--------------------|-----------|
| a        | yes      | name of the trained algorithm or pipeline of plugins | specify the algorithm to enroll |
| b        | no       | relative path to 'br' executable | default path is "openbr/build/app/br/br" |
| e        | no       | directory of images to enroll with | default database is ATT |
| g        | no       | name of the outputted gallery file | has default name |
| h        | no       |                    | help |
| n        | yes      | comma separated sequence of numbers | specify the number of copies of the enrolling image directory to use; numbers need to be in increasing order |
| o        | no       | filename for timing data | has default name |



###bashTrain.sh
- use for training
- p and n flags are required
- p flag specifies the pipeline