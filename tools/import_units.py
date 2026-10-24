#!/usr/bin/env python3
"""Nhập hình đơn vị trong trận (D-144) vào assets/art/<art_id>.png (ArtLibrary).

  python3 tools/import_units.py          # cần Pillow

Cắt sát phần có hình, đặt vào ô vuông trong suốt, **chân chạm đáy ô, giữa theo chiều ngang** —
UnitsView neo đáy ô vào chân đơn vị. Bản theo đội: `<art_id>_blue` / `<art_id>_red`.
Chạy lại an toàn (ghi đè).
"""
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
INBOX = os.path.join(ROOT, "art_inbox")
DST = os.path.join(ROOT, "assets", "art")
HEROES = ["brakk", "myra", "noctis", "vexa", "gorran", "duy_anh"]
# (file trong art_inbox, art_id, cạnh ảnh xuất)
UNITS = [
    ("02_units/creep_melee_blue.png", "creep_melee_blue", 256),
    ("02_units/creep_melee_red.png", "creep_melee_red", 256),
    ("02_units/creep_ranged_blue.png", "creep_ranged_blue", 256),
    ("02_units/creep_ranged_red.png", "creep_ranged_red", 256),
    ("02_units/creep_siege_blue.png", "creep_siege_blue", 320),
    ("02_units/creep_siege_red.png", "creep_siege_red", 320),
    ("02_units/neutral_small.png", "neutral_wolf", 256),
    ("02_units/neutral_medium.png", "neutral_shaman", 256),
    ("02_units/neutral_boss.png", "neutral_bear", 384),
    ("02_units/neutral_large.png", "neutral_buffalo", 384),
    ("02_units/hex_frog.png", "hex_frog", 192),
    ("01_env/tower_blue.png", "tower_blue", 384),
    ("01_env/tower_red.png", "tower_red", 384),
    ("01_env/guard_blue.png", "tower_guard_blue", 384),
    ("01_env/guard_red.png", "tower_guard_red", 384),
    ("01_env/core_blue.png", "core_blue", 512),
    ("01_env/core_red.png", "core_red", 512),
]


def save(src, art_id, side):
    im = Image.open(src).convert("RGBA")
    l, t, r, b = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    im = im.crop((l, t, r, b))
    big = max(im.width, im.height)
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((big - im.width) // 2, big - im.height))  # chân chạm đáy
    canvas.resize((side, side), Image.LANCZOS).save(os.path.join(DST, art_id + ".png"))
    print("  ", os.path.relpath(src, INBOX), "->", art_id)


def main():
    for hero in HEROES:
        src = os.path.join(INBOX, "03_heroes", hero + "_body.png")
        if os.path.exists(src):
            save(src, hero, 384)
    for rel, art_id, side in UNITS:
        src = os.path.join(INBOX, rel)
        if os.path.exists(src):
            save(src, art_id, side)


if __name__ == "__main__":
    main()
