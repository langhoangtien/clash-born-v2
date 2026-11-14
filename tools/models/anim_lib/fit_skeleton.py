#!/usr/bin/env python3
"""Ướm bộ xương afk của một tướng MẪU vào lưới tướng mới bằng hình học (D-399).

  python3 -I tools/models/anim_lib/fit_skeleton.py mẫu_afk.glb lưới.glb [--check đáp_án_afk.glb --height 1.3]

Vị trí khớp: mốc (đáy, đũng, nách, cổ, đỉnh; đường tâm chân / tay / thân, landmarks.py) của mẫu và lưới mới; mỗi khớp
mẫu = điểm trên đường tâm + độ lệch → chuyển sang đường tâm tương ứng của lưới mới (co giãn theo độ dài đoạn).
Xoay nghỉ theo quy ước afk (khảo sát D-399): gốc / hông / cột sống / cổ / đầu có xoay thế giới cố định (chép từ mẫu);
xương còn lại trục +Y chĩa tới khớp con trong chuỗi, cuộn giữ gần mẫu nhất (xoay ngắn nhất đưa trục Y mẫu về hướng mới).
--check: so với xương afk thật của chính lưới đó (cm theo --height, độ).
"""
import argparse, os, re, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_anims as GA  # noqa: E402
import rig_math as RM  # noqa: E402
import mesh_slices as MS  # noqa: E402
import landmarks as LM  # noqa: E402

FIXED = {"afk-human", "Armature", "root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head", "head_leaf"}
CHAIN = {"clavicle": "upperarm", "upperarm": "lowerarm", "lowerarm": "hand", "hand": "middle_01", "thigh": "calf",
         "calf": "foot", "foot": "ball", "ball": "ball_leaf"}


def group(name):
    m = re.match(r"(.*)_([lr])$", name)
    if not m:
        return "torso", None
    base, side = m.groups()
    if base in ("thigh", "calf", "foot", "ball", "ball_leaf"):
        return "leg", side
    if base in ("clavicle", "upperarm", "lowerarm", "hand"):
        return "arm", side
    return "finger", side


def chain_child(name):
    m = re.match(r"(.*)_([lr])$", name)
    if not m:
        return None
    base, side = m.groups()
    if base in CHAIN:
        return f"{CHAIN[base]}_{side}"
    f = re.match(r"([a-z]+)_0(\d)$", base)
    if f:
        k = int(f.group(2)) + 1
        return f"{f.group(1)}_0{k}{'_leaf' if k == 4 else ''}_{side}"
    return None


def skeleton_world(path):
    g, b = GA.read(path)
    s = RM.Skeleton(g)
    wp, wr = s.fk(*s.rest())
    return s, wp[0], wr[0]


def _knots(L):
    return np.array([L["bot"], L["crotch"], L["armpit"], L["neck"], L["top"]])


def _map_y(y, a, b):
    return float(np.interp(y, a, b, left=b[0] + (y - a[0]), right=b[-1] + (y - a[-1])))


def _limb(y, Lt, Ln, part, side):
    """(curve mẫu, curve mới, y mới, tỉ lệ) cho chân / tay một bên."""
    if part == "leg":
        (ty, tc), (ny, nc) = Lt["leg"][side], Ln["leg"][side]
        a0, a1, b0, b1 = Lt["bot"], ty[-1], Ln["bot"], ny[-1]
    else:
        (tt, ty, tc), (nt, ny, nc) = Lt["arm"][side], Ln["arm"][side]
        a0, a1, b0, b1 = tt[1], ty[-1], nt[1], ny[-1]
    k = (b1 - b0) / (a1 - a0)
    return (ty, tc), (ny, nc), b0 + (y - a0) * k, k


def fit_positions(ts, twp, Lt, Ln):
    pos = {}
    kt, kn = _knots(Lt), _knots(Ln)
    for k, name in enumerate(ts.name):
        J = twp[k]
        part, side = group(name)
        if part == "torso":
            y = _map_y(J[1], kt, kn)  # sâu (z) chép từ mẫu: tâm tiết diện thân bị túi tên / áo choàng kéo lệch
            pos[name] = np.array([J[0], y, J[2] * Ln["H"] / Lt["H"]])
        elif part in ("leg", "arm"):
            (ty, tc), (ny, nc), y, s = _limb(J[1], Lt, Ln, part, side)
            pos[name] = LM.curve_at(ny, nc, y) + (J - LM.curve_at(ty, tc, J[1])) * np.array([s, 0, s]) \
                + np.array([0, y - LM.curve_at(ny, nc, y)[1], 0])
    _neck(pos, ts, twp, Ln)
    _mirror(pos)
    for side in "lr":  # ngón tay: theo bàn tay, xoay theo hướng cẳng tay, co giãn theo tay
        h, la = f"hand_{side}", f"lowerarm_{side}"
        d_t, d_n = twp[ts.by_name[h]] - twp[ts.by_name[la]], pos[h] - pos[la]
        q = _swing(d_t, d_n)
        s = np.linalg.norm(d_n) / np.linalg.norm(d_t)
        for k, name in enumerate(ts.name):
            if group(name) == ("finger", side):
                pos[name] = pos[h] + RM.qrot(q, (twp[k] - twp[ts.by_name[h]]) * s)
    return pos


def _neck(pos, ts, twp, Ln):
    """Cổ / đầu theo mốc của chính lưới (mẫu afk có khi đặt cổ trong mũ — Vexa): đầu ở chỗ cổ hẹp nhất, neck_01 giữa
    nách và chỗ đó, spine_03 ngay trên nách; head_leaf giữ độ lệch so với đầu như mẫu."""
    a, n = Ln["armpit"], Ln["neck"]
    for name, y in (("spine_03", a + 0.1 * (n - a)), ("neck_01", (a + n) / 2), ("head", n)):
        pos[name] = np.array([pos[name][0], y, pos[name][2]])
    k = ts.by_name
    pos["head_leaf"] = pos["head"] + (twp[k["head_leaf"]] - twp[k["head"]]) * Ln["H"] / Ln["H"]


def _mirror(pos):
    """Lưới gần đối xứng: lấy trung bình bên trái với ảnh gương bên phải (mốc một bên hay lệch vì phụ kiện)."""
    m = np.array([-1.0, 1, 1])
    for name in [n for n in pos if n.endswith("_l")]:
        r = name[:-2] + "_r"
        if r in pos:
            avg = (pos[name] + pos[r] * m) / 2
            pos[name], pos[r] = avg, avg * m


def _swing(a, b):
    """Quaternion xoay ngắn nhất đưa hướng a về hướng b."""
    a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
    c = np.cross(a, b)
    q = np.array([c[0], c[1], c[2], 1.0 + float(np.dot(a, b))])
    return q / np.linalg.norm(q) if q[3] > 1e-8 else np.array([1.0, 0, 0, 0])


# D-399: quy ước cuộn của afk (khảo sát 7 tướng, trừ Phong Tiễn v3): xương đầu chuỗi có trục Y chĩa tới khớp con,
# trục X / Z gần nhất với một hướng thế giới cố định (sai số trung bình 0,3–10°).
ROLL = {"thigh": ("Z", (0, 0, -1)), "foot": ("X", (1, 0, 0)), "ball": ("X", (-1, 0, 0)),
        "clavicle": ("Z", (0, 1, 0)), "upperarm": ("Z", (0, 0, 1))}
SWING = {"calf", "lowerarm"}  # nối chuỗi: khung xương cha xoay ngắn nhất cho Y chĩa khớp con (cẳng tay / cẳng chân)


def _frame(y, axis, ref):
    y = y / np.linalg.norm(y)
    r = np.array(ref, float) - np.dot(ref, y) * y
    r /= np.linalg.norm(r)
    x, z = (r, np.cross(r, y)) if axis == "X" else (np.cross(y, r), r)
    m = np.stack([x, y, z], 1)
    w = np.sqrt(max(1e-12, 1 + m[0, 0] + m[1, 1] + m[2, 2])) / 2
    q = np.array([(m[2, 1] - m[1, 2]) / (4 * w), (m[0, 2] - m[2, 0]) / (4 * w), (m[1, 0] - m[0, 1]) / (4 * w), w])
    return RM.qnorm(q)


def fit_rotations(ts, twr, pos):
    rot = {}
    for k, name in enumerate(ts.name):
        child, p = chain_child(name), ts.parent[k]
        base = name[:-2] if name[-2:] in ("_l", "_r") else name
        if name in FIXED or name not in pos:
            rot[name] = twr[k]
        elif base in ROLL:
            rot[name] = _frame(pos[child] - pos[name], *ROLL[base])
        elif base in SWING:
            par = rot[ts.name[p]]
            rot[name] = RM.qnorm(RM.qmul(_swing(RM.qrot(par, np.array([0, 1.0, 0])), pos[child] - pos[name]), par))
        else:  # bàn tay, ngón tay, xương mút: giữ xoay cục bộ của mẫu so với cha
            rot[name] = RM.qnorm(RM.qmul(rot[ts.name[p]], RM.qmul(RM.qinv(twr[p]), twr[k])))
    return rot


def fit(template_path, mesh_path):
    ts, twp, twr = skeleton_world(template_path)
    Lt = LM.landmarks(MS.Slicer(*MS.load_mesh(template_path)))
    Ln = LM.landmarks(MS.Slicer(*MS.load_mesh(mesh_path)))
    pos = fit_positions(ts, twp, Lt, Ln)
    for k, name in enumerate(ts.name):
        pos.setdefault(name, twp[k])  # nút trên gốc (afk-human, Armature)
    return ts, pos, fit_rotations(ts, twr, pos)


def check(ts, pos, rot, answer_path, height):
    s, wp, wr = skeleton_world(answer_path)
    v, _ = MS.load_mesh(answer_path)
    cm = height / (v[:, 1].max() - v[:, 1].min()) * 100
    rows = []
    for k, name in enumerate(s.name):
        if name in pos and name not in ("afk-human", "Armature"):
            d = float(np.linalg.norm(pos[name] - wp[k])) * cm
            a = float(np.degrees(2 * np.arccos(min(1.0, abs(float(np.dot(rot[name], wr[k])))))))
            rows.append((name, d, a))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("template"); ap.add_argument("mesh")
    ap.add_argument("--check"); ap.add_argument("--height", type=float, default=1.3)
    a = ap.parse_args()
    ts, pos, rot = fit(a.template, a.mesh)
    if a.check:
        rows = check(ts, pos, rot, a.check, a.height)
        body = [r for r in rows if group(r[0])[0] != "finger"]
        for name, d, ang in body:
            print(f"  {name:12s} lệch {d:5.1f} cm  trục {ang:5.1f}°")
        for label, rs in (("thân+tay+chân", body), ("ngón tay", [r for r in rows if r not in body])):
            ds, angs = np.array([r[1] for r in rs]), np.array([r[2] for r in rs])
            print(f"{label}: lệch khớp TB {ds.mean():.1f} cm (max {ds.max():.1f}), trục TB {angs.mean():.1f}° "
                  f"(max {angs.max():.1f})")


if __name__ == "__main__":
    main()
