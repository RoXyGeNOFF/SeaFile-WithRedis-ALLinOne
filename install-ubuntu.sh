#!/usr/bin/env bash
set -euo pipefail
RED=$(tput setaf 1 || true); GREEN=$(tput setaf 2 || true); YELLOW=$(tput setaf 3 || true); RESET=$(tput sgr0 || true)
need_sudo(){ if [ "$EUID" -ne 0 ]; then echo "${RED}Нужен root: sudo bash install-ubuntu.sh${RESET}"; exit 1; fi; }
confirm(){ read -r -p "$1 [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]]; }
command_exists(){ command -v "$1" >/dev/null 2>&1; }
ubuntu_version_check(){ . /etc/os-release; echo "Обнаружена: $PRETTY_NAME"; }
apt_update_upgrade(){ apt-get update -y; if confirm "Выполнить upgrade?"; then DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; fi; }
install_packages(){
  apt-get install -y ca-certificates curl gnupg lsb-release wget git ufw cron
  if ! command_exists docker; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
  fi
  if ! command_exists certbot; then
    if command_exists snap; then snap install core; snap refresh core; snap install --classic certbot; ln -sf /snap/bin/certbot /usr/bin/certbot; else apt-get install -y certbot; fi
  fi
}
setup_ufw(){ ufw allow OpenSSH || true; ufw allow 80/tcp || true; ufw allow 443/tcp || true; if confirm "Включить UFW?"; then ufw --force enable; fi; }
ask_input(){
  read -rp "Домен (seafile.example.com): " DOMAIN
  read -rp "Email для Let's Encrypt: " EMAIL
  read -rp "HTTP порт [80]: " HTTP_PORT; HTTP_PORT=${HTTP_PORT:-80}
  read -rp "HTTPS порт [443]: " HTTPS_PORT; HTTPS_PORT=${HTTPS_PORT:-443}
  read -rp "Каталог данных [/opt/seafile-data]: " DATA_DIR; DATA_DIR=${DATA_DIR:-/opt/seafile-data}
  read -rp "Email администратора [admin@${DOMAIN}]: " ADMIN_EMAIL; ADMIN_EMAIL=${ADMIN_EMAIL:-admin@${DOMAIN}}
  read -rp "Пароль администратора (пусто=автоген): " ADMIN_PASS; if [ -z "$ADMIN_PASS" ]; then ADMIN_PASS=$(openssl rand -base64 12); fi
  MYSQL_ROOT_PASSWORD=$(openssl rand -base64 18); SEAFILE_DB_PASSWORD=$(openssl rand -base64 18); REDIS_PASSWORD=$(openssl rand -base64 18); JWT_KEY=$(openssl rand -hex 40)
  export DOMAIN EMAIL HTTP_PORT HTTPS_PORT DATA_DIR ADMIN_EMAIL ADMIN_PASS MYSQL_ROOT_PASSWORD SEAFILE_DB_PASSWORD REDIS_PASSWORD JWT_KEY
}
prepare_dirs(){ mkdir -p "${DATA_DIR}/seafile" "${DATA_DIR}/mysql" "${DATA_DIR}/certs" "${DATA_DIR}/backups" "nginx/www"; chmod -R 750 "${DATA_DIR}"; }
tune_sysctl_for_es(){ echo "vm.max_map_count=262144" > /etc/sysctl.d/99-elasticsearch.conf; sysctl -w vm.max_map_count=262144; }
write_env(){
cat > .env <<EOF
SEAFILE_VOLUME=${DATA_DIR}/seafile
SEAFILE_MYSQL_VOLUME=${DATA_DIR}/mysql
CERTS_DIR=${DATA_DIR}/certs
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
INIT_SEAFILE_ADMIN_EMAIL=${ADMIN_EMAIL}
INIT_SEAFILE_ADMIN_PASSWORD=${ADMIN_PASS}
LETSENCRYPT_EMAIL=${EMAIL}
HTTP_PORT=${HTTP_PORT}
HTTPS_PORT=${HTTPS_PORT}
EOF
}
write_compose(){
cat > docker-compose.yml <<'YML'
version: "3.9"
services:
  db:
    image: mariadb:10.11
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${INIT_SEAFILE_MYSQL_ROOT_PASSWORD}
      - MYSQL_LOG_CONSOLE=true
      - MARIADB_AUTO_UPGRADE=1
    command: ["--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci","--transaction-isolation=READ-COMMITTED","--binlog-format=ROW"]
    volumes: [ "${SEAFILE_MYSQL_VOLUME}:/var/lib/mysql" ]

  redis:
    image: redis:7
    restart: unless-stopped
    command: ["redis-server","--requirepass","${REDIS_PASSWORD}"]
    volumes: [ "${SEAFILE_VOLUME}/redis:/data" ]

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.17.23
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
    ulimits: { memlock: { soft: -1, hard: -1 } }
    volumes: [ "${SEAFILE_VOLUME}/esdata:/usr/share/elasticsearch/data" ]
    restart: unless-stopped

  seafile:
    image: seafileltd/seafile-mc:12.0.14
    depends_on: [ db, redis, elasticsearch ]
    environment:
      - SEAFILE_MYSQL_DB_HOST=db
      - SEAFILE_MYSQL_DB_PORT=3306
      - SEAFILE_MYSQL_DB_USER=${SEAFILE_MYSQL_DB_USER}
      - SEAFILE_MYSQL_DB_PASSWORD=${SEAFILE_MYSQL_DB_PASSWORD}
      - SEAFILE_MYSQL_DB_CCNET_DB_NAME=${SEAFILE_MYSQL_DB_CCNET_DB_NAME}
      - SEAFILE_MYSQL_DB_SEAFILE_DB_NAME=${SEAFILE_MYSQL_DB_SEAFILE_DB_NAME}
      - SEAFILE_MYSQL_DB_SEAHUB_DB_NAME=${SEAFILE_MYSQL_DB_SEAHUB_DB_NAME}
      - CACHE_PROVIDER=redis
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
      - SEARCH_SERVERS=elasticsearch:9200
      - JWT_PRIVATE_KEY=${JWT_PRIVATE_KEY}
      - SEAFILE_SERVER_HOSTNAME=${SEAFILE_SERVER_HOSTNAME}
      - SEAFILE_SERVER_PROTOCOL=${SEAFILE_SERVER_PROTOCOL}
      - TIME_ZONE=${TIME_ZONE}
      - INIT_SEAFILE_ADMIN_EMAIL=${INIT_SEAFILE_ADMIN_EMAIL}
      - INIT_SEAFILE_ADMIN_PASSWORD=${INIT_SEAFILE_ADMIN_PASSWORD}
    volumes: [ "${SEAFILE_VOLUME}:/shared" ]
    restart: unless-stopped

  nginx:
    image: nginx:1.27
    depends_on: [ seafile ]
    ports: [ "${HTTP_PORT}:80", "${HTTPS_PORT}:443" ]
    volumes:
      - "./nginx/seafile.conf:/etc/nginx/conf.d/default.conf:ro"
      - "${CERTS_DIR}:/etc/letsencrypt:ro"
      - "./nginx/www:/var/www/certbot:ro"
      - "${SEAFILE_VOLUME}:/shared:ro"
    restart: unless-stopped

  certbot:
    image: certbot/certbot:latest
    volumes:
      - "${CERTS_DIR}:/etc/letsencrypt"
      - "./nginx/www:/var/www/certbot"
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew --webroot -w /var/www/certbot; sleep 12h & wait $${!}; done'"
    restart: unless-stopped
YML
}
write_nginx(){
cat > nginx/seafile.conf <<'NGX'
server {
    listen 80;
    server_name ${SEAFILE_SERVER_HOSTNAME};
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 301 https://$host$request_uri; }
}
server {
    listen 443 ssl;
    server_name ${SEAFILE_SERVER_HOSTNAME};
    ssl_certificate /etc/letsencrypt/live/${SEAFILE_SERVER_HOSTNAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${SEAFILE_SERVER_HOSTNAME}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers HIGH:!aNULL:!MD5;
    client_max_body_size 2G;
    proxy_read_timeout 3600s;
    location /seafhttp {
        rewrite ^/seafhttp(.*)$ $1 break;
        proxy_pass http://seafile:8082;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    location / {
        proxy_pass http://seafile:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    location /media { alias /shared/seafile/seahub/media; }
}
NGX
mkdir -p nginx/www
}
initial_cert(){
  echo "Выпускаю стартовый сертификат для ${DOMAIN}..."
  docker run --rm -v "${DATA_DIR}/certs:/etc/letsencrypt" -v "${PWD}/nginx/www:/var/www/certbot" certbot/certbot certonly \
    --webroot -w /var/www/certbot -d "${DOMAIN}" --email "${EMAIL}" --agree-tos --no-eff-email || true
}
write_scripts(){
  mkdir -p scripts
  printf '#!/usr/bin/env bash\nset -e\ndocker compose up -d\n' > scripts/start.sh
  printf '#!/usr/bin/env bash\nset -e\ndocker compose down\n' > scripts/stop.sh
  printf '#!/usr/bin/env bash\nset -e\ndocker compose pull && docker compose up -d\n' > scripts/update.sh
  cat > scripts/backup.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
TS=$(date +"%Y%m%d-%H%M%S")
OUT="backups/backup-${TS}.tar.gz"
mkdir -p backups
tar -czf "$OUT" .env docker-compose.yml nginx
echo "Backup: $OUT"
BASH
  cat > scripts/restore.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
ARCHIVE="$1"
[ -z "$ARCHIVE" ] && { echo "Usage: scripts/restore.sh <archive.tar.gz>"; exit 1; }
docker compose down || true
tar -xzf "$ARCHIVE"
echo "Восстановлено. Запустите: docker compose up -d"
BASH
  cat > scripts/reinstall.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
read -rp "Переустановить стек? [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] || exit 0
docker compose down -v || true
docker system prune -af || true
docker compose pull
docker compose up -d
BASH
  cat > scripts/issue-cert.sh <<'BASH'
#!/usr/bin/env bash
set -e
DOMAIN=$(grep SEAFILE_SERVER_HOSTNAME .env | cut -d= -f2)
EMAIL=$(grep LETSENCRYPT_EMAIL .env | cut -d= -f2)
DATA_DIR=$(grep SEAFILE_VOLUME .env | cut -d= -f2 | sed 's#/seafile$##')
mkdir -p "$DATA_DIR/certs" nginx/www
docker run --rm -v "${DATA_DIR}/certs:/etc/letsencrypt" -v "${PWD}/nginx/www:/var/www/certbot" certbot/certbot certonly \
  --webroot -w /var/www/certbot -d "${DOMAIN}" --email "${EMAIL}" --agree-tos --no-eff-email
BASH
  chmod +x scripts/*.sh
}
setup_cron_systemd(){
  (crontab -l 2>/dev/null; echo "0 3 * * * cd $(pwd) && /usr/bin/bash scripts/backup.sh >/dev/null 2>&1") | crontab -
  cat > /etc/systemd/system/seafile-stack.service <<UNIT
[Unit]
Description=Seafile Docker Stack
After=docker.service
Requires=docker.service
[Service]
Type=oneshot
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable seafile-stack.service
}
stack_up(){ docker compose pull && docker compose up -d; }
health_check(){ docker compose ps; echo "https://${DOMAIN}/"; echo "Admin: ${ADMIN_EMAIL}"; echo "Pass: ${ADMIN_PASS}"; }

main(){ need_sudo; ubuntu_version_check; apt_update_upgrade; install_packages; setup_ufw; ask_input; prepare_dirs; tune_sysctl_for_es; write_env; write_compose; write_nginx; initial_cert; write_scripts; setup_cron_systemd; stack_up; health_check; echo "${GREEN}Готово!${RESET}"; }
main "$@"
