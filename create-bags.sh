#!/bin/sh

src=/data/staging/Maps
mrc=/data/staging/marc
dst=/data/staging/bags
bagit=/usr/local/bin/bagit.py
fits=/opt/fits/fits.sh

restrictionOnAccess="http://rightsstatements.org/vocab/NKC/1.0/"
useAndReproduction="All requests to reproduce, publish, quote from or otherwise use collection materials must be submitted in writing to the Director of Library and Archives, North Baker Research Library, California Historical Society, 678 Mission Street, San Francisco, CA 94105. Consent is given on behalf of the California Historical Society as the owner of the physical items and is not intended to include or imply permission from the copyright owner. Such permission must be obtained from the copyright owner. Restrictions also apply to digital representations of the original materials. Use of digital files is restricted to research and educational purposes."

for i in $(ls $src/*.tif); do
  tif=$(basename $i)
  bag=$(basename $i .tif)
  xml=$bag.xml

  printf "%s\n" $bag

  [ -d $dst/$bag ] && rm -rf $dst/$bag

  mkdir $dst/$bag

  # TIFF
  cp $src/$tif $dst/$bag
  $fits -xc -i $dst/$bag -o $dst/$bag

  # MARC
  xmlstarlet val --net -e $mrc/$xml || exit
  xmlstarlet fo $mrc/$xml > $dst/$bag/$xml

  xmlstarlet ed -L \
    -s /marc:collection/marc:record -t elem -n marc:datafieldTMP -v '' \
    $dst/$bag/$xml
  xmlstarlet ed -L \
    -i //marc:datafieldTMP -t attr -n tag -v 506 \
    -i //marc:datafieldTMP -t attr -n ind1 -v ' ' \
    -i //marc:datafieldTMP -t attr -n ind2 -v ' ' \
    -s //marc:datafieldTMP -t elem -n marc:subfield -v "${restrictionOnAccess}" \
    -i '$prev' -t attr -n code -v 'a' \
    -r //marc:datafieldTMP -v datafield \
    $dst/$bag/$xml
  xmlstarlet ed -L \
    -s /marc:collection/marc:record -t elem -n marc:datafieldTMP -v '' \
    $dst/$bag/$xml
  xmlstarlet ed -L \
    -i //marc:datafieldTMP -t attr -n tag -v 540 \
    -i //marc:datafieldTMP -t attr -n ind1 -v ' ' \
    -i //marc:datafieldTMP -t attr -n ind2 -v ' ' \
    -s //marc:datafieldTMP -t elem -n marc:subfield -v "${useAndReproduction}" \
    -i '$prev' -t attr -n code -v 'a' \
    -r //marc:datafieldTMP -v datafield \
    $dst/$bag/$xml

  # BAGIT
  $bagit --md5 --sha256 --quiet --log=/dev/null $dst/$bag

  # CHECK
  n=data/$tif

  src_md5=$(awk -v RS='\r\n' '$2 == n {print $1}' n=$n $src/manifest-md5.txt)
  dst_md5=$(awk              '$2 == n {print $1}' n=$n $dst/$bag//manifest-md5.txt)

  if [ $src_md5 != $dst_md5 ]; then
    printf "MD5 match failed!\n"
    exit
  fi
done
