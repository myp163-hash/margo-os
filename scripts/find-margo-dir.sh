#!/usr/bin/env bash
# Печатает путь к ядру Марго (папка с matrix.py).
# Порядок: $MARGO_DIR → ~/MARGO_CORE → поиск Spotlight (папка, где рядом
# с matrix.py лежат tools/перезапуск.sh или margo_v1.db).
set -uo pipefail

if [ -n "${MARGO_DIR:-}" ] && [ -f "$MARGO_DIR/matrix.py" ]; then echo "$MARGO_DIR"; exit 0; fi
if [ -f "$HOME/MARGO_CORE/matrix.py" ]; then echo "$HOME/MARGO_CORE"; exit 0; fi

found=""
while IFS= read -r f; do
  d="$(dirname "$f")"
  case "$d" in */Library/*|*/.Trash/*|*/backups/*|*/patches/*|*/.margo_*) continue ;; esac
  if [ -f "$d/tools/перезапуск.sh" ] || [ -f "$d/margo_v1.db" ]; then
    found="${found}${d}"$'\n'
  fi
done < <(mdfind "kMDItemFSName == 'matrix.py'" 2>/dev/null)
found="$(printf '%s' "$found" | sort -u | sed '/^$/d')"

if [ -n "$found" ] && [ "$(printf '%s\n' "$found" | wc -l | tr -d ' ')" = "1" ]; then
  echo "$found"; exit 0
fi
{
  echo "Не нашла папку с matrix.py автоматически."
  [ -n "$found" ] && { echo "Кандидаты:"; printf '%s\n' "$found" | sed 's/^/  /'; }
  echo "Укажи путь явно:  MARGO_DIR=/путь/к/MARGO_CORE <команда>"
} >&2
exit 1
