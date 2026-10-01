#!/usr/bin/env bash
# Запуск Claude Code Remote Control на Mac Марго.
# Сессия появится в приложении Claude Code / claude.ai/code (телефон, планшет, браузер),
# а команды выполняются на Mac: видны MARGO_CORE, matrix и Кузница по LAN.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

MARGO_DIR="${MARGO_DIR:-$HOME/MARGO_CORE}"
FORGE_HOST="${FORGE_HOST:-192.168.1.20}"
FORGE_PORT="${FORGE_PORT:-11434}"

if ! command -v claude >/dev/null 2>&1; then
  echo "CLI claude не найден. Установи:"
  echo "  curl -fsSL https://claude.ai/install.sh | bash"
  exit 1
fi

if [[ ! -d "$MARGO_DIR" ]]; then
  echo "Папка проекта не найдена: $MARGO_DIR"
  echo "Укажи путь явно:  MARGO_DIR=/путь/к/MARGO_CORE $0"
  exit 1
fi

echo "=== preflight Кузница + matrix ==="
if ! bash "$ROOT/scripts/health-lan.sh"; then
  echo
  echo "Предупреждение: не всё отвечает."
  echo "Remote Control всё равно можно стартовать — Claude на Mac сможет чинить сервисы."
  echo "Ожидается Кузница: http://${FORGE_HOST}:${FORGE_PORT}"
  echo "Ожидается matrix:  http://127.0.0.1:2026"
fi

echo
echo "=== старт Claude Remote Control в ${MARGO_DIR} ==="
echo "Дальше с планшета/телефона: приложение Claude Code или claude.ai/code → эта сессия."
echo "Не закрывай этот терминал. Остановить: Ctrl+C."
echo

cd "$MARGO_DIR"

# Не даём Mac уснуть, пока жив этот процесс (exec сохраняет PID).
if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -dims -w $$ &
fi

exec claude remote-control
