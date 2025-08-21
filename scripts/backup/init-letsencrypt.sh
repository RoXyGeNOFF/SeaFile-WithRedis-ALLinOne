#!/usr/bin/env bash
set -euo pipefail

# Инициализация Let's Encrypt (первичная выдача сертификата)
if [ -f ".env" ]; then
  export $(grep -Ev '^(#|$)' .env | xargs -d '\n')
else
  echo "Файл .env не найден"
  exit 1
fi

if [ -z "${SEAFILE_SERVER_HOSTNAME:-}" ] || [ -z "${LETSENCRYPT_EMAIL:-}" ]; then
  echo "SEAFILE_SERVER_HOSTNAME и LETSENCRYPT_EMAIL должны быть заданы"
  exit 1
fi

mkdir -p "${CERTBOT_WWW}" "${CERTBOT_CONF}"

# Запускаем только nginx, чтобы webroot отвечал на 80
docker compose up -d nginx

echo "Ждём Nginx..."
sleep 3

if [ "${LETSENCRYPT_ENV}" = "staging" ]; then SERVER="--staging"; else SERVER=""; fi

echo "Запрашиваем сертификат для ${SEAFILE_SERVER_HOSTNAME}"
docker compose run --rm certbot sh -c "certbot certonly --webroot -w /var/www/certbot -d ${SEAFILE_SERVER_HOSTNAME} --agree-tos --email ${LETSENCRYPT_EMAIL} ${SERVER} --rsa-key-size 4096 --non-interactive"

echo "Перезагружаем Nginx..."
docker compose exec nginx nginx -t && docker compose exec nginx nginx -s reload || docker compose restart nginx

echo "Готово. При необходимости переключите LETSENCRYPT_ENV=production и повторите."
