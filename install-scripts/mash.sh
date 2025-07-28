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
if [ -n "$MASH_TAG_NAME" ] ; then
   TAG_NAME=$MASH_TAG_NAME
fi
DISTRO_NAME="$TAG_NAME"
BUILD_ARCHES="x86_64 i686"
KOJI_DIR="${KOJI_DIR:-/srv/koji}"
MASH_TOP="/srv/mash"
MASH_DIR="$MASH_TOP/$TAG_NAME"
MASH_TRACKER_FILE="$MASH_DIR"/latest-mash-build
MASH_TRACKER_DIR="$MASH_DIR"/latest
MASH_DIR_OLD="$MASH_TRACKER_DIR".old
KEEP_NUM=4
write_packages_file() {
	local PKG_DIR="$1"
	local PKG_FILE="$2"
	rpm -qp --qf="%{NAME}\t%{VERSION}\t%{RELEASE}\n" "$PKG_DIR"/*.rpm | sort > "$PKG_FILE" || true
}

clean_up() {
	TMPFILE=$(mktemp)
	pushd $MASH_DIR
	# Get directories.
	ls -l | grep ^d | while read A B C D E F G H FILENAME J K; do 
		echo $FILENAME
	done | sort -n | tee $TMPFILE

        # find out how many there are.
	LEN=$(cat $TMPFILE | wc -l )

        # How many are left over when wee keep KEEP_NUM
	SHORT=$(expr $LEN - $KEEP_NUM)
        # Remove the older directories.
	cat $TMPFILE | head -n $SHORT | sort -n | while read DIRNAME; do rm -rf $DIRNAME; done

        # Remove danlginglin links
	ls -l | grep ^l | grep -v latest | while read A B C D E F G H FILENAME J K; do 
	   if ! ls $FILENAME/. ; then 
		rm -f $FILENAME 2>/dev/null
	   fi
	done
	rm -f $TMPFILE
	popd
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
VID="$(echo $TAG_NAME | sed s,-,,g | sed s,\\.,,)"
if [[ "$MASH_BUILD_NUM" -ne "$KOJI_BUILD_NUM" ]]; then
# Generate comps.xml
    COMPS_FILE="$(mktemp)"
    ALL_PACKAGES=$(mktemp)
    koji list-tagged dist-"$TAG_NAME" --latest --inherit --rpms | awk '{print $1}' | sed -E 's/-[0-9][^-]*-[^-]*$//' | sort -u > $ALL_PACKAGES
    COMPS_SNIP=$(mktemp)
    echo "  <group>
    <id>all-packages</id>
    <name>All Packages</name>
    <packagelist>" > $COMPS_SNIP

    cat $ALL_PACKAGES | while read pkg; do
        echo "      <packagereq type=\"default\">$pkg</packagereq>"
    done >> $COMPS_SNIP

    echo "    </packagelist>
  </group>" >> $COMPS_SNIP
    rm -f $ALL_PACKAGES

    DEBUG_GROUP=$(koji list-tagged dist-"$TAG_NAME" --latest --rpms | \
    awk '{print $1}' | grep '\-debuginfo' | \
    sed -E 's/-[0-9][^-]*-[0-9][^-]*\..*//' | sort -u | \
    awk 'BEGIN {
         print "  <group>"
         print "    <id>debug</id>"
         print "    <name>Debug Info</name>"
         print "    <packagelist>"
    }
    {
         printf "      <packagereq type=\"default\">%s</packagereq>\n", $1
    }
    END {
         print "    </packagelist>"
         print "  </group>"
    }')

    cat > "$COMPS_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<comps>
  <group>
    <id>build</id>
    <name>Build Environment</name>
    <packagelist>
      <packagereq type="default">build</packagereq>
    </packagelist>
  </group>

  <group>
    <id>srpm-build</id>
    <name>SRPM Build Environment</name>
    <packagelist>
      <packagereq type="default">srpm-build</packagereq>
    </packagelist>
  </group>
EOF

    echo "$DEBUG_GROUP" >> $COMPS_FILE
    cat $COMPS_SNIP >> $COMPS_FILE
    rm -f $COMPS_SNIP
    echo "</comps>" >> "$COMPS_FILE"
    cat $COMPS_FILE

    MASH_DIR_NEW="$MASH_DIR/$KOJI_BUILD_NUM"
    rm -rf "$MASH_DIR_NEW"
    mkdir -p "$MASH_DIR_NEW"
    COMPOSE_DIR="$MASH_TOP/compose/dist-$TAG_NAME"
    rm -rf $COMPOSE_DIR
    mkdir -p $COMPOSE_DIR
    cat > "$COMPOSE_DIR"/variants.xml << EOF
<variants>
  <variant id="$VID" name="$TAG_NAME" type="variant">
    <arches>
      <arch>x86_64</arch>
      <arch>i386</arch>
    </arches>
    <groups>
      <group>build</group>
      <group>srpm-build</group>
      <group>debug</group>
      <group>all-packages</group>
    </groups>
  </variant>
</variants>
EOF

# Generate pungi.conf
comps_path="$COMPS_FILE"
        cat > $COMPOSE_DIR/pungi.conf << EOF
release_name = "$TAG_NAME"
release_short = "$TAG_NAME"
release_version = "$MASH_BUILD_NUM"

gather_method = "nodeps"
gather_source = "koji"
greedy_method = "all"
check_deps = False          
gather_fulltree = True
check_arches = True 
# Mandatory for pungi-koji
compose_type = "nightly"

link_type = "symlink"

# Koji configuration
pkgset_source = "koji"
pkgset_koji_tag = "dist-$TAG_NAME"
pkgset_koji_inherit = True
koji_profile = "koji"

# Repo metadata generation
createrepo_c = True
createrepo_checksum = "sha256"

variants_file = "$COMPOSE_DIR/variants.xml"
comps_file = "$comps_path"

tree_arches = ["x86_64", "i386"]

# Skip unused phases (only keep needed ones)
skip_phases = ["buildinstall", "live_media", "ostree", "test", "extra_files"]
allow_invalid_sigkeys = True
# Signature handling
sigkeys = [""]

# No multilib (mimics mash setting)
multilib = []  # MUST be a list or it will fail validation

create_debug = True
create_optional = True
create_source = True

EOF

# Create Mash
        pungi-koji --no-label --config "$COMPOSE_DIR/pungi.conf" --target-dir "$COMPOSE_DIR"
        mkdir -p $MASH_DIR_NEW/$DISTRO_NAME
        cp -a $COMPOSE_DIR/*/compose/$VID/* $MASH_DIR_NEW/$TAG_NAME/
        # Make pungi output match the previous mash output
        if [ -e $MASH_DIR_NEW/$DISTRO_NAME/source/iso ] ; then
           rm -rf $MASH_DIR_NEW/$DISTRO_NAME/source/iso
        fi
        if [ -e $MASH_DIR_NEW/$DISTRO_NAME/tree ] ; then
           mv $MASH_DIR_NEW/$DISTRO_NAME/tree $MASH_DIR_NEW/$DISTRO_NAME/SRPMS
        fi
        rm -rf $MASH_DIR_NEW/$DISTRO_NAME/*/iso
        for BUILD_ARCH in $BUILD_ARCHES; do
            if [ -e $MASH_DIR_NEW/$DISTRO_NAME/$BUILD_ARCH/debug/tree ] ; then
               mv $MASH_DIR_NEW/$DISTRO_NAME/$BUILD_ARCH/debug/tree/Packages/* $MASH_DIR_NEW/$DISTRO_NAME/$BUILD_ARCH/debug/ || true
               rm -rf $MASH_DIR_NEW/$DISTRO_NAME/$BUILD_ARCH/debug/tree
               pushd $MASH_DIR_NEW/$DISTRO_NAME/$BUILD_ARCH/debug/
               createrepo_c .
               popd
            fi
            if [ -e $MASH_DIR_NEW/$DISTRO_NAME/$BUILD_ARCH/iso ] ; then
               rm -rf $MASH_DIR_NEW/$DISTRO_NAME/$BUILD_ARCH/iso
            fi
            if [ -e $MASH_DIR_NEW/$DISTRO_NAME/$BUILD_ARCH/jigdo ] ; then
               rm -rf $MASH_DIR_NEW/$DISTRO_NAME/$BUILD_ARCH/jigdo
            fi
	    write_packages_file "$MASH_DIR_NEW"/"$DISTRO_NAME"/"$BUILD_ARCH"/os/Packages "$MASH_DIR_NEW"/"$DISTRO_NAME"/"$BUILD_ARCH"/packages-os
	    write_packages_file "$MASH_DIR_NEW"/"$DISTRO_NAME"/"$BUILD_ARCH"/debug "$MASH_DIR_NEW"/"$DISTRO_NAME"/"$BUILD_ARCH"/packages-debug
        done
        if [ -e $MASH_DIR_NEW/$DISTRO_NAME/source/tree ] ; then
             mv $MASH_DIR_NEW/$DISTRO_NAME/source/tree/Packages $MASH_DIR_NEW/$DISTRO_NAME/source/SRPMS
             pushd $MASH_DIR_NEW/$DISTRO_NAME/source/SRPMS
             createrepo_c .
             popd
             rm -rf $MASH_DIR_NEW/$DISTRO_NAME/source/tree
        fi
        if [ -e $MASH_DIR_NEW/$DISTRO_NAME/source/iso ] ; then
            rm -rf $MASH_DIR_NEW/$DISTRO_NAME/source/iso
        fi
        if [ -e $MASH_DIR_NEW/$DISTRO_NAME/source/jigdo ] ; then
            rm -rf $MASH_DIR_NEW/$DISTRO_NAME/source/jigdo
        fi
	write_packages_file "$MASH_DIR_NEW"/"$DISTRO_NAME"/source/SRPMS "$MASH_DIR_NEW"/"$DISTRO_NAME"/source/packages-SRPMS
        find "$MASH_DIR_NEW"/"$DISTRO_NAME" | grep media.repo | xargs rm
	if [ -L "$MASH_TRACKER_DIR" -o ! -e $MASH_TRACKER_DIR ] ; then
        	rm -f "$MASH_TRACKER_DIR"
        	ln -s $KOJI_BUILD_NUM $MASH_TRACKER_DIR
	fi
        repoMd=$(find  $MASH_DIR_NEW  | grep repomd.xml | grep \/os\/)
        DATEID=$(ls -T 1 --time-style=+"%y%m%d%H%M" -l $repoMd | cut -d " " -f 6 | tail -n 1)
        ln -s "$KOJI_BUILD_NUM" $MASH_DIR/"$DATEID"

	echo "$KOJI_BUILD_NUM" > "$MASH_TRACKER_FILE"
	clean_up
fi
