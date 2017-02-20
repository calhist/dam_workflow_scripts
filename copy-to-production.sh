#!/bin/sh

src=/data/staging/Maps
dst=/data/staging/bags
bagit=/usr/local/bin/bagit.py
fits=/opt/fits/fits.sh

for i in $(ls $src/*.tif); do
  tif=$(basename $i)
  bag=$(basename $i .tif)

  printf "%-40s %s\n" $tif $bag

  [ -d $dst/$bag ] && rm -rf $dst/$bag

  mkdir $dst/$bag
  cp $src/$tif $dst/$bag
  $fits -xc -i $dst/$bag -o $dst/$bag
  $bagit --md5 --sha256 --quiet --log=/dev/null $dst/$bag

  n=data/$tif

  src_md5=$(awk -v RS='\r\n' '$2 == n {print $1}' n=$n $src/manifest-md5.txt)
  dst_md5=$(awk              '$2 == n {print $1}' n=$n $dst/$bag//manifest-md5.txt)

  if [ $src_md5 != $dst_md5 ]; then
    printf "MD5 match failed!\n"
    exit
  fi
done
