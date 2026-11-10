#!/usr/bin/env bash
# ST.4 (D-331): gửi biên bản trận bot vs bot (JSONL của sim_matches.gd) lên Clashborn Stats theo lô (POST /api/matches,
# cần mã: biến CLASHBORN_TOKEN, hoặc proxy của phiên cloud tự thêm). Dùng: bash tools/stats/upload_matches.sh file.jsonl
set -euo pipefail
FILE="$1"
URL="${CLASHBORN_URL:-https://clashborn.quest}/api/matches"
AUTH=()
[ -n "${CLASHBORN_TOKEN:-}" ] && AUTH=(-H "Authorization: Bearer $CLASHBORN_TOKEN")
split -l 200 "$FILE" "$FILE.part."
for part in "$FILE".part.*; do
  python3 -I -c 'import json,sys; print(json.dumps({"matches": [json.loads(l) for l in open(sys.argv[1]) if l.strip()]}))' "$part" \
    | curl -sS --fail-with-body -X POST "${AUTH[@]}" -H "Content-Type: application/json" --data-binary @- "$URL"
  echo
  rm -f "$part"
done
