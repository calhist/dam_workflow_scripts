## Basic Workflow

### On Quarantine server (CHS-ISL002)

1. Upload assets to a folder on the quarantine server.  The folder should be a bag or a flat collection of assets.  The quarantine server handles virus checking.

  http://chs.dgicloud.com:60080/owncloud/

2. Create bags for each asset.

  ~~~
  $ create-bags.sh -i "folder name"
  ~~~

3. Copy the collection of bags to the archive server.

  ~~~
  $ copy-to-archive.sh -i "folder name".bags
  ~~~

4. Copy the collection of bags to the production server.

  ~~~
  $ copy-to-production.sh -i "folder name".bags
  ~~~

### On Archive server (CHS-ISL003)

1. Validate bags on the archive server.  Validation includes checking that bags are well-formed and fixity is correct.

  ~~~
  $ validate-bags.sh -i "folder name".bags
  ~~~
  
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
