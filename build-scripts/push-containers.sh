#!/bin/bash

TMPFILE=$(mktemp)
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
TOPDIR=$(dirname "$SCRIPT_DIR")
source "$SCRIPT_DIR"/parameters.sh

sudo docker images | grep -v ^CONTAINERS > $TMPFILE
for container in $CONTAINERS; do
    latestHash=$(cat $TMPFILE | \
	    grep $container | \
	    grep latest | \
	    grep -v $REGISTRY | \
	    while read name tag hash theRest; do echo $hash; done)
    sudo docker tag $latestHash $REGISTRY/$container:latest
    I=0
    while ! sudo docker push $REGISTRY/$container:latest; do
	    if [ "$I" = "10" ] ; then
		   echo Could not push container
		   exit 1
	    fi
	    I=$(($I +1)) 
	    sleep 1
    done
done
rm -f $TMPFILE
