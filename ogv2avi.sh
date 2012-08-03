#!/bin/bash
# ogv to avi
mencoder "$1" -ovc xvid -oac mp3lame -xvidencopts pass=1 -o "$2"
