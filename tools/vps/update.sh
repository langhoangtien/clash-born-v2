#!/usr/bin/env bash
# Clashborn — cập nhật VPS bằng MỘT lệnh (D-288). Chạy trên VPS bằng root:
#   sudo bash /srv/clashborn/repo/tools/vps/update.sh
# Chạy lại bao nhiêu lần cũng được: kéo code, tạo thư mục, cài service + cấu hình nginx (chỉ khi khác, sao lưu bản
# cũ, nginx -t lỗi thì trả lại bản cũ), chạy test máy chủ, khởi động lại, ghi commit vào /srv/clashborn/deployed
# (hiện ở https://clashborn.quest/api/health → phiên cloud tự kiểm VPS đã cập nhật chưa). Việc riêng từng đợt: docs/VPS_TASKS.md.
set -euo pipefail
ROOT=/srv/clashborn
REPO="$ROOT/repo"
NGINX_SITE=/etc/nginx/sites-available/clashborn.quest
SERVICE=/etc/systemd/system/clashborn-upload.service
[ "$(id -u)" -eq 0 ] || { echo "Cần chạy bằng root (sudo)."; exit 1; }

echo "== 1. Kéo code"
git -C "$REPO" pull --ff-only
COMMIT="$(git -C "$REPO" rev-parse --short HEAD)"

echo "== 2. Test máy chủ (trước khi đổi gì)"
( cd "$REPO" && python3 -I -m unittest discover -s tools/vps -p 'test_*.py' -q ) || { echo "Test đỏ — dừng, chưa đổi gì."; exit 1; }
rm -rf "$REPO/tools/vps/__pycache__"

echo "== 3. Thư mục"
install -d -o clashborn -g clashborn "$ROOT/www" "$ROOT/incoming" "$ROOT/reports" "$ROOT/stats" "$ROOT/rejected"

echo "== 4. Service"
if ! cmp -s "$REPO/tools/vps/clashborn-upload.service" "$SERVICE"; then
  install -m 644 "$REPO/tools/vps/clashborn-upload.service" "$SERVICE"
  systemctl daemon-reload
  echo "   đã cài service mới"
fi

echo "== 5. nginx"
if ! cmp -s "$REPO/tools/vps/nginx-clashborn.conf" "$NGINX_SITE"; then
  BACKUP="$NGINX_SITE.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$NGINX_SITE" "$BACKUP"
  diff -u "$BACKUP" "$REPO/tools/vps/nginx-clashborn.conf" || true
  install -m 644 "$REPO/tools/vps/nginx-clashborn.conf" "$NGINX_SITE"
  if nginx -t; then
    systemctl reload nginx
    echo "   đã nạp cấu hình nginx mới (bản cũ: $BACKUP)"
  else
    cp "$BACKUP" "$NGINX_SITE"
    echo "nginx -t lỗi — đã trả lại bản cũ."; exit 1
  fi
fi

echo "== 6. Khởi động lại máy chủ nhận bản build"
echo "$COMMIT" > "$ROOT/deployed"
chmod 644 "$ROOT/deployed"
systemctl restart clashborn-upload
for i in 1 2 3 4 5; do
  sleep 1
  if curl -fsS http://127.0.0.1:8787/api/health; then echo; break; fi
  [ "$i" -eq 5 ] && { echo "Máy chủ không lên:"; journalctl -u clashborn-upload -n 30 --no-pager; exit 1; }
done

echo "== 6b. Máy chủ phòng online (D-338) — cần Godot ở /opt/godot/godot (docs/VPS_TASKS.md V-007)"
GODOT_BIN=/opt/godot/godot
ROOMS="$ROOT/rooms"
ROOMS_SERVICE=/etc/systemd/system/clashborn-rooms.service
if [ -x "$GODOT_BIN" ]; then
  install -d -o clashborn -g clashborn "$ROOMS" "$ROOMS/home"
  # Bản sao riêng (repo chỉ đọc; Godot cần ghi .godot/): giữ .godot cũ để import nhanh, bỏ ảnh / tài liệu không cần.
  rsync -a --delete --exclude .git --exclude .godot --exclude home --exclude art_inbox --exclude build --exclude docs \
    "$REPO"/ "$ROOMS"/
  chown -R clashborn:clashborn "$ROOMS"
  sudo -u clashborn env HOME="$ROOMS/home" "$GODOT_BIN" --headless --path "$ROOMS" --import >/dev/null 2>&1 || true
  if ! cmp -s "$REPO/tools/vps/clashborn-rooms.service" "$ROOMS_SERVICE"; then
    install -m 644 "$REPO/tools/vps/clashborn-rooms.service" "$ROOMS_SERVICE"
    systemctl daemon-reload
    systemctl enable clashborn-rooms
    echo "   đã cài service máy chủ phòng"
  fi
  systemctl restart clashborn-rooms
  for i in $(seq 1 20); do
    sleep 1
    if ss -ltn | grep -q '127.0.0.1:8790'; then echo "   máy chủ phòng nghe 127.0.0.1:8790"; break; fi
    [ "$i" -eq 20 ] && { echo "Máy chủ phòng không lên:"; journalctl -u clashborn-rooms -n 40 --no-pager; exit 1; }
  done
  journalctl -u clashborn-rooms -n 3 --no-pager | grep room_server || true
else
  echo "   chưa có $GODOT_BIN — bỏ qua máy chủ phòng"
fi

echo "== 7. Kiểm tra từ ngoài"
curl -fsS https://clashborn.quest/api/health; echo
curl -sS -X POST https://clashborn.quest/api/report -d '{}'; echo "   ← mong: lỗi 'thiếu kind' (cổng báo cáo đã mở)"
echo "XONG: VPS chạy commit $COMMIT"
