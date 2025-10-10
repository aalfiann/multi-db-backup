# Multi DB Backup
A multi db backup will upload your file backup to GDrive via Account Service. 

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
├── common/
│   ├── service-account.json      # this file is downloaded from Google Cloud (Service Account key)
│   └── backup.sh                 # script for backup + automatic upload
```

### Preparation
This script is require a `service-account.json`, so here is the tutorial how to get it.

1. Visit [https://console.cloud.google.com](https://console.cloud.google.com/).
2. Login with your google account.
3. Click New Project
    - **Project Name:** Auto Backup Database
    - **Location:** (leave default)
4. Activate the Google Drive API
    - In the left menu, open `APIs & Services` → `Library`.
    - Look for `Google Drive API`.
    - Click `Enable`.
5. Open `APIs & Services` → `Credentials`.
    - Click `+ CREATE CREDENTIALS` → `Service account`.
        - **Service account name:** rclone-backup
        - **Description:** Used for automated backup uploads via rclone
    - Click `Create and continue`.
    - **Role:** choose `Project → Editor` (or `Owner` for full access).
    - Click `Continue → Done`.
6. Create file service-account.json.
    - In the Service Accounts list, click the service account that you create.
    - Now click the menu tab `Keys`.
    - Click `Add key → Create new key`. File will automatically downloaded.
    - Renamed it as `service-account.json` and move it to `common/` directory of this project.
7. Give an access to your Google Drive Folder.
    - Visit [https://drive.google.com](https://drive.google.com).
    - Create new folder, for example `database-backup`.
    - Right click it folder then click `Share`.
    - Take the `client_email` from `service-account.json`, for example `rclone-backup@auto-backup-database-474121.iam.gserviceaccount.com`.
    - Choose that email as `Editor` in `Google Drive Folder`.
    - Done.

### Make a Test
If you have finished getting the `service-account.json` by following the tutorial above, now you have to make a test.

```bash
docker compose run --rm rclone lsd gdrive:
```

or if you want to see the list files
```bash
docker compose run --rm rclone ls gdrive:database-backup
```
If you don't see any errors, means your service-account.json is successful connected with your Google Drive.

### Usage
After you have the service-account.json and have already made a successful test.  
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
