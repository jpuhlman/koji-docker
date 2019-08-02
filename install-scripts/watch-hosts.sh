#!/bin/bash
set -e
ADD_HOSTS=/usr/share/koji-docker/add-hosts.sh
HOSTSFILE=/tmp/koji-hosts

sudo -u kojiadmin koji list-hosts | grep -v ^Hostname | while read A B C D; do echo $A; done > $HOSTSFILE
if [ ! -e $HOSTSFILE.old ] ; then
	$ADD_HOSTS
	mv $HOSTSFILE $HOSTSFILE.old
	exit 0
fi
if [ -n "$(diff $HOSTSFILE.old $HOSTSFILE)" ] ; then
	$ADD_HOSTS
	mv $HOSTSFILE $HOSTSFILE.old
fi

