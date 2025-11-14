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
  echo "🗃 Backing up PostgreSQL: $POSTGRES_DB@$POSTGRES_HOST:${POSTGRES_PORT:-5432}"
  PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h "$POSTGRES_HOST" -p "${POSTGRES_PORT:-5432}" -U "$POSTGRES_USER" -d "$POSTGRES_DB" | gzip > "$FILE"
  upload_to_remote "$FILE" "$REMOTE" "$REMOTE_PATH"

elif [ -n "$MYSQL_HOST" ]; then
  FILE="$TMP_DIR/${BACKUP_NAME}_${DATE}.sql.gz"
  echo "🗃 Backing up MySQL: $MYSQL_DATABASE@$MYSQL_HOST:${MYSQL_PORT:-3306}"
  mysqldump -h "$MYSQL_HOST" -P "${MYSQL_PORT:-3306}" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" | gzip > "$FILE"
  upload_to_remote "$FILE" "$REMOTE" "$REMOTE_PATH"

elif [ -n "$MONGO_URI" ]; then
  FILE="$TMP_DIR/${BACKUP_NAME}_${DATE}.gz"
  echo "🗃 Backing up MongoDB: $MONGO_URI"
  mongodump --uri="$MONGO_URI" --archive="$FILE" --gzip
  upload_to_remote "$FILE" "$REMOTE" "$REMOTE_PATH"

elif [ -n "$BACKUP_SOURCES" ]; then
  FILE="$TMP_DIR/${BACKUP_NAME}_${DATE}.tar.gz"
  echo "📁 Backing up multiple folders: $BACKUP_SOURCES"
  
  IFS=':' read -ra DIRS <<< "$BACKUP_SOURCES"
  
  echo "📦 Creating tar.gz archive..."
  echo "   Directories to backup:"
  
  # List directories and their sizes
  TOTAL_SIZE=0
  for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
      DIR_SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "unknown")
      echo "   ✓ $dir ($DIR_SIZE)"
    else
      echo "   ⚠️  $dir (not found)"
    fi
  done
  
  # Create tar command
  TAR_CMD="tar -czf \"$FILE\""
  for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
      # Remove leading slash untuk relative path dalam tar
      RELATIVE_PATH="${dir#/}"
      TAR_CMD="$TAR_CMD -C / \"$RELATIVE_PATH\""
    fi
  done
  
  echo "   Executing: $TAR_CMD"
  
  # Execute tar command
  if eval $TAR_CMD; then
    echo "✅ Backup created successfully: $(du -h "$FILE" | cut -f1)"
    upload_to_remote "$FILE" "$REMOTE" "$REMOTE_PATH"
  else
    echo "❌ Failed to create backup archive"
    exit 1
  fi

else
  echo "❌ No database environment or backup source detected."
  echo "   Set one of: POSTGRES_HOST, MYSQL_HOST, MONGO_URI, or BACKUP_SOURCES"
  exit 1
fi

# ==============================================
# CLEANUP
# ==============================================
echo "🧹 Cleaning up local temporary files..."
rm -f "$FILE"
rm -rf "$TMP_DIR"
echo "✅ Local cleanup completed"

echo "✅ Backup completed successfully at $DATE"
