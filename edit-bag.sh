#!/bin/bash

USAGE="Usage: $(basename $0) -c <collection> -b <list of bags file> [-f]"

source=704869648062-archive
input=
output=
force=0

while getopts "c:b:f" opt; do
	case $opt in
	c)
		collection=${OPTARG%/} # remove trailing slash
		;;
	b)
		baglist=${OPTARG%/} # remove trailing slash
		;;
	f)
		force=1
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

if [ "${collection}" == '' ]; then
	echo ${USAGE}
	echo
	aws s3 ls ${source} | grep '.bags' | sed 's| *PRE |    |'
	exit 1
fi

if [ "${baglist}" == '' ]; then
	echo ${USAGE}
	echo
	aws s3 ls ${source}/${collection}/ | sed 's| *PRE |    |'
	exit 1
fi

if [ -f "${baglist}" ]; then
	for bag in $(cat ${baglist}); do
		aws s3 ls ${source}/${collection}/${bag}/ > /dev/null

		if [ $? -gt 0 ]; then
			echo "${collection}/${bag}: not a bag in ${source}/${collection}/."
			exit 1
		fi

		echo "${collection}/${bag} found"
	done
fi

output=${collection}

if [ -d $output ]; then
	if [ $force -eq 1 ]; then
		rm -rf $output
	else
		echo "${output}: directory already exists."
		exit 1
	fi
fi

for bag in $(cat ${baglist}); do
	aws s3 sync s3://${source}/${collection}/${bag} ${output}/${bag}
done

for i in $(ls $output); do
	$bagit --validate $output/$i

	if [ $? -ne 0 ]; then
		echo
		echo "Directory must a directory of valid bags."
		exit 1
	fi
done
