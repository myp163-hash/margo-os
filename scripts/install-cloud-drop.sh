#!/usr/bin/env bash
# Установка облачного почтового ящика на Mac Марго (launchd, раз в минуту).
#   ./scripts/install-cloud-drop.sh            — поставить / обновить
#   ./scripts/install-cloud-drop.sh uninstall  — убрать
# Путь к проекту: MARGO_DIR=/путь/к/MARGO_CORE ./scripts/install-cloud-drop.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/cloud-drop-sync.sh"
LABEL="com.margo.cloud-drop"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
STATE="${CLOUD_DROP_HOME:-$HOME/.margo_cloud_drop}"
MARGO_DIR="${MARGO_DIR:-$HOME/MARGO_CORE}"
INCOMING_DIR="${INCOMING_DIR:-$HOME/margo_incoming}"
DOMAIN="gui/$(id -u)"

if [[ "${1:-}" == "uninstall" ]]; then
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Почтовый ящик снят. Состояние и бэкапы остались в $STATE"
  exit 0
fi

MARGO_DIR="$(MARGO_DIR="$MARGO_DIR" bash "$ROOT/scripts/find-margo-dir.sh")"
echo "Ядро Марго: $MARGO_DIR"
command -v git >/dev/null || { echo "git не найден"; exit 1; }
command -v python3 >/dev/null || { echo "python3 не найден"; exit 1; }

mkdir -p "$STATE" "$INCOMING_DIR" "$(dirname "$PLIST")"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$SCRIPT</string></array>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
    <key>MARGO_DIR</key><string>$MARGO_DIR</string>
    <key>INCOMING_DIR</key><string>$INCOMING_DIR</string>
    <key>CLOUD_DROP_HOME</key><string>$STATE</string>
  </dict>
  <key>StandardOutPath</key><string>$STATE/launchd.log</string>
  <key>StandardErrorPath</key><string>$STATE/launchd.log</string>
</dict>
</plist>
EOF

echo "=== пробный запуск (запоминает ветки, проверяет доступ к GitHub) ==="
MARGO_DIR="$MARGO_DIR" INCOMING_DIR="$INCOMING_DIR" CLOUD_DROP_HOME="$STATE" bash "$SCRIPT"
tail -n 5 "$STATE/sync.log" 2>/dev/null || true

launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
echo
echo "Готово: $LABEL работает раз в минуту."
echo "  журнал:  $STATE/sync.log"
echo "  бэкапы:  $STATE/backups/"
echo "  снять:   $0 uninstall"
