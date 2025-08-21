#!/bin/sh
set -eu
TS=$(date +"%Y-%m-%d_%H-%M-%S")
MYSQL_HOST=${MYSQL_HOST:-mysql}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_DB=${MYSQL_DATABASE:-seafile}
MYSQL_USER=${MYSQL_USER:-seafile}
MYSQL_PASS=${MYSQL_USER_PASSWORD:-}
BACKUP_DIR=${BACKUP_DIR:-/backups}

mkdir -p "$BACKUP_DIR/mysql" "$BACKUP_DIR/seafile"

echo "[backup] Dump MySQL..."
mysqldump -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" --routines --events --triggers --single-transaction "$MYSQL_DB" | gzip -c > "$BACKUP_DIR/mysql/${TS}-${MYSQL_DB}.sql.gz" || echo "[backup] WARN: dump failed"

echo "[backup] Archive Seafile data (/shared)..."
tar -C / -czf "$BACKUP_DIR/seafile/${TS}-seafile-data.tar.gz" shared || echo "[backup] WARN: archive failed"

echo "[backup] Done."
