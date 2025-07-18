#!/bin/bash
TMPFILE=$(mktemp)
/usr/bin/hostenv.sh > $TMPFILE
source $TMPFILE
rm $TMPFILE
set -ex
function finish {
 echo -en "\n## Caught EXIT; Clean up kojid and Exit \n"
 ps aux | grep kojid | grep -v grep | while read USER PID REST; do kill -s TERM $PID; done
 wait %1
 exit 0
}
cd /root
trap finish EXIT
CONFIGFILES="clientca.crt  client.crt  config  serverca.crt"
KOJI_MOUNT=/mnt/koji
PATH_TO_CONFIGS=hosts/
CONFIGS=$KOJI_MOUNT/$PATH_TO_CONFIGS
if [ -z "$KOJI_BUILDER" -o -z "$KOJI_HOST" ] ; then
	echo 2>&1
	echo ERROR: You need to specify the KOJI_HOST and KOJI_BUILDER values when starting up the container. 2>&1
	echo 'ERROR: add -e KOJI_HOST=<fully qualified domain name for the koji hub> -e KOJI_BUILDER=<fully qualified domain name for this builder>' 2>&1
        exit 1
fi
echo "Koji Hub server           : $KOJI_HOST"
echo "Koji builder(this machine): $KOJI_BUILDER"

if [ -z "$GIT_FQND" ] ; then
   export GIT_FQDN=""
fi
if [ -z "$GIT_PATH" ] ; then
   export GIT_PATH=""
fi
if [ -z "$GIT_GETSOURCES" ] ; then
        export GIT_GETSOURCES=""
fi
if [ -z "$KOJI_SCMS" ] ; then
        KOJI_SCMS=$GIT_FQDN:$GIT_PATH$GIT_GETSOURCES
fi
if [ "$KOJI_SCMS" = ":" ] ; then
   echo "You must define what the SCMS the koji builder can use."
   echo "You can define this with KOJI_SCMS by defining the whole string."
   echo "You can also define it with:"
   echo "GIT_FQND - host of your git server"
   echo "GIT_PATH - relitve path to your packages"
   echo "GIT_GETSOURCES - how to get sources"
   echo "This sets the SCMS to \$GIT_FQDN:\$GIT_PATH\$GIT_GETSOURCES"
   echo "These values should be passed to the container via --env"
   exit 1 
fi

mkdir -p .koji
pushd .koji

for config in $CONFIGFILES; do
    i=0
    while ! curl -q -O http://$KOJI_HOST/kojifiles/hosts/kojiadmin/$config; do 
          i=$(($i + 1))
          if [ "$i" == "10" ] ; then
             exit 1
          fi
          sleep 3
    done
done
popd

if [ -z "$KOJI_BUILDER_CAPACITY" ] ; then
   KOJI_BUILDER_CAPACITY=16
fi

if [ -z "$(koji list-hosts | grep $KOJI_BUILDER)" ] ; then
   ARCH="$(koji list-hosts | grep -v Hostname | while read A B C D E F; do echo $E; done | sort -u | tr '\n' ',' | sed 's/,$//' | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/^,//')"
   koji add-host $KOJI_BUILDER "$(echo  $ARCH | sed s/,/\ /g)"
   koji edit-host $KOJI_BUILDER --capacity $KOJI_BUILDER_CAPACITY 
fi
CONFIG_URL=http://$KOJI_HOST/kojifiles/hosts/$KOJI_BUILDER
while ! curl -O $CONFIG_URL/client.ca ; do
      echo waiting for client certifcates from server
      sleep 10
done

mkdir -p /etc/kojid
if [ ! -e /etc/kojid/client.ca ] ; then
   pushd /etc/kojid/
     while true; do
        curl -O $CONFIG_URL/client.ca 
        if [ -n "$(cat client.ca | grep 'PRIVATE KEY')" ] ; then
           break
        else
           echo Not a valid client certificate, remove and wait.
           rm -f client.ca
        fi
        sleep 10
     done
     cat client.ca
   popd
fi

while ! curl -O $CONFIG_URL/serverca.crt ; do
      echo waiting for client certifcates from server
      sleep 10
done

if [ ! -e /etc/kojid/serverca.crt ] ; then
   pushd /etc/kojid/
     while true; do
        curl -O $CONFIG_URL/serverca.crt
        if [ -n "$(cat serverca.crt | grep 'END CERTIFICATE')" ] ; then
           break
        else
           echo Not a valid server certificate, remove and wait.
           rm -f serverca.crt
        fi
        sleep 10
     done
     cat serverca.crt
   popd
fi 

mkdir -p /etc/ca-certs/trusted
pushd /etc/ca-certs/trusted
		rm -f serverca.crt
    	curl -O $CONFIG_URL/serverca.crt
popd

while true; do
        if update-ca-trust; then
                break
        fi
		pushd /etc/pki/ca-trust/source/anchors/
		        rm -f serverca.crt
    			curl -O $CONFIG_URL/serverca.crt
		popd
done

if [ -z "$KOJI_BUILDER_MAXJOBS" ] ; then
	KOJI_BUILDER_MAXJOBS=16
fi
cat > /etc/kojid/kojid.conf <<- EOF
[kojid]
sleeptime=5
retry_interval=30
max_retries=5
maxjobs=$KOJI_BUILDER_MAXJOBS
workdir=/tmp/koji
mockdir=/var/lib/mock
mockuser=kojibuilder
mockhost=generic-linux-gnu
user=$KOJI_BUILDER
server=https://$KOJI_HOST/kojihub
topurl=http://$KOJI_HOST/kojifiles
use_createrepo_c=True
allowed_scms=$KOJI_SCMS
cert = /etc/kojid/client.ca
serverca = /etc/kojid/serverca.crt
packager = MontaVista Software
vendor = MontaVista Software
EOF

mkdir -p /etc/mock/koji
mkdir -p /var/lib/mock
chown -R root:mock /var/lib/mock
# Setup User Accounts
if [ -z "$(id kojibuilder)" ] ; then
        useradd -r kojibuilder
fi
usermod -G mock kojibuilder

#Add nobest to mock runs:
sed -e "s/\\['--setopt=deltarpm=False'/\\['--nobest',\\ '--setopt=deltarpm=False'/" -i /usr/lib/python*/site-packages/mockbuild/package_manager.py || true
update-crypto-policies --set LEGACY || true
dnf install -y git || true
export NSS_STRICT_NOFORK=DISABLED
/usr/sbin/kojid --fg --force-lock --verbose &
while true; do sleep 10; done
