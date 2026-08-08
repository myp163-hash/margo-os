#!/usr/bin/env bash
# Хелпер: дернуть Кузницу с Mac (модели / generate smoke).
set -euo pipefail

FORGE="${FORGE_URL:-http://192.168.31.107:11434}"
MODEL="${MODEL:-qwen2.5-coder}"

case "${1:-tags}" in
  tags)
    curl -fsS -m 10 "${FORGE}/api/tags" | python3 -m json.tool 2>/dev/null || curl -fsS -m 10 "${FORGE}/api/tags"
    ;;
  ping)
    curl -fsS -m 60 "${FORGE}/api/generate" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"${MODEL}\",\"prompt\":\"ok\",\"stream\":false,\"options\":{\"num_predict\":8}}" \
      | python3 -m json.tool 2>/dev/null || true
    ;;
  *)
    echo "usage: $0 [tags|ping]"
    exit 2
    ;;
esac
