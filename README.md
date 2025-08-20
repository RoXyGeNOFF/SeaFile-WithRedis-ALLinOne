# 🚀 Seafile Auto Installer (nginx-proxy + Let's Encrypt)

Полностью автоматический деплой Seafile + MariaDB + Redis + nginx-proxy + Let's Encrypt.

## Установка за 1 минуту

На чистом сервере Ubuntu/Debian достаточно одной команды:

```bash
git clone https://github.com/RoXyGeNOFF/SeaFile-WithRedis-ALLinOne.git
cd SeaFile-WithRedis-ALLinOne
cp .env.example .env
nano .env   # впишите свои значения (LOCAL_IP, EMAIL, пароли)
chmod +x install.sh
./install.sh
```

(или просто скачайте репозиторий и выполните `./install.sh`).

## Что делает скрипт
- Устанавливает Docker и Docker Compose v2 (если нет).
- Создаёт `.env` из шаблона и спросит у вас домен и e-mail для Let's Encrypt.
- Поднимает весь стек командой `docker compose up -d`.

## Логи и проверка
```bash
docker compose logs -f acme-companion   # выпуск/обновление сертификата
docker compose logs -f seafile          # Seafile сервер
```

## Структура
- `install.sh` — автоустановка и запуск за 1 минуту
- `docker-compose.yml` — основной стек
- `.env.example` — шаблон конфигурации
- `scripts/` — вспомогательные скрипты
- `nginx/` — каталоги для прокси и сертификатов

---

# Seafile + nginx-proxy + Let's Encrypt (docker-compose)

Этот репозиторий полностью переработан: Добавлен реверс‑прокси **nginx-proxy** и автоматическая выдача/продление сертификатов **Let's Encrypt** через **acme-companion**.

## Быстрый старт

1. Установите Docker и docker-compose (Docker Compose V2).
2. Склонируйте репозиторий или распакуйте архив.
3. Скопируйте `.env.example` в `.env` и укажите:
   - `SEAFILE_DOMAIN` — ваш домен (например, `cloud.example.com`)
   - `LETSENCRYPT_EMAIL` — e‑mail для Let's Encrypt
   - По желанию — `SEAFILE_ADMIN_EMAIL`, `SEAFILE_ADMIN_PASSWORD`, `TIME_ZONE`
4. Запустите:
   ```bash
   ./scripts/setup-letsencrypt.sh
   ```
   или
   ```bash
   docker compose up -d
   ```

Сертификат будет выпущен автоматически. Первую минуту возможны 502/503, пока сервисы стартуют и сертификат не выпущен.

## Структура

- `docker-compose.yml` — основной стек:
  - `nginx-proxy` (порт 80/443)
  - `acme-companion` (Let's Encrypt)
  - `db` (MariaDB 10.11)
  - `redis`
  - `seafile` (официальный образ `seafileltd/seafile-mc`)
- `.env.example` — шаблон переменных окружения
- `scripts/setup-letsencrypt.sh` — быстрый выпуск сертов
- `nginx/` — каталоги, которые использует nginx-proxy и companion

## Полезные команды

```bash
# Логи companion (выпуск/обновление сертификатов)
docker compose logs -f acme-companion

# Логи nginx-proxy
docker compose logs -f nginx-proxy

# Логи Seafile
docker compose logs -f seafile

# Обновление образов
docker compose pull && docker compose up -d
```

## Примечания

- Для тестирования можно включить staging‑сервер Let's Encrypt:
  раскомментируйте переменную `ACME_CA_URI` в сервисе `acme-companion` в `docker-compose.yml`.
- Убедитесь, что DNS записи `A/AAAA` для `вашего домена` указывают на ваш сервер, и порты 80/443 доступны из интернета.
- Если ваш Seafile был настроен на другой порт/URL, убедитесь, что переменные `SEAFILE_SERVER_HOSTNAME` и `VIRTUAL_PORT` соответствуют действительности.
