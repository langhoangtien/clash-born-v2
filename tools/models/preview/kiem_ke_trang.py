#!/usr/bin/env python3
"""D-360: dựng trang "Clashborn — Kiểm kê hình" từ ảnh chụp (kiem_ke.gd, kiem_ke_tran.gd), số đo stats.json và
nhận xét art_inbox/kiem_ke/nhan_xet.json. Ghi art_inbox/kiem_ke/trang/ (index.html + ảnh webp cỡ web).

  python3 tools/models/preview/kiem_ke_trang.py
"""
import glob, html, json, os
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "..")
KK = os.path.join(ROOT, "art_inbox", "kiem_ke")
OUT = os.path.join(KK, "trang")
ART = os.path.join(ROOT, "assets", "art")
TEX = os.path.join(ROOT, "assets", "textures", "style")
HEROES = ["brakk", "gorran", "noctis", "duy_anh", "myra", "vexa", "phong_tien", "huyet_cu_nhan", "thach_giap", "tho_san"]
TILE = (58, 62, 60)
ST = {"dat": "Đạt", "lech": "Lệch", "muon": "Mượn tạm", "chua": "Chưa có"}
SCENERY = [("Đá và tường", ["rock_", "boulder_", "parapet"]), ("Cây", ["pine_", "tree_"]),
           ("Cỏ, bụi, hoa", ["bush_", "plant_", "grass_tuft", "reeds", "flowers", "lily", "mushrooms"]),
           ("Vật trang trí", ["log", "stump", "campfire", "crystals", "bones", "totem"])]


def web_model(src, dst):
    im = Image.open(src).convert("RGB").crop((40, 150, 600, 800)).resize((392, 455), Image.LANCZOS)
    im.save(dst, quality=80)


def strip(names, cell, cols, dst):
    """Xếp các icon thành lưới trên nền tối; tên None = ô trống."""
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * cell), TILE)
    for i, n in enumerate(names):
        p = os.path.join(ART, n + ".png") if n else ""
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA").resize((cell - 8, cell - 8), Image.LANCZOS)
        sheet.paste(im, ((i % cols) * cell + 4, (i // cols) * cell + 4), im)
    sheet.save(dst, quality=84)


def make_images():
    os.makedirs(OUT, exist_ok=True)
    for f in glob.glob(os.path.join(KK, "models", "*.png")):
        web_model(f, os.path.join(OUT, os.path.basename(f)[:-4] + ".webp"))
    for f in glob.glob(os.path.join(KK, "models_goc2", "*.png")):
        web_model(f, os.path.join(OUT, os.path.basename(f)[:-4] + "_b.webp"))
    for f in glob.glob(os.path.join(KK, "tran", "*.jpg")):
        Image.open(f).convert("RGB").resize((1600, 900), Image.LANCZOS).save(os.path.join(OUT, os.path.basename(f)[:-4] + ".webp"), quality=78)
    for h in HEROES:
        strip([h + s for s in ["_portrait", "", "_innate", "_q", "_w", "_r"]], 132, 6, os.path.join(OUT, "icon_%s.webp" % h))
    used = {h + s for h in HEROES for s in ["_portrait", "", "_innate", "_q", "_w", "_r"]}
    rest = sorted(os.path.basename(f)[:-4] for f in glob.glob(os.path.join(ART, "*.png")))
    rest = [n for n in rest if n not in used]
    size = {n: Image.open(os.path.join(ART, n + ".png")).size[0] for n in rest}
    sprites = [n for n in rest if n.split("_")[0] in ("creep", "neutral", "tower", "core")]
    ui = [n for n in rest if n.startswith("ui_") or n == "recall"]
    status = [n for n in rest if size[n] == 64]
    items = [n for n in rest if n not in sprites + ui + status]
    strip(items, 96, 10, os.path.join(OUT, "sheet_items.webp"))
    strip(status, 96, 8, os.path.join(OUT, "sheet_status.webp"))
    strip(sprites, 132, 6, os.path.join(OUT, "sheet_sprites.webp"))
    strip(ui, 132, 4, os.path.join(OUT, "sheet_ui.webp"))
    tex = sorted(glob.glob(os.path.join(TEX, "*.png")))
    sheet = Image.new("RGB", (5 * 260, 2 * 260), TILE)
    for i, f in enumerate(tex):
        sheet.paste(Image.open(f).convert("RGB").resize((256, 256), Image.LANCZOS), ((i % 5) * 260 + 2, (i // 5) * 260 + 2))
    sheet.save(os.path.join(OUT, "sheet_ground.webp"), quality=82)
    make_trials()
    return {"items": len(items), "status": len(status), "sprites": len(sprites), "ui": len(ui), "ground": len(tex)}


def make_trials():
    """D-361: ảnh bản thử chuẩn cảnh vật (thu_canh_vat/) và khung icon (thu_icon/)."""
    cv = os.path.join(KK, "thu_canh_vat")
    for v in ["goc", "A", "B"]:
        Image.open(os.path.join(cv, "hang_tuong_%s.jpg" % v)).convert("RGB").crop((0, 150, 1920, 1010)).resize((1280, 573), Image.LANCZOS).save(os.path.join(OUT, "thu_hang_%s.webp" % v), quality=78)
        Image.open(os.path.join(cv, "tran_020s_%s.jpg" % v)).convert("RGB").crop((0, 250, 1920, 820)).resize((1280, 380), Image.LANCZOS).save(os.path.join(OUT, "thu_base_%s.webp" % v), quality=78)
        row = Image.new("RGB", (4 * 280, 325))
        for i, m in enumerate(["pine_l", "bush_a", "rock_low", "plant_orange"]):
            row.paste(Image.open(os.path.join(cv, "phong", "%s_%s.png" % (m, v))).convert("RGB").crop((40, 150, 600, 800)).resize((280, 325), Image.LANCZOS), (i * 280, 0))
        row.save(os.path.join(OUT, "thu_phong_%s.webp" % v), quality=80)
    cb = os.path.join(ROOT, "art_inbox", "concepts", "chuan_brakk")  # D-364: concept chờ duyệt
    im = Image.open(os.path.join(cb, "phong_tien", "bang_so_sanh.png")).convert("RGB")
    im.resize((1600, round(im.height * 1600 / im.width)), Image.LANCZOS).save(os.path.join(OUT, "cc_pt_bang.webp"), quality=84)
    for k in (1, 2, 3):
        Image.open(os.path.join(cb, "phong_tien", "pa%d.png" % k)).convert("RGB").resize((683, 1024), Image.LANCZOS).save(os.path.join(OUT, "cc_pt_pa%d.webp" % k), quality=84)
        Image.open(os.path.join(cb, "canh_vat", "huong%d.png" % k)).convert("RGB").resize((1200, 800), Image.LANCZOS).save(os.path.join(OUT, "cc_cv_%d.webp" % k), quality=82)
    for f in glob.glob(os.path.join(KK, "thu_icon", "*.png")):
        Image.open(f).convert("RGB").save(os.path.join(OUT, "thu_" + os.path.basename(f)[:-4] + ".webp"), quality=86)


def e(s):
    return html.escape(str(s))


def pill(st):
    return '<span class="pill %s">%s</span>' % (st, ST[st])


def stat_line(s):
    parts = ["%s tam giác" % f"{s['tris']:,}".replace(",", ".")]
    if s["bones"]:
        parts.append("%d xương" % s["bones"])
    if s["anims"]:
        parts.append("%d hoạt ảnh" % s["anims"])
    parts.append("ảnh màu " + ", ".join(t for t in s["tex"] if not t.endswith("×1")) if s["tex"] else "màu đỉnh, không ảnh")
    if s.get("placed"):
        parts.append("đặt %d chỗ" % s["placed"])
    parts.append("cao %s m" % str(s["height"]).replace(".", ","))
    return " · ".join(parts)


def card(s, nx, hero=False):
    st, note = nx["models"].get(s["id"], ["lech", ""])
    name = nx["names"].get(s["id"], s["id"])
    imgs = '<img loading="lazy" src="%s__%s.webp" alt="%s">' % (s["group"], s["id"], e(name))
    if hero:
        imgs += '<img loading="lazy" src="hero__%s_b.webp" alt="%s, góc thứ hai">' % (s["id"], e(name))
    out = ['<article class="card%s" data-st="%s">' % (" hero" if hero else "", st), '<div class="shots">%s</div>' % imgs,
           '<div class="body"><h3>%s %s</h3>' % (e(name), pill(st)),
           '<p class="meta">%s</p>' % e(stat_line(s)),
           '<p class="meta">Nguồn: %s · <code>%s</code></p>' % (e(nx["src"][s["group"]]), e(s["id"])), '<p>%s</p>' % e(note)]
    if hero:
        ist, inote = nx["icons"][s["id"]]
        out += ['<div class="icons" data-st="%s"><img loading="lazy" src="icon_%s.webp" alt="Chân dung và icon chiêu của %s">' % (ist, s["id"], e(name)),
                '<div class="cap"><span>Chân dung</span><span>Thân 2D</span><span>Nội tại</span><span>Q</span><span>W</span><span>R</span></div>',
                '<p><strong>Chân dung, icon</strong> %s %s</p></div>' % (pill(ist), e(inote))]
    out.append("</div></article>")
    return "\n".join(out)


def sheet(key, nx, count):
    st, title, note = nx["sheets"][key]
    return ('<article class="card wide" data-st="%s"><div class="sheet"><img loading="lazy" src="sheet_%s.webp" alt="%s"></div>'
            '<div class="body"><h3>%s <span class="n">%d</span> %s</h3><p>%s</p></div></article>') % (st, key, e(title), e(title), count, pill(st), e(note))


def build():
    counts = make_images()
    nx = json.load(open(os.path.join(KK, "nhan_xet.json"), encoding="utf-8"))
    stats = {s["id"]: s for s in json.load(open(os.path.join(KK, "models", "stats.json"), encoding="utf-8"))}
    by = lambda g: [s for s in stats.values() if s["group"] == g]
    sec = {"tuong": "\n".join(card(stats[h], nx, True) for h in HEROES),
           "linh": "\n".join(card(s, nx) for s in by("creep")),
           "quai": "\n".join(card(s, nx) for s in by("creature") + by("boss")),
           "congtrinh": "\n".join(card(s, nx) for s in by("structure") + by("fx"))}
    scen = []
    for title, keys in SCENERY:
        rows = [s for s in by("scenery") if any(s["id"].startswith(k) for k in keys)]
        scen.append('<h3 class="sub">%s</h3><div class="grid small">%s</div>' % (title, "\n".join(card(s, nx) for s in rows)))
    sec["canhvat"] = "\n".join(scen)
    for k in counts:
        sec["sheet_" + k] = sheet(k, nx, counts[k])
    tally = {k: 0 for k in ST}
    for s in stats.values():
        tally[nx["models"].get(s["id"], ["lech"])[0]] += 1
    for h in HEROES:
        tally[nx["icons"][h][0]] += 1
    for k in nx["sheets"]:
        tally[nx["sheets"][k][0]] += 1
    page = open(os.path.join(KK, "trang_mau.html"), encoding="utf-8").read()
    for k, v in sec.items():
        page = page.replace("{{%s}}" % k, v)
    for k, v in tally.items():
        page = page.replace("{{n_%s}}" % k, str(v))
    open(os.path.join(OUT, "index.html"), "w", encoding="utf-8").write(page)
    print("trang:", len(os.listdir(OUT)), "file,", sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT)) // 1024, "KB", tally)


if __name__ == "__main__":
    build()
