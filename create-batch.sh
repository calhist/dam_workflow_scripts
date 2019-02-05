#!/bin/bash

USAGE="Usage: $(basename $0) -i <input directory> -c <collection pid> -m <content model pid>"

input=
output=

while getopts "i:c:m:" opt; do
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

output=${input/%.bags/.batch}

if [ -d ${output} ]; then
	rm -rf ${output}
fi

mkdir ${output}

if [[ ! $collection =~ ^.*:.* ]]; then
	echo "${collection}: invalid collection pid."
	exit 1
fi

if [[ ! $model =~ ^islandora:.* ]]; then
	echo "${model}: invalid model pid."
	exit 1
fi

drush=/home/ubuntu/.config/composer/vendor/bin/drush

if [ -x /usr/bin/drush ]; then
	drush=/usr/bin/drush
fi

if [ ! -x ${drush} ]; then
        echo "${drush}: not found."
        exit 1
fi

bagit=/usr/local/bin/bagit.py

if [ ! -x ${bagit} ]; then
	echo "${bagit}: not found."
	echo "might need to run: sudo pip install bagit"
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

for base in $(ls $input/); do
	bags=$input
	bag_data_dir=$bags/$base/data

	for i in $(ls $bag_data_dir/); do
		if [[ $i =~ $base\.(jpg|png|tif|mp3)$ ]]; then
			cp $bag_data_dir/$i $output/$i
		fi
	done

	  if [ -f $bag_data_dir/MODS.xml ]; then
		cp $bag_data_dir/MODS.xml $output/$base.xml
	elif [ -f $bag_data_dir/MARC.xml ]; then
		cp $bag_data_dir/MARC.xml $output/$base.xml
	elif [ -f $bag_data_dir/MARC.mrc ]; then
		cp $bag_data_dir/MARC.mrc $output/$base.mrc
	elif [ -f $bag_data_dir/DC.xml ]; then
		cp $bag_data_dir/DC.xml $output/$base.xml
	fi
done

ls -lh $output

drush --user=admin \
	islandora_batch_scan_preprocess \
	--content_models=$model \
	--parent=$collection \
	--type=directory \
	--target=$output
