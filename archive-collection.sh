#!/bin/bash

USAGE="Usage: $(basename $0) -c <collection> [-f] [-n]"

cleanup () {
	[ -d ${output} ] && rm -r $output
}

trap 'cleanup' EXIT HUP INT QUIT TERM

source=704869648062-output
input=
output=
archive=704869648062-archive
force=0
dryrun=0

while getopts "c:fn" opt; do
	case $opt in
	c)
		input=$OPTARG
		;;
	f)
		force=1
		;;
	n)
		dryrun=1
		;;
 	\?)
		echo ${USAGE}
		exit 1
	esac
done

aws=~/.local/bin/aws

if [ ! -x ${aws} ]; then
	echo "${aws}: not found."
	exit 1
fi

bagit=~/.local/bin/bagit.py

if [ ! -x ${bagit} ]; then
	echo "${bagit}: not found."
	exit 1
fi

if [ "${input}" == '' ]; then
	echo ${USAGE}
	echo
	aws s3 ls ${source} | grep '.bags' | sed 's| *PRE |    |'
	exit 1
fi

aws s3 ls ${source}/${input} > /dev/null

if [ $? -gt 0 ]; then
	echo "${input}: not a collection in ${source}."
	exit 1
fi

output=${input}

if [ -d $output ]; then
	if [ $force -eq 1 ]; then
		rm -rf $output
	else
		echo "${output}: directory already exists."
		exit 1
	fi
fi

aws s3 sync s3://${source}/${input} ${output}

for i in $(ls $output); do
	$bagit --validate $output/$i

	if [ $? -ne 0 ]; then
		echo
		echo "Directory must a directory of valid bags."
 		exit 1
	fi
done

echo
echo Ready to save to ${output} to ${archive}/${output}
echo

printf "Proceed with sync ? (y or n): "
read ln

if [ ${ln} != 'y' ]; then
	echo
	exit 1
fi

echo

if [ $dryrun -eq 1 ]; then
	aws s3 sync ${output} s3://${archive}/${output} --dryrun
else
	aws s3 sync ${output} s3://${archive}/${output}
fi
