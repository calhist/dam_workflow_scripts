#!/bin/bash

USAGE="Usage: $(basename $0) -i <input file>"

PATH=$PATH:$HOME/Fits:/opt/fits

echo_exit () {
  echo "$(basename $0): ${1}" >&2
  exit 1
}

cleanup () {
	[ -d ${dst_bag} ] && rm -rf $dst_bag
}

trap 'cleanup' EXIT HUP INT QUIT TERM

input=

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

which aws        >/dev/null 2>&1 || echo_exit "aws not found"
which bagit.py   >/dev/null 2>&1 || echo_exit "bagit.py not found"
which fits.sh    >/dev/null 2>&1 || echo_exit "fits.sh not found"
which xmlstarlet >/dev/null 2>&1 || echo_exit "xmlstarlet not found"

if [[ "${input}" =~ ^s3://([0-9]+-input)/(([^./]+)(\..+)?)/((.+)(\..+))$ ]]; then
  src_url=${BASH_REMATCH[0]}
  src_bucket=${BASH_REMATCH[1]}
  src_prefix=${BASH_REMATCH[2]}
  src_prefix_base=${BASH_REMATCH[3]}
  src_prefix_ext=${BASH_REMATCH[4]}
  src_object=${BASH_REMATCH[5]}
  src_object_base=${BASH_REMATCH[6]}
  src_object_ext=${BASH_REMATCH[7]}
else
  echo_exit "${input} must be a S3 URL"
fi

echo $src_url: $src_bucket $src_prefix $src_object
echo $src_prefix: $src_prefix_base $src_prefix_ext
echo $src_object: $src_object_base $src_object_ext
echo 

dst_bucket=${src_bucket/-input/-output}
dst_prefix=${src_prefix_base}.bags
dst_bag=${src_object_base}
dst_object=${src_object}

[ -d ${dst_bag} ] && rm -rf $dst_bag

mkdir $dst_bag

# MODS
aws s3api head-object --bucket ${src_bucket} --key ${src_prefix_base}.MODS/${src_object_base}.xml >/dev/null 2>&1

if [ $? -eq 0 ]; then
  aws s3 cp s3://${src_bucket}/${src_prefix_base}.MODS/${src_object_base}.xml ${dst_bag}/MODS.xml --no-progress || echo_exit "mods cp failed"
	xmlstarlet val -w ${dst_bag}/MODS.xml || echo_exit "xmlstarlet failed"
fi

# ASSETS
for i in jpg tif mp3 mov wav; do
	aws s3api head-object --bucket ${src_bucket} --key ${src_prefix_base}/${src_object_base}.$i >/dev/null 2>&1

	if [ $? -eq 0 ]; then
		aws s3 cp s3://${src_bucket}/${src_prefix_base}/${src_object_base}.$i ${dst_bag}/${src_object_base}.$i --no-progress || echo_exit "$i cp failed"
		fits.sh -xc -i ${dst_bag}/${src_object_base}.$i -o $dst_bag/${src_object_base}.$i.fits.xml || echo_exit "fits.sh failed"
	fi
done

[ -z "$(ls -A ${dst_bag})" ] && echo_exit "empty bag"

bagit.py --processes 3 --md5 --sha256 --sha512 $dst_bag || echo_exit "bagit.py failed"
aws s3 sync $dst_bag s3://${dst_bucket}/${dst_prefix}/${dst_bag} --no-progress || echo_exit "dst sync failed"
