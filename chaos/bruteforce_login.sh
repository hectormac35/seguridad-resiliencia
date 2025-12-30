#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-http://localhost/login}"
REQUESTS="${2:-200}"
PARALLEL="${3:-20}"

echo "[+] Bruteforce simulado a $TARGET con $REQUESTS requests (parallel=$PARALLEL)..."

seq 1 "$REQUESTS" | xargs -I{} -P "$PARALLEL" bash -c '
  i="{}"
  curl -s -o /dev/null -w "req=$i status=%{http_code}\n" \
    -H "Content-Type: application/json" \
    -X POST "'"$TARGET"'" \
    -d "{\"user\":\"admin\",\"password\":\"mal\"}" || true
'

echo "[+] Listo. Espera ver 429 si el rate limit está funcionando."
