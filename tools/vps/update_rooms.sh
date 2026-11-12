#!/usr/bin/env bash
# Clashborn — cập nhật VPS CHỈ CHẠY MÁY CHỦ PHÒNG (D-352, VPS Singapore) bằng một lệnh. Chạy bằng root:
#   sudo bash /srv/clashborn/repo/tools/vps/update_rooms.sh
# Chạy lại bao nhiêu lần cũng được: kéo code, chép sang /srv/clashborn/rooms, import, cài service (khi khác), khởi động
# lại, chờ cổng 8790, ghi commit + dấu vân tay vào /srv/clashborn/rooms_deployed (hiện ở https://sg.clashborn.quest/rooms-health).
# Cài lần đầu (Godot, nginx, chứng chỉ): docs/VPS_TASKS.md V-015. Không đụng nginx.
set -euo pipefail
ROOT=/srv/clashborn
REPO="$ROOT/repo"
ROOMS="$ROOT/rooms"
GODOT_BIN=/opt/godot/godot
SERVICE=/etc/systemd/system/clashborn-rooms.service
[ "$(id -u)" -eq 0 ] || { echo "Cần chạy bằng root (sudo)."; exit 1; }
[ -x "$GODOT_BIN" ] || { echo "Chưa có $GODOT_BIN (V-015 bước 2)."; exit 1; }

echo "== 1. Kéo code"
git -C "$REPO" pull --ff-only
COMMIT="$(git -C "$REPO" rev-parse --short HEAD)"

echo "== 2. Chép + import"
install -d -o clashborn -g clashborn "$ROOMS" "$ROOMS/home"
rsync -a --delete --exclude .git --exclude .godot --exclude home --exclude art_inbox --exclude build --exclude docs \
  "$REPO"/ "$ROOMS"/
chown -R clashborn:clashborn "$ROOMS"
sudo -u clashborn env HOME="$ROOMS/home" "$GODOT_BIN" --headless --path "$ROOMS" --import >/dev/null 2>&1 || true

# D-405 (ST.5): mã ghi trận online — phải giống /etc/clashborn/rooms_token của máy chính (không in, không qua chat).
if [ ! -s /etc/clashborn/rooms_token ]; then
  echo "   CHÚ Ý: thiếu /etc/clashborn/rooms_token — máy này KHÔNG ghi trận online (xem docs/VPS_TASKS.md)"
fi

echo "== 3. Service"
if ! cmp -s "$REPO/tools/vps/clashborn-rooms-sg.service" "$SERVICE"; then
  install -m 644 "$REPO/tools/vps/clashborn-rooms-sg.service" "$SERVICE"
  systemctl daemon-reload
  systemctl enable clashborn-rooms
  echo "   đã cài service máy chủ phòng"
fi
systemctl restart clashborn-rooms
for i in $(seq 1 30); do
  sleep 1
  if ss -ltn | grep -q '127.0.0.1:8790'; then echo "   máy chủ phòng nghe 127.0.0.1:8790"; break; fi
  [ "$i" -eq 30 ] && { echo "Máy chủ phòng không lên:"; journalctl -u clashborn-rooms -n 40 --no-pager; exit 1; }
done
LINE="$(journalctl -u clashborn-rooms -n 20 --no-pager | grep 'room_server' | tail -n 1 || true)"
echo "$COMMIT ${LINE##*room_server: }" > "$ROOT/rooms_deployed"
chmod 644 "$ROOT/rooms_deployed"
echo "XONG: máy chủ phòng chạy commit $COMMIT"
echo "   $LINE"
