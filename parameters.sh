#!/bin/bash
# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

## KOJI RPM BUILD AND TRACKER
export KOJI_DIR=/srv/koji
export KOJI_MOUNT_DIR=/mnt/koji

export KOJI_MASTER_FQDN="$HOST"
if [ -z "$KOJI_MASTER_FQDN" ] ; then
	echo Need to set "HOST" to system fully qualified domain name
	exit 1
fi
export KOJI_URL=https://"$KOJI_MASTER_FQDN"
export KOJI_MOUNT_DIR=/mnt/koji
export KOJI_SLAVE_FQDN="$KOJI_MASTER_FQDN"
export KOJID_CAPACITY=16
export TAG_NAME=centos-updates-mv
# Use for koji SSL certificates
export COUNTRY_CODE='US'
export STATE='California'
export LOCATION='Santa Clara'
export ORGANIZATION='Montavista'
export ORG_UNIT='MV'
# Use for importing existing RPMs
export RPM_ARCH='x86_64'
export SRC_RPM_DIR=
export BIN_RPM_DIR=
export DEBUG_RPM_DIR=
# Comment the following if supplying all RPMs as an upstream and not a downstream
export EXTERNAL_REPO=http://vault.centos.org/7.5.1804/os/x86_64/

## POSTGRESQL DATABASE
export POSTGRES_DIR=/srv/pgsql

## GIT REPOSITORIES
export GIT_DIR=/srv/git
export GIT_FQDN="gitcentos.mvista.com"
export GIT_PATH=/centos/upstream/packages/*
export GIT_GETSOURCES=":common:/chroot_tmpdir/scmroot/common/get_sources.sh"
export IS_ANONYMOUS_GIT_NEEDED=false
export GITOLITE_PUB_KEY=''

## UPSTREAMS CACHE
export UPSTREAMS_DIR=/srv/upstreams

## MASH RPMS
export MASH_DIR=/srv/mash
export MASH_SCRIPT_DIR=/usr/local/bin
