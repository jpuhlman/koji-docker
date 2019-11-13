#!/bin/bash
# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -xe
if [[ -e /etc/profile.d/proxy.sh ]]; then
	source /etc/profile.d/proxy.sh
fi
if [ -e /etc/koji/parameters.sh ] ; then
	source /etc/koji/parameters.sh
fi

TAG_NAME="${TAG_NAME:-clear}"
DISTRO_NAME="${DISTRO_NAME:-clear}"
BUILD_ARCH="${BUILD_ARCH:-x86_64}"
KOJI_DIR="${KOJI_DIR:-/srv/koji}"
MASH_DIR="${MASH_DIR:-/srv/mash}"
MASH_TRACKER_FILE="$MASH_DIR"/latest-mash-build
MASH_TRACKER_DIR="$MASH_DIR"/latest
MASH_DIR_OLD="$MASH_TRACKER_DIR".old

write_packages_file() {
	local PKG_DIR="$1"
	local PKG_FILE="$2"
	rpm -qp --qf="%{NAME}\t%{VERSION}\t%{RELEASE}\n" "$PKG_DIR"/*.rpm | sort > "$PKG_FILE"
}

if [[ -e "$MASH_TRACKER_FILE" ]]; then
	MASH_BUILD_NUM="$(< "$MASH_TRACKER_FILE")"
else
	MASH_BUILD_NUM=0
fi
DISTRO_DIR="$KOJI_DIR"/repos/dist-"$TAG_NAME"-build
CURRENT_KOJI_BUILD_NUM="$(basename "$(realpath "$DISTRO_DIR"/latest/)")"
KOJI_BUILD_NUM="$CURRENT_KOJI_BUILD_NUM"
if [[ "$MASH_BUILD_NUM" -eq "$CURRENT_KOJI_BUILD_NUM" ]]; then
	inotifywait -e create $DISTRO_DIR
	NEWBUILD=$(ls $DISTRO_DIR | sort -n | tail -n 1)
	KOJI_BUILD_NUM="$(basename "$(realpath "$DISTRO_DIR"/latest/)")"
	if [ "$NEWBUILD" -ne "$KOJI_BUILD_NUM" ] ; then
	   inotifywait -t 30 -e modify $DISTRO_DIR
	   KOJI_BUILD_NUM="$(basename "$(realpath "$DISTRO_DIR"/latest/)")"
	fi
fi
if [[ "$MASH_BUILD_NUM" -ne "$KOJI_BUILD_NUM" ]]; then
	COMPS_FILE="$(mktemp)"
	koji show-groups --comps dist-"$TAG_NAME"-build > "$COMPS_FILE"
    MASH_DIR_NEW="$MASH_DIR/$KOJI_BUILD_NUM"
	rm -rf "$MASH_DIR_NEW"
	mkdir -p "$MASH_DIR_NEW"
	mash --outputdir="$MASH_DIR_NEW" --compsfile="$COMPS_FILE" "$DISTRO_NAME"
	rm -f "$COMPS_FILE"

	write_packages_file "$MASH_DIR_NEW"/"$DISTRO_NAME"/"$BUILD_ARCH"/os/Packages "$MASH_DIR_NEW"/"$DISTRO_NAME"/"$BUILD_ARCH"/packages-os
	write_packages_file "$MASH_DIR_NEW"/"$DISTRO_NAME"/"$BUILD_ARCH"/debug "$MASH_DIR_NEW"/"$DISTRO_NAME"/"$BUILD_ARCH"/packages-debug
	write_packages_file "$MASH_DIR_NEW"/"$DISTRO_NAME"/source/SRPMS "$MASH_DIR_NEW"/"$DISTRO_NAME"/source/packages-SRPMS

	if [[ -L "$MASH_TRACKER_DIR" -o ! -e $MASH_TRACKER_DIR ]]; then
        rm -f "$MASH_TRACKER_DIR"
        ln -s $KOJI_BUILD_NUM $MASH_TRACKER_DIR
	fi

	echo "$KOJI_BUILD_NUM" > "$MASH_TRACKER_FILE"
fi
