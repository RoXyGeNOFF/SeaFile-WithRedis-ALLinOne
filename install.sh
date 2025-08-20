#!/usr/bin/env bash
set -euo pipefail

echo "=== Seafile Auto Installer (nginx-proxy + Let's Encrypt) ==="

# --- Detect OS and install Docker if missing ---
if ! command -v docker >/dev/null 2>&1; then
  echo "[INFO] Docker not found. Installing..."
  if [ -f /etc/debian_version ]; then
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo       "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")       $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif [ -f /etc/redhat-release ]; then
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable --now docker
  else
    echo "[ERROR] Unsupported OS. Install Docker manually."
    exit 1
  fi
else
  echo "[INFO] Docker already installed."
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[ERROR] Docker Compose v2 is required. Please upgrade Docker."
  exit 1
fi

# --- Prepare .env ---
if [ ! -f ".env" ]; then
  cp .env.example .env
  echo "[INFO] .env created from template."
fi

# Ask user for domain and email if placeholders remain
if grep -q "example.com" .env; then
  read -rp "Enter your domain (e.g., cloud.example.com): " DOMAIN
  read -rp "Enter your email for Let's Encrypt: " EMAIL
  sed -i "s/SEAFILE_DOMAIN=.*/SEAFILE_DOMAIN=$DOMAIN/" .env
  sed -i "s/LETSENCRYPT_EMAIL=.*/LETSENCRYPT_EMAIL=$EMAIL/" .env
fi

# --- Launch stack ---
echo "[INFO] Starting Seafile stack with nginx-proxy + Let's Encrypt..."
docker compose up -d

echo "=== DONE ==="
echo "Check logs: docker compose logs -f acme-companion"
echo "Wait ~1 minute for Let's Encrypt to issue the certificate."
