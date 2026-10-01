#!/usr/bin/env bash
# Подключить Яндекс.Диск к Кузнице (rclone + WebDAV) для бэкапов перед чисткой.
# Пароль не выводится и не попадает в git: хранится только на Кузнице в ~/.config/rclone.
#   ./scripts/setup-yadisk.sh
# Нужен пароль приложения: id.yandex.ru → Безопасность → Пароли приложений → Файлы (WebDAV).
set -euo pipefail

FORGE="${FORGE:-margo@192.168.1.20}"

read -r -p "Логин Яндекса (без @yandex.ru): " YLOGIN
read -r -s -p "Пароль приложения для Диска: " YPASS; echo

echo "== ставлю rclone на Кузнице (если нет)"
ssh "$FORGE" 'command -v rclone >/dev/null || (curl -fsSL https://rclone.org/install.sh | sudo -n bash) || (sudo -n apt-get install -y rclone)' \
  || { echo "Не смог поставить rclone без пароля sudo. Зайди: ssh $FORGE и выполни: sudo apt-get install -y rclone"; exit 1; }

echo "== настраиваю удалённый диск yadisk:"
printf '%s' "$YPASS" | ssh "$FORGE" "set -e; P=\$(rclone obscure -); rclone config create yadisk webdav url=https://webdav.yandex.ru vendor=other user='$YLOGIN' pass=\"\$P\" >/dev/null"
unset YPASS

echo "== проверка"
ssh "$FORGE" 'rclone about yadisk: 2>&1 | head -5; rclone mkdir yadisk:MARGO_BACKUP && echo "папка MARGO_BACKUP готова"'
echo "Готово. Напиши Claude «диск подключён»."
