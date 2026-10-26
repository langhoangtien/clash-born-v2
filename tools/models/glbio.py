import json, struct
import numpy as np
def load(path):
    d = open(path, 'rb').read()
    n = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20+n])
    off = 20 + n
    bl = struct.unpack('<I', d[off:off+4])[0]
    b = d[off+8:off+8+bl]
    def acc(i, dt, comps):
        a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
        o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        return np.frombuffer(b, dt, a['count']*comps, o).reshape(a['count'], comps) if comps > 1 else np.frombuffer(b, dt, a['count'], o)
    p = j['meshes'][0]['primitives'][0]
    pos = acc(p['attributes']['POSITION'], np.float32, 3).copy()
    nor = acc(p['attributes']['NORMAL'], np.float32, 3).copy()
    idx = acc(p['indices'], np.uint32, 1).copy()
    return pos, nor, idx
def save(path, pos, nor, idx, col, name):
    pos = pos.astype(np.float32); nor = nor.astype(np.float32); idx = idx.astype(np.uint32)
    col = (np.clip(col, 0, 1) * 65535).astype(np.uint16)
    col4 = np.concatenate([col, np.full((len(col), 1), 65535, np.uint16)], 1)
    blobs = [pos.tobytes(), nor.tobytes(), col4.tobytes(), idx.tobytes()]
    views, off = [], 0
    bin_ = b''
    for k, bb in enumerate(blobs):
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(bb), "target": 34963 if k == 3 else 34962})
        bin_ += bb; pad = (-len(bin_)) % 4; bin_ += b'\0' * pad; off = len(bin_)
    j = {"asset": {"version": "2.0", "generator": "clashborn paint_vc"},
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(pos), "type": "VEC3", "max": pos.max(0).tolist(), "min": pos.min(0).tolist()},
            {"bufferView": 1, "componentType": 5126, "count": len(pos), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5123, "normalized": True, "count": len(pos), "type": "VEC4"},
            {"bufferView": 3, "componentType": 5125, "count": len(idx), "type": "SCALAR"}],
        "buffers": [{"byteLength": len(bin_)}], "bufferViews": views,
        "materials": [{"name": name + "_vc", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 1}}],
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "COLOR_0": 2}, "indices": 3, "material": 0}]}],
        "nodes": [{"name": name, "mesh": 0}], "scenes": [{"nodes": [0]}], "scene": 0}
    js = json.dumps(j).encode(); js += b' ' * ((-len(js)) % 4)
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_))
    out += struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bin_), 0x004E4942) + bin_
    open(path, 'wb').write(out)
def components(n, idx):
    par = np.arange(n)
    def f(x):
        while par[x] != x:
            par[x] = par[par[x]]; x = par[x]
        return x
    t = idx.reshape(-1, 3)
    for a, b, c in t:
        ra, rb, rc = f(a), f(b), f(c)
        par[rb] = ra; par[f(rc)] = ra
    return np.array([f(i) for i in range(n)])
