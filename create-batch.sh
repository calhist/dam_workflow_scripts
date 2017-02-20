#!/bin/sh

#src=/data/staging/bags
#src=/home/ubuntu/bags
src=/home/chsadmin/bags
dst=/tmp/test

[ -d $dst ] && rm -rf $dst

mkdir /tmp/test

for i in $(ls $src/*/data/*.tif); do
	bag=$(basename $i .tif)
	dir=$(dirname $i)
	tif=$(basename $i)
	xml=$(basename $i .tif).xml

	if [ $bag = 'map_0118' ]; then
		continue
		cp $dir/$tif $dst/$tif
		cp $dir/$xml $dst/$xml
	fi
	if [ $bag = 'map_0389' ]; then
		continue
		cp $dir/$tif $dst/$tif
		cp $dir/$xml $dst/$xml
	fi
	if [ $bag = 'map_0468' ]; then
		continue
		cp $dir/$tif $dst/$tif
		cp $dir/$xml $dst/$xml
	fi
	cp $dir/$tif $dst/$tif
	cp $dir/$xml $dst/$xml
done

#sudo drush \
#	--root=/var/www/drupal7 \
#	--user=admin \
#	--uri=http://default \
#	st

sudo drush \
	--root=/var/www/drupal7 \
	--user=admin \
	--uri=http://default \
	islandora_batch_scan_preprocess \
	--content_models=islandora:sp_large_image_cmodel \
	--namespace=islandora \
	--parent=islandora:1473 \
	--parent_relationship_pred=isMemberOfCollection \
	--type=directory \
	--target=/tmp/test

sudo drush \
	--root=/var/www/drupal7 \
	--user=admin \
	--uri=http://default \
	islandora_batch_ingest


