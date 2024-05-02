#!/bin/bash

set -xe
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

while [ ! -d $KOJI_DIR ] ; do
	inotifywait -e create $(dirname $KOJI_DIR) 
done
while [ ! -d $KOJI_DIR/repos ] ; do
	inotifywait -e create $KOJI_DIR
done

while [ -z "$(ls $KOJI_DIR/repos)" ] ; do
	inotifywait -e create $KOJI_DIR/repos
done

while true; do
   NEW=0
   for repo in $(ls $KOJI_DIR/repos); do 
	TAG_NAME=$(echo $repo | sed -e "s,dist-,," | sed -s "s,-build,,")
	if [ ! -e /etc/mash/$TAG_NAME.mash ] ; then
	       NEW=1
	       cat > /etc/mash/"$TAG_NAME".mash <<- EOF
[$TAG_NAME]
rpm_path = %(arch)s/os/Packages
repodata_path = %(arch)s/os/
source_path = source/SRPMS
debuginfo = True
multilib = False
multilib_method = devel
tag = dist-$TAG_NAME
inherit = True
strict_keys = False
arches = i386 x86_64 
EOF
	fi
	if [ ! -e /etc/systemd/system/mash-$TAG_NAME.service ] ; then
		cat > /etc/systemd/system/mash-$TAG_NAME.service <<- EOF
[Unit]
Description=Mash script to loop local repository creation for local image builds

[Service]
Environment=MASH_TAG_NAME=$TAG_NAME
User=kojiadmin
Group=kojiadmin
ExecStart=$MASH_SCRIPT_DIR/mash.sh
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
	sudo systemctl daemon-reload
	sudo systemctl enable --now mash-$TAG_NAME
        sleep 30
        sudo systemctl enable --now mash-$TAG_NAME
	fi

    done
    if [ "$NEW" = "0" ] ; then
       inotifywait -e create $KOJI_DIR/repos
       sleep 10
    fi	
done



