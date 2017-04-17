## Basic Workflow

### On Quarantine server (CHS-ISL002)

1. Upload assets to a folder on the quarantine server.  The folder should be a bag or a flat collection of assets.  The quarantine server handles virus checking.

  http://chs.dgicloud.com:60080/owncloud/
  
2. Create bags for each asset.

  ~~~
  $ create-bags.sh -i "folder name"
  ~~~

  Example 1: sample_1_source
  
  ~~~
  $ cd /data/quarantine
  $ ls -l
  drwxr-xr-x  2 www-data www-data 4096 Feb 26 21:44 sample_1_source
  $ sudo -u www-data create-bags.sh -i sample_1_source
  /data/quarantine/sample_1_source/image001.jpg
  /data/quarantine/sample_1_source/image002.png
  ~~~
  
  Example 2: sample_1_source AND sample_1_source.MODS

  ~~~
  $ cd /data/quarantine
  $ ls -l
  drwxr-xr-x  2 www-data www-data 4096 Feb 26 21:44 sample_1_source
  $ sudo -u www-data create-bags.sh -i sample_1_source
  /data/quarantine/sample_1_source/image001.jpg
  /data/quarantine/sample_1_source.MODS/image001.xml - valid
  /data/quarantine/sample_1_source/image002.png
  /data/quarantine/sample_1_source.MODS/image002.xml - valid
  ~~~

3. Copy the collection of bags to the archive server.

  ~~~
  $ copy-to-archive.sh -i "folder name".bags
  ~~~

  Example 1: sample_1_source.bags
  
  ~~~
  $ cd /data/quarantine
  $ copy-to-archive.sh -i sample_1_source.bags
  2017-03-20 16:16:55,476 - INFO - /data/quarantine/sample_1_source.bags/image001 is valid
  2017-03-20 16:16:55,514 - INFO - /data/quarantine/sample_1_source.bags/image002 is valid

  sending incremental file list
  created directory /data/sample_1_source.bags
  ./
  image001/
  image001/bag-info.txt
  image001/bagit.txt
  image001/manifest-md5.txt
  image001/manifest-sha256.txt
  image001/tagmanifest-md5.txt
  image001/tagmanifest-sha256.txt
  image001/data/
  image001/data/image001.jpg
  image001/data/image001.jpg.fits.xml

  sent 71,165 bytes  received 400 bytes  47,710.00 bytes/sec
  total size is 69,835  speedup is 0.98
  ~~~
  
4. [OPTIONAL] Copy the collection of bags to the sandbox server.

  ~~~
  $ copy-to-sandbox.sh -i "folder name".bags
  ~~~

  Example 1: sample_1_source.bags
  
  ~~~
  $ cd /data/quarantine
  $ copy-to-sandbox.sh -i sample_1_source.bags
  ~~~
  
5. Copy the collection of bags to the production server.

  ~~~
  $ copy-to-production.sh -i "folder name".bags
  ~~~

### On Archive server (CHS-ISL003)

1. Validate bags on the archive server.  Validation includes checking that bags are well-formed and fixity is correct.

  ~~~
  $ validate-bags.sh -i "folder name".bags
  ~~~

  Example 1: sample_1_source.bags
  
  ~~~
  $ cd /data
  $ validate-bags.sh -i sample_1_source.bags
  Checking /data/sample_1_source.bags
  2017-04-02 13:51:55,097 - INFO - /data/sample_1_source.bags/image001 is valid
  ~~~

### On Sandbox server (islandora-chs)

1. Create an ingest batch from the bags on the sandbox server.  Metadata is created if MODS file found in the bag.

  ~~~
  $ create-batch.sh -i "folder name".bags -c "collection name"
  ~~~
  
  Example 1: sample_1_source.bags
  
  ~~~
  $ cd ~
  $ create-batch.sh -i sample_1_source.bags
  Checking /data/sample_1_source.bags
  2017-04-02 13:51:55,097 - INFO - /data/sample_1_source.bags/image001 is valid
  ~~~

2. Ingest the batch.

  http://islandora-chs.laddhanson.org/

### On Production server (CHS-ISL001)

1. Review bags on the production server.

  http://chs.dgicloud.com/owncloud/

2. Create an ingest batch from the bags on the production server.  Metadata is created if MODS file found in the bag.

  ~~~
  $ create-batch.sh -i "folder name".bags -c "collection name"
  ~~~

3. Ingest the batch.

  http://chs.dgicloud.com/islandora/
  
### On Archive server (CHS-ISL003)

Use the '-c' option to validate bags periodically.  For example, to validate bags older than 30 days at 4:00 AM everyday add this line to /etc/cron.d/validate.

~~~
0 4 * * * www-data /home/ubuntu/dam_workflow_scripts/validate.sh -i /data/quarantine -6 +30
~~~

Run as the user 'www-data' when using the '-c' option.
