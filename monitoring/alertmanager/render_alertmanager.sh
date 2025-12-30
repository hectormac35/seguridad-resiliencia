#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="$ROOT/.env"
TPL="$ROOT/monitoring/alertmanager/alertmanager.yml.tpl"
OUT="$ROOT/monitoring/alertmanager/alertmanager.yml"

if [ ! -f "$ENV_FILE" ]; then
  echo "[!] Falta $ENV_FILE"
  exit 1
fi

# Cargar .env
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
  echo "[!] TELEGRAM_BOT_TOKEN o TELEGRAM_CHAT_ID vacío en .env"
  exit 1
fi

# Validaciones básicas
if ! [[ "$TELEGRAM_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
  echo "[!] TELEGRAM_CHAT_ID debe ser numérico (puede ser negativo si es un grupo). Valor: $TELEGRAM_CHAT_ID"
  exit 1
fi

tmp="$(mktemp)"
sed \
  -e "s/__BOT_TOKEN__/${TELEGRAM_BOT_TOKEN}/g" \
  -e "s/__CHAT_ID__/${TELEGRAM_CHAT_ID}/g" \
  "$TPL" > "$tmp"

mv "$tmp" "$OUT"
echo "[+] Render OK -> $OUT"
