#!/bin/bash
set -e

# ==============================================
# CONFIG
# ==============================================
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
TMP_DIR="/tmp/backup"
mkdir -p "$TMP_DIR"

RCLONE_CONF_DIR="$HOME/.config/rclone"
RCLONE_CONF_FILE="$RCLONE_CONF_DIR/rclone.conf"

# Default retention: 7 days
RETENTION_DAYS=${RETENTION_DAYS:-7}

# ==============================================
# INSTALL & CONFIGURE RCLONE
# ==============================================
if ! command -v rclone &> /dev/null; then
  echo "Installing rclone..."
  curl -s https://rclone.org/install.sh | bash
fi

mkdir -p "$RCLONE_CONF_DIR"
cat > "$RCLONE_CONF_FILE" <<EOF
[b2]
type = b2
account = ${B2_ACCOUNT_ID}
key = ${B2_ACCOUNT_KEY}
EOF

# ==============================================
# FUNCTIONS
# ==============================================
upload_to_remote() {
  local file=$1
  local remote=$2
  local path=$3

  echo "📤 Uploading $file → $remote:$path/"
  rclone copy "$file" "$remote:$path/" --progress

  echo "🧹 Cleaning up old backups (> ${RETENTION_DAYS} days)..."
  rclone delete "$remote:$path" --min-age ${RETENTION_DAYS}d --b2-hard-delete --verbose
  rclone rmdirs "$remote:$path" --leave-root --verbose
}

# ==============================================
# BACKUP LOGIC
# ==============================================
if [ -n "$POSTGRES_HOST" ]; then
  FILE="$TMP_DIR/${BACKUP_NAME}_${DATE}.sql.gz"
  echo "🗃 Backing up PostgreSQL: $POSTGRES_DB@$POSTGRES_HOST"
  PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" | gzip > "$FILE"
  upload_to_remote "$FILE" "$REMOTE" "$REMOTE_PATH"

elif [ -n "$MYSQL_HOST" ]; then
  FILE="$TMP_DIR/${BACKUP_NAME}_${DATE}.sql.gz"
  echo "🗃 Backing up MySQL: $MYSQL_DATABASE@$MYSQL_HOST"
  mysqldump -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" | gzip > "$FILE"
  upload_to_remote "$FILE" "$REMOTE" "$REMOTE_PATH"

elif [ -n "$MONGO_URI" ]; then
  FILE="$TMP_DIR/${BACKUP_NAME}_${DATE}.gz"
  echo "🗃 Backing up MongoDB: $MONGO_URI"
  mongodump --uri="$MONGO_URI" --archive="$FILE" --gzip
  upload_to_remote "$FILE" "$REMOTE" "$REMOTE_PATH"

else
  echo "❌ No database environment detected. Set one of POSTGRES_HOST, MYSQL_HOST, or MONGO_URI."
  exit 1
fi

echo "✅ Backup completed successfully at $DATE"
