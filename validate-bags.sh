#!/bin/bash

USAGE="Usage: $(basename $0) -i <input directory> -c <days>"

input=
output=

while getopts "i:c:" opt; do
	case $opt in
        i)
                input=$OPTARG
                ;;
        c)
                days=$OPTARG
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

if [[ ! ${days} =~ ^\+[0-9]+$ ]]; then
        echo "${days}: invalid number of days."
        exit 1
fi

input=$(cd ${input}; pwd) # convert to absolute path

# https://github.com/LibraryOfCongress/bagit-python

bagit=/usr/local/bin/bagit.py

if [ ! -x ${bagit} ]; then
        echo "${bagit}: not found."
        exit 1
fi

if [ ${input} -a ${days} ]; then
	for a in $(find ${input} -maxdepth 1 -type d -name "*.bags" -mtime ${days}); do
		for b in $(find ${a} -maxdepth 1 -type d ! -name "*.bags" -mtime ${days}); do
			$bagit --validate $b

			if [ $? -ne 0 ]; then
				echo
				echo "Input directory must a directory of valid bags."
				exit 1
			fi
		done

 		touch -c -m -t $(date +%Y%m%d0000.00) $a
	done
else
	if [ ${input: -5} != ".bags" ]; then
	        echo "${input}: not a directory ending with '.bags'."
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
fi
