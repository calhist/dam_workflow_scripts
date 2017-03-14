#!/bin/sh

# use to backup islandora remotely

if [ "Xroot" != "X${LOGNAME}" ]; then
	echo "Must be run as user 'root'."
	exit
fi

host=$1

echo ${host} | egrep '^[a-z][-a-z0-9]+$' > /dev/null

if [ $? -ne 0 ]; then
	echo "invalid host: [${host}]"
	exit
fi

domain=$2

echo ${domain} | egrep '^[a-z]+\.utexas\.edu$' > /dev/null

if [ $? -ne 0 ]; then
	echo "invalid domain: ${domain}"
	exit
fi

ec2="/usr/local/bin/aws ec2"

id=`${ec2} describe-instances \
	--filters Name=instance-state-name,Values="stopped,running" \
		  Name=tag:Name,Values=${host} \
		  Name=tag:Domain,Values=${domain} \
	--query   Reservations[].Instances[].InstanceId`

echo ${id} | egrep '^i-[a-z0-9]+$' > /dev/null

if [ $? -ne 0 ]; then
	echo "invalid instance id: ${id}"
	exit
fi

# save current state

state=`${ec2} describe-instances \
	--filters Name=instance-id,Values=${id} \
	--query   Reservations[].Instances[].State.Name`

if [ "${state}" = 'stopped' ]; then
	${ec2} start-instances --instance-ids ${id} 2>&1
	n=1
	until [ $n -eq 60 ]; do
		s=`${ec2} describe-instances \
			--filters Name=instance-id,Values=${id} \
			--query   Reservations[].Instances[].State.Name`
	        if [ "$s" = 'running' ]; then
	                n=60
	        else
	                sleep 1
	                n=`expr $n + 1`
	        fi
	done
fi

date=`date +"%Y-%m-%d"`

backups=lib-itas-backups/islandora

ssh="ssh -t -t -i /.ssh/us-west-2.pem ${host}"

s3="/usr/local/bin/aws s3"

${ssh} 'sudo service tomcat7 stop' > /dev/null

#
# Fedora
#

${ssh} 'test -d /usr/local/fedora/data'

if [ $? = 0 ]; then
	${ssh} "${s3} \
		--quiet \
		--delete \
		sync /usr/local/fedora/data/ s3://${backups}/${host}.${date}/fedora-data/"
else
	echo "fedora is missing"
	exit
fi

a=`${ssh} 'find /usr/local/fedora/data/ -type f| wc -l'`

b=`${ssh} "${s3} ls --recursive s3://${backups}/${host}.${date}/fedora-data/ | wc -l"`

if [ $a != $b ]; then
	echo "fedora backup failed"
	exit 
fi

#
# Solr
#

${ssh} 'test -d /usr/local/solr'

if [ $? = 0 ]; then
	${ssh} "${s3} \
		--quiet \
		--delete \
		sync /usr/local/solr/ s3://${backups}/${host}.${date}/solr/"
else
	echo "solr is missing"
	exit
fi

${ssh} 'sudo service tomcat7 start' > /dev/null

sleep 30

#
# Drupal
#

${ssh} 'test -f /home/ubuntu/.composer/vendor/bin/drush'

if [ $? = 0 ]; then
	${ssh} 'drush -q -y cache-clear all'

	${ssh} 'drush -q -y watchdog-delete all'

	${ssh} 'sudo service apache2 stop' > /dev/null

	list=enabled-modules.txt

	${ssh} "drush -q pm-list --status=enabled --format=list > /tmp/${list}"

	${ssh} "test -f /tmp/${list}"

	if [ $? = 0 ]; then
		${ssh} "${s3} \
			--quiet \
			cp /tmp/${list} s3://${backups}/${host}.${date}/${list}"

		${ssh} "rm /tmp/${list}"
	else
		echo "/tmp/${list} missing"
		exit
	fi

	archive=${host}.${date}.tar.gz

	${ssh} "drush -q archive-dump --overwrite --destination=/tmp/${archive}"

	${ssh} 'sudo service apache2 start' > /dev/null

	${ssh} "test -f /tmp/${archive}"

	if [ $? = 0 ]; then
		${ssh} "${s3} \
			--quiet \
			cp /tmp/${archive} s3://${backups}/${host}.${date}/${archive}"

		${ssh} "rm /tmp/${archive}"
	else
		echo "/tmp/${archive} missing"
		exit
	fi
else
	echo "drush is missing"
	exit
fi

if [ "${state}" = 'stopped' ]; then
	${ec2} stop-instances --instance-ids ${id} 2>&1
	n=1
	until [ $n -eq 60 ]; do
		s=`${ec2} describe-instances \
			--filters Name=instance-id,Values=${id} \
			--query   Reservations[].Instances[].State.Name`
	        if [ "$s" = 'stopped' ]; then
	                n=60
	        else
	                sleep 1
	                n=`expr $n + 1`
	        fi
	done
fi

# cleanup

k=7        # how many backups to keep

list=`${s3} ls s3://${backups}/ | sed "s| *PRE ||" | perl -ne "print if m|^${host}\.\d{4}-\d{2}-\d{2}/$|" |sort -r`

for i in ${list}; do
	if [ ${k} -gt 0 ]; then
		k=`expr ${k} - 1`
	else
		${s3} rm s3://${backups}/${i}
	fi
done

touch -c -t `date +"%Y%m010000.00"` $0
