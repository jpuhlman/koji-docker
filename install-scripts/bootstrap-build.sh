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

if [[ -n "$SRC_RPM_DIR" && -n "$BIN_RPM_DIR" ]]; then
	find "$SRC_RPM_DIR" -name '*.src.rpm' | xargs -n 1 -I {} sudo -u kojiadmin koji import {}
	find "$BIN_RPM_DIR" -name "*.$RPM_ARCH.rpm" | xargs -n 1 -I {} sudo -u kojiadmin koji import {}
	if [[ -n "$DEBUG_RPM_DIR" ]]; then
		find "$DEBUG_RPM_DIR" -name "*.$RPM_ARCH.rpm" | xargs -n 1 -I {} sudo -u kojiadmin koji import {}
	fi
fi
sudo -u kojiadmin koji add-tag dist-"$TAG_NAME"
sudo -u kojiadmin koji edit-tag dist-"$TAG_NAME" -x mock.package_manager=dnf
if [[ -n "$SRC_RPM_DIR" && -n "$BIN_RPM_DIR" ]]; then
	sudo -u kojiadmin koji list-pkgs --quiet | xargs -I {} sudo -u kojiadmin koji add-pkg --owner kojiadmin dist-"$TAG_NAME" {}
	sudo -u kojiadmin koji list-untagged | xargs -n 1 -I {} sudo -u kojiadmin koji call tagBuildBypass dist-"$TAG_NAME" {}
fi
sudo -u kojiadmin koji add-tag --parent dist-"$TAG_NAME" --arches "$RPM_ARCH" dist-"$TAG_NAME"-build
sudo -u kojiadmin koji add-target dist-"$TAG_NAME" dist-"$TAG_NAME"-build
sudo -u kojiadmin koji add-group dist-"$TAG_NAME"-build build
sudo -u kojiadmin koji add-group dist-"$TAG_NAME"-build srpm-build
sudo -u kojiadmin koji add-group-pkg dist-"$TAG_NAME"-build build autoconf automake binutils bzip2 coreutils diffutils gawk gcc gettext git glibc-devel glibc-common glibc-utils grep gzip hostname libc6-dev libcap libtool kernel-headers m4 make setup nss-altfiles patch pigz pkgconfig rpm-build sed shadow-utils systemd-libs tar unzip which xz
# clr-rpm-config

sudo -u kojiadmin koji add-group-pkg dist-"$TAG_NAME"-build srpm-build coreutils cpio curl git glibc-utils grep gzip make rpm-build sed shadow-utils tar unzip wget xz
# plzip
if [[ -n "$EXTERNAL_REPO" ]]; then
	sudo -u kojiadmin koji add-external-repo -t dist-"$TAG_NAME"-build dist-"$TAG_NAME"-external-repo "$EXTERNAL_REPO"
fi
sudo -u kojiadmin koji regen-repo dist-"$TAG_NAME"-build
