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

if [[ "${input}" =~ ^s3://(.+)/(.+)/((.+)\.(.+))$ ]]; then
  src_url=${BASH_REMATCH[0]}
  src_bucket=${BASH_REMATCH[1]}
  src_prefix=${BASH_REMATCH[2]}
  src_object=${BASH_REMATCH[3]}
  src_base=${BASH_REMATCH[4]}
  src_ext=${BASH_REMATCH[5]}
else
  echo_exit "${input} must be a S3 URL"
fi

dst_bucket=${src_bucket}
dst_prefix=${src_prefix}.bags
dst_bag=${src_base}
dst_object=${src_object}

[ -d ${dst_bag} ] && rm -rf $dst_bag

mkdir $dst_bag

aws s3 cp $src_url ${dst_bag}/${dst_object} --no-progress || echo_exit "aws failed"

fits.sh -xc -i ${dst_bag} -o $dst_bag || echo_exit "fits.sh failed"

aws s3api head-object --bucket ${src_bucket} --key ${src_prefix}.MODS/${src_base}.xml >/dev/null 2>&1

if [ $? -eq 0 ]; then
  aws s3 cp s3://${src_bucket}/${src_prefix}.MODS/${src_base}.xml ${dst_bag}/MODS.xml --no-progress

	xmlstarlet val -w ${dst_bag}/MODS.xml

	if [ $? -ne 0 ]; then
    rm -rf $dst_bag
		exit 1
	fi
fi

bagit.py --processes 3 --md5 --sha256 --sha512 $dst_bag || echo_exit "bagit.py failed"

aws s3 sync $dst_bag s3://${dst_bucket}/${dst_prefix}/${dst_bag} --no-progress || echo_exit "aws failed"
