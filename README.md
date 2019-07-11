## Archiving collection when complete:

1. Upload assets and MODS files to the input bucket, ```704869648062-input```.

2. Bags are automatically created in the output bucket, ```704869648062-output```.

3. Review collection in the output bucket, ```704869648062-output```.

4. When ready, run archive script to transfer collection to archive bucket, ```704869648062-archive```.

   ```bash
   cd /data/Collections.BATCH
   ./archive-collection.sh -c <COLLECTION>
   ```

   Note: run script without options to see list of collections
