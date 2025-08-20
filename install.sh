#!/usr/bin/env bash
set -e

echo "=== Установка Seafile ALL-in-One ==="

check_dep() {
  if ! command -v $1 &>/dev/null; then
    echo "❌ Требуется $1, но он не найден в PATH."
    exit 1
  fi
}

check_dep docker
check_dep make
check_dep openssl

if [ ! -f ".env" ]; then
  echo "Создаём .env..."

  read -p "🌐 Введите ваш домен (например, seafile.example.com): " DOMAIN
  read -p "📧 Введите ваш email (для Let's Encrypt): " EMAIL

  MYSQL_ROOT_PASSWORD=$(openssl rand -base64 18)
  SEAFILE_DB_PASSWORD=$(openssl rand -base64 18)
  REDIS_PASSWORD=$(openssl rand -base64 18)
  JWT_KEY=$(openssl rand -hex 40)
  ADMIN_PASS=$(openssl rand -base64 12)

  cat > .env <<EOF
SEAFILE_VOLUME=./data/seafile-data
SEAFILE_MYSQL_VOLUME=./data/mysql

INIT_SEAFILE_MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
SEAFILE_MYSQL_DB_USER=seafile
SEAFILE_MYSQL_DB_PASSWORD=${SEAFILE_DB_PASSWORD}
SEAFILE_MYSQL_DB_CCNET_DB_NAME=ccnet_db
SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=seafile_db
SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=seahub_db

REDIS_PASSWORD=${REDIS_PASSWORD}

JWT_PRIVATE_KEY=${JWT_KEY}
SEAFILE_SERVER_HOSTNAME=${DOMAIN}
SEAFILE_SERVER_PROTOCOL=https
TIME_ZONE=UTC

INIT_SEAFILE_ADMIN_EMAIL=admin@${DOMAIN}
INIT_SEAFILE_ADMIN_PASSWORD=${ADMIN_PASS}

LETSENCRYPT_EMAIL=${EMAIL}
LOCAL_IP=127.0.0.1
EOF
  echo ".env создан ✅"
fi

echo "✅ Зависимости найдены. Запуск установки..."

make up

echo ""
echo "🎉 Seafile установлен!"
echo "Откройте: https://${DOMAIN}/"
echo ""
echo "Админ-логин: $(grep INIT_SEAFILE_ADMIN_EMAIL .env | cut -d= -f2)"
echo "Админ-пароль: $(grep INIT_SEAFILE_ADMIN_PASSWORD .env | cut -d= -f2)"
