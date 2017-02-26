#!/bin/bash

set -e

USAGE="Usage: $(basename $0) -i <input directory> [-f]"

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

if [ ! -d ${input} ]; then
	echo "${input}: not a directory."
	exit 1
fi

input=$(cd ${input}; pwd) # convert to absolute path

output=${input}.bags

if [ -d $output ]; then
	if [ $force -eq 1 ]; then
		rm -rf $output
	else
		echo "${output}: directory already exists."
		exit 1
	fi
fi

# https://github.com/LibraryOfCongress/bagit-python

bagit=/usr/local/bin/bagit.py

if [ ! -x ${bagit} ]; then
	echo "${bagit}: not found."
	exit 1
fi

# https://github.com/harvard-lts/fits/tree/master

fits=/opt/fits/fits.sh

if [ ! -x ${fits} ]; then
	echo "${fits}: not found."
	exit 1
fi

if [ -f $input/bagit.txt ]; then
	$bagit --validate --quiet $input

	if [ $? -ne 0 ]; then
		echo "${input}: invalid bag."
		exit
	fi

	for i in $(find $input/data -type f); do
		printf "%s\n" $i

		file=$(basename $i)

		bag=$(basename ${i%.*})

		[ -d $output/$bag ] && rm -rf $output/$bag

		mkdir -p $output/$bag

		cp $input/data/$file $output/$bag/$file

		$fits -xc -i $output/$bag -o $output/$bag 2>/dev/null

		$bagit --md5 --sha256 --log=/dev/null $output/$bag

		# CHECK
		if [ -f $input/manifest-md5.txt ]; then
			n=data/$file

			A=$(awk '$2 == n {print $1}' n=$n $input/manifest-md5.txt)
			B=$(awk '$2 == n {print $1}' n=$n $output/$bag/manifest-md5.txt)

			if [ "$A" != "$B" ]; then
				printf "MD5 match failed!\n"
				exit
			fi
		fi
	done

	# CHECK
	A=$(cat $input/manifest-md5.txt | wc -l)
	B=$(ls $output | wc -l)

	if [ $A -ne $B ]; then
		printf "File count failed!\n"
		exit
	fi

else
	for i in $(find $input -type f); do
		printf "%s\n" $i

		file=$(basename $i)

		bag=$(basename ${i%.*})

		[ -d $output/$bag ] && rm -rf $output/$bag

		mkdir -p $output/$bag

		cp $input/$file $output/$bag/$file

		$fits -xc -i $output/$bag -o $output/$bag 2>/dev/null

		$bagit --md5 --sha256 --log=/dev/null $output/$bag
	done
fi
