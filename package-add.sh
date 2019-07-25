#!/bin/bash

TMPFILE=$(mktemp)
sudo -u kojiadmin koji list-pkgs > $TMPFILE
if [ -z "$(grep 'no matching packages' $TMPFILE)" ] ; then
	cat /etc/koji/app.list | while read package; do
	  if [ -z "$(grep ^$package$ $TMPFILE)" ] ; then
	     sudo -u kojiadmin koji add-pkg dist-"$TAG_NAME" --owner=kojiadmin $package
	  fi
	done
else
	cat /etc/koji/app.list | xargs sudo -u kojiadmin koji add-pkg dist-"$TAG_NAME" --owner=kojiadmin
fi
rm -f $TMPFILE
