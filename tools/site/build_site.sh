#!/usr/bin/env bash
# Dựng trang giới thiệu (D-284) vào build/site: web/site (HTML/CSS/JS, ảnh chụp) + phần sinh từ dữ liệu game
# (heroes.json, chân dung, icon chiêu thu nhỏ webp, phông Lora, icon trang). Dùng: GODOT=... bash tools/site/build_site.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="$ROOT/build/site"
rm -rf "$OUT" && mkdir -p "$OUT"
cp -r "$ROOT/web/site/." "$OUT/"
mkdir -p "$OUT/fonts" "$OUT/img/heroes" "$OUT/img/skills"
cp "$ROOT/assets/fonts/Lora-Variable.ttf" "$OUT/fonts/"
"$GODOT" --headless --path "$ROOT" -s tools/site/export_heroes.gd -- "$OUT/heroes.json" >/dev/null 2>&1
python3 -I - "$ROOT" "$OUT" <<'PY'
import json, os, sys
from PIL import Image
root, out = sys.argv[1], sys.argv[2]
art = os.path.join(root, "assets", "art")
def save(src, dst, size):
    im = Image.open(os.path.join(art, src + ".png")).convert("RGBA")
    im.thumbnail((size, size), Image.LANCZOS)
    im.save(dst, "WEBP", quality=85, method=6)
heroes = json.load(open(os.path.join(out, "heroes.json")))
for h in heroes:
    save(h["id"] + "_portrait", os.path.join(out, "img", "heroes", h["id"] + ".webp"), 192)
    for s in h["skills"]:
        if os.path.exists(os.path.join(art, s["icon"] + ".png")):
            save(s["icon"], os.path.join(out, "img", "skills", s["icon"] + ".webp"), 96)
icon = Image.open(os.path.join(art, "duy_anh_portrait.png")).convert("RGBA")
icon.thumbnail((128, 128), Image.LANCZOS)
icon.save(os.path.join(out, "img", "icon.png"))
print("tướng:", len(heroes))
PY
du -sh "$OUT" | cut -f1 | xargs echo "Trang:"
