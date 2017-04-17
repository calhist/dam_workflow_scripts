#!/bin/bash

USAGE="Usage: $(basename $0) -i <input directory> -c <collection name> -m <content model>"

input=
output=$(mktemp -d --tmpdir=/tmp $(basename $0 .sh).XXXX)

function cleanup {
	rm -rf $output
	echo "Deleted temp working directory $output"
}

trap cleanup EXIT

while getopts "i:c:" opt; do
        case $opt in
        i)
                input=$OPTARG
                ;;
        c)
                collection=$OPTARG
                ;;
        m)
                model=$OPTARG
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

if [ ${input: -5} != ".bags" ]; then
        echo "${input}: not a directory ending with '.bags'."
        exit 1
fi

drush=/home/ubuntu/.config/composer/vendor/bin/drush

if [ ! -x ${drush} ]; then
        echo "${drush}: not found."
        exit 1
fi

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

for i in $(ls $input/*/data/*|egrep '.[jpg|tif|png$]'); do
	bag=$(basename $i .tif)
	dir=$(dirname $i)
	tif=$(basename $i)
	xml=$(basename $i .tif).xml

	echo cp $dir/$tif $output/$tif

	if [ -f $dir/$xml ]; then
		echo cp $dir/$xml $output/$xml
	fi
done

echo drush \
	--root=/var/www/drupal7 \
	--user=admin \
	--uri=http://default \
	islandora_batch_scan_preprocess \
	--content_models=$model \
	--parent=$collection \
	--type=directory \
	--target=$output

#echo drush \
#	--root=/var/www/drupal7 \
#	--user=admin \
#	--uri=http://default \
#	islandora_batch_ingest


