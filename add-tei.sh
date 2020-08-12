#!/bin/bash

USAGE="Usage: $(basename $0) -i <input directory> [-f]"

echo_exit () {
  echo "$(basename $0): ${1}" >&2
  exit 1
}

cleanup () {
  [ -f /tmp/${base}.txt ] && rm /tmp/${base}.txt
  [ -f /tmp/${output}   ] && rm /tmp/${output}
}

#trap 'cleanup' EXIT HUP INT QUIT TERM

input=
output=TEI.xml
force=0

while getopts "i:f" opt; do
	case $opt in
	i)
		input=${OPTARG%/} # remove trailing slash
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
which uni2ascii  >/dev/null 2>&1 || echo_exit "uni2ascii not found"

if [ "${input}" == '' ]; then
  echo ${USAGE}
  exit 1
fi

if [ ! -d ${input} ]; then
  echo_exit "${input} must be a directory"
fi

title=$(xmlstarlet sel -t -v "mods:mods/mods:relatedItem[@type='host']/mods:titleInfo/mods:title" $input/MODS.xml)

sourceDesc=$(xmlstarlet sel -t -v "mods:mods/mods:note[@type='preferredCitation']" $input/MODS.xml)

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

echo OUTPUT $output

if [ -f $input/$output ]; then
  if [ $force -eq 1 ]; then
    rm -f $input/$output
  else
    echo_exit "${input}/${output} file already exits"
  fi
fi

if [ -f ${base}.txt ]; then
  if [ $force -eq 1 ]; then
    rm -f ${base}.txt
  else
    echo_exit "${base}.txt file already exits"
  fi
fi

printf '<TEI xmlns="http://www.tei-c.org/ns/1.0">\n'  > /tmp/$output
printf '  %s\n'                    "`cat $template`" >> /tmp/$output
printf '  <text>\n'                                  >> /tmp/$output
printf '    <body>\n'                                >> /tmp/$output

for i in $(find $input/*/OBJ.tif -type f); do
  printf "%s\n" $i

  if [[ "${i}" =~ ^.+/([0-9]+)/[^.]+\.tif$ ]]; then
    base=${BASH_REMATCH[1]}
  else
    echo_exit "${input} must be a TIF image"
  fi

  echo INFO tesseract $i /tmp/$base
  tesseract $i /tmp/$base

  echo INFO uni2ascii /tmp/${base}.txt
  uni2ascii -B /tmp/${base}.txt > /tmp/${base}.ascii.txt

  while read p; do
    if [ "$p" != '' ]; then
      p=$(echo $p | sed 's/</ /g; s/>/ /g;')
      p=$(echo $p | sed 's/ & / and /g;')
      #p=$(echo $p | sed 's/“/"/g') # curly quote to straight quote
      #p=$(echo $p | sed 's/”/"/g') # curly quote to straight quote
      printf '<p>%s</p>\n' "$p" >> /tmp/$output
    fi
  done < /tmp/${base}.ascii.txt
done

printf '    </body>\n'                               >> /tmp/$output
printf '  </text>\n'                                 >> /tmp/$output
printf '</TEI>\n'                                    >> /tmp/$output

xmlstarlet val -e -w /tmp/${output} || echo_exit "xmlstarlet failed"

xmlstarlet fo /tmp/${output} > $input/$output # converts to xml entities
