#!/bin/sh

# use to backup drupal remotely

host=$(echo $1 | cut -d. -f1)

domain=$(echo $1 | cut -d. -f2-)

echo ${host} | egrep '^[a-z][-a-z0-9]+$' > /dev/null

if [ $? -ne 0 ]; then
	echo "invalid host: [${host}]"
	exit
fi

echo ${domain} | egrep '^[a-z]+\.utexas\.edu$' > /dev/null

if [ $? -ne 0 ]; then
	echo "invalid domain: ${domain}"
	exit
fi

ec2="/usr/local/bin/aws ec2"

id=`${ec2} describe-instances \
	--output text \
	--filters Name=instance-state-name,Values="stopped,running" \
		  Name=tag:Host,Values=${host} \
		  Name=tag:Domain,Values=${domain} \
	--query   Reservations[].Instances[].InstanceId`

echo ${id} | egrep '^i-[a-z0-9]+$' > /dev/null

if [ $? -ne 0 ]; then
	echo "invalid instance id: ${id}"
	exit
fi

# save current state

state=$(${ec2} describe-instances \
	--output text \
	--filters Name=instance-id,Values=${id} \
	--query   Reservations[].Instances[].State.Name)

if [ "${state}" = 'stopped' ]; then
	out=`${ec2} start-instances --instance-ids ${id}`
	n=1
	until [ $n -eq 60 ]; do
		s=`${ec2} describe-instances \
			--output text \
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

backups=oei-backups

ssh="ssh ${host}"

cp="/usr/local/bin/aws s3 cp --quiet"
rm="/usr/local/bin/aws s3 rm --quiet"
ls="/usr/local/bin/aws s3 ls"

#
# Drupal
#

${ssh} 'test -f /home/ubuntu/.composer/vendor/bin/drush'

if [ $? = 0 ]; then
	drush="/home/ubuntu/.composer/vendor/bin/drush -q"

	${ssh} "sudo ${drush} -y cache-clear all"

	${ssh} "${drush} -y watchdog-delete all"

	${ssh} 'sudo service apache2 stop' > /dev/null

	list=enabled-modules.txt

	${ssh} "${drush} pm-list --status=enabled --format=list > /tmp/${list}"

	${ssh} "test -f /tmp/${list}"

	if [ $? = 0 ]; then
		${ssh} "${cp} /tmp/${list} s3://${backups}/${host}/${date}/${list}"
		${ssh} "rm /tmp/${list}"
	else
		echo "/tmp/${list} missing"
		exit
	fi

	archive=${host}.${date}.tar.gz

	${ssh} "${drush} archive-dump --overwrite --destination=/tmp/${archive}"

	${ssh} 'sudo service apache2 start' > /dev/null

	${ssh} "test -f /tmp/${archive}"

	if [ $? = 0 ]; then
		${ssh} "${cp} /tmp/${archive} s3://${backups}/${host}/${date}/${archive}"
		${ssh} "rm /tmp/${archive}"
	else
		echo "/tmp/${archive} missing"
		exit
	fi

	# cleanup

	k=7   # how many backups to keep

#	list=`${ssh} "${ls} s3://${backups}/${host}/" | sed "s| *PRE ||" | perl -ne "print if m|^${host}\.\d{4}-\d{2}-\d{2}/$|" |sort -r`
	list=`${ssh} "${ls} s3://${backups}/${host}/" | sed "s| *PRE ||" |sort -r`

	for i in ${list}; do
		if [ ${k} -gt 0 ]; then
			k=`expr ${k} - 1`
		else
			${ssh} "${rm} s3://${backups}/${host}/${i} --recursive"
		fi
	done
else
	echo "drush is missing"
	exit
fi

if [ "${state}" = 'stopped' ]; then
	out=`${ec2} stop-instances --instance-ids ${id}`
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
