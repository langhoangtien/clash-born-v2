#!/usr/bin/env python3
"""Nhập mô hình 3D KayKit (CC0) cho bản thử 3D (D-145/D-146) vào assets/models/kaykit/.

  python3 tools/import_3d.py          # cần Pillow

- Nhân vật (.glb, Rig_Medium / Rig_Large), vũ khí (.gltf + .bin), hoạt ảnh dùng chung theo rig.
- Ảnh màu theo đội: <tên>_blue.png / <tên>_red.png — đổi sắc các mảng màu nhấn (đỏ / xanh dương
  bão hòa) của bảng màu gốc sang xanh hoặc đỏ; da, kim loại, vàng giữ nguyên.
"""
import colorsys, os, shutil
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "art_inbox", "05_3d")
EXTRA = os.path.join(SRC, "adventurers_extra")
DST = os.path.join(ROOT, "assets", "models", "kaykit")
CHARACTERS = ["Knight", "Barbarian", "Barbarian_Large", "Mage", "Druid", "Rogue_Hooded", "Ranger", "Engineer"]
TEXTURES = ["knight", "barbarian", "mage", "druid", "rogue", "ranger", "engineer"]
WEAPONS = ["sword_1handed", "shield_badge_color", "axe_1handed", "axe_2handed_Large", "staff", "druid_staff",
           "dagger", "crossbow_1handed", "spellbook_open", "wand"]
ANIMS = {"Rig_Medium": ["General", "MovementBasic", "CombatMelee", "CombatRanged"],
         "Rig_Large": ["General", "MovementBasic", "CombatMelee"]}
# Sắc (0..1) của màu đội.
TEAM_HUE = {"blue": 0.6, "red": 0.99}


def team_texture(src, dst, hue):
    im = Image.open(src).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            accent = s > 0.5 and v > 0.25 and (h < 0.03 or h > 0.88 or 0.52 < h < 0.72)
            if accent:
                nr, ng, nb = colorsys.hsv_to_rgb(hue, s, v)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    im.save(dst)


def main():
    os.makedirs(DST, exist_ok=True)
    for c in CHARACTERS:
        shutil.copy(os.path.join(EXTRA, "Characters", "gltf", c + ".glb"), DST)
    for t in TEXTURES:
        src = os.path.join(EXTRA, "Characters", "gltf", t + "_texture.png")
        shutil.copy(src, DST)  # vũ khí .gltf trỏ tới ảnh này theo tên
        for team, hue in TEAM_HUE.items():
            team_texture(src, os.path.join(DST, "%s_texture_%s.png" % (t, team)), hue)
    for w in WEAPONS:
        for ext in (".gltf", ".bin"):
            shutil.copy(os.path.join(EXTRA, "Assets", "gltf", w + ext), DST)
    anim_dir = os.path.join(SRC, "animations", "Animations", "gltf")
    for rig, sets in ANIMS.items():
        for s in sets:
            shutil.copy(os.path.join(anim_dir, rig, "%s_%s.glb" % (rig, s)), DST)
    shutil.copy(os.path.join(EXTRA, "License.txt"), os.path.join(DST, "License_KayKit.txt"))
    print("xong:", len(os.listdir(DST)), "file")


if __name__ == "__main__":
    main()
