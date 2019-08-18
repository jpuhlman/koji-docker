#!/bin/bash


KOJI_CONTAINER_NAME=koji-test
KOJI_CONTAINER_DOCKERFILE="Dockerfiles/koji-docker"

KOJIBUILDER_CONTAINER_NAME=koji-builder
KOJIBUILDER_CONTAINER_DOCKERFILE="Dockerfiles/builder"

CONTAINER_VERSIONS=$(date +%y%m%d)
