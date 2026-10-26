#!/usr/bin/env python3
"""Tối ưu GLB cho game (D-167): giữ đúng ảnh màu (baseColor), bỏ normal / metallicRoughness / AO /
emissive, thu ảnh màu về --size (mặc định 1024, JPEG chất lượng 90 — ảnh vẽ tay nhiều chi tiết, PNG quá nặng; ảnh có nền trong suốt giữ PNG), ghi GLB mới. Với --team: tách thêm ảnh
<tên>_blue.jpg / <tên>_red.jpg — điểm ảnh có sắc độ trong --hue (độ, vd 150-210 = xanh ngọc) và đủ
đậm được đổi sang xanh phe / đỏ phe; GLB nhúng bản xanh.

  python3 tools/models/glb_slim.py vào.glb ra.glb [--size 1024] [--team --hue 150-210] [--saturation 0.5]
In số tam giác, cỡ (m), dung lượng trước / sau.
"""
import argparse, colorsys, io, json, struct, sys
from PIL import Image

BLUE_HUE, RED_HUE = 217.0, 0.0  # Blue #3D8BFF, Red #FF4D4D


def read_glb(path):
    b = open(path, 'rb').read()
    jlen = struct.unpack('<I', b[12:16])[0]
    g = json.loads(b[20:20 + jlen])
    off = 20 + jlen
    binc = b''
    if off < len(b):
        blen = struct.unpack('<I', b[off:off + 4])[0]
        binc = b[off + 8:off + 8 + blen]
    return g, binc, len(b)


def view_bytes(g, binc, idx):
    bv = g['bufferViews'][idx]
    o = bv.get('byteOffset', 0)
    return binc[o:o + bv['byteLength']]


def write_glb(path, g, chunks):
    """chunks: danh sách bytes theo thứ tự bufferView mới."""
    data = b''
    views = []
    for c in chunks:
        while len(data) % 4:
            data += b'\0'
        views.append({'buffer': 0, 'byteOffset': len(data), 'byteLength': len(c)})
        data += c
    while len(data) % 4:
        data += b'\0'
    return views, data


def recolor(img, lo, hi, target_hue):
    img = img.convert('RGB')
    px = img.load()
    out = img.copy()
    po = out.load()
    for y in range(img.height):
        for x in range(img.width):
            r, gg, bb = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, gg / 255, bb / 255)
            if s > 0.25 and v > 0.12 and lo <= h * 360 <= hi:  # chỉ phần màu phe
                nr, ng, nb = colorsys.hsv_to_rgb(target_hue / 360, min(1.0, s * 1.05), v)
                po[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src'); ap.add_argument('dst')
    ap.add_argument('--size', type=int, default=1024)
    ap.add_argument('--team', action='store_true')
    ap.add_argument('--hue', default='150-210')
    ap.add_argument('--saturation', type=float, default=1.0, help='nhân độ đậm màu ảnh (D-168: đá viền 0.5)')
    a = ap.parse_args()
    g, binc, before = read_glb(a.src)
    keep_images = set()
    for m in g.get('materials', []):
        pbr = m.setdefault('pbrMetallicRoughness', {})
        pbr.pop('metallicRoughnessTexture', None)
        pbr['metallicFactor'] = 0.0
        pbr['roughnessFactor'] = 1.0
        for k in ('normalTexture', 'occlusionTexture', 'emissiveTexture'):
            m.pop(k, None)
        m.pop('emissiveFactor', None)
        if 'baseColorTexture' in pbr:
            keep_images.add(g['textures'][pbr['baseColorTexture']['index']]['source'])
    # ảnh màu: thu nhỏ, PNG
    img_bytes = {}
    base_img = None
    for i in keep_images:
        src = Image.open(io.BytesIO(view_bytes(g, binc, g['images'][i]['bufferView'])))
        alpha = src.mode in ('RGBA', 'LA') and src.getchannel('A').getextrema()[0] < 250
        im = src.convert('RGBA' if alpha else 'RGB')
        if max(im.size) > a.size:
            im = im.resize((a.size, a.size), Image.LANCZOS)
        if a.saturation != 1.0:
            from PIL import ImageEnhance
            im = ImageEnhance.Color(im).enhance(a.saturation)
        base_img = im
        if a.team:
            lo, hi = (float(x) for x in a.hue.split('-'))
            blue = recolor(im, lo, hi, BLUE_HUE)
            red = recolor(im, lo, hi, RED_HUE)
            stem = a.dst[:-4]
            blue.save(stem + '_blue.jpg', quality=90); red.save(stem + '_red.jpg', quality=90)
            im = blue
        buf = io.BytesIO()
        im.save(buf, 'PNG', optimize=True) if alpha else im.save(buf, 'JPEG', quality=90)
        img_bytes[i] = (buf.getvalue(), 'image/png' if alpha else 'image/jpeg')
    # dựng lại bufferViews: giữ view của accessor, thay view ảnh giữ lại, bỏ ảnh khác
    old_views = g['bufferViews']
    used = sorted({acc['bufferView'] for acc in g['accessors'] if 'bufferView' in acc})
    chunks, remap = [], {}
    for v in used:
        remap[v] = len(chunks); chunks.append(view_bytes(g, binc, v))
    new_images, img_remap = [], {}
    for i in sorted(keep_images):
        img_remap[i] = len(new_images)
        new_images.append({'mimeType': img_bytes[i][1], 'bufferView': len(chunks), 'name': g['images'][i].get('name', 'albedo')})
        chunks.append(img_bytes[i][0])
    views, data = write_glb(None, g, chunks)
    for k, v in enumerate(views):
        if k < len(used):
            ov = old_views[used[k]]
            for key in ('byteStride', 'target'):
                if key in ov:
                    v[key] = ov[key]
    for acc in g['accessors']:
        if 'bufferView' in acc:
            acc['bufferView'] = remap[acc['bufferView']]
    g['bufferViews'] = views
    g['images'] = new_images
    new_tex, tex_remap = [], {}
    for t, tex in enumerate(g.get('textures', [])):
        if tex.get('source') in img_remap:
            tex_remap[t] = len(new_tex); tex = dict(tex); tex['source'] = img_remap[tex['source']]; new_tex.append(tex)
    g['textures'] = new_tex
    for m in g.get('materials', []):
        bt = m['pbrMetallicRoughness'].get('baseColorTexture')
        if bt is not None:
            bt['index'] = tex_remap[bt['index']]
    if not new_tex:
        g.pop('textures', None); g.pop('images', None); g.pop('samplers', None)
    g['buffers'] = [{'byteLength': len(data)}]
    j = json.dumps(g, separators=(',', ':')).encode()
    while len(j) % 4:
        j += b' '
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(data))
    out += struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(data), 0x004E4942) + data
    open(a.dst, 'wb').write(out)
    tris = 0; mn = [1e9] * 3; mx = [-1e9] * 3
    for m in g['meshes']:
        for p in m['primitives']:
            acc = g['accessors'][p['indices']] if 'indices' in p else g['accessors'][p['attributes']['POSITION']]
            tris += acc['count'] // 3
            pa = g['accessors'][p['attributes']['POSITION']]
            mn = [min(x, y) for x, y in zip(mn, pa['min'])]; mx = [max(x, y) for x, y in zip(mx, pa['max'])]
    print('%s: %d tam giác, cỡ %s m, %.1f MB → %.2f MB' % (a.dst, tris, [round(y - x, 2) for x, y in zip(mn, mx)], before / 1e6, len(out) / 1e6))


if __name__ == '__main__':
    main()
