#!/usr/bin/env bash
set -euo pipefail

BASE="${1:-http://localhost}"
REQ="${2:-200}"
PAR="${3:-30}"

echo "== DEMO: Incidente seguridad (fuerza bruta /login) =="
echo "Lanzando $REQ requests en paralelo=$PAR contra $BASE/login"
./chaos/bruteforce_login.sh "$BASE/login" "$REQ" "$PAR" | tail -n 40

echo
echo "Últimos logs del proxy (debería verse 429 + limiting requests):"
docker compose logs proxy --tail=30
echo "== FIN DEMO =="
