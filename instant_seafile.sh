#!/bin/bash

# Cкрипт установки Seafile
echo "🐳 Начинаем установку Seafile с Redis и Elasticsearch!"
echo "📦 Этот скрипт сделает всё автоматически..."
echo ""

# Проверяем, установлен ли Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен. Устанавливаем Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker установлен! Перезапустите терминал и запустите скрипт снова."
    exit 1
fi

# Проверяем, установлен ли Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose не установлен. Устанавливаем..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose установлен!"
fi

# Создаем папку для Seafile
mkdir -p seafile-setup
cd seafile-setup

echo "📁 Создаем папку для данных и конфигураций..."

# Создаем папки для данных
mkdir -p mysql-data redis-data elastic-data

# Создаем файл .env с настройками
cat > .env << EOF
# Временная зона
TIME_ZONE=Europe/Moscow

# Настройки MySQL
MYSQL_IMAGE=mysql:5.7
MYSQL_ROOT_PASSWORD=secret_root_password
MYSQL_DATABASE=seafile
MYSQL_USER=seafile
MYSQL_USER_PASSWORD=secret_user_password

# Настройки Redis
REDIS_IMAGE=redis:7.0.4-alpine
REDIS_PASSWORD=secret_redis_password

# Настройки Elasticsearch
ELASTIC_IMAGE=elasticsearch:7.17.9
ES_JAVA_OPTS=-Xms512m -Xmx512m

# Название проекта и сети
COMPOSE_PROJECT_NAME=seafile
DOCKER_NETWORK=seafile_net

# Пути к данным
MYSQL_DATA_DIR=./mysql-data
REDIS_DATA_DIR=./redis-data
ELASTIC_DATA_DIR=./elastic-data
EOF

# Создаем docker-compose.yml файл
cat > docker-compose.yml << 'EOF'


services:
  mysql:
    image: ${MYSQL_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}_mysql
    command: ["--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci","--innodb-buffer-pool-size=256M"]
    environment:
      TZ: ${TIME_ZONE}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_USER_PASSWORD}
    volumes:
      - ${MYSQL_DATA_DIR}:/var/lib/mysql
    networks:
      - ${DOCKER_NETWORK}
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -p${MYSQL_ROOT_PASSWORD} --silent"]
      start_period: 30s
      interval: 10s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  redis:
    image: ${REDIS_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}_redis
    command: >
      sh -c 'redis-server --appendonly yes --requirepass "${REDIS_PASSWORD}"'
    environment:
      TZ: ${TIME_ZONE}
    volumes:
      - ${REDIS_DATA_DIR}:/data
    networks:
      - ${DOCKER_NETWORK}
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 10s
    restart: unless-stopped

  elasticsearch:
    image: ${ELASTIC_IMAGE}
    container_name: ${COMPOSE_PROJECT_NAME}_elasticsearch
    environment:
      discovery.type: single-node
      ES_JAVA_OPTS: "${ES_JAVA_OPTS}"
      TZ: ${TIME_ZONE}
    ulimits:
      memlock:
        soft: -1
        hard: -1
    mem_limit: 2g
    volumes:
      - ${ELASTIC_DATA_DIR}:/usr/share/elasticsearch/data
    networks:
      - ${DOCKER_NETWORK}
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1:9200 >/dev/null 2>&1"]
      interval: 15s
      timeout: 5s
      retries: 20
      start_period: 30s
    restart: unless-stopped

  seafile:
    image: docker.seadrive.org/seafileltd/seafile-mc:9.0.18
    container_name: ${COMPOSE_PROJECT_NAME}_seafile
    ports:
      - "80:80"
      - "443:443"
    environment:
      TZ: ${TIME_ZONE}
      SEAFILE_SERVER_HOSTNAME: localhost
      SEAFILE_ADMIN_EMAIL: admin@example.com
      SEAFILE_ADMIN_PASSWORD: secret_admin_password
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_USER_PASSWORD: ${MYSQL_USER_PASSWORD}
      REDIS_PASSWORD: ${REDIS_PASSWORD}
      ELASTIC_PASSWORD: ${ELASTIC_PASSWORD}
    volumes:
      - ./seahub-data:/shared
    networks:
      - ${DOCKER_NETWORK}
    depends_on:
      - mysql
      - redis
      - elasticsearch
    restart: unless-stopped

networks:
  seafile_net:
    name: seafile_net
    driver: bridge
EOF

echo "✅ Файлы конфигурации созданы!"
echo "🐳 Запускаем Docker Compose..."

# Запускаем контейнеры
docker-compose up -d

echo ""
echo "🎉 Установка завершена!"
echo "📊 Seafile будет доступен через несколько минут по адресу:"
echo "   http://localhost"
echo ""
echo "🔑 Данные для входа:"
echo "   Email: admin@example.com"
echo "   Пароль: secret_admin_password"
echo ""
echo "💾 Ваши данные хранятся в папке: $(pwd)"
echo ""
echo "⚙️ Для остановки выполните: docker-compose down"
echo "▶️ Для запуска выполните: docker-compose up -d"
