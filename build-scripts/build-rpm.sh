#!/bin/bash -x
set -e
MV_CUSTOM_RPM=git://gitcentos.mvista.com/centos/upstream/updated-clearlinux-pkgs
USER_EMAIL="jenkins@mvista.com"
USER_NAME="jenkins"
BUILD_LOCATION=`pwd`/rpm-build
COPY_LOCATION=`pwd`
sudo swupd bundle-add os-clr-on-clr
if [ ! -e user-setup.sh ] ; then
	curl -O https://raw.githubusercontent.com/clearlinux/common/master/user-setup.sh
	chmod +x user-setup.sh
fi
if [ ! -d $BUILD_LOCATION ] ; then
	./user-setup.sh --directory $BUILD_LOCATION
fi
if [ -z "$(git config --global user.email)" ] ; then
	git config --global user.email "$USER_EMAIL"
fi

if [ -z "$(git config --global user.jenkins)" ] ; then
	git config --global user.name "$USER_NAME"
fi
PACKAGES="rpm librepo libsolv libdnf dnf libmodulemd createrepo_c"
mkdir -p $COPY_LOCATION/rpms/
for package in $PACKAGES; do
    pushd $BUILD_LOCATION
	if [ ! -d packages/$package ] ; then
		make clone_$package PKG_BASE_URL=$MV_CUSTOM_RPM
	fi
	pushd packages/$package
		if [ ! -d rpms -o -z "$(ls rpms/*.rpm)" ] ; then
			make build
			make repoenable
			make repoadd
		fi
		RPMSDIR=$(readlink -f rpms)
	popd
    popd
    cp -a $RPMSDIR $COPY_LOCATION
done
