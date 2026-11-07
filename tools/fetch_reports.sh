#!/usr/bin/env bash
# D-287: đọc báo cáo hiệu năng người chơi gửi từ game lên https://clashborn.quest. Mã bí mật như publish_vps.sh:
# phiên Claude Code trên cloud thì proxy tự gắn; chạy tay thì đặt CLASHBORN_UPLOAD_TOKEN.
# Dùng: bash tools/fetch_reports.sh            → danh sách (mới nhất trước)
#       bash tools/fetch_reports.sh B-0042     → lưu .local/reports/B-0042.json + in ghi chú và tóm tắt
#       bash tools/fetch_reports.sh latest     → báo cáo mới nhất
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${CLASHBORN_HOST:-https://clashborn.quest}"
AUTH=()
if [ -n "${CLASHBORN_UPLOAD_TOKEN:-}" ]; then AUTH=(-H "Authorization: Bearer $CLASHBORN_UPLOAD_TOKEN"); fi
if [ $# -eq 0 ]; then
  curl -fsS "${AUTH[@]}" "$HOST/api/reports" | python3 -c '
import json, sys
for r in json.load(sys.stdin)["reports"]:
    print("%-7s %s  %-5s %-8s %-12s %s" % (r["id"], r["received"], r["kind"], r["version"], r["device"], r["note"]))'
  exit 0
fi
OUT="$ROOT/.local/reports"
mkdir -p "$OUT"
TMP="$OUT/.tai.json"
curl -fsS "${AUTH[@]}" "$HOST/api/reports/$1" -o "$TMP"
ID="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["id"])' "$TMP")"
mv "$TMP" "$OUT/$ID.json"
python3 -c '
import json, sys
r = json.load(open(sys.argv[1]))
print("%s · %s · %s" % (r["id"], r["kind"], r["received"]))
print("Ghi chú: " + (r.get("note") or "—"))
print(r.get("summary", ""))' "$OUT/$ID.json"
echo "Đầy đủ: $OUT/$ID.json"
