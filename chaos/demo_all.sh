#!/usr/bin/env bash
set -euo pipefail

BASE="${1:-http://localhost}"

ts="$(date -u +%Y%m%d_%H%M%S)"
outdir="evidencias/demo_$ts"
mkdir -p "$outdir"

echo "== DEMO COMPLETA (UTC $ts) ==" | tee "$outdir/00_inicio.txt"
echo "[+] URL base: $BASE" | tee -a "$outdir/00_inicio.txt"
echo | tee -a "$outdir/00_inicio.txt"

echo "[1] Health inicial" | tee "$outdir/01_health_inicial.txt"
curl -s "$BASE/estado" | tee -a "$outdir/01_health_inicial.txt"; echo | tee -a "$outdir/01_health_inicial.txt"
curl -s "$BASE/datos"  | tee -a "$outdir/01_health_inicial.txt"; echo | tee -a "$outdir/01_health_inicial.txt"

echo "[2] Incidente resiliencia: DB pause -> /datos 503" | tee "$outdir/02_incidente_db.txt"
./chaos/kill_db.sh | tee -a "$outdir/02_incidente_db.txt"
echo -n "/estado -> " | tee -a "$outdir/02_incidente_db.txt"
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/estado" | tee -a "$outdir/02_incidente_db.txt"
echo -n "/datos  -> " | tee -a "$outdir/02_incidente_db.txt"
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/datos" | tee -a "$outdir/02_incidente_db.txt"
echo "Body /datos:" | tee -a "$outdir/02_incidente_db.txt"
curl -s "$BASE/datos" | tee -a "$outdir/02_incidente_db.txt"; echo | tee -a "$outdir/02_incidente_db.txt"

echo "[3] Recovery DB: unpause -> /datos 200" | tee "$outdir/03_recovery_db.txt"
./chaos/unpause_db.sh | tee -a "$outdir/03_recovery_db.txt"
sleep 5
echo -n "/datos  -> " | tee -a "$outdir/03_recovery_db.txt"
curl -s -o /dev/null -w "%{http_code}\n" "$BASE/datos" | tee -a "$outdir/03_recovery_db.txt"
curl -s "$BASE/datos" | tee -a "$outdir/03_recovery_db.txt"; echo | tee -a "$outdir/03_recovery_db.txt"

echo "[4] Incidente seguridad: brute force -> 429" | tee "$outdir/04_incidente_login.txt"
./chaos/bruteforce_login.sh "$BASE/login" 200 30 | tee -a "$outdir/04_incidente_login.txt" >/dev/null
echo "Tail (últimas 40 líneas):" | tee -a "$outdir/04_incidente_login.txt"
tail -n 40 "$outdir/04_incidente_login.txt" | tee "$outdir/04_incidente_login_tail.txt"

echo "[5] Logs proxy (últimos 60)" | tee "$outdir/05_proxy_logs.txt"
docker compose logs proxy --tail=60 | tee -a "$outdir/05_proxy_logs.txt" >/dev/null

echo "[6] Esperar DB healthy (para que el cierre quede perfecto)" | tee "$outdir/06_wait_db_healthy.txt"
./chaos/wait_db_healthy.sh 60 | tee -a "$outdir/06_wait_db_healthy.txt"

echo "[7] Estado docker compose" | tee "$outdir/07_compose_ps.txt"
docker compose ps | tee -a "$outdir/07_compose_ps.txt"

echo
echo "== FIN DEMO. Evidencias guardadas en: $outdir =="
