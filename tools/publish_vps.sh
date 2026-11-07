#!/usr/bin/env bash
# Đẩy APK vừa build (build/android/) lên https://clashborn.quest (D-278). Mã bí mật KHÔNG nằm ở đây:
# - phiên Claude Code trên cloud: proxy mạng tự gắn header Authorization cho host clashborn.quest;
# - chạy tay ở máy khác: đặt biến CLASHBORN_UPLOAD_TOKEN.
# Dùng: bash tools/publish_vps.sh ["ghi chú bản này"]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${CLASHBORN_HOST:-https://clashborn.quest}"
APK="$ROOT/build/android/clashborn.apk"
CODE="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["code"])' "$ROOT/build/android/version.json")"
NAME="0.1.$CODE"
FILE="clashborn-$NAME.apk"
SHA="$(sha256sum "$APK" | cut -d' ' -f1)"
AUTH=()
if [ -n "${CLASHBORN_UPLOAD_TOKEN:-}" ]; then AUTH=(-H "Authorization: Bearer $CLASHBORN_UPLOAD_TOKEN"); fi
echo "Tải lên $FILE ($(du -h "$APK" | cut -f1))…"
curl -fsS "${AUTH[@]}" -T "$APK" "$HOST/api/upload/$FILE" >/dev/null
NOTES="${1:-}"
BODY="$(python3 -c 'import json,sys;print(json.dumps({"code":int(sys.argv[1]),"name":sys.argv[2],"file":sys.argv[3],"sha256":sys.argv[4],"notes":sys.argv[5]}))' "$CODE" "$NAME" "$FILE" "$SHA" "$NOTES")"
curl -fsS "${AUTH[@]}" -H "Content-Type: application/json" -d "$BODY" "$HOST/api/publish"
echo
LIVE="$(curl -fsS "$HOST/version.json?t=$(date +%s)")"
case "$LIVE" in *"\"code\": $CODE"*) echo "OK: trang báo $NAME" ;; *) echo "LỖI: version.json chưa đổi: $LIVE"; exit 1 ;; esac
