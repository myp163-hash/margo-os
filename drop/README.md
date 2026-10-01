# drop/ — облачный почтовый ящик Mac Марго

Ящик живёт в приватном репозитории `myp163-hash/margo-core`. Файлы, которые Claude кладёт в его `drop/` в ветке `main` или `claude/*`, Mac забирает
сам раз в минуту (`scripts/cloud-drop-sync.sh` под launchd):

| В репозитории            | На Маке                       |
|--------------------------|-------------------------------|
| `drop/core/<путь>`       | `$MARGO_DIR/<путь>` (MARGO_CORE) |
| `drop/incoming/<путь>`   | `~/margo_incoming/<путь>`     |
| `drop/run/<имя>.sh`      | выполняется один раз в MARGO_DIR (таймаут 300 с), вывод с замаскированными ключами → `run-*.log` в `cloud-drop-status` |

- `.env`, `credentials`, `.ssh`, `.git`, ключи и базы не трогаются никогда.
- `.py` и `.sh` проверяются на синтаксис; битый файл не кладётся.
- Прежняя версия файла сохраняется в `~/.margo_cloud_drop/backups/<время>/`.
- Удаления не выполняются.
- После замены `matrix.py`, `ollama_router.py` или `margo_billing.py` ядро
  перезапускается через `tools/перезапуск.sh`.
- В отчёте — названия ключей из `.env` (без значений): задан / пусто / выключен.
- Отчёт (что легло, здоровье Кузницы и matrix) Mac пишет в ветку
  `cloud-drop-status`, файл `status.md`.

Установка на Маке: `MARGO_DIR=/путь/к/MARGO_CORE ./scripts/install-cloud-drop.sh`
