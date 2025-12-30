#!/usr/bin/env bash
set -euo pipefail

BASE="${1:-http://localhost}"

echo "== DEMO ALERTAS =="
echo "Alertmanager UI:  http://localhost:9093"
echo "Prometheus Alerts: http://localhost:9090/alerts"
echo

echo "[0] Sanity"
curl -s -o /dev/null -w "/estado -> %{http_code}\n" "$BASE/estado"
curl -s -o /dev/null -w "/datos  -> %{http_code}\n" "$BASE/datos"
echo

echo "[1] Disparar 429 en /login (posible fuerza bruta)"
./chaos/bruteforce_login.sh "$BASE/login" 300 40 >/dev/null
echo "OK (se generó tráfico con 429)"
echo

echo "[2] Disparar 5xx en /datos (DB pause + requests)"
./chaos/kill_db.sh >/dev/null
for i in $(seq 1 40); do
  code="$(curl -s -o /dev/null -w "%{http_code}" "$BASE/datos" || true)"
  echo "req=$i status=$code"
  sleep 0.5
done
./chaos/unpause_db.sh >/dev/null
echo "OK (se generó tráfico 5xx en /datos durante la pausa)"
echo

echo "[3] Esperar a que Prometheus evalúe reglas (for: 30s)"
echo "Esperando 45s..."
sleep 45
echo

echo "[4] Mostrar alertas activas (Prometheus)"
curl -s http://localhost:9090/api/v1/alerts | python3 - << 'PY'
import json, sys
data=json.load(sys.stdin)
alerts=data.get("data", {}).get("alerts", [])
firing=[a for a in alerts if a.get("state")=="firing"]
print(f"FIRING: {len(firing)}")
for a in firing:
    labels=a.get("labels", {})
    ann=a.get("annotations", {})
    print(f"- {labels.get('alertname')} severity={labels.get('severity')} | {ann.get('summary')}")
PY
echo

echo "[5] Mostrar alertas activas (Alertmanager)"
curl -s http://localhost:9093/api/v2/alerts | python3 - << 'PY'
import json, sys
alerts=json.load(sys.stdin)
firing=[a for a in alerts if a.get("status", {}).get("state")=="active"]
print(f"ACTIVE: {len(firing)}")
for a in firing:
    labels=a.get("labels", {})
    ann=a.get("annotations", {})
    print(f"- {labels.get('alertname')} severity={labels.get('severity')} | {ann.get('summary')}")
PY

echo
echo "== FIN DEMO ALERTAS =="
