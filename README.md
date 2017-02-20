## Workflow

### On Quarantine server (CHS-ISL002)

1. Upload assets to a folder on the quarantine server.  The folder should be a bag or a flat collection of assets.  The quarantine server handles virus checking.

  http://chs.dgicloud.com:60080/owncloud/

2. Create bags for each asset.

  ~~~
  chsadmin@CHS-ISL002:~$ create-bags.sh -i "folder name"
  ~~~

3. Copy the collection of bags to the production server.

  ~~~
  chsadmin@CHS-ISL002:~$ copy-to-production.sh -i "folder name".bags
  ~~~

### On Production server (CHS-ISL001)

1. Create an ingest batch on the production server.

  ~~~
  chsadmin@CHS-ISL001:~$ create-batch.sh -i "folder name".bags
  ~~~
