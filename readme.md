# Multi DB Backup
A multi db backup will upload your file backup to Blackblaze B2. 

## Feature
- ✅ 100% auto — without login and token OAuth
- ✅ Multiple database (PostgreSQL, MySQL and MongoDB)
- ✅ Modular (can run for spesific backup service)
- ✅ Safe — there is no any password inside file rclone.conf
- ✅ Ready for cronjob or CI/CD


### Structure
```bash
multi-db-backup/
├── docker-compose.yml
├── Dockerfile.backup
├── common/
│   ├── rclone.conf               # this file is optional for testing purpose
│   └── backup.sh                 # script for backup + automatic upload
```

### Preparation
This script is require a `Blackblaze account`, so here is the tutorial how to get it.

1. Visit [https://www.backblaze.com/sign-up/cloud-storage](https://www.backblaze.com/sign-up/cloud-storage?referrer=getstarted).
2. Create your account then try to login.
3. After login → go to B2 Cloud Storage → Buckets → Create a Bucket
    - **Bucket Name:** your_web_name-backup
    - **Private:** Private
4. Create Application Key
    - In the left menu, open `Application Keys` → `Add a New Application Key`.
        - Name of Key: rclone-backup
        - Allow access to bucket: All or choose what have you created.
        - Now click `Create New Key`.
    - Save the result
        - keyID → **B2_ACCOUNT_ID**
        - applicationKey → **B2_ACCOUNT_KEY**
5. Done

### Make a Test
If you have finished getting the `keyID` and `applicationKey` by following the tutorial above, now you have to make a test.

1. Create rclone.conf and put it inside `common/` directory of this project.

```bash
[b2]
type = b2
account = <keyID>
key = <applicationKey>
```

or if you want to see the list files
```bash
docker compose run --rm rclone -vv ls b2:
```
If you see your folder then your configuration is succesful.

### Usage
After you have already made a successful test.  
Here is the basic usage of this script.

#### Edit the docker-compose.yml
You have to edit the docker-compose.yml and modify it with your database connection.  
If you don't use other databases, just leave it as default.

#### Run the script 
This docker-compose was design to support by running a spesific database service.  
Technically the command should be like this
```bash
docker compose run --rm <service_name>
```

For example
```bash
docker compose run --rm backup-postgres

# or
docker compose run --rm backup-mysql

# or
docker compose run --rm backup-mongo
```

Note:
- You can choose what service that you want to run backup.
- This command will run only once then exited and delete the container automatically.

#### Example for Cronjob

```bash
0 3 * * * cd /srv/multi-db-backup && docker compose run --rm backup-postgres >> /var/log/backup-postgres.log 2>&1
```

Note:
- Assume that the `multi-db-backup` is located inside `/srv/` directory.
- You can change the path to anywhere you like.
