#!/usr/bin/env bash
# D-372: quay video Phong Tiễn mới cạnh bản cũ (so_tam_giac.gd): 2 góc × 3 hoạt ảnh × 3 giây, 4 bản → so_tam_giac.mp4
cd "$(dirname "$0")/../../../.." || exit 1
D=art_inbox/3d/phong_tien_v3
M="res://assets/models/style/heroes/phong_tien.glb,res://$D/game/phong_tien_v3.glb"
L="Hiện tại (chibi 3.1k),Mới (6.5k + ngón tay)"
T=$(mktemp -d)
n=0
for view in game near; do for anim in idle run attack; do
  for yaw in -20; do
    n=$((n+1))
    xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan --resolution 1280x720 --fixed-fps 30 \
      --write-movie "$T/$n.avi" --quit-after 90 -s tools/models/preview/so_tam_giac.gd -- --models="$M" --labels="$L" \
      --anim=$anim --view=$view --strings=$D/game/bow_string.json --yaw=$yaw >/dev/null 2>&1
    echo "file '$T/$n.avi'" >> "$T/list.txt"
  done
done; done
ffmpeg -y -loglevel error -f concat -safe 0 -i "$T/list.txt" -an -c:v libx264 -pix_fmt yuv420p -crf 22 $D/preview/phong_tien_v3.mp4
ls -la $D/preview/phong_tien_v3.mp4
