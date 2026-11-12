#!/usr/bin/env bash
# D-367: quay video so sánh mức tam giác (so_tam_giac.gd): 2 góc × 3 hoạt ảnh × 3 giây, 4 bản → so_tam_giac.mp4
cd "$(dirname "$0")/../../../.." || exit 1
D=art_inbox/3d/phong_tien_v2
M="res://assets/models/style/heroes/phong_tien.glb,res://$D/game/phong_tien_v2_3k.glb,res://$D/game/phong_tien_v2_6k.glb,res://$D/game/phong_tien_v2_12k.glb"
L="Hiện tại 3.1k,PA3 3.7k,PA3 6.6k + ngón,PA3 11.5k + ngón"
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
ffmpeg -y -loglevel error -f concat -safe 0 -i "$T/list.txt" -an -c:v libx264 -pix_fmt yuv420p -crf 22 $D/preview/so_tam_giac.mp4
ls -la $D/preview/so_tam_giac.mp4
