#!/bin/bash

USAGE="Usage: $(basename $0) -i <input file> [-f]"

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
output=
force=0

while getopts "i:f" opt; do
	case $opt in
	i)
		input=$OPTARG
		;;
	f)
		force=1
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

if [ ! -d ${input} ]; then
	echo_exit "${input}: not a directory."
fi

input=$(cd ${input}; pwd) # convert to absolute path

output=${input}.bag

if [ -d $output ]; then
	if [ $force -eq 1 ]; then
		rm -rf $output
	else
		echo "${output}: directory already exists."
		exit 1
	fi
fi

mkdir $output

# MODS
if [ -f ${input}/MODS.xml ]; then
	xmlstarlet val -w ${input}/MODS.xml

	if [ $? -ne 0 ]; then
		echo_exit "xmlstarlet failed"
	fi

	cp ${input}/MODS.xml ${output}/MODS.xml
fi

# TEI
if [ -f ${input}/TEI.xml ]; then
	xmlstarlet val -w ${input}/TEI.xml

	if [ $? -ne 0 ]; then
		echo_exit "xmlstarlet failed"
	fi

	cp ${input}/TEI.xml ${output}/TEI.xml
fi

# ASSETS
for i in $(find $input -type d | egrep "${input}/[0-9]+$"); do
	echo $i

	if [ -f ${i}/OBJ.tif ]; then
		mkdir ${output}/$(basename $i)
		cp $i/OBJ.tif ${output}/$(basename $i)/OBJ.tif
	else
		echo_exit "${input}: must only contain OBJ.tif"
	fi
done

# FITS
if [ -d $output ]; then
	for i in $(find $output -type f -name OBJ.tif); do
		echo $i
		fits.sh -xc -i $i -o $(dirname $i)/OBJ.tif.fits.xml
		if [ $? -ne 0 ]; then
			echo_exit "fits.sh failed"
		fi
	done
fi

bagit.py --processes 3 --md5 --sha256 --sha512 $output
