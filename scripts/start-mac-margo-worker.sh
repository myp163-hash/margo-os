#!/usr/bin/env bash
# Запуск Cursor My Machines worker на Mac Марго.
# С планшета: новый Agent → environment = mac-margo.
# Кузница доступна с Mac по LAN (192.168.31.107:11434).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WORKER_NAME="${WORKER_NAME:-mac-margo}"
FORGE_HOST="${FORGE_HOST:-192.168.31.107}"
FORGE_PORT="${FORGE_PORT:-11434}"

if ! command -v agent >/dev/null 2>&1; then
  echo "CLI agent не найден. Установи:"
  echo "  curl https://cursor.com/install -fsS | bash"
  exit 1
fi

echo "=== preflight Кузница + matrix ==="
if ! bash "$ROOT/scripts/health-lan.sh"; then
  echo
  echo "Предупреждение: не всё отвечает."
  echo "Worker всё равно можно стартовать — агент на Mac сможет чинить сервисы."
  echo "Ожидается Кузница: http://${FORGE_HOST}:${FORGE_PORT}"
  echo "Ожидается matrix:  http://127.0.0.1:2026"
fi

echo
echo "=== старт worker: ${WORKER_NAME} ==="
echo "Дальше с планшета: cursor.com/agents → New → выбери ${WORKER_NAME}"
echo "Не закрывай этот терминал."
echo

exec agent worker start --name "$WORKER_NAME" --worker-dir "$ROOT"
