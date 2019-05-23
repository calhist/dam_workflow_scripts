#!/bin/bash

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

# if [ "$USER" != 'www-data' ]; then
# 	echo "Must be run as www-data."
# 	exit 1
# fi

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

#
# https://github.com/LibraryOfCongress/bagit-python
#
# Ubuntu 18.04
# $ python --version
# Python 2.7.15rc1
# $ pip install --user bagit
# $ which bagit.py
# /home/ubuntu/.local/bin/bagit.py
#
# Installation (OS X)
# $ pyenv versions
#   system
#   3.6.8
# * 3.7.0 (set by /Users/ladd/.pyenv/version)
#   3.7.2
# $ which pip
# /Users/ladd/.pyenv/shims/pip
# $ pip install --user bagit
# $ which bagit.py
# /Users/ladd/.local/bin/bagit.py
#

bagit=~/.local/bin/bagit.py

if [ ! -x ${bagit} ]; then
	echo "${bagit}: not found."
	exit 1
fi

#
# https://github.com/harvard-lts/fits/tree/master
#
# Use the FITS installed with Islandora at /opt/fits
#
# $ ln -s /opt/fits Fits
# $ Fits/fits.sh -v
#

fits=~/Fits/fits.sh

if [ ! -x ${fits} ]; then
	echo "${fits}: not found."
	exit 1
fi

#
# http://xmlstar.sourceforge.net/docs.php
#
# $ sudo apt install xmlstarlet
# $ xmlstarlet --version
#

xml=/usr/bin/xmlstarlet

if [ ! -x ${xml} ]; then
	echo "${xml}: not found."
	exit 1
fi

if [ -f $input/bagit.txt ]; then
	$bagit --validate $input

	if [ $? -ne 0 ]; then
		echo "${input}: invalid bag."
		exit
	fi

	for i in $(find $input/data -type f); do
		printf "%s\n" $i

		#if [ $i != "/home/ubuntu/Collections/PC-PA-070_a-tttt/data/alternates/PC-PA-070c_alt.tif" ]; then
		#	continue
		#fi

		file=$(basename $i)

		bag=$(basename ${i%.*})

		if [ $file == ".BridgeCache" ]; then
			bag=".BridgeCache"
		fi

		if [ $file == ".BridgeCacheT" ]; then
			bag=".BridgeCacheT"
		fi

		if [ $file == ".BridgeSort" ]; then
			bag=".BridgeSort"
		fi

		if [ $file == ".DS_Store" ]; then
			bag=".DS_Store"
		fi

		[ -d $output/$bag ] && rm -rf $output/$bag

		mkdir -p $output/$bag

		subdir=""

		if [ $file == "PC-PA-070c_alt.tif" ]; then
			subdir="/alternates"
		fi

		if [ $file == "PC-PA-070hhhh_alt.tif" ]; then
			subdir="/alternates"
		fi

		if [ $file == "PC-PA-070jjjj_alt.tif" ]; then
			subdir="/alternates"
		fi

		cp $input/data${subdir}/$file $output/$bag/$file

		$fits -xc -i $output/$bag -o $output/$bag 2>/dev/null

		if [ -d ${input}.MODS ]; then
			if [ -f ${input}.MODS/$bag.xml ]; then
				$xml val -w ${input}.MODS/$bag.xml

				if [ $? -ne 0 ]; then
					exit 1
				fi

				cp ${input}.MODS/$bag.xml $output/$bag/MODS.xml
			else
				echo ${input}.MODS/$bag.xml - MISSING
			fi
		fi

		$bagit --md5 --sha256 --log=/dev/null $output/$bag

		# CHECK
		if [ -f $input/manifest-md5.txt ]; then
			n=data/$file

			if [ $file == "PC-PA-070c_alt.tif" ]; then
				n=data/alternates/$file
			fi

			if [ $file == "PC-PA-070hhhh_alt.tif" ]; then
				n=data/alternates/$file
			fi

			if [ $file == "PC-PA-070jjjj_alt.tif" ]; then
				n=data/alternates/$file
			fi

			A=$(awk '$2 == n {print $1}' n=$n $input/manifest-md5.txt)

			n=data/$file

			B=$(awk '$2 == n {print $1}' n=$n $output/$bag/manifest-md5.txt)

			if [ "$A" != "$B" ]; then
				printf "MD5 match failed!\n"
				exit
			fi
		fi
	done

	# CHECK
	A=$(cat $input/manifest-md5.txt | wc -l)
	B=$(ls -a $output | egrep -v "^\.$|^\.\.$" | wc -l)

	if [ $A -ne $B ]; then
		printf "File count failed!\n"
		exit
	fi
else
	for i in $(find $input -type f); do
		printf "%s\n" $i

		file=$(basename $i)

		bag=$(basename ${i%.*})

		if [ $file == ".BridgeCache" ]; then
			bag=".BridgeCache"
		fi

		if [ $file == ".BridgeCacheT" ]; then
			bag=".BridgeCacheT"
		fi

		[ -d $output/$bag ] && rm -rf $output/$bag

		mkdir -p $output/$bag

		cp $input/$file $output/$bag/$file

		$fits -xc -i $output/$bag -o $output/$bag 2>/dev/null

		if [ -d ${input}.MODS ]; then
			$xml val -w ${input}.MODS/$bag.xml

			if [ $? -ne 0 ]; then
				exit 1
			fi

			cp ${input}.MODS/$bag.xml $output/$bag/MODS.xml
		fi

		$bagit --md5 --sha256 --log=/dev/null $output/$bag
	done
fi
