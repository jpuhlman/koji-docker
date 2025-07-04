#!/bin/bash

if [ -z "$1" ] ; then
   echo Need directory
   exit 1
fi

dir=$1
latest=$(cat $dir/latest-mash-build)
echo $latest
cd $dir
for each in *; do
    if [ -d "$each" -a ! -h "$each" -a $each != "$latest" ] ; then
       rm -rf $each
    fi
done
