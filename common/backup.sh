#!/bin/bash
set -e

# Timestamp
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
TMP_DIR="/tmp/backup"
mkdir -p "$TMP_DIR"

# Path ke file JSON Service Account
SERVICE_ACCOUNT_FILE="/common/service-account.json"

# Pastikan rclone tersedia
if ! command -v rclone &> /dev/null; then
  echo "Installing rclone..."
  curl -s https://rclone.org/install.sh | bash
fi

# Buat rclone.conf dinamis
mkdir -p ~/.config/rclone
cat > ~/.config/rclone/rclone.conf <<EOF
[gdrive]
type = drive
scope = drive
service_account_file = ${SERVICE_ACCOUNT_FILE}
EOF

# Fungsi upload ke Google Drive
upload_to_drive() {
  local file=$1
  local remote=$2
  local path=$3
  echo "Uploading $file → $remote:$path/"
  rclone copy "$file" "$remote:$path/" --progress
}

# Deteksi tipe backup
if [ -n "$POSTGRES_HOST" ]; then
  FILE="$TMP_DIR/${BACKUP_NAME}_${DATE}.sql.gz"
  echo "Backing up PostgreSQL..."
  PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h "$POSTGRES_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" | gzip > "$FILE"
  upload_to_drive "$FILE" "$GDRIVE_REMOTE" "$GDRIVE_PATH"

elif [ -n "$MYSQL_HOST" ]; then
  FILE="$TMP_DIR/${BACKUP_NAME}_${DATE}.sql.gz"
  echo "Backing up MySQL..."
  mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" | gzip > "$FILE"
  upload_to_drive "$FILE" "$GDRIVE_REMOTE" "$GDRIVE_PATH"

elif [ -n "$MONGO_URI" ]; then
  FILE="$TMP_DIR/${BACKUP_NAME}_${DATE}.gz"
  echo "Backing up MongoDB..."
  mongodump --uri="$MONGO_URI" --archive="$FILE" --gzip
  upload_to_drive "$FILE" "$GDRIVE_REMOTE" "$GDRIVE_PATH"

else
  echo "No database environment detected. Please set one of POSTGRES_HOST, MYSQL_HOST, or MONGO_URI."
  exit 1
fi

echo "✅ Backup completed successfully!"
