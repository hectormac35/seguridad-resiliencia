#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
OUT="evidencias/$TS"
mkdir -p "$OUT"

echo "[1/6] Estado targets Prometheus" | tee "$OUT/00_info.txt"
curl -s "http://localhost:9090/api/v1/targets" > "$OUT/targets.json"

echo "[2/6] Tráfico a /datos (para histograma por path)" | tee -a "$OUT/00_info.txt"
for i in {1..50}; do
  curl -s http://localhost/datos >/dev/null || true
done

echo "[3/6] Disparando fuerza bruta (60s)" | tee -a "$OUT/00_info.txt"
end=$((SECONDS+60))
while [ $SECONDS -lt $end ]; do
  curl -s -X POST http://localhost/login \
    -H "Content-Type: application/json" \
    -d '{"user":"x","password":"y"}' >/dev/null || true
  sleep 0.2
done

echo "[4/6] Alertas Prometheus" | tee -a "$OUT/00_info.txt"
curl -s "http://localhost:9090/api/v1/alerts" > "$OUT/prom_alerts.json"

echo "[5/6] Alertas Alertmanager" | tee -a "$OUT/00_info.txt"
curl -s "http://localhost:9093/api/v2/alerts" > "$OUT/am_alerts.json"

echo "[6/6] Logs recientes Alertmanager" | tee -a "$OUT/00_info.txt"
docker compose logs --since=10m alertmanager > "$OUT/alertmanager.log" || true

echo "OK: Evidencias guardadas en $OUT"
