# Multi DB Backup
A multi db backup will upload your file backup to GDrive via Account Service. 


### Structure
```bash
multi-db-backup/
├── docker-compose.yml
├── common/
│   ├── service-account.json      # this file is downloaded from Google Cloud (Service Account key)
│   └── backup.sh                 # script for backup + automatic upload
```
