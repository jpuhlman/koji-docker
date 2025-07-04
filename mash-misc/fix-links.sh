#!/bin/bash

if [ -z "$1" ] ; then
   echo Need directory
   exit 1
fi

dir=$1
latest=$(cat $dir/latest-mash-build)
echo $latest
cd $dir
links=""
for each in *; do
    if [ -h "$each" ] ; then
       links="$each $links"
    fi
    if [ -d "$each" -a ! -h "$each" ] ; then
       repo=$each
    fi
done
if [ "$(echo $links | wc -w)" == "1" ] ; then
   echo $dir
   echo $repo
   repoMd=$(find  $repo  | grep repomd.xml | grep \/os\/)
   DATEID=$(ls -T 1 --time-style=+"%y%m%d%H%M" -l $repoMd | cut -d " " -f 6 | tail -n 1)
   echo $DATEID
   sudo -u kojiadmin ln -s $latest $DATEID
fi
