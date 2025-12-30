#!/usr/bin/env bash
set -euo pipefail

TIMEOUT="${1:-60}"
START="$(date +%s)"

echo "[+] Esperando a que db esté healthy (timeout=${TIMEOUT}s)..."

while true; do
  status="$(docker inspect -f '{{.State.Health.Status}}' seguridad-resiliencia-db-1 2>/dev/null || echo unknown)"
  if [ "$status" = "healthy" ]; then
    echo "[+] db = healthy"
    exit 0
  fi

  now="$(date +%s)"
  if [ $((now - START)) -ge "$TIMEOUT" ]; then
    echo "[!] Timeout: db no llegó a healthy. Estado actual: $status"
    echo "[!] Últimos logs db:"
    docker compose logs db --tail=40
    exit 1
  fi

  echo "    db = $status ..."
  sleep 2
done
