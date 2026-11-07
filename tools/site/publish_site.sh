#!/usr/bin/env bash
# Dựng rồi đẩy trang giới thiệu lên https://clashborn.quest (D-284): PUT site.tar.gz → POST /api/site.
# Mã tải lên do proxy của môi trường gắn (như tools/publish_vps.sh); chạy tay thì đặt CLASHBORN_UPLOAD_TOKEN.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOST="${CLASHBORN_HOST:-https://clashborn.quest}"
bash "$ROOT/tools/site/build_site.sh"
TAR="$ROOT/build/site.tar.gz"
tar -czf "$TAR" -C "$ROOT/build/site" .
AUTH=()
if [ -n "${CLASHBORN_UPLOAD_TOKEN:-}" ]; then AUTH=(-H "Authorization: Bearer $CLASHBORN_UPLOAD_TOKEN"); fi
curl -fsS "${AUTH[@]}" -T "$TAR" "$HOST/api/upload/site.tar.gz" >/dev/null
curl -fsS "${AUTH[@]}" -X POST "$HOST/api/site"
echo
