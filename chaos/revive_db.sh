#!/usr/bin/env bash
set -euo pipefail

echo "[+] Arrancando Postgres (docker compose up -d db)..."
docker compose up -d db

echo "[+] Espera 5-10s y prueba:"
echo "    curl -i http://localhost/datos"
