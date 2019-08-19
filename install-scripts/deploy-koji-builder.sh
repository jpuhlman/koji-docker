#!/bin/bash
# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -xe
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

ECTKOJI=/etc/koji

if [ -e "$ECTKOJI"/globals.sh ] ; then
	source "$ECTKOJI"/globals.sh
else
	source "$SCRIPT_DIR"/globals.sh
fi
if [ -e "$ECTKOJI"/parameters.sh ] ; then
	source "$ECTKOJI"/parameters.sh
else
	source "$SCRIPT_DIR"/parameters.sh
fi

# Install kojid
#swupd bundle-add koji

# Create mock folders and permissions
mkdir -p /etc/mock/koji
mkdir -p /var/lib/mock
chown -R root:mock /var/lib/mock

# Setup User Accounts
if [ -z "$(id kojibuilder)" ] ; then
	useradd -r kojibuilder
fi
usermod -G mock kojibuilder

# Kojid Configuration Files
KOJI_TOP_DIR="$KOJI_DIR"
mkdir -p /config/kojid
if [ ! -L /etc/kojid ] ; then
	ln -s /config/kojid /etc/kojid
fi
if [ ! -e /etc/kojid/kojid.conf ] ; then
cat > /etc/kojid/kojid.conf <<- EOF
[kojid]
sleeptime=5
maxjobs=16
topdir=$KOJI_TOP_DIR
workdir=/tmp/koji
mockdir=/var/lib/mock
mockuser=kojibuilder
mockhost=generic-linux-gnu
user=$KOJI_MASTER_FQDN
server=$KOJI_URL/kojihub
topurl=$KOJI_URL/kojifiles
use_createrepo_c=True
allowed_scms=$KOJI_SCMS
cert = $KOJI_PKI_DIR/$KOJI_MASTER_FQDN.pem
ca = $KOJI_PKI_DIR/koji_ca_cert.crt
serverca = $KOJI_PKI_DIR/koji_ca_cert.crt
EOF
fi

if env | grep -q proxy; then
	echo "yum_proxy = $https_proxy" >> /etc/kojid/kojid.conf
	mkdir -p /etc/systemd/system/kojid.service.d
	cat > /etc/systemd/system/kojid.service.d/00-proxy.conf <<- EOF
	[Service]
	Environment=http_proxy=$http_proxy
	Environment=https_proxy=$https_proxy
	Environment=no_proxy=$no_proxy
	EOF
	systemctl daemon-reload
fi

mkdir -p /config/logs/kojid
if [ -f /var/log/kojid.log -a ! -L /var/log/kojid.log ] ; then
	mv /var/log/kojid.log /config/logs/kojid/
fi
touch /config/logs/kojid/kojid.log
if [ ! -L /var/log/kojid.log ] ; then
	ln -s /config/logs/kojid/kojid.log /var/log/kojid.log
fi
systemctl enable --now kojid
