#!/bin/bash

USAGE="Usage: $(basename $0) -i <input directory>"

#production=chsadmin@69.164.147.253:60222
production=chs1

input=
output=

while getopts "i:" opt; do
	case $opt in
        i)
                input=$OPTARG
                ;;
        \?)
                echo ${USAGE}
                exit 1
        esac
done

if [ "${input}" == '' ]; then
        echo ${USAGE}
        exit 1
fi

if [ ! -d ${input} ]; then
        echo "${input}: not a directory."
        exit 1
fi

input=$(cd ${input}; pwd) # convert to absolute path
output=$(basename $input)

if [ ${input: -5} != ".bags" ]; then
        echo "${input}: not a directory ending with '.bags'."
        exit 1
fi

ssh $production "[ -d /data/$output ]"

if [ $? -eq 0 ]; then
	echo "${production}:/data/${output}: already exists."
	exit 1
fi

# https://github.com/LibraryOfCongress/bagit-python

bagit=/usr/local/bin/bagit.py

if [ ! -x ${bagit} ]; then
        echo "${bagit}: not found."
        exit 1
fi

for i in $(ls $input); do
	$bagit --validate $input/$i

	if [ $? -ne 0 ]; then
		echo
		echo "Input directory must a directory of valid bags."
		exit 1
	fi
done

echo

echo rsync -nav $input/ $production:/home/ubuntu/$output/
