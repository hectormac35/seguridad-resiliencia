#!/usr/bin/env bash
set -euo pipefail
echo "[+] Reanudando Postgres (docker compose unpause db)..."
docker compose unpause db >/dev/null 2>&1 || true
