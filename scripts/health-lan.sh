#!/usr/bin/env bash
# Проверка Mac Марго + Кузница (Forge) из локалки.
set -euo pipefail

FORGE_HOST="${FORGE_HOST:-192.168.31.107}"
FORGE_PORT="${FORGE_PORT:-11434}"
MATRIX_HOST="${MATRIX_HOST:-127.0.0.1}"
MATRIX_PORT="${MATRIX_PORT:-2026}"

ok=0
fail=0

check() {
  local name="$1"
  local url="$2"
  if curl -fsS -m 4 "$url" >/dev/null 2>&1; then
    echo "OK   $name  $url"
    ok=$((ok + 1))
  else
    echo "FAIL $name  $url"
    fail=$((fail + 1))
  fi
}

echo "=== MARGO LAN health ==="
check "Кузница /tags" "http://${FORGE_HOST}:${FORGE_PORT}/api/tags"
check "Кузница /"     "http://${FORGE_HOST}:${FORGE_PORT}/"
check "matrix :${MATRIX_PORT}" "http://${MATRIX_HOST}:${MATRIX_PORT}/"

if command -v ollama >/dev/null 2>&1; then
  echo "--- локальный ollama list ---"
  ollama list 2>/dev/null || true
fi

echo "=== итог: ok=${ok} fail=${fail} ==="
if [[ "$fail" -gt 0 ]]; then
  exit 1
fi
