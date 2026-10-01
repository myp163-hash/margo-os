#!/usr/bin/env bash
# Подключить Яндекс.Диск к Кузнице для бэкапов — вход через сайт Яндекса (OAuth), без паролей.
#   ./scripts/setup-yadisk.sh
# Откроется браузер: войди в Яндекс и нажми «Разрешить». Токен уйдёт только на Кузницу.
set -euo pipefail

FORGE="${FORGE:-margo@192.168.1.20}"

command -v rclone >/dev/null || { echo "== ставлю rclone на Мак"; brew install rclone; }

echo "== открываю браузер: войди в Яндекс и нажми «Разрешить»"
OUT="$(rclone authorize yandex 2>&1)"
TOKEN="$(printf '%s\n' "$OUT" | sed -n '/--->/,/<---/p' | sed '1d;$d' | tr -d '\n')"
[ -n "$TOKEN" ] || { echo "Токен не получен:"; printf '%s\n' "$OUT" | tail -5; exit 1; }

echo "== ставлю rclone на Кузнице (если нет)"
ssh "$FORGE" 'command -v rclone >/dev/null || sudo -n apt-get install -y rclone >/dev/null 2>&1 || (curl -fsSL https://rclone.org/install.sh | sudo -n bash >/dev/null)' \
  || { echo "Не смог поставить rclone на Кузнице без пароля sudo: ssh $FORGE, затем sudo apt-get install -y rclone, и запусти скрипт снова."; exit 1; }

echo "== передаю доступ на Кузницу"
printf '%s' "$TOKEN" | ssh "$FORGE" 'T=$(cat); rclone config delete yadisk >/dev/null 2>&1; rclone config create yadisk yandex token "$T" >/dev/null'
unset TOKEN OUT

echo "== проверка"
ssh "$FORGE" 'rclone about yadisk: 2>&1 | head -4; rclone mkdir yadisk:MARGO_BACKUP && echo "папка MARGO_BACKUP готова"'
echo "Готово. Напиши Claude «диск подключён»."
