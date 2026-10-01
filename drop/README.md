# drop/ — облачный почтовый ящик Mac Марго

Файлы, которые Claude кладёт сюда в ветке `main` или `claude/*`, Mac забирает
сам раз в минуту (`scripts/cloud-drop-sync.sh` под launchd):

| В репозитории            | На Маке                       |
|--------------------------|-------------------------------|
| `drop/core/<путь>`       | `$MARGO_DIR/<путь>` (MARGO_CORE) |
| `drop/incoming/<путь>`   | `~/margo_incoming/<путь>`     |

- `.env`, `credentials`, `.ssh`, `.git`, ключи и базы не трогаются никогда.
- `.py` и `.sh` проверяются на синтаксис; битый файл не кладётся.
- Прежняя версия файла сохраняется в `~/.margo_cloud_drop/backups/<время>/`.
- Удаления не выполняются.
- После замены `matrix.py`, `ollama_router.py` или `margo_billing.py` ядро
  перезапускается через `tools/перезапуск.sh`.
- Отчёт (что легло, здоровье Кузницы и matrix) Mac пишет в ветку
  `cloud-drop-status`, файл `status.md`.

Установка на Маке: `MARGO_DIR=/путь/к/MARGO_CORE ./scripts/install-cloud-drop.sh`
