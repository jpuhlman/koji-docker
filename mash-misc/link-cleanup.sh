#!/bin/bash

if [ -z "$1" ] ; then
   echo Need directory
   exit 1
fi

dir=$1
latest=$(basename $(readlink -f $1/latest))
echo $latest
for each in $1/* ; do
    if [ -h "$each" ] ; then
       path=$(readlink -f "$each")
       linkdir=$(basename $path)
       if [ "$linkdir" == "$latest" ] ; then
          echo "yes $each"
          if [ "$(basename $each)" != "latest" ] ; then
             newDir=$(echo "$each" | tail -n 1)
             rm -f "$each"
             sudo -u kojiadmin ln -s $latest $dir/$newDir
          fi
       else
          echo "'$linkdir' '$latest'"
          rm -f "$each"
       fi

    fi
done
