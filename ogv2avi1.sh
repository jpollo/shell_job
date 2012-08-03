#!/bin/bash
# ogv to avi
# Call this with multiple arguments
# for example : ls *.{ogv,OGV} | xargs ogv2avi
N=$#;
echo "Converting $N files !"
for ((i=0; i<=(N-1); i++))
do
echo "converting" $1
filename=${1%.*}
mencoder "$1" -ovc xvid -oac mp3lame -xvidencopts pass=1 -o $filename.avi
shift 1
done
