#!/usr/bin/env python3
"""Nhập icon đã duyệt từ art_inbox/04_icons vào assets/art/<art_id>.png (ArtLibrary).

  python3 tools/import_icons.py          # cần Pillow

- item_<id>.png  -> <id>.png           (art_id của món = id)
- skill_<id>.png -> <id>.png           (vd skill_brakk_q -> brakk_q)
- ui_<x>.png     -> ui_<x>.png       (ui_attack*: chỉ lấy hình trắng, căn giữa — D-131)
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


def save(src, art_id, size, trim=False):
    im = Image.open(src).convert("RGBA")
    if trim:  # bỏ phần trong suốt quanh hình để icon lấp đầy nút
        l, t, r, b = im.getbbox()
        side = max(r - l, b - t)
        cx, cy = (l + r) // 2, (t + b) // 2
        im = im.crop((cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side))
    im = im.resize((size, size), Image.LANCZOS)
    im.save(os.path.join(DST, art_id + ".png"))
    print("  ", os.path.basename(src), "->", art_id)


def _smooth(im):
    """Ảnh gốc bị răng cưa (nét bậc thang ~5 px): phóng 4×, làm mờ rồi nắn lại cạnh sắc → mép thẳng, mịn."""
    from PIL import ImageFilter
    a = im.getchannel("A").resize((im.width * 4, im.height * 4), Image.BICUBIC)
    a = a.filter(ImageFilter.GaussianBlur(7))
    a = a.point(lambda v: max(0, min(255, int((v - 128) * 6 + 128))))
    a = a.resize(im.size, Image.LANCZOS)
    out = Image.new("RGBA", im.size, (255, 255, 255, 0))
    out.putalpha(a)
    return out


def save_glyph(src, art_id, size):
    """Nút Đánh / Lính / Trụ (D-131): chỉ giữ hình trắng ở giữa, bỏ đĩa + vòng viền trong ảnh
    (game tự vẽ bằng code cho mịn), cắt sát rồi đặt ĐÚNG TÂM ô vuông trong suốt."""
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    cx, cy, rad = w / 2, h / 2, min(w, h) * 0.36  # trong vòng viền
    px = im.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    po = out.load()
    for y in range(h):
        for x in range(w):
            if (x - cx) ** 2 + (y - cy) ** 2 > rad * rad:
                continue
            r, g, b, a = px[x, y]
            v = min(r, g, b)  # trắng cao, nền xanh than thấp
            k = max(0.0, min(1.0, (v - 70) / 150))
            if k > 0:
                po[x, y] = (255, 255, 255, int(255 * k * a / 255))
    out = _smooth(out)
    l, t, r2, b2 = out.getbbox()
    side = int(max(r2 - l, b2 - t) * 1.0)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(out.crop((l, t, r2, b2)), ((side - (r2 - l)) // 2, (side - (b2 - t)) // 2))
    canvas.resize((size, size), Image.LANCZOS).save(os.path.join(DST, art_id + ".png"))
    print("  ", os.path.basename(src), "->", art_id, "(hình trắng, căn giữa)")


def main():
    if not os.path.isdir(SRC):
        sys.exit("chưa có " + SRC)
    os.makedirs(DST, exist_ok=True)
    heroes = os.path.join(ROOT, "art_inbox", "03_heroes")  # chân dung cho màn chọn tướng (D-123)
    for name in sorted(os.listdir(heroes)) if os.path.isdir(heroes) else []:
        if name.endswith("_portrait.png"):
            save(os.path.join(heroes, name), name[:-4], 256)
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".png"):
            continue
        stem = name[:-4]
        path = os.path.join(SRC, name)
        if stem.startswith("item_"):
            save(path, stem[5:], 256)
        elif stem.startswith("skill_"):
            save(path, stem[6:], 256)
        elif stem.startswith("ui_attack"):
            save_glyph(path, stem, 256)
        elif stem.startswith("ui_"):
            save(path, stem, 256, trim=True)  # nút giao diện: ui_attack… giữ nguyên tên
        elif stem.startswith("state_"):
            for art_id in STATE.get(stem[6:], []):
                save(path, art_id, 256 if stem == "state_recall" else 64)


if __name__ == "__main__":
    main()
