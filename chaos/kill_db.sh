#!/usr/bin/env bash
set -euo pipefail
echo "[+] Pausando Postgres (docker compose pause db)..."
docker compose pause db >/dev/null 2>&1 || true
