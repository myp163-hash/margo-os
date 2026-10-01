#!/usr/bin/env bash
# Облачный почтовый ящик Марго.
# Claude из облака кладёт файлы в папку drop/ репозитория на GitHub,
# этот скрипт (launchd, раз в минуту) забирает их на Mac и раскладывает:
#   drop/core/<путь>      → $MARGO_DIR/<путь>      (MARGO_CORE)
#   drop/incoming/<путь>  → $INCOMING_DIR/<путь>   (~/margo_incoming)
# Соединения только исходящие (Mac → GitHub): туннели, ngrok, Cloudflare не нужны.
# Обратно на ветку $STATUS_BRANCH пишется status.md — облако видит, что легло,
# и как себя чувствуют Кузница и matrix.
#
# Защита:
#   • .env, credentials, .ssh, .git, ключи, базы — не трогаются никогда;
#   • .py проверяется на синтаксис до записи, битый файл не кладётся;
#   • старая версия каждого файла сохраняется в $STATE/backups/<время>/;
#   • удаления не выполняются — только запись/замена;
#   • самый первый запуск лишь запоминает текущее состояние веток, ничего не кладёт.
# Работает на bash 3.2 (штатный bash macOS).
set -uo pipefail

REPO_URL="${REPO_URL:-https://github.com/myp163-hash/margo-os.git}"
MAIN_BRANCH="${MAIN_BRANCH:-main}"
DROP_PREFIXES="${DROP_PREFIXES:-claude}"          # ветки облачных сессий: claude/*
STATUS_BRANCH="${STATUS_BRANCH:-cloud-drop-status}"
MARGO_DIR="${MARGO_DIR:-$HOME/MARGO_CORE}"
INCOMING_DIR="${INCOMING_DIR:-$HOME/margo_incoming}"
STATE="${CLOUD_DROP_HOME:-$HOME/.margo_cloud_drop}"
REPORT="${REPORT:-1}"                              # 0 — не писать status.md
HEARTBEAT_EVERY="${HEARTBEAT_EVERY:-900}"          # сек между отчётами без новостей
RESTART_ON_CORE="${RESTART_ON_CORE:-1}"            # перезапуск ядра после замены matrix.py и т.п.
CORE_FILES="matrix.py ollama_router.py margo_billing.py"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

REPO="$STATE/repo.git"
SEEN="$STATE/seen"
LOG="$STATE/sync.log"
EMPTY_TREE="4b825dc642cb6eb9a060e54bf8d69288fbee4904"
TS="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$STATE" "$SEEN"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG" >&2; }

# ── один экземпляр за раз (flock на macOS нет — mkdir атомарен) ─────────────
LOCK="$STATE/lock"
if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then
  rmdir "$LOCK" 2>/dev/null
fi
mkdir "$LOCK" 2>/dev/null || exit 0
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cloud-drop.XXXXXX")"
trap 'rm -rf "$TMP"; rmdir "$LOCK" 2>/dev/null' EXIT

g() { git -C "$REPO" "$@"; }

# ── зеркало репозитория ─────────────────────────────────────────────────────
if [ ! -d "$REPO" ]; then
  log "клонирую $REPO_URL"
  git clone -q --bare "$REPO_URL" "$REPO" || { log "ОШИБКА: не склонировал $REPO_URL"; exit 1; }
fi
if ! g fetch -q --prune origin '+refs/heads/*:refs/heads/*' 2>"$TMP/fetch.err"; then
  log "ОШИБКА fetch: $(head -c 300 "$TMP/fetch.err")"
  exit 1
fi

FIRST_RUN=0
[ -z "$(ls -A "$SEEN" 2>/dev/null)" ] && FIRST_RUN=1

blocked() {
  # 0 = путь запрещён
  local part rc=1 IFS=/
  set -f
  for part in $1; do
    case "$part" in
      ""|.|..|.env|.env.*|*.env|credentials|.ssh|.git|.gnupg|device_tokens.json|margo_v1.db*|*.pem|*.key|id_rsa*|id_ed25519*)
        rc=0 ;;
    esac
  done
  set +f
  return $rc
}

is_core() {
  local f
  for f in $CORE_FILES; do [ "$1" = "$f" ] && return 0; done
  return 1
}

APPLIED="$TMP/applied"; SKIPPED="$TMP/skipped"
: > "$APPLIED"; : > "$SKIPPED"
NEED_RESTART=0

apply_one() {
  # $1 = коммит, $2 = путь в репозитории (drop/<корень>/<путь>), $3 = ветка
  local sha="$1" src="$2" ref="$3" rest root rel dest base tmpf bak
  rest="${src#drop/}"
  root="${rest%%/*}"
  rel="${rest#*/}"
  [ "$rel" = "$rest" ] && return 0            # drop/README.md и т.п. — служебное
  case "$root" in
    core)     base="$MARGO_DIR" ;;
    incoming) base="$INCOMING_DIR" ;;
    *) echo "$src — неизвестная папка «$root» (есть core/ и incoming/)" >> "$SKIPPED"; return 0 ;;
  esac
  if blocked "$rel"; then
    echo "$src — запрещённый путь, не трогаю" >> "$SKIPPED"; return 0
  fi
  if [ ! -d "$base" ]; then
    echo "$src — нет папки $base" >> "$SKIPPED"; return 0
  fi
  dest="$base/$rel"
  tmpf="$TMP/blob"
  if ! g cat-file blob "$sha:$src" > "$tmpf" 2>/dev/null; then
    echo "$src — не прочитал из $ref" >> "$SKIPPED"; return 0
  fi
  case "$rel" in
    *.py)
      if ! python3 -c 'import ast,sys; ast.parse(open(sys.argv[1],"rb").read())' "$tmpf" 2>"$TMP/syntax.err"; then
        echo "$src — синтаксическая ошибка, НЕ положил: $(tail -n 1 "$TMP/syntax.err")" >> "$SKIPPED"; return 0
      fi ;;
    *.sh)
      if ! bash -n "$tmpf" 2>"$TMP/syntax.err"; then
        echo "$src — синтаксическая ошибка, НЕ положил: $(tail -n 1 "$TMP/syntax.err")" >> "$SKIPPED"; return 0
      fi ;;
  esac
  if [ -f "$dest" ] && cmp -s "$tmpf" "$dest"; then
    return 0                                   # уже такой же
  fi
  if [ -e "$dest" ]; then
    bak="$STATE/backups/$TS/$root/$rel"
    mkdir -p "$(dirname "$bak")" && cp -p "$dest" "$bak"
  fi
  mkdir -p "$(dirname "$dest")" || { echo "$src — не создал папку" >> "$SKIPPED"; return 0; }
  if cp "$tmpf" "$dest.cloud-drop.tmp" && mv -f "$dest.cloud-drop.tmp" "$dest"; then
    case "$rel" in *.sh) chmod +x "$dest" ;; esac
    echo "$root/$rel  ($ref @ ${sha:0:7})" >> "$APPLIED"
    log "положила $dest  ← $ref"
    if [ "$root" = core ] && is_core "$rel"; then NEED_RESTART=1; fi
  else
    rm -f "$dest.cloud-drop.tmp"
    echo "$src — не записал в $dest" >> "$SKIPPED"
  fi
}

# ── ветки: main + claude/* ──────────────────────────────────────────────────
PATTERNS="refs/heads/$MAIN_BRANCH"
for p in $DROP_PREFIXES; do PATTERNS="$PATTERNS refs/heads/$p"; done

# старые коммиты сначала — свежая ветка перезапишет старую, а не наоборот
for ref in $(g for-each-ref --sort=committerdate --format='%(refname:short)' $PATTERNS); do
  new="$(g rev-parse "refs/heads/$ref")"
  key="$SEEN/$(echo "$ref" | tr '/' '_')"
  old="$(cat "$key" 2>/dev/null || true)"
  [ "$new" = "$old" ] && continue
  if [ "$FIRST_RUN" = 1 ]; then
    echo "$new" > "$key"; continue
  fi
  if [ -n "$old" ] && g cat-file -e "$old^{commit}" 2>/dev/null; then
    from="$(g merge-base "$old" "$new" 2>/dev/null || echo "$EMPTY_TREE")"
  elif [ "$ref" = "$MAIN_BRANCH" ]; then
    from="$EMPTY_TREE"
  else
    from="$(g merge-base "refs/heads/$MAIN_BRANCH" "$new" 2>/dev/null || echo "$EMPTY_TREE")"
  fi
  while IFS= read -r -d '' st && IFS= read -r -d '' path; do
    case "$st" in
      A|M|T) apply_one "$new" "$path" "$ref" ;;
      D)     echo "$path — удалён в $ref, на Маке не удаляю" >> "$SKIPPED" ;;
    esac
  done < <(g diff -z --no-renames --name-status "$from" "$new" -- drop/)
  echo "$new" > "$key"
done

if [ "$FIRST_RUN" = 1 ]; then
  log "первый запуск: запомнила текущие ветки, дальше кладу только новое"
fi

RESTART_NOTE=""
if [ "$NEED_RESTART" = 1 ]; then
  if [ "$RESTART_ON_CORE" = 1 ] && [ -f "$MARGO_DIR/tools/перезапуск.sh" ]; then
    if (cd "$MARGO_DIR" && bash tools/перезапуск.sh) > "$TMP/restart.out" 2>&1; then
      RESTART_NOTE="ядро перезапущено (tools/перезапуск.sh)"
    else
      RESTART_NOTE="перезапуск ядра упал: $(tail -n 3 "$TMP/restart.out" | tr '\n' ' ')"
    fi
  else
    RESTART_NOTE="ядро НЕ перезапущено (RESTART_ON_CORE=0 или нет tools/перезапуск.sh)"
  fi
  log "$RESTART_NOTE"
fi

[ -s "$SKIPPED" ] && while IFS= read -r l; do log "пропуск: $l"; done < "$SKIPPED"

# ── отчёт в облако ──────────────────────────────────────────────────────────
[ "$REPORT" = 1 ] || exit 0
last_report="$(cat "$STATE/last_report" 2>/dev/null || echo 0)"
now="$(date +%s)"
if [ ! -s "$APPLIED" ] && [ ! -s "$SKIPPED" ] && [ "$FIRST_RUN" = 0 ] \
   && [ $((now - last_report)) -lt "$HEARTBEAT_EVERY" ]; then
  exit 0
fi

{
  echo "# Mac Марго — отчёт почтового ящика"
  echo
  echo "- время: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- хост: $(hostname -s 2>/dev/null || hostname)"
  echo "- MARGO_DIR: $([ -d "$MARGO_DIR" ] && echo есть || echo НЕТ)"
  [ "$FIRST_RUN" = 1 ] && echo "- первый запуск: ветки запомнены, ничего не положено"
  echo
  echo "## Положено в этот раз"
  if [ -s "$APPLIED" ]; then sed 's/^/- /' "$APPLIED"; else echo "- ничего"; fi
  echo
  echo "## Пропущено"
  if [ -s "$SKIPPED" ]; then sed 's/^/- /' "$SKIPPED"; else echo "- ничего"; fi
  [ -n "$RESTART_NOTE" ] && { echo; echo "## Ядро"; echo "- $RESTART_NOTE"; }
  echo
  echo "## Здоровье (health-lan.sh)"
  echo '```'
  if [ -f "$SCRIPTS_DIR/health-lan.sh" ]; then
    bash "$SCRIPTS_DIR/health-lan.sh" 2>&1 | head -n 40
  else
    echo "health-lan.sh не найден рядом со скриптом"
  fi
  echo '```'
} > "$TMP/status.md"

blob="$(g hash-object -w "$TMP/status.md")" &&
tree="$(printf '100644 blob %s\tstatus.md\n' "$blob" | g mktree)" &&
commit="$(GIT_AUTHOR_NAME="Mac Margo" GIT_AUTHOR_EMAIL="mac-margo@localhost" \
          GIT_COMMITTER_NAME="Mac Margo" GIT_COMMITTER_EMAIL="mac-margo@localhost" \
          g commit-tree "$tree" -m "status $TS")" &&
if g push -q --force origin "$commit:refs/heads/$STATUS_BRANCH" 2>"$TMP/push.err"; then
  echo "$now" > "$STATE/last_report"
else
  log "отчёт не ушёл (нет прав на push?): $(head -c 300 "$TMP/push.err")"
fi
exit 0
