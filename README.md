# Seafile CE 12 + MariaDB + NGINX + Redis (Docker Compose)

Готовый репозиторий для «запуска с одного клика». Стек: **Seafile CE 12.0.14**, **MariaDB 10.11**, **NGINX**, **Redis 7**. Всё упаковано в Docker Compose.

> Быстрый старт (HTTP, без TLS):  
> **`make up`** — создаст `.env` (если его нет), поднимет контейнеры и через ~минуту Seafile будет доступен на `http://localhost/`.

## Что входит
- `docker-compose.yml` — сервисы: `seafile`, `db` (MariaDB), `redis`, `nginx` (reverse proxy).
- `nginx/seafile.conf` — готовый конфиг NGINX (проксирует Seahub и Fileserver).
- `scripts/gen-env.sh` — сгенерирует `.env` с надёжными паролями/ключами.
- `.env.example` — пример значений.
- `Makefile` — удобные команды (`up`, `down`, `logs`, `reset`).
- `.gitignore` — исключает данные и локальные файлы.
  
## Быстрый запуск
```bash
# 1) Клонируйте репозиторий или распакуйте zip
# 2) Запуск
make up

# Открыть в браузере
http://localhost/
```
При первом запуске будет создан админ: `INIT_SEAFILE_ADMIN_EMAIL` / `INIT_SEAFILE_ADMIN_PASSWORD` (смотрите/меняйте в `.env`).

## Параметры
Все переменные берутся из `.env`. Ключевые:
- `SEAFILE_SERVER_HOSTNAME` — ваш домен/хост (например, `cloud.example.com`).
- `SEAFILE_SERVER_PROTOCOL` — `http` или `https` (для внешней схемы URL в Seafile).
- `TIME_ZONE` — таймзона для контейнеров (например, `Europe/Berlin`).
- `CACHE_PROVIDER=redis` + `REDIS_*` — кэш Redis (подготовлено для Seafile 12/13).

## HTTPS (опционально)
В этом шаблоне NGINX слушает **80/tcp**. Для быстрого прототипа этого достаточно. Для продакшена рекомендуем:
- Поставить внешнюю TLS-терминацию (Traefik/Nginx Proxy Manager/Caddy/Cloudflare Tunnel)  
  или
- Добавить сертификаты в контейнер NGINX и включить `listen 443 ssl;` (не входит в quick-start).

## Пути данных
- MariaDB: `./data/mysql`
- Seafile (конфиги/данные/логи): `./data/seafile-data`

Эти каталоги монтируются в контейнеры и переживут пересоздание сервисов.

## Команды
```bash
make up         # генерация .env при необходимости + docker compose up -d
make down       # остановить
make logs       # смотреть логи seafile
make reset      # ОСТОРОЖНО: удалить ./data/* и пересоздать всё начисто
```

## Версии и источники
- Образ Seafile CE: `seafileltd/seafile-mc:12.0.14` (последний стабильный на 2025‑05‑29).  
- Официальные доки по Docker для Seafile 12: manual.seafile.com/12.0  
- Перенаправление `/seafhttp` на fileserver (8082) и `/` на Seahub (8000) реализовано в `nginx/seafile.conf`.

## Примечания
- Первый запуск и инициализация БД занимает ~1–2 минуты на среднем железе.
- Для больших загрузок можно поднять `client_max_body_size` в `nginx/seafile.conf`.
- Для продакшена смените пароли/секреты и включите HTTPS.
