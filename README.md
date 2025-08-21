# Seafile Docker Stack (Ubuntu 24.04)
Просто скачайте и запустите наш скрипт:

```bash
git clone https://github.com/RoXyGeNOFF/SeaFile-WithRedis-ALLinOne.git
cd instant_seafile
chmod +x instant_seafile.sh
./instant_seafile.sh
```
Готовый репозиторий для развёртывания **Seafile 11+** с помощью Docker Compose:
**Seafile**, **Nginx**, **Certbot (Let's Encrypt)**, **MySQL 8.0**, **Redis**, **Elasticsearch 7.x**.

## Что внутри
- Полная изоляция контейнеров и общая сеть
- Автоматический выпуск и продление SSL
- Правильные healthchecks и порядок запуска
- Скрипт ожидания зависимостей (`scripts/wait-for-services.sh`)
- Ночной авто-бэкап БД и данных (`backup` сервис)
- Простая настройка через `.env`

---

## 0) Требования
1. Ubuntu 24.04 с открытыми портами **80** и **443**
2. Домен `SEAFILE_SERVER_HOSTNAME` с A-записью на IP сервера
3. Установленный Docker + Docker Compose

## 1) Установка Docker и Compose
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker --version && docker compose version
```
*(опционально)* дать права без sudo:
```bash
sudo usermod -aG docker $USER && newgrp docker
```

## 2) Клонирование
```bash
git clone https://github.com/RoXyGeNOFF/SeaFile-WithRedis-ALLinOne.git
cd SeaFile-WithRedis-ALLinOne
```

## 3) Настройка `.env`
Откройте `.env` и задайте:
- `SEAFILE_SERVER_HOSTNAME` — ваш домен (например, drive.example.com)
- `LETSENCRYPT_EMAIL` — почта для Let's Encrypt
- поменяйте все автоматические пароли на свои

Мини-пример:
```ini
SEAFILE_SERVER_HOSTNAME=drive.example.com
LETSENCRYPT_EMAIL=you@example.com
LETSENCRYPT_ENV=staging
SEAFILE_ADMIN_EMAIL=admin@example.com
SEAFILE_ADMIN_PASSWORD=SuperSecret_123
```

## 4) Первый запуск (без сертификата)
Создаём папки и стартуем:
```bash
mkdir -p data/seafile/seafile-data data/mysql data/redis data/elasticsearch data/certbot/{conf,www} data/backups
docker compose up -d
docker compose ps
docker compose logs -f seafile
```

Откройте `http://ВАШ_ДОМЕН` — будет редирект на HTTPS после получения сертификата.

## 5) Получение SSL
```bash
chmod +x scripts/init-letsencrypt.sh
./scripts/init-letsencrypt.sh   # staging/production берётся из .env
```
После успеха сайт доступен по `https://SEAFILE_SERVER_HOSTNAME`.
Готово — автопродление делает контейнер `certbot`.

## 6) Поиск и кэш
После первого старта в `data/seafile/seafile-data/seafile/conf` появятся:
- `seahub_settings.py` — добавьте Redis-кэш:
  ```python
  CACHES = {
      'default': {
          'BACKEND': 'django_redis.cache.RedisCache',
          'LOCATION': 'redis://:REDIS_PASSWORD@redis:6379/0',
          'OPTIONS': {'CLIENT_CLASS': 'django_redis.client.DefaultClient','IGNORE_EXCEPTIONS': True}
      }
  }
  ENABLE_SSL = True
  ```
- `seafevents.conf` — включите индексирование:
  ```ini
  [INDEX FILES]
  enabled = true
  interval = 10m
  index_office_pdf = true

  [INDEX SEARCH]
  es_host = elasticsearch
  es_port = 9200

  [SEAHUB]
  enabled = true
  ```
Перезапуск:
```bash
docker compose restart seafile
```

## 7) Бэкапы
Каждую ночь в **03:15** контейнер `backup` делает:
- `mysqldump` базы `${MYSQL_DATABASE}` в `data/backups/mysql/`
- архив `/shared` (данные Seafile) в `data/backups/seafile/`

Вручную запустить разово:
```bash
docker compose exec backup sh /backup.sh
```

## 8) Полезные команды
```bash
docker compose logs -f                # все логи
docker compose logs -f seafile        # только seafile
docker compose ps
docker compose restart nginx
docker compose down                   # остановка (данные сохранятся)
docker compose pull && docker compose up -d   # обновление образов
```

## 9) Устранение неполадок
- **HTTP-01 challenge не проходит**: проверьте, что порт 80 открыт и DNS указывает на сервер. Если Cloudflare — выключите проксирование (серое облачко) на время выпуска.
- **Seafile не запускается**: убедитесь, что `mysql`, `redis`, `elasticsearch` здоровы: `docker compose ps` и `docker compose logs`.
- **Недостаточно памяти**: уменьшите `ES_JAVA_OPTS` в `.env` (например, `-Xms256m -Xmx256m`). На очень маленьких VPS можно временно убрать Elasticsearch (поиск работать не будет).
- **Большие загрузки**: увеличьте `CLIENT_MAX_BODY_SIZE` в `.env` и `docker compose restart nginx`.
- **Доступ по HTTP**: Nginx перенаправляет на HTTPS. Убедитесь, что сертификат выпущен (`data/certbot/conf/live/...`).

## 10) Обновления
- Образы зафиксированы в `.env`. Для Seafile по требованию используется `:latest` (можете закрепить конкретный тег).
- Обновление: `docker compose pull && docker compose up -d`.

## 11) Резервное копирование (лучшие практики)
- Резервируйте весь каталог `./data/` снаружи (scp/rsync/S3).
- Периодически проверяйте восстановление из бэкапа на тестовом стенде.
- Индекс Elasticsearch можно не сохранять (перестроится). Главные данные — `seafile-data` и дампы MySQL.

---
### Структура
```
seafile-docker-ubuntu/
├── .env
├── .gitignore
├── docker-compose.yml
├── README.md
├── config/nginx/nginx.conf
├── config/nginx/options-ssl-nginx.conf
├── scripts/init-letsencrypt.sh
├── scripts/wait-for-services.sh
├── scripts/backup.sh
└── data/...
```
