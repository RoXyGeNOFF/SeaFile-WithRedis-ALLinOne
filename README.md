markdown
# Быстрая установка (one-click)

Этот файл описывает быстрый запуск Docker Compose стека Seafile.

Запуск на сервере (рекомендуется Ubuntu 22.04/24.04):

1) Клонируйте репозиторий и перейдите в него:
```bash
git clone https://github.com/RoXyGeNOFF/SeaFile-WithRedis-ALLinOne.git
cd SeaFile-WithRedis-ALLinOne
```

2) Сделайте скрипт исполняемым и запустите (пример с доменом и e-mail для certbot):
```bash
chmod +x install_one_click.sh
sudo ./install_one_click.sh drive.example.com you@example.com
```

Что делает скрипт:
- при необходимости устанавливает Docker;
- создаёт базовые каталоги `data/...`;
- создаёт минимальный `.env`, если его нет;
- подтягивает Docker-образы и поднимает стек через `docker compose up -d`;
- если передан домен, запускает инициализацию certbot в фоне (staging по умолчанию).

Примечания:
- Полное время развертывания зависит от скорости скачивания Docker-образов. При уже закешированных образах запуск укладывается в ~1 минуту.
- Для теста получения сертификатов используйте `LETSENCRYPT_ENV=staging` в `.env`.
