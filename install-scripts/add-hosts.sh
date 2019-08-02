#!/bin/bash
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

if [ -e /tmp/koji-hosts ] ; then
 cat /tmp/koji-hosts | while read HOST B; do 

   mkdir -p $KOJI_DIR/hosts/$HOST
   if [ ! -e $KOJI_PKI_DIR/$HOST.pem ] ; then
	   pushd $KOJI_PKI_DIR
              ./gencert.sh "$HOST" "/C=$COUNTRY_CODE/ST=$STATE/L=$LOCATION/O=$ORGANIZATION/CN=$HOST" 
	   popd
   fi
   if [ ! -e $KOJI_DIR/hosts/$HOST/client.ca ] ; then
	   cp $KOJI_PKI_DIR/$HOST.pem $KOJI_DIR/hosts/$HOST/client.ca
   fi
   if [ ! -e $KOJI_DIR/host/$HOST/serverca.crt ] ; then
	   cp $KOJI_PKI_DIR/koji_ca_cert.crt $KOJI_DIR/hosts/$HOST/serverca.crt
   fi
 done
fi
