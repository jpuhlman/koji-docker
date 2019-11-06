#!/bin/bash
# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -xe
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR"/globals.sh
source "$SCRIPT_DIR"/parameters.sh

#swupd bundle-add koji

mkdir -p "$MASH_DIR"
chown -R kojiadmin:kojiadmin "$MASH_DIR"
mkdir -p "$HTTPD_DOCUMENT_ROOT"
MASH_LINK="$HTTPD_DOCUMENT_ROOT"/"$(basename "$MASH_DIR")"
ln -sf "$MASH_DIR" "$MASH_LINK"
chown -h kojiadmin:kojiadmin "$MASH_LINK"
usermod -a -G kojiadmin "$HTTPD_USER"
# Required because Clear is stateless, and mash is run as a non-elevated user
mkdir -p /var/cache/mash
chown -R kojiadmin:kojiadmin /var/cache/mash
rpm --initdb

mkdir -p /config/mash
if [ ! -L /etc/mash ] ; then
	ln -s /config/mash /etc/mash
fi
if [ ! -e /etc/mash/mash.conf ] ; then
cat > /etc/mash/mash.conf <<- EOF
[defaults]
configdir = /etc/mash
buildhost = $KOJI_URL/kojihub
repodir = file://$KOJI_DIR
use_sqlite = True
use_repoview = False
EOF
fi
if [ ! -e /etc/mash/"$DISTRO_NAME".mash ] ; then
cat > /etc/mash/"$DISTRO_NAME".mash <<- EOF
[$DISTRO_NAME]
rpm_path = %(arch)s/os/Packages
repodata_path = %(arch)s/os/
source_path = source/SRPMS
debuginfo = True
multilib = False
multilib_method = devel
tag = dist-$TAG_NAME
inherit = True
strict_keys = False
arches = $RPM_ARCH
EOF
fi

mkdir -p "$MASH_SCRIPT_DIR"
cp -f "$SCRIPT_DIR"/mash.sh "$MASH_SCRIPT_DIR"

mkdir -p /etc/systemd/system
cat > /etc/systemd/system/mash.service <<- EOF
[Unit]
Description=Mash script to loop local repository creation for local image builds

[Service]
User=kojiadmin
Group=kojiadmin
ExecStart=$MASH_SCRIPT_DIR/mash.sh
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now mash
