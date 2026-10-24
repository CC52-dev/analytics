#!/usr/bin/env sh
# One-time server setup for SBC Analytics on a fresh Ubuntu/Debian server.
# Run as root from the deploy/ folder:  sh setup.sh
set -eu

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi

if [ ! -f .env ]; then
  echo "Creating .env with fresh secrets..."
  cp .env.example .env
  sed -i "s|^SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$(openssl rand -base64 48 | tr -d '\n')|" .env
  sed -i "s|^TOTP_VAULT_KEY=.*|TOTP_VAULT_KEY=$(openssl rand -base64 32 | tr -d '\n')|" .env
  sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(openssl rand -hex 24)|" .env
  chmod 600 .env
fi

# A small server needs swap to get through the first build
if [ "$(swapon --show | wc -l)" -eq 0 ] && [ ! -f /swapfile ]; then
  echo "Adding 4 GB swap..."
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "Building and starting (the first build takes 10-20 minutes)..."
docker compose up -d --build

echo
echo "Done. Open $(grep '^BASE_URL=' .env | cut -d= -f2) and register the first account:"
echo "it becomes the founding admin. Then manage everything from /admin."
