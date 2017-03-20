#!/bin/sh

host=$(hostname)

echo ${host} | egrep '^[a-zA-Z][-a-zA-Z0-9]+$' > /dev/null

if [ $? -ne 0 ]; then
	echo "invalid host: [${host}]"
	exit
fi

date=`date +"%Y-%m-%d"`

backups=chs-backups

#sudo service tomcat7 stop > /dev/null

#
# Fedora
#

if [ -d /usr/local/fedora/data ]; then
	aws s3 --delete sync /usr/local/fedora/data/ s3://${backups}/${host}.${date}/fedora-data/
else
	echo "fedora is missing"
	exit
fi

#a=`find /usr/local/fedora/data/ -type f | wc -l`
#b=`aws s3 ls s3://${backups}/${host}.${date}/fedora-data/ --recursive | wc -l`
#
#if [ $a != $b ]; then
#	echo "fedora backup failed"
#	exit 
#fi

#
# Solr
#

if [ -d /usr/local/fedora/solr ]; then
	aws s3 --delete sync /usr/local/fedora/solr/ s3://${backups}/${host}.${date}/solr/
else
	echo "solr is missing"
	exit
fi

#sudo service tomcat7 start > /dev/null
#
#sleep 30

#
# Drupal
#

if [ -x /usr/bin/drush ]; then
	sudo drush -q -y cache-clear all

	sudo drush -q -y watchdog-delete --severity=notice

	#sudo service apache2 stop > /dev/null

	list=enabled-modules.txt

	sudo drush pm-list --status=enabled --format=list > /tmp/${list}

	if [ -f /tmp/${list} ]; then
		aws s3 cp /tmp/${list} s3://${backups}/${host}.${date}/${list}
		rm /tmp/${list}
	else
		echo "/tmp/${list} missing"
		exit
	fi

	archive=${host}.${date}.tar.gz

	sudo drush archive-dump --overwrite --destination=/tmp/${archive}

	#sudo service apache2 start > /dev/null

	if [ -f /tmp/${archive} ]; then
		aws s3 cp /tmp/${archive} s3://${backups}/${host}.${date}/${archive}
		sudo rm /tmp/${archive}
	else
		echo "/tmp/${archive} missing"
		exit
	fi
else
	echo "drush is missing"
	exit
fi
