#!/usr/bin/env bash
set -euo pipefail

if [ ! -f ".env" ]; then
  echo "Creating .env from .env.example..."
  cp .env.example .env
  echo "Please edit .env with your real domain and email before running 'docker compose up -d'."
fi

echo "Bringing up the nginx proxy and Seafile stack..."
docker compose up -d

echo "If this is your first run, the Let's Encrypt companion may take ~1-2 minutes to issue the cert."
echo "You can check logs with: docker compose logs -f acme-companion"
