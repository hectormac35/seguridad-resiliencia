#!/usr/bin/env bash
set -euo pipefail

BASE="${1:-http://localhost}"

echo "== DEMO: Incidente resiliencia (DB colgada) =="
echo "[1] Estado inicial"
curl -s "$BASE/estado"; echo
curl -s "$BASE/datos"; echo

echo
echo "[2] Pausar DB (simula caída/hang)"
docker compose pause db

echo
echo "[3] Comprobación durante incidente"
echo -n "/estado -> "; curl -s -o /dev/null -w "%{http_code}\n" "$BASE/estado"
echo -n "/datos  -> "; curl -s -o /dev/null -w "%{http_code}\n" "$BASE/datos"
echo "Body /datos:"
curl -s "$BASE/datos"; echo

echo
echo "[4] Recuperación (unpause DB)"
docker compose unpause db

echo
echo "[5] Espera 5s y re-check"
sleep 5
echo -n "/datos  -> "; curl -s -o /dev/null -w "%{http_code}\n" "$BASE/datos"
curl -s "$BASE/datos"; echo

echo "== FIN DEMO =="
