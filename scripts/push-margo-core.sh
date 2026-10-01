#!/usr/bin/env bash
# Снимок MARGO_CORE → приватный репозиторий myp163-hash/margo-core.
# Рабочую папку и её собственный git не трогает: снимок ведётся в отдельном
# git-каталоге ($SNAP), рабочее дерево — сама MARGO_CORE.
# Не уходят: .env, ключи, credentials, базы, сессии Telegram, логи, модели,
# venv, файлы больше $MAX_MB МБ и любой файл, где найден текст, похожий на токен
# (такие файлы печатаются списком).
# Повторный запуск дошлёт только изменения.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="${REMOTE:-https://github.com/myp163-hash/margo-core.git}"
BRANCH="${BRANCH:-main}"
SNAP="${SNAP_GIT:-$HOME/.margo_core_snapshot.git}"
MAX_MB="${MAX_MB:-20}"
LIMIT_TOTAL_MB="${LIMIT_TOTAL_MB:-400}"   # больше — не отправляю, показываю, что тяжёлое

MARGO_DIR="$(bash "$ROOT/scripts/find-margo-dir.sh")"
echo "Ядро: $MARGO_DIR"

if [ ! -d "$SNAP" ]; then
  git init -q --bare "$SNAP"
  git --git-dir="$SNAP" config core.bare false
fi
cat > "$SNAP/info/exclude" <<'EOF'
.git
.env
.env.*
*.env
credentials/
.ssh/
.gnupg/
*.pem
*.key
*.p12
id_rsa*
id_ed25519*
*.session
*.session-journal
device_tokens.json
*.db
*.db-*
*.sqlite
*.sqlite3
chroma_db/
logs/
*.log
uploads/
tg_drops/
patches/rollback/
venv/
.venv/
node_modules/
__pycache__/
*.pyc
*.gguf
*.safetensors
*.bin
*.pt
*.pth
*.onnx
*.ckpt
models/
.DS_Store
margo.pid
# архивы, распаковки, переписка и база знаний — для разбора кода не нужны
/Марго/UNPACKED/
/_НАХОДКИ_АРХИВЫ/
/Знания/
/Синхро/
*.zip
*.tar
*.tgz
*.gz
*.7z
*.rar
*.dmg
*.pkg
*.ipa
*.iso
*.mp4
*.mov
*.m4a
*.mp3
*.wav
*.ogg
*.heic
EOF
for d in ${EXTRA_EXCLUDE:-}; do echo "/$d/" >> "$SNAP/info/exclude"; done

G() { git -c core.quotePath=false --git-dir="$SNAP" --work-tree="$MARGO_DIR" "$@"; }

rm -f "$SNAP/index"
echo "=== собираю снимок ==="
G add -A . 2>"$SNAP/add.err" || { cat "$SNAP/add.err"; exit 1; }

# вложенные git-репозитории не переносятся (только ссылка) — убираем и сообщаем
nested="$(G ls-files -s | awk -F '\t' '{ split($1,m," "); if (m[1]=="160000") print $2 }')"
if [ -n "$nested" ]; then
  echo "Вложенные git-репозитории (не перенесены):"; echo "$nested" | sed 's/^/  /'
  echo "$nested" | while IFS= read -r p; do G rm -q --cached -- "$p"; done
fi

# большие файлы
limit=$((MAX_MB * 1024 * 1024))
big="$(G ls-tree -r -l "$(G write-tree)" | awk -v L="$limit" -F '\t' '{ split($1,m," "); if (m[4]+0 > L) print $2 }')"
if [ -n "$big" ]; then
  echo "Больше ${MAX_MB} МБ (не перенесены):"; echo "$big" | sed 's/^/  /'
  echo "$big" | while IFS= read -r p; do G rm -q --cached -- "$p"; done
fi

# похожее на токены — файл целиком не уходит
PAT='-----BEGIN [A-Z ]*PRIVATE KEY-----|sk-(ant-|or-|proj-)?[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|[0-9]{8,10}:AA[A-Za-z0-9_-]{33}|hf_[A-Za-z0-9]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}'
secret="$(G grep --cached -l -I -E -e "$PAT" || true)"
if [ -n "$secret" ]; then
  echo "Найден текст, похожий на ключ/токен (файлы НЕ перенесены):"; echo "$secret" | sed 's/^/  /'
  echo "$secret" | while IFS= read -r p; do G rm -q --cached -- "$p"; done
fi

tree="$(G write-tree)"
count="$(G ls-tree -r "$tree" | wc -l | tr -d ' ')"
size="$(G ls-tree -r -l "$tree" | awk '{s+=$4} END {printf "%.1f", s/1048576}')"
echo "В снимке: $count файлов, ${size} МБ"
mb="$(G ls-tree -r -l "$tree" | awk '{s+=$4} END {printf "%d", s/1048576}')"
if [ "$mb" -gt "$LIMIT_TOTAL_MB" ]; then
  echo "Слишком много (${mb} МБ > ${LIMIT_TOTAL_MB} МБ). Самые тяжёлые папки:"
  G ls-tree -r -l "$tree" | awk -F '\t' '{ split($1,m," "); n=split($2,p,"/"); k=(n>2 ? p[1]"/"p[2] : p[1]); s[k]+=m[4] }
    END { for (k in s) printf "%8.1f МБ  %s\n", s[k]/1048576, k }' | sort -rn | head -15
  echo "Исключить папки:  EXTRA_EXCLUDE='папка1 папка2/подпапка' $0"
  echo "Или отправить всё: LIMIT_TOTAL_MB=2000 $0"
  exit 1
fi

# Родитель — только то, что реально дошло до GitHub (refs/pushed/*): неотправленный
# снимок от прерванного запуска в историю не попадёт и не потянется следом.
parent="$(G rev-parse -q --verify "refs/pushed/$BRANCH" || true)"
if [ -n "$parent" ] && [ "$(G rev-parse "$parent^{tree}")" = "$tree" ]; then
  echo "Изменений нет с прошлой отправки. Готово."
  exit 0
fi
name="$(git config --global user.name || echo 'Mac Margo')"
mail="$(git config --global user.email || echo 'mac-margo@localhost')"
commit="$(GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$mail" \
          GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$mail" \
          G commit-tree "$tree" ${parent:+-p "$parent"} -m "снимок MARGO_CORE $(date '+%Y-%m-%d %H:%M')")"
G update-ref "refs/heads/$BRANCH" "$commit"

echo "=== отправляю в $REMOTE ==="
G push "$REMOTE" "+refs/heads/$BRANCH:refs/heads/$BRANCH"
G update-ref "refs/pushed/$BRANCH" "$commit"
echo "Готово."
