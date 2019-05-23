#!/bin/sh

#if [ "Xroot" != "X${LOGNAME}" ]; then
#	echo "Must be run as user 'root'."
#	exit
#fi

#host=$(hostname | cut -d. -f1)
host=islandora-chs

echo ${host} | egrep '^[a-z][-a-z0-9]+$' > /dev/null

if [ $? -ne 0 ]; then
        echo "invalid host: [${host}]"
        exit
fi

if [ ! -x /usr/bin/aws ]; then
	echo 'File note found: aws.'
	exit
fi

if [ ! -x /usr/bin/drush ]; then
	echo 'File note found: drush.'
	exit
fi

date=`date +"%Y-%m-%d"`

backups=chs-backups

cp="aws s3 cp --quiet"
rm="aws s3 rm --quiet"
ls="aws s3 ls"

#
# Drupal
#

sudo drush -y cache-clear all

sudo drush -y watchdog-delete --severity=notice

#sudo service apache2 stop > /dev/null

list=enabled-modules.txt

sudo drush pm-list --status=enabled --format=list > /tmp/${list}

if [ -f /tmp/${list} ]; then
	aws s3 cp /tmp/${list} s3://${backups}/${host}/${date}/${list}
	sudo rm /tmp/${list}
else
	echo "/tmp/${list} missing"
	exit
fi

archive=${host}.${date}.tar.gz

sudo drush archive-dump --overwrite --destination=/tmp/${archive}

#service apache2 start > /dev/null

if [ -f /tmp/${archive} ]; then
	aws s3 cp /tmp/${archive} s3://${backups}/${host}/${date}/${archive}
	sudo rm /tmp/${archive}
else
	echo "/tmp/${archive} missing"
	exit
fi
