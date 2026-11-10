#!/usr/bin/env bash
# Dựng trang giới thiệu (D-284) vào build/site: web/site (HTML/CSS/JS, ảnh chụp) + phần sinh từ dữ liệu game
# (heroes.json, chân dung, icon chiêu thu nhỏ webp, phông Lora, icon trang; D-331: items.json + icon đồ cho /stats/). Dùng: GODOT=... bash tools/site/build_site.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="$ROOT/build/site"
rm -rf "$OUT" && mkdir -p "$OUT" && touch "$ROOT/build/.gdignore"  # Godot không nạp ảnh trong build/ vào dự án
cp -r "$ROOT/web/site/." "$OUT/"
mkdir -p "$OUT/fonts" "$OUT/img/heroes" "$OUT/img/skills" "$OUT/img/items"
cp "$ROOT/assets/fonts/Lora-Variable.ttf" "$OUT/fonts/"
"$GODOT" --headless --path "$ROOT" -s tools/site/export_heroes.gd -- "$OUT/heroes.json" >/dev/null 2>&1
"$GODOT" --headless --path "$ROOT" -s tools/site/export_items.gd -- "$OUT/items.json" >/dev/null 2>&1  # D-331: trang stats
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
for it in json.load(open(os.path.join(out, "items.json"))):  # D-331: icon đồ cho trang stats
    if os.path.exists(os.path.join(art, it["icon"] + ".png")):
        save(it["icon"], os.path.join(out, "img", "items", it["id"] + ".webp"), 64)
icon = Image.open(os.path.join(art, "duy_anh_portrait.png")).convert("RGBA")
icon.thumbnail((128, 128), Image.LANCZOS)
icon.save(os.path.join(out, "img", "icon.png"))
print("tướng:", len(heroes))
PY
du -sh "$OUT" | cut -f1 | xargs echo "Trang:"
