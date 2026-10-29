#!/usr/bin/env python3
"""D-174: Tính lại trọng số da (JOINTS_0 / WEIGHTS_0) của GLB có xương theo khoảng cách tới đoạn xương ở tư thế gốc.
Dùng khi mô hình có xương + hoạt ảnh nhưng da dính cả vào xương gốc (đi / đánh như một tấm ảnh).
  python3 -I tools/models/reweight_skin.py vào.glb ra.glb [--skip-root]
"""
import json, struct, sys, numpy as np
src, dst = sys.argv[1], sys.argv[2]
d = open(src, 'rb').read(); n = struct.unpack('<I', d[12:16])[0]; j = json.loads(d[20:20 + n]); off = 20 + n
bl = struct.unpack('<I', d[off:off + 4])[0]; b = bytearray(d[off + 8:off + 8 + bl])
def view(i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]; o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    c = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    dt = {5126: np.float32, 5121: np.uint8, 5123: np.uint16}[a['componentType']]
    return np.frombuffer(b, dt, a['count'] * c, o).reshape(a['count'], c), o, dt
def trs(nd):
    m = np.eye(4)
    if 'matrix' in nd: return np.array(nd['matrix']).reshape(4, 4).T
    t = nd.get('translation', [0, 0, 0]); r = nd.get('rotation', [0, 0, 0, 1]); s = nd.get('scale', [1, 1, 1])
    x, y, z, w = r
    R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    m[:3, :3] = R * np.array(s); m[:3, 3] = t; return m
parent = {}
for i, nd in enumerate(j['nodes']):
    for c in nd.get('children', []): parent[c] = i
def world(i):
    m = trs(j['nodes'][i])
    while i in parent: i = parent[i]; m = trs(j['nodes'][i]) @ m
    return m
skin = j['skins'][0]; joints = skin['joints']
ibm, _, _ = view(skin['inverseBindMatrices'])
# vị trí khớp ở tư thế bind = nghịch đảo inverseBind
pos = np.array([np.linalg.inv(ibm[k].reshape(4, 4).T)[:3, 3] for k in range(len(joints))])
idx = {nd: k for k, nd in enumerate(joints)}
seg = []
for k, nd in enumerate(joints):
    kids = [idx[c] for c in j['nodes'][nd].get('children', []) if c in idx]
    if kids:
        for c in kids: seg.append((k, pos[k], pos[c]))
    elif parent.get(nd) in idx:
        p = pos[idx[parent[nd]]]; seg.append((k, pos[k], pos[k] + (pos[k] - p) * 0.5))
    else:
        seg.append((k, pos[k], pos[k]))
pr = j['meshes'][0]['primitives'][0]
V, _, _ = view(pr['attributes']['POSITION'])
mesh_node = [i for i, nd in enumerate(j['nodes']) if 'mesh' in nd][0]
M = world(mesh_node); Vw = (np.c_[V, np.ones(len(V))] @ M.T)[:, :3]
D = np.full((len(V), len(joints)), np.inf)
for k, a, c in seg:
    ab = c - a; L = (ab * ab).sum()
    t = np.clip(((Vw - a) @ ab) / L, 0, 1) if L > 1e-12 else np.zeros(len(V))
    q = a + t[:, None] * ab
    D[:, k] = np.minimum(D[:, k], np.linalg.norm(Vw - q, axis=1))
if '--skip-root' in sys.argv:
    D[:, 0] = np.inf
order = np.argsort(D, axis=1)[:, :4]
dd = np.take_along_axis(D, order, 1)
w = 1.0 / np.maximum(dd, 1e-4) ** 4
w[:, 2:] *= (dd[:, 2:] < dd[:, :1] * 1.6)  # chỉ pha xương ở gần ngang nhau
w /= w.sum(1, keepdims=True)
J, oj, dj = view(pr['attributes']['JOINTS_0']); W, ow, dw = view(pr['attributes']['WEIGHTS_0'])
Jn = order.astype(dj); b[oj:oj + Jn.nbytes] = Jn.tobytes()
if dw == np.float32: Wn = w.astype(np.float32)
else: Wn = np.round(w * np.iinfo(dw).max).astype(dw)
b[ow:ow + Wn.nbytes] = Wn.tobytes()
dom = order[:, 0]; u, cnt = np.unique(dom, return_counts=True)
print('xương chính:', dict(zip(u.tolist(), cnt.tolist())))
out = bytearray(d[:off + 8]) + b + d[off + 8 + bl:]
open(dst, 'wb').write(bytes(out))
