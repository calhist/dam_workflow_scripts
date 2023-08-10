#!/bin/bash

USAGE="Usage: $(basename $0) -i <input directory> [-f]"

PATH=$PATH:$HOME/Fits:/opt/fits

echo_exit () {
	echo "$(basename $0): ${1}" >&2
	exit 1
}

cleanup () {
	[ -d ${dst_bag} ] && rm -rf $dst_bag
}

#trap 'cleanup' EXIT HUP INT QUIT TERM

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
which tesseract  >/dev/null 2>&1 || echo_exit "tesseract not found"

if [ ! -d ${input} ]; then
	echo_exit "${input}: not a directory."
fi

dir=$(cd ${input}; pwd) # convert to absolute path

output=${input}.bags

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
for i in $(find ${dir}.MODS -type f | egrep "${dir}.MODS/${input}_[0-9]+\.xml$"); do
	xmlstarlet val -w $i

	if [ $? -ne 0 ]; then
		echo_exit "xmlstarlet failed"
	fi

	if [[ $i =~ ^.*/(${input}_[0-9]+)\.xml$ ]]; then
		bag=${BASH_REMATCH[1]}
		mkdir ${output}/${bag}
		cp $i ${output}/${bag}/MODS.xml
	fi
done

# ASSETS
for i in $(find $input -type f | egrep "${input}/${input}_[0-9]+[a-z]\.tif$"); do
	if [[ $i =~ ^${input}/(${input}_[0-9]+)([a-d])\.tif$ ]]; then
		bag=${BASH_REMATCH[1]}
		page=0
		[ "${BASH_REMATCH[2]}" = 'a' ] && page=1
		[ "${BASH_REMATCH[2]}" = 'b' ] && page=2
		[ "${BASH_REMATCH[2]}" = 'c' ] && page=3
		[ "${BASH_REMATCH[2]}" = 'd' ] && page=4
		[ "${BASH_REMATCH[2]}" = 'e' ] && page=5
		[ "${BASH_REMATCH[2]}" = 'f' ] && page=6
		[ "${BASH_REMATCH[2]}" = 'g' ] && page=7
		[ "${BASH_REMATCH[2]}" = 'h' ] && page=8
		[ "${BASH_REMATCH[2]}" = 'i' ] && page=9
		[ "${BASH_REMATCH[2]}" = 'j' ] && page=10

		[ "${BASH_REMATCH[2]}" = 'k' ] && page=11
		[ "${BASH_REMATCH[2]}" = 'l' ] && page=12
		[ "${BASH_REMATCH[2]}" = 'm' ] && page=13
		[ "${BASH_REMATCH[2]}" = 'n' ] && page=14
		[ "${BASH_REMATCH[2]}" = 'o' ] && page=15
		[ "${BASH_REMATCH[2]}" = 'p' ] && page=16
		[ "${BASH_REMATCH[2]}" = 'q' ] && page=17
		[ "${BASH_REMATCH[2]}" = 'r' ] && page=18
		[ "${BASH_REMATCH[2]}" = 's' ] && page=19
		[ "${BASH_REMATCH[2]}" = 't' ] && page=20

		[ "${BASH_REMATCH[2]}" = 'u' ] && page=21
		[ "${BASH_REMATCH[2]}" = 'v' ] && page=22
		[ "${BASH_REMATCH[2]}" = 'w' ] && page=23
		[ "${BASH_REMATCH[2]}" = 'x' ] && page=24
		[ "${BASH_REMATCH[2]}" = 'y' ] && page=25
		[ "${BASH_REMATCH[2]}" = 'z' ] && page=26

		echo ${output}/$bag/$page/OBJ.tif

		mkdir ${output}/$bag/$page
		cp $i ${output}/$bag/$page/OBJ.tif

		# FITS
		fits.sh -xc -i ${output}/$bag/$page/OBJ.tif -o ${output}/$bag/$page/OBJ.tif.fits.xml
		if [ $? -ne 0 ]; then
			echo_exit "fits.sh failed"
		fi
	fi
done

# TEI
for i in $(find ${output} -maxdepth 1 -type d | egrep "${input}_[0-9]+$"); do
	echo $i

	title=$(xmlstarlet sel -t -v "mods:mods/mods:relatedItem[@type='host']/mods:titleInfo/mods:title" $i/MODS.xml)
	sourceDesc=$(xmlstarlet sel -t -v "mods:mods/mods:note[@type='preferredCitation']" $i/MODS.xml)
	template=/tmp/template.teiHeader

	echo "<teiHeader>"                      > $template
	echo "  <fileDesc>"                    >> $template
	echo "    <titleStmt>"                 >> $template
	echo "      <title>${title}</title>"   >> $template
	echo "      <author>AUTHOR</author>"   >> $template
	echo "    </titleStmt>"                >> $template
	echo "    <publicationStmt>"           >> $template
	echo "      <p>PUBLISHER</p>"          >> $template
	echo "    </publicationStmt>"          >> $template
	echo "    <sourceDesc>"                >> $template
	echo "      <p>${sourceDesc}</p>"      >> $template
	echo "    </sourceDesc>"               >> $template
	echo "  </fileDesc>"                   >> $template
	echo "</teiHeader>"                    >> $template

	printf '<TEI xmlns="http://www.tei-c.org/ns/1.0">\n'  > /tmp/TEI.xml
	printf '  %s\n'                    "`cat $template`" >> /tmp/TEI.xml
	printf '  <text>\n'                                  >> /tmp/TEI.xml
	printf '    <body>\n'                                >> /tmp/TEI.xml

	for j in $(find $i -type d | egrep "/[0-9]$" | sort); do
		tif="$j/OBJ.tif"
		if [ -f $tif ]; then
			if [[ "${tif}" =~ ^.+/([0-9]+)/[^.]+\.tif$ ]]; then
				base=${BASH_REMATCH[1]}
			fi
			tesseract $tif /tmp/$base
			uni2ascii -B /tmp/${base}.txt > /tmp/${base}.ascii.txt
			[ -f /tmp/${base}.txt ] && rm /tmp/${base}.txt
			while read p; do
				if [ "$p" != '' ]; then
					p=$(echo $p | sed 's/</ /g; s/>/ /g;')
					p=$(echo $p | sed 's/ & / and /g;')
					p=$(echo $p | sed 's/^&$/and/g;')
					#p=$(echo $p | sed 's/“/"/g') # curly quote to straight quote
					#p=$(echo $p | sed 's/”/"/g') # curly quote to straight quote
					printf '<p>%s</p>\n' "$p" >> /tmp/TEI.xml
				fi
			done < /tmp/${base}.ascii.txt
			[ -f /tmp/${base}.ascii.txt ] && rm /tmp/${base}.ascii.txt
		else
			echo_exit "${tif} must be a TIF image"
		fi
	done

	printf '    </body>\n'                               >> /tmp/TEI.xml
	printf '  </text>\n'                                 >> /tmp/TEI.xml
	printf '</TEI>\n'                                    >> /tmp/TEI.xml

	xmlstarlet val -e -w /tmp/TEI.xml || echo_exit "xmlstarlet failed"

	xmlstarlet fo /tmp/TEI.xml > $i/TEI.xml # converts to xml entities
done

for i in $(find ${output} -maxdepth 1 -type d | egrep "${input}_[0-9]+$"); do
	bagit.py --processes 3 --md5 --sha256 --sha512 $i
done

rm /tmp/apache-tika-*
