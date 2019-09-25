#!/bin/bash
# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
## KOJI RPM BUILD AND TRACKER

TMPFILE=$(mktemp)
sudo hostenv.sh > $TMPFILE
source $TMPFILE
cat $TMPFILE
rm -rf $TMPFILE
export KOJIHOST=$HOSTNAME
export KOJI_DIR=/srv/koji
export KOJI_MOUNT_DIR=/mnt/koji
export COMMON_CONFIG=/config
export KOJI_MASTER_FQDN="$KOJIHOST"
if [ -z "$KOJI_MASTER_FQDN" ] ; then
	echo Need to set "HOST" to system fully qualified domain name
	exit 1
fi
export KOJI_URL=https://"$KOJI_MASTER_FQDN"
export KOJID_CAPACITY=16
if [ -z "$TAG_NAME" ] ; then
	export TAG_NAME=centos-updates-mv
else
	export TAG_NAME
fi
if [ -z "$DISTRO_NAME" ] ; then
	export DISTRO_NAME="centos-updates"
else
	export DISTRO_NAME
fi
# Use for koji SSL certificates
if [ -z "$COUNTRY_CODE" ] ; then
	export COUNTRY_CODE='US'
else
	export COUNTRY_CODE
fi
if [ -z "$STATE" ] ; then
	export STATE='SomeState'
else
	export STATE
fi
if [ -z "$LOCATION" ] ; then
	export LOCATION='SomeCity'
else
	export LOCATION
fi
if [ -z "$ORGANIZATION" ] ; then
	export ORGANIZATION='SomeCompany'
else
	export ORGANIZATION
fi
if [ -z "$ORG_UNIT" ] ; then
	export ORG_UNIT='devel'
else
	export ORG_UNIT
fi

# Use for importing existing RPMs
if [ -z "$RPM_ARCH" ] ; then
	export RPM_ARCH='x86_64'
fi
## POSTGRESQL DATABASE
export POSTGRES_DIR=/srv/pgsql

## GIT REPOSITORIES

export GIT_DIR=/srv/git
if [ -z "$GIT_FQND" ] ; then
   export GIT_FQDN="gitcentos.mvista.com"
fi
if [ -z "$GIT_PATH" ] ; then
   export GIT_PATH=/centos/upstream/packages/*
fi
if [ -z "$GIT_PATH" ] ; then
	export GIT_GETSOURCES=":common:/chroot_tmpdir/scmroot/common/get_sources.sh"
fi
if [ -z "$KOJI_SCMS" ] ; then
	KOJI_SCMS=$GIT_FQDN:$GIT_PATH$GIT_GETSOURCES
fi
export IS_ANONYMOUS_GIT_NEEDED=false
export GITOLITE_PUB_KEY=''

## UPSTREAMS CACHE
export UPSTREAMS_DIR=/srv/upstreams

## MASH RPMS
export MASH_DIR=/srv/mash
export MASH_SCRIPT_DIR=/usr/local/bin
