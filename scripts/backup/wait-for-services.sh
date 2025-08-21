#!/bin/sh
set -eu

echo "[wait] Ожидание MySQL (${MYSQL_HOST:-mysql}:${MYSQL_PORT:-3306})..."
until nc -z ${MYSQL_HOST:-mysql} ${MYSQL_PORT:-3306}; do
  echo "[wait] MySQL ещё не готов, спим 2с"
  sleep 2
done
echo "[wait] MySQL доступен."

echo "[wait] Ожидание Redis (${REDIS_HOST:-redis}:${REDIS_PORT:-6379})..."
until nc -z ${REDIS_HOST:-redis} ${REDIS_PORT:-6379}; do
  echo "[wait] Redis ещё не готов, спим 2с"
  sleep 2
done
echo "[wait] Redis доступен."

echo "[wait] Ожидание Elasticsearch (${ELASTICSEARCH_HOST:-elasticsearch}:${ELASTICSEARCH_PORT:-9200})..."
# ждём tcp, затем проверяем http 200
until nc -z ${ELASTICSEARCH_HOST:-elasticsearch} ${ELASTICSEARCH_PORT:-9200}; do
  echo "[wait] Elasticsearch tcp ещё не готов, спим 2с"
  sleep 2
done

# Дополнительная проверка http
for i in $(seq 1 30); do
  if wget -qO- "http://${ELASTICSEARCH_HOST:-elasticsearch}:${ELASTICSEARCH_PORT:-9200}" >/dev/null 2>&1; then
    echo "[wait] Elasticsearch HTTP доступен."
    exit 0
  fi
  echo "[wait] Elasticsearch HTTP ещё не готов, попытка $i/30"
  sleep 2
done

echo "[wait] Elasticsearch не ответил HTTP вовремя"; exit 1
