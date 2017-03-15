#!/bin/sh

USAGE="Usage: drupal7-restore <archive files or blank for list>"

if [ "Xubuntu" != "X${LOGNAME}" ]; then
	echo "Must be run as user 'ubuntu'."
	exit
fi

host=$(hostname | cut -d. -f1)

echo ${host} | egrep '^[a-z][-a-z0-9]+$' > /dev/null

if [ $? -ne 0 ]; then
	echo "invalid host: [${host}]"
	exit
fi

s3="/usr/local/bin/aws s3"

date=`date +"%Y-%m-%d"`

backups=oei-backups

if [ $# -eq 0 ]; then
	printf "\n"
	printf "$USAGE\n"
	printf "\n"
	printf "Possible restore archives:\n"
	${aws} ${s3} ls --recursive s3://${backups}/${host}/ | grep tar | awk '{print $4}' | sort | sed 's|^|    |'
	exit 2
fi

backup=$1

if [ "X`${s3} ls s3://${backups}/${backup}`" = 'X' ]; then
	echo "Archive not found: ${backup}"
	exit 2 
fi

printf "Restore ${backup} ? (y or n): "
read ln

if [ ${ln} != 'y' ]; then
	exit
fi

drush=/home/ubuntu/.composer/vendor/bin/drush

if [ ! -x ${drush} ]; then
	echo "drush is missing"
	exit
fi

sudo service apache2 stop

docroot=/var/www/html

[ -d ${docroot} ] && sudo rm -rf ${docroot}

[ -f /tmp/${backup} ] && rm /tmp/${backup}

${s3} cp s3://${backups}/${backup} /tmp/${backup}

${drush} archive-restore --destination=${docroot} /tmp/${backup}

#[ -f /tmp/${backup}.tar.gz ] && rm /tmp/${backup}.tar.gz
#
#[ -d /tmp/${backup}        ] && rm -rf /tmp/${backup}
#
#${s3} cp s3://${backups}/${backup}/${backup}.tar.gz /tmp/${backup}.tar.gz 
#
#${drush} archive-restore --destination=${docroot} /tmp/${backup}.tar.gz

sudo chown -R ubuntu:www-data ${docroot}/sites/default/files

sudo chown    ubuntu:www-data ${docroot}/sites/default/settings.php

sudo service apache2 start
