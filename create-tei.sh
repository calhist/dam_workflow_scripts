#!/bin/bash

USAGE="Usage: $(basename $0) -i <TIFF Image> -t <teiHeader File> [-f]"

echo_exit () {
  echo "$(basename $0): ${1}" >&2
  exit 1
}

cleanup () {
  [ -f /tmp/${base}.txt ] && rm /tmp/${base}.txt
  [ -f /tmp/${output}   ] && rm /tmp/${output}
}

trap 'cleanup' EXIT HUP INT QUIT TERM

#source=704869648062-archive
input=
output=TEI.xml
force=0

while getopts "i:t:f" opt; do
	case $opt in
	i)
		input=${OPTARG%/} # remove trailing slash
		;;
	t)
		template=${OPTARG%/} # remove trailing slash
		;;
	f)
		force=1
		;;
 	\?)
		echo ${USAGE}
		exit 1
	esac
done

which tesseract  >/dev/null 2>&1 || echo_exit "tesseract not found"
which xmlstarlet >/dev/null 2>&1 || echo_exit "xmlstarlet not found"

if [[ "${input}" =~ ^([^.]+)\.tif$ ]]; then
  base=${BASH_REMATCH[1]}
else
  echo_exit "${input} must be a TIF image"
fi

if ! [[ "${template}" =~ ^([^.]+)\.teiHeader$ ]]; then
  echo_exit "${template} must be a TEI Header"
fi

if [ -f $output ]; then
  if [ $force -eq 1 ]; then
    rm -f $output
  else
    echo_exit "${output} file already exits"
  fi
fi

if [ -f ${base}.txt ]; then
  if [ $force -eq 1 ]; then
    rm -f ${base}.txt
  else
    echo_exit "${base}.txt file already exits"
  fi
fi

tesseract $input /tmp/$base

printf '<TEI xmlns="http://www.tei-c.org/ns/1.0">\n'  > /tmp/$output
printf '  %s\n'                    "`cat $template`" >> /tmp/$output
printf '  <text>\n'                                  >> /tmp/$output
printf '    <body>\n'                                >> /tmp/$output

while read p; do
  if [ "$p" != '' ]; then
    printf '<p>%s</p>\n' "$p" >> /tmp/$output
  fi
done < /tmp/${base}.txt

printf '    </body>\n'                               >> /tmp/$output
printf '  </text>\n'                                 >> /tmp/$output
printf '</TEI>\n'                                    >> /tmp/$output

xmlstarlet val -w /tmp/${output} || echo_exit "xmlstarlet failed"

# xmlstarlet fo --omit-decl /tmp/${output} > $output

xmlstarlet fo /tmp/${output} > $output # converts to xml entities
