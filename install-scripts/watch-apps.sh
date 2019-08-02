#!/bin/bash
ADD_APPS=/usr/share/koji-docker/package-add.sh
APPS_FILE=/etc/koji/app.list

if [ -e $APPS_FILE ] ; then
	inotifywait -e modify $APPS_FILE
	$ADD_APPS
fi
