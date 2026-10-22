#!/usr/bin/env python3
"""Nhập icon đã duyệt từ art_inbox/04_icons vào assets/art/<art_id>.png (ArtLibrary).

  python3 tools/import_icons.py          # cần Pillow

- item_<id>.png  -> <id>.png           (art_id của món = id)
- skill_<id>.png -> <id>.png           (vd skill_brakk_q -> brakk_q)
- ui_<x>.png     -> ui_<x>.png       (nút Đánh / Lính / Trụ)
- state_<x>.png  -> art_id của các hiệu ứng tương ứng (bảng STATE dưới)
Icon kỹ năng / đồ thu về 256 px, icon trạng thái 64 px. Chạy lại an toàn (ghi đè).
"""
import os, sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "art_inbox", "04_icons")
DST = os.path.join(ROOT, "assets", "art")
STATE = {
    "stunned": ["stun"], "rooted": ["root"], "silenced": ["silence"], "disarmed": ["disarm"],
    "slowed": ["frost_orb_slow", "myra_frost_slow", "vexa_purge_slow"], "revealed": ["revealed"],
    "ghost": ["ghost_form", "brakk_undying"], "invulnerable": ["cyclone"], "magic_immune": ["magic_immune"],
    "hexed": ["hex", "vexa_frog"], "shield": ["brakk_iron_shield"], "burning": [], "recall": ["recall"],
}


def save(src, art_id, size):
    im = Image.open(src).convert("RGBA").resize((size, size), Image.LANCZOS)
    im.save(os.path.join(DST, art_id + ".png"))
    print("  ", os.path.basename(src), "->", art_id)


def main():
    if not os.path.isdir(SRC):
        sys.exit("chưa có " + SRC)
    os.makedirs(DST, exist_ok=True)
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".png"):
            continue
        stem = name[:-4]
        path = os.path.join(SRC, name)
        if stem.startswith("item_"):
            save(path, stem[5:], 256)
        elif stem.startswith("skill_"):
            save(path, stem[6:], 256)
        elif stem.startswith("ui_"):
            save(path, stem, 256)  # nút giao diện: ui_attack… giữ nguyên tên
        elif stem.startswith("state_"):
            for art_id in STATE.get(stem[6:], []):
                save(path, art_id, 256 if stem == "state_recall" else 64)


if __name__ == "__main__":
    main()
