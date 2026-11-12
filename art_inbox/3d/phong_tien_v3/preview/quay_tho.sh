#!/usr/bin/env bash
# D-374: video từng hoạt ảnh Mixamo Pro Longbow nguyên bản (không cắt, không khóa tại chỗ), cung gắn tay, góc cận, camera theo hông.
cd "$(dirname "$0")/../../../.." || exit 1
D=art_inbox/3d/phong_tien_v3
M="res://$D/game/phong_tien_v3_mx_tho.glb"
T=$(mktemp -d)
python3 - "$D/game/phong_tien_v3_mx_tho.glb" > "$T/clips.txt" <<'P'
import json, struct, sys
b = open(sys.argv[1], "rb").read(); n = struct.unpack("<I", b[12:16])[0]; g = json.loads(b[20:20 + n])
for a in g["animations"]:
    print("%s\t%.3f" % (a["name"], max(g["accessors"][s["input"]]["max"][0] for s in a["samplers"])))
P
n=0
while IFS=$'\t' read -r name len; do
  n=$((n+1)); frames=$(python3 -c "import math;print(max(45, math.ceil($len*30)+6))")
  xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan --resolution 1280x720 --fixed-fps 30 \
    --write-movie "$T/$n.avi" --quit-after $frames -s tools/models/preview/so_tam_giac.gd -- --models="$M" --labels="$name" \
    "--anim=$name" --view=near --yaw=-30 --follow --strings=$D/game/bow_string.json </dev/null >/dev/null 2>&1
  echo "file '$T/$n.avi'" >> "$T/list.txt"
done < "$T/clips.txt"
ffmpeg -y -loglevel error -f concat -safe 0 -i "$T/list.txt" -an -c:v libx264 -pix_fmt yuv420p -crf 23 $D/preview/mixamo_nguyen_ban.mp4
ls -la $D/preview/mixamo_nguyen_ban.mp4
