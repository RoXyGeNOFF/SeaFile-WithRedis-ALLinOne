# Seafile CE 12 + MariaDB + NGINX + Redis + HTTPS (ALL-in-One)

Готовый репозиторий для «одного клика». Включает: **Seafile CE 12.0.14**, **MariaDB 10.11**, **NGINX**, **Redis 7**, **Let's Encrypt (Certbot)**.

---

## 🚀 Быстрый старт
```bash
git clone https://github.com/RoXyGeNOFF/SeaFile-WithRedis-ALLinOne.git
cd SeaFile-WithRedis-ALLinOne
chmod +x install.sh
./install.sh
```

Скрипт автоматически:
- спросит у вас **домен** и **email**,
- сгенерирует все пароли и ключи,
- создаст `.env`,
- запустит Seafile в Docker.

После этого Seafile будет доступен на https://<ваш_домен>/

---

## ⚙️ Что входит
- `docker-compose.yml` — сервисы: `seafile`, `mariadb`, `redis`, `nginx`, `certbot`  
- `nginx/seafile.conf` — reverse proxy c HTTPS и Let's Encrypt  
- `.env` — создаётся автоматически при установке  
- `Makefile` — удобные команды (`up`, `down`, `logs`, `reset`, `update`)  
- `install.sh` — автоустановка (полный интерактивный режим)  

---

## 🔑 Данные администратора
После установки скрипт выведет:
- логин администратора (по умолчанию `admin@<ваш_домен>`)
- случайный пароль

---

## 🔒 HTTPS
- Автоматически включён при первом запуске  
- Сертификаты хранятся в `./certs`  
- Обновление выполняется автоматически (certbot внутри контейнера)  

---

## 🔄 Обновление
```bash
make update
```

---

## 🗑️ Сброс
```bash
make reset
```

Эта команда удалит все данные и пересоздаст сервисы.
