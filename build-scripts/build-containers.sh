#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
TOPDIR=$(dirname "$SCRIPT_DIR")
source "$SCRIPT_DIR"/parameters.sh

build_container () {
	dockerfile=$1
	imageName=$2
	version=$3
	sudo docker build -f $dockerfile . -t $imageName:$version
	hash=$(sudo docker images | grep ^$imageName | grep $version | head -n 1 | while read n v h d; do echo $h; done)
        echo hash = $hash
	sudo docker tag $hash $imageName:latest
}

cd $TOPDIR

build_container $KOJIBASE_CONTAINER_DOCKERFILE $KOJIBASE_CONTAINER_NAME $CONTAINER_VERSIONS
build_container $KOJI_CONTAINER_DOCKERFILE $KOJI_CONTAINER_NAME $CONTAINER_VERSIONS
build_container $KOJIBUILDER_CONTAINER_DOCKERFILE $KOJIBUILDER_CONTAINER_NAME $CONTAINER_VERSIONS

