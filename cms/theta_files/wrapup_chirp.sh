#!/bin/bash

cd $1 && find . -iname '.chirp.ad*' -exec cat "{}" >> "./.job.ad.out" \;
#CHIRP_AD_LOCATION=`find . -type f -iname ".chirp.ad*"`

#if [ -n $CHIRP_AD_LOCATION ]
#then 
echo Done appending chirp
cat "$1/.job.ad.out"
#fi 
