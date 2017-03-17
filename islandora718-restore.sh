#!/bin/bash

USAGE="Usage: islandora715-upgrade <archive files or blank for list>"

if [ "Xubuntu" != "X${LOGNAME}" ]; then
	echo "Must be run as user 'ubuntu'."
	exit
fi

aws=/usr/local/bin/aws

if [ ! -x ${aws} ]; then
	echo "aws is missing"
	exit
fi

rsync=/usr/bin/rsync

if [ ! -x ${rsync} ]; then
	echo "rsync is missing"
	exit
fi

rsync="rsync -a --delete"

host=`hostname|cut -d. -f1`

echo ${host} | grep -E '^[a-z][a-z0-9-]+$' > /dev/null

if [ $? -ne 0 ]; then
	echo "invalid host: ${host}"
	exit
fi

domain=`hostname|cut -d. -f2-`

echo ${domain} | grep -E '^[a-z]+\.utexas\.edu$' > /dev/null

if [ $? -ne 0 ]; then
	echo "invalid domain: ${domain}"
	exit
fi

date=`date +"%Y-%m-%d"`

backups=lib-itas-backups/islandora

if [ ! -d /usr/local/fedora ]; then
	echo "fedora home is missing"
	exit
fi

if [ $# -eq 0 ]; then
	printf "\n"
	printf "$USAGE\n"
	printf "\n"
	printf "Possible archives:\n"
	${aws} s3 ls s3://${backups}/ | sed 's| *PRE ||' | sed 's|/$||' | sort | sed 's|^|    |'
	exit 2
fi

backup=$1

if [ "X`${aws} s3 ls s3://${backups}/${backup}/`" = 'X' ]; then
	echo "Archive not found: ${backup}"
	exit 2 
fi

printf "Upgrade from ${backup} ? (y or n): "
read ln

if [ ${ln} != 'y' ]; then
	exit
fi

#
# Fedora
#

fedora_upgrade=1

if [ $fedora_upgrade -eq 1 ]; then
	if [ ! -d /usr/local/fedora/data ]; then
		echo "fedora missing"
		exit
	fi

	sudo service tomcat7 stop

	echo restoring s3://${backups}/${backup}/fedora-data

	sudo chown -R ubuntu:ubuntu /usr/local/fedora/data

	${aws} s3 \
		--quiet \
		sync s3://${backups}/${backup}/fedora-data/ /usr/local/fedora/data/ \
		--delete

	sudo chown -R tomcat7:tomcat7 /usr/local/fedora/data

	expect=/usr/bin/expect

	if [ ! -x ${expect} ]; then
		sudo apt-get -qq -y install expect
	fi

	echo 'spawn /usr/local/fedora/server/bin/fedora-rebuild.sh'  > rebuild
	echo 'expect "What do you want to do?*Enter (1-3) -->"'     >> rebuild
	echo 'send "1\r"'                                           >> rebuild
	echo 'expect "Start rebuilding?*Enter (1-2) -->"'           >> rebuild
	echo 'send "1\r"'                                           >> rebuild
	echo 'interact'                                             >> rebuild

	sudo -E -u tomcat7 expect rebuild

	echo 'spawn /usr/local/fedora/server/bin/fedora-rebuild.sh'  > rebuild
	echo 'expect "What do you want to do?*Enter (1-3) -->"'     >> rebuild
	echo 'send "2\r"'                                           >> rebuild
	echo 'expect "Start rebuilding?*Enter (1-2) -->"'           >> rebuild
	echo 'send "1\r"'                                           >> rebuild
	echo 'interact'                                             >> rebuild

	sudo -E -u tomcat7 expect rebuild

	rm rebuild

	sudo service tomcat7 start

	sleep 30
fi

#
# Solr
#

solr_upgrade=0

if [ $solr_upgrade -eq 1 ]; then
	if [ ! -d /usr/local/solr/collection1 ]; then
		echo "solr missing"
		exit
	fi

	[ -d /tmp/solr ] && rm -rf /tmp/solr

	${aws} s3 \
		--quiet \
		sync s3://${backups}/${backup}/solr/ /tmp/solr/
fi

#
# Drupal
#

drush=/home/ubuntu/.composer/vendor/bin/drush

if [ ! -x ${drush} ]; then
	echo "drush is missing"
	exit
fi

${drush} pm-list --format=list|sort > /tmp/installed-modules.txt

sudo service apache2 stop

docroot=/var/www/html

[ -f /tmp/${backup}.tar.gz ] && rm     /tmp/${backup}.tar.gz

[ -d /tmp/${backup}        ] && rm -rf /tmp/${backup}

${aws} s3 cp s3://${backups}/${backup}/enabled-modules.txt /tmp/enabled-modules.txt

${aws} s3 cp s3://${backups}/${backup}/${backup}.tar.gz /tmp/${backup}.tar.gz 

if [ -f /tmp/${backup}.tar.gz -a -f /tmp/enabled-modules.txt ]; then
	mkdir /tmp/${backup}
	tar xzf /tmp/${backup}.tar.gz -C /tmp/${backup}
	rm /tmp/${backup}.tar.gz

	sudo chown -R ubuntu:ubuntu ${docroot}

	sudo rsync -a --delete \
		/tmp/${backup}/drupal7/sites/default/files/ ${docroot}/sites/default/files/

	sudo chown -R ubuntu:www-data ${docroot}/sites/default/files

	sudo chown ubuntu:www-data ${docroot}/sites/default/settings.php

	for i in `cat /tmp/enabled-modules.txt`; do
		echo $i
		grep "^$i$" /tmp/installed-modules.txt > /dev/null
		if [ $? -ne 0 ]; then
			if [ "$i" = 'entity_token' ]; then
				echo "Skipping entity_token, part of entity module"
			else
				${drush} dl $i
			fi
		fi
	done

	${drush} sql-cli < /tmp/${backup}/DRUPAL7.sql

	${drush} -y updb

	cat /tmp/enabled-modules.txt|sort                    > /tmp/a.txt
	${drush} pm-list --status=enabled --format=list|sort > /tmp/b.txt
	diff /tmp/a.txt /tmp/b.txt

	if [ $? -ne 0 ]; then
		echo "Failed to synchronize modules"
		exit
	fi
fi

sudo service apache2 start

sleep 10

touch -c -t `date +"%Y%m010000.00"` $0
