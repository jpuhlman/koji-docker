#!/bin/bash
ADD_USER=/usr/share/koji-docker/user-add.sh
USER_FILE=/etc/koji/user.list


if [ -e $USER_FILE ] ; then
	inotifywait -e modify $USER_FILE
	$ADD_USER
fi
