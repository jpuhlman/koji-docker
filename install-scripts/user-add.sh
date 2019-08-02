#!/bin/bash
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
ADMIN_KOJI_DIR="$(echo ~kojiadmin)"/.koji
if [ -e /etc/koji/user.list ] ; then
	cat /etc/koji/user.list | grep -v "^#" | while read user; do
	    if [ ! -e $KOJI_PKI_DIR/$user.pem ] ; then
		    pushd $KOJI_PKI_DIR
		      ./gencert.sh $user "/C=$COUNTRY_CODE/ST=$STATE/L=$LOCATION/O=$ORGANIZATION/OU=$ORG_UNIT/CN=$user"
		    popd
	    fi
	    mkdir -p "$COMMON_CONFIG"/users/$user
	    cp -f "$KOJI_PKI_DIR"/koji_ca_cert.crt "$COMMON_CONFIG"/users/$user/clientca.crt
	    cp -f "$KOJI_PKI_DIR"/koji_ca_cert.crt "$COMMON_CONFIG"/users/$user/serverca.crt
	    cp -f "$KOJI_PKI_DIR"/$user.pem "$COMMON_CONFIG"/users/$user/client.crt
	    cp -f "$ADMIN_KOJI_DIR"/config $COMMON_CONFIG/users/$user/
        done 
fi

