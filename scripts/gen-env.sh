#!/usr/bin/env bash
set -euo pipefail

FORCE=0
while getopts "f" opt; do
  case $opt in
    f) FORCE=1 ;;
  esac
done

if [[ -f ".env" && $FORCE -eq 0 ]]; then
  echo ".env уже существует — пропускаю генерацию"
  exit 0
fi

mkdir -p data/seafile-data data/mysql

rand() { openssl rand -base64 36 | tr -d '\n' ; }
jwt()  { openssl rand -hex 40 | tr -d '\n' ; }

INIT_SEAFILE_MYSQL_ROOT_PASSWORD=$(rand)
SEAFILE_MYSQL_DB_PASSWORD=$(rand)
REDIS_PASSWORD=$(rand)
JWT_PRIVATE_KEY=$(jwt)
TIME_ZONE=${TIME_ZONE:-Europe/Berlin}

cat > .env <<EOF
SEAFILE_VOLUME=./data/seafile-data
SEAFILE_MYSQL_VOLUME=./data/mysql

INIT_SEAFILE_MYSQL_ROOT_PASSWORD=${INIT_SEAFILE_MYSQL_ROOT_PASSWORD}
SEAFILE_MYSQL_DB_USER=seafile
SEAFILE_MYSQL_DB_PASSWORD=${SEAFILE_MYSQL_DB_PASSWORD}
SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db

REDIS_PASSWORD=${REDIS_PASSWORD}

JWT_PRIVATE_KEY=${JWT_PRIVATE_KEY}
SEAFILE_SERVER_HOSTNAME=localhost
SEAFILE_SERVER_PROTOCOL=http
TIME_ZONE=${TIME_ZONE}
INIT_SEAFILE_ADMIN_EMAIL=admin@example.com
INIT_SEAFILE_ADMIN_PASSWORD=ChangeMe123!
EOF

echo ".env сгенерирован."
