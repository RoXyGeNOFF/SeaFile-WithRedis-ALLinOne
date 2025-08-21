#!/bin/bash

# Установка Seafile на Ubuntu 22.04 (MySQL + Nginx + Memcached)
# Запускайте от имени root или через sudo!

# Обновляем систему
apt update -y && apt upgrade -y

# Устанавливаем зависимости
apt install -y wget curl python3 python3-pip python3-setuptools python3-ldap memcached nginx mysql-server

# Настраиваем MySQL
mysql -e "CREATE DATABASE seafile_db CHARACTER SET utf8mb4;"
mysql -e "CREATE USER 'seafile'@'localhost' IDENTIFIED BY 'seafile_password';"
mysql -e "GRANT ALL PRIVILEGES ON seafile_db.* TO 'seafile'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Скачиваем и распаковываем Seafile
SEAFILE_VERSION="10.0.0"  # Укажите актуальную версию!
wget -O seafile-server.tar.gz "https://download.seadrive.org/seafile-server_${SEAFILE_VERSION}_x86-64.tar.gz"
tar -xzf seafile-server.tar.gz -C /opt
rm seafile-server.tar.gz
cd /opt/seafile-server-${SEAFILE_VERSION}

# Запускаем установку Seafile
./setup-seafile-mysql.sh <<EOF
seafile
localhost
seafile_password
seafile_db
EOF

# Настраиваем Memcached
sed -i 's/-l 127.0.0.1/-l 0.0.0.0/' /etc/memcached.conf
systemctl restart memcached

# Настраиваем Nginx
cat > /etc/nginx/conf.d/seafile.conf <<EOF
server {
    listen 80;
    server_name seafile.example.com;  # Замените на ваш домен или IP!

    location / {
        proxy_pass         http://127.0.0.1:8000;
        proxy_set_header   Host \$host;
        proxy_set_header   X-Real-IP \$remote_addr;
        proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# Запускаем Seafile и Nginx
./seafile.sh start
./seahub.sh start
systemctl restart nginx

# Выводим инструкции
echo "✅ Seafile установлен!"
echo "🔗 Доступен по адресу: http://$(hostname -I | awk '{print $1}')"
echo "👤 Логин: admin@example.com"
echo "🔑 Пароль: сгенерирован при установке (проверьте лог setup-seafile-mysql.sh)"
