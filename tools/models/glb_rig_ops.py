"""Thao tác xương / hoạt ảnh trên glTF đã đọc (g = JSON, binc = bytearray BIN) cho glb_anims.py (D-209).

- concat: nối nhiều hoạt ảnh thành một (vd đòn đánh tách đôi vung + thu tay của afk.ai: `A+B=attack`).
- drop_bones: bỏ xương theo tên (ngón tay, xương đầu mút) — trọng số dồn về xương cha gần nhất còn giữ.
Dữ liệu mới nối vào cuối binc; glb_anims.prune dọn phần không dùng.
"""
import re
import numpy as np

FRAME = 1.0 / 30.0  # khoảng cách giữa hai hoạt ảnh nối nhau (một khung)


def add_accessor(g, binc, arr, kind, with_bounds=False):
    arr = np.ascontiguousarray(arr, np.float32)
    binc += b"\0" * (-len(binc) % 4)
    g["bufferViews"].append({"buffer": 0, "byteOffset": len(binc), "byteLength": arr.nbytes})
    binc += arr.tobytes()
    acc = {"bufferView": len(g["bufferViews"]) - 1, "componentType": 5126, "count": len(arr), "type": kind}
    if with_bounds:
        acc["min"], acc["max"] = [float(arr.min())], [float(arr.max())]
    g["accessors"].append(acc)
    return len(g["accessors"]) - 1


def _rest(node, path):
    return {"translation": [0, 0, 0], "rotation": [0, 0, 0, 1], "scale": [1, 1, 1]}[path] if path not in node \
        else node[path]


def _span(name, full):
    if "@" not in name:
        return 0.0, full
    rng = name.split("@")[1]
    return (float(rng.split("-")[0]), float(rng.split("-")[1])) if "-" in rng else (0.0, float(rng))


def concat(g, binc, array, names, new_name, gap=FRAME):
    """gap: giây giữa hai đoạn — khớp được nội suy thành chuyển động (vd vung kiếm xuống giữa giơ và thu tay).
    `tên@cuối` / `tên@đầu-cuối` (giây): chỉ lấy đoạn đó (bỏ khung cuối afk.ai hay giật về tư thế đứng, bỏ phần lấy đà
    dài để đòn khớp nhịp đánh — D-214)."""
    anims = [next(a for a in g["animations"] if a.get("name") == n.split("@")[0]) for n in names]
    span = [_span(n, max(g["accessors"][s["input"]]["max"][0] for s in a["samplers"])) for n, a in zip(names, anims)]
    length = [b - a for a, b in span]
    keys = []
    for a in anims:
        for c in a["channels"]:
            k = (c["target"]["node"], c["target"]["path"])
            if k not in keys:
                keys.append(k)
    out = {"name": new_name, "channels": [], "samplers": []}
    for node, path in keys:
        times, values, off = [], [], 0.0
        for a, ln, (start, _end) in zip(anims, length, span):
            ch = next((c for c in a["channels"] if (c["target"]["node"], c["target"]["path"]) == (node, path)), None)
            if ch is None:  # phần này không động tới xương: giữ tư thế gốc
                rest = np.array([_rest(g["nodes"][node], path)] * 2, np.float32)
                times.append(np.array([0.0, ln]) + off)
                values.append(rest)
            else:
                s = a["samplers"][ch["sampler"]]
                assert s.get("interpolation", "LINEAR") != "CUBICSPLINE", "chưa hỗ trợ CUBICSPLINE"
                t = array(g, binc, s["input"])[:, 0].copy()
                v = array(g, binc, s["output"]).copy()
                inside = (t >= start - 1e-4) & (t <= start + ln + 1e-4)
                before = max(0, int(np.searchsorted(t, start, "right")) - 1)
                if not inside.any() or t[inside][0] > start + 1e-4:  # giữ khóa gần nhất trước điểm cắt
                    times.append(np.array([0.0]) + off)
                    values.append(v[before:before + 1])
                times.append(t[inside] - start + off)
                values.append(v[inside])
            off += ln + gap
        t = np.concatenate(times)[:, None]
        v = np.concatenate(values)
        kind = "VEC4" if v.shape[1] == 4 else "VEC3"
        out["samplers"].append({"input": add_accessor(g, binc, t, "SCALAR", True),
                                "output": add_accessor(g, binc, v, kind), "interpolation": "LINEAR"})
        out["channels"].append({"sampler": len(out["samplers"]) - 1, "target": {"node": node, "path": path}})
    return out


def drop_bones(g, binc, array, pattern):
    rx = re.compile(pattern)
    parent = {c: i for i, n in enumerate(g["nodes"]) for c in n.get("children", [])}
    dropped = {i for i, n in enumerate(g["nodes"]) if rx.search(n.get("name", ""))}
    changed = True
    while changed:  # con của xương bị bỏ cũng bỏ
        extra = {c for c, p in parent.items() if p in dropped and c not in dropped}
        dropped |= extra
        changed = bool(extra)
    skin = g["skins"][0]
    joints = skin["joints"]
    kept = [j for j in joints if j not in dropped]

    def target(j):
        while j in dropped:
            j = parent[j]
        return kept.index(j)
    remap = np.array([target(j) for j in joints])
    _reweight(g, binc, array, remap, len(kept))
    ibm = array(g, binc, skin["inverseBindMatrices"]).copy()  # bản sao: binc sắp nối thêm
    skin["inverseBindMatrices"] = add_accessor(g, binc, ibm[[joints.index(j) for j in kept]], "MAT4")
    _remove_nodes(g, dropped, kept)
    return len(joints), len(kept)


def _reweight(g, binc, array, remap, count):
    for m in g["meshes"]:
        for p in m["primitives"]:
            if "JOINTS_0" not in p["attributes"]:
                continue
            jo = array(g, binc, p["attributes"]["JOINTS_0"])
            we = array(g, binc, p["attributes"]["WEIGHTS_0"])
            assert we.dtype == np.float32, "WEIGHTS_0 phải là float"
            for v in range(len(jo)):
                acc = np.zeros(count)
                np.add.at(acc, remap[jo[v]], we[v])
                top = np.argsort(-acc)[:4]
                jo[v] = top
                we[v] = acc[top] / max(acc[top].sum(), 1e-9)


def _remove_nodes(g, dropped, kept):
    order = [i for i in range(len(g["nodes"])) if i not in dropped]
    idx = {old: new for new, old in enumerate(order)}
    nodes = []
    for old in order:
        n = dict(g["nodes"][old])
        if "children" in n:
            n["children"] = [idx[c] for c in n["children"] if c in idx]
            if not n["children"]:
                del n["children"]
        nodes.append(n)
    g["nodes"] = nodes
    for s in g["skins"]:
        s["joints"] = [idx[j] for j in kept] if s is g["skins"][0] else [idx[j] for j in s["joints"] if j in idx]
        if s.get("skeleton") in idx:
            s["skeleton"] = idx[s["skeleton"]]
    for sc in g["scenes"]:
        sc["nodes"] = [idx[n] for n in sc["nodes"] if n in idx]
    for a in g.get("animations", []):
        chans = [c for c in a["channels"] if c["target"].get("node") in idx]
        a["samplers"] = [a["samplers"][c["sampler"]] for c in chans]  # bỏ sampler của xương đã bỏ
        a["channels"] = [dict(c, sampler=k, target=dict(c["target"], node=idx[c["target"]["node"]]))
                         for k, c in enumerate(chans)]


def in_place(g, binc, array, anim, root_names=("root",)):
    """`tên~` (D-229): bỏ dời chỗ của xương gốc (hoạt ảnh 'RM' có tiến tới) — sim đã tự di chuyển đơn vị."""
    for c in anim["channels"]:
        node = g["nodes"][c["target"]["node"]].get("name", "")
        if c["target"]["path"] != "translation" or node not in root_names:
            continue
        s = anim["samplers"][c["sampler"]]
        v = array(g, binc, s["output"]).copy()
        v[:] = v[0]
        s["output"] = add_accessor(g, binc, v, "VEC3")


def attach_rigid(g, binc, array, src_path, joint_name, read):
    """`--attach tệp.glb:xương` (D-231): thêm lưới vật cứng (vũ khí tách bằng split_weapons.py, cùng hệ tọa độ và
    ảnh màu với thân) thành primitive mới của lưới có da, dính 100% vào xương `joint_name`."""
    wg, wb = read(src_path)
    wp = wg["meshes"][0]["primitives"][0]
    skin = g["skins"][0]
    names = [g["nodes"][j].get("name", "") for j in skin["joints"]]
    assert joint_name in names, f"không có xương {joint_name}: {names}"
    joint = names.index(joint_name)
    attrs = {}
    for key in ("POSITION", "NORMAL", "TEXCOORD_0"):
        if key in wp["attributes"]:
            arr = array(wg, wb, wp["attributes"][key]).astype(np.float32)
            attrs[key] = add_accessor(g, binc, arr, {2: "VEC2", 3: "VEC3"}[arr.shape[1]], key == "POSITION")
            if key == "POSITION":
                acc = g["accessors"][attrs[key]]
                acc["min"], acc["max"] = arr.min(0).tolist(), arr.max(0).tolist()
                count = len(arr)
    joints = np.zeros((count, 4), np.uint16)
    joints[:, 0] = joint
    weights = np.zeros((count, 4), np.float32)
    weights[:, 0] = 1.0
    attrs["JOINTS_0"] = _add_raw(g, binc, joints, 5123, "VEC4")
    attrs["WEIGHTS_0"] = add_accessor(g, binc, weights, "VEC4")
    idx = array(wg, wb, wp["indices"]).astype(np.uint32).ravel()
    prim = {"attributes": attrs, "indices": _add_raw(g, binc, idx, 5125, "SCALAR")}
    body = g["meshes"][0]["primitives"][0]
    own = _copy_material(g, binc, wg, wb, wp)  # D-235: vật dựng riêng có ảnh màu riêng
    if own is not None:
        prim["material"] = own
    elif "material" in body:
        prim["material"] = body["material"]
    g["meshes"][0]["primitives"].append(prim)
    return count


def _add_raw(g, binc, arr, comp, kind):
    arr = np.ascontiguousarray(arr)
    binc += b"\0" * (-len(binc) % 4)
    g["bufferViews"].append({"buffer": 0, "byteOffset": len(binc), "byteLength": arr.nbytes})
    binc += arr.tobytes()
    g["accessors"].append({"bufferView": len(g["bufferViews"]) - 1, "componentType": comp,
                           "count": len(arr), "type": kind})
    return len(g["accessors"]) - 1


def _copy_material(g, binc, wg, wb, wp):
    """Chép vật liệu + ảnh màu của vật (nếu ảnh khác ảnh của thân — vật tách từ cùng lưới thì dùng chung)."""
    if "material" not in wp:
        return None
    mat = dict(wg["materials"][wp["material"]])
    pbr = dict(mat.get("pbrMetallicRoughness", {}))
    tex_ref = pbr.get("baseColorTexture")
    if tex_ref is None:
        return None
    img = wg["images"][wg["textures"][tex_ref["index"]]["source"]]
    bv = wg["bufferViews"][img["bufferView"]]
    data = bytes(wb[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])
    for gi in g.get("images", []):  # cùng ảnh với thân (vũ khí tách từ chính lưới thân) → dùng vật liệu thân
        gbv = g["bufferViews"][gi["bufferView"]]
        if gbv["byteLength"] == len(data) and bytes(binc[gbv.get("byteOffset", 0):gbv.get("byteOffset", 0) + len(data)]) == data:
            return None
    binc += b"\0" * (-len(binc) % 4)
    g["bufferViews"].append({"buffer": 0, "byteOffset": len(binc), "byteLength": len(data)})
    binc += data
    g.setdefault("images", []).append({"bufferView": len(g["bufferViews"]) - 1, "mimeType": img.get("mimeType", "image/jpeg")})
    g.setdefault("textures", []).append({"source": len(g["images"]) - 1})
    pbr["baseColorTexture"] = {"index": len(g["textures"]) - 1}
    pbr.pop("metallicRoughnessTexture", None)
    mat = {"name": mat.get("name", "prop"), "pbrMetallicRoughness": pbr}
    g.setdefault("materials", []).append(mat)
    return len(g["materials"]) - 1
