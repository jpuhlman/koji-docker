#!/bin/bash -x

MV_CUSTOM_RPM=git://gitcentos.mvista.com/centos/upstream/utils
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
pushd $BUILD_LOCATION
	if [ ! -d packages/rpm ] ; then
		make clone_rpm PKG_BASE_URL=$MV_CUSTOM_RPM
	fi
	pushd packages/rpm
		if [ ! -d rpms -o -z "$(ls rpms/*.rpm)" ] ; then
			make build
		fi
		RPMSDIR=$(readlink -f rpms)
	popd
popd
cp -a $RPMSDIR $COPY_LOCATION
