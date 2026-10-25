#!/usr/bin/env python3
"""D-167: chuẩn bị GLB tự làm (Tripo, Sol…) trước khi đưa vào game.

- Chỉ giữ ảnh màu (baseColor); bỏ normal map, metallic/roughness, occlusion, emissive.
- Thu ảnh màu về tối đa --max px (mặc định 1024), lưu PNG trong GLB.
- Vật liệu: metallic 0, roughness 1 (đồ họa thấp, ánh sáng vẽ sẵn trong ảnh).
- --team: thêm <ra>_blue.png / <ra>_red.png cạnh file — đổi các điểm ảnh có sắc độ trong
  [--hue-min, --hue-max] (độ, mặc định 160–250: xanh ngọc → xanh dương) sang xanh / đỏ phe.

Dùng: tools/import_glb.py vào.glb ra.glb [--max 1024] [--team]
"""
import argparse, colorsys, io, json, struct, sys
from PIL import Image

BLUE = (0x3D, 0x8B, 0xFF)
RED = (0xFF, 0x4D, 0x4D)


def read_glb(path):
    b = open(path, 'rb').read()
    jlen = struct.unpack('<I', b[12:16])[0]
    gltf = json.loads(b[20:20 + jlen])
    off = 20 + jlen
    blen = struct.unpack('<I', b[off:off + 4])[0]
    return gltf, b[off + 8:off + 8 + blen]


def write_glb(path, gltf, views):
    """views: danh sách bytes theo thứ tự bufferViews mới."""
    blob = b''
    for i, data in enumerate(views):
        gltf['bufferViews'][i]['byteOffset'] = len(blob)
        gltf['bufferViews'][i]['byteLength'] = len(data)
        gltf['bufferViews'][i]['buffer'] = 0
        blob += data + b'\0' * ((4 - len(data) % 4) % 4)
    gltf['buffers'] = [{'byteLength': len(blob)}]
    j = json.dumps(gltf, separators=(',', ':')).encode()
    j += b' ' * ((4 - len(j) % 4) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(blob))
    out += struct.pack('<I', len(j)) + b'JSON' + j + struct.pack('<I', len(blob)) + b'BIN\0' + blob
    open(path, 'wb').write(out)


def team_variant(img, rgb, hmin, hmax):
    px = img.convert('RGB').load()
    out = img.convert('RGB').copy()
    po = out.load()
    w, h = out.size
    th, ts, _ = colorsys.rgb_to_hsv(*[c / 255 for c in rgb])
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s > 0.25 and v > 0.15 and hmin <= hh * 360 <= hmax:
                nr, ng, nb = colorsys.hsv_to_rgb(th, min(1.0, max(s, ts * 0.85)), v)
                po[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('dst')
    ap.add_argument('--max', type=int, default=1024)
    ap.add_argument('--team', action='store_true')
    ap.add_argument('--hue-min', type=float, default=160)
    ap.add_argument('--hue-max', type=float, default=250)
    a = ap.parse_args()
    gltf, bin0 = read_glb(a.src)
    views = [bin0[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']] for v in gltf['bufferViews']]
    keep_tex = set()
    for m in gltf.get('materials', []):
        pbr = m.setdefault('pbrMetallicRoughness', {})
        if 'baseColorTexture' in pbr:
            keep_tex.add(pbr['baseColorTexture']['index'])
        pbr.pop('metallicRoughnessTexture', None)
        pbr['metallicFactor'] = 0.0
        pbr['roughnessFactor'] = 1.0
        for k in ('normalTexture', 'occlusionTexture', 'emissiveTexture'):
            m.pop(k, None)
    base_img = None
    for ti in keep_tex:
        ii = gltf['textures'][ti]['source']
        im = gltf['images'][ii]
        img = Image.open(io.BytesIO(views[im['bufferView']])).convert('RGB')
        if max(img.size) > a.max:
            img = img.resize((a.max, a.max), Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, 'PNG', optimize=True)
        views[im['bufferView']] = buf.getvalue()
        im['mimeType'] = 'image/png'
        base_img = img
    # bỏ ảnh / texture không còn dùng, đánh lại chỉ số
    used_tex = sorted(keep_tex)
    tex_map = {old: new for new, old in enumerate(used_tex)}
    used_img = sorted({gltf['textures'][t]['source'] for t in used_tex})
    img_map = {old: new for new, old in enumerate(used_img)}
    gltf['textures'] = [dict(gltf['textures'][t], source=img_map[gltf['textures'][t]['source']]) for t in used_tex]
    for m in gltf.get('materials', []):
        pbr = m['pbrMetallicRoughness']
        if 'baseColorTexture' in pbr:
            pbr['baseColorTexture']['index'] = tex_map[pbr['baseColorTexture']['index']]
    dropped_views = {gltf['images'][i]['bufferView'] for i in range(len(gltf['images'])) if i not in img_map}
    gltf['images'] = [gltf['images'][i] for i in used_img]
    view_map, new_views = {}, []
    for i, data in enumerate(views):
        if i in dropped_views:
            continue
        view_map[i] = len(new_views)
        new_views.append(data)
    gltf['bufferViews'] = [gltf['bufferViews'][i] for i in sorted(view_map)]
    for acc in gltf.get('accessors', []):
        if 'bufferView' in acc:
            acc['bufferView'] = view_map[acc['bufferView']]
    for im in gltf['images']:
        im['bufferView'] = view_map[im['bufferView']]
    write_glb(a.dst, gltf, new_views)
    if a.team and base_img is not None:
        stem = a.dst[:-4]
        team_variant(base_img, BLUE, a.hue_min, a.hue_max).save(stem + '_blue.png', optimize=True)
        team_variant(base_img, RED, a.hue_min, a.hue_max).save(stem + '_red.png', optimize=True)
    print('xong', a.dst)


if __name__ == '__main__':
    sys.exit(main())
