"""Trọng số da kiểu "bone heat" bằng numpy (D-399; thay Blender automatic weights khi không có bpy).

Giải (L + H) w_j = H p_j cho từng xương j trên đồ thị cạnh lưới (lặp Jacobi): p_ij = 1 nếu j là xương gần đỉnh i
nhất, H_i = 1 / d_i² (d_i: khoảng cách tới xương gần nhất), L: Laplace cạnh trọng số 1 / độ dài. Nhiệt chỉ lan theo
mặt lưới nên không nhảy qua khe (đùi trái ↔ đùi phải, tay ↔ hông). Sau đó bỏ trọng số < 1 %, giữ 4 xương / đỉnh.
"""
import numpy as np

ITER = 600  # số vòng Jacobi (đủ hội tụ với lưới vài nghìn đỉnh)
MIN_W = 0.01


def seg_dist(v, a, b):
    """Khoảng cách từ mọi đỉnh v (N,3) tới đoạn a–b."""
    ab = b - a
    t = np.clip(((v - a) @ ab) / max(float(ab @ ab), 1e-12), 0, 1)
    return np.linalg.norm(v - (a + t[:, None] * ab), axis=1)


def heat(verts, tris, segs, c=0.3, smooth=10):  # D-399: chọn sau khi quét c ∈ {1, 0,3, 0,1} × làm mượt {0, 10}
    """verts (N,3) đã gộp đỉnh trùng, tris (M,3), segs: list (đầu, cuối) mỗi xương → trọng số (N, B).
    c: hằng số nhiệt (nhỏ → lan rộng, mềm hơn); smooth: số vòng làm mượt trọng số cuối theo cạnh."""
    d = np.stack([seg_dist(verts, a, b) for a, b in segs], 1)
    dmin = d.min(1)
    p = (d <= dmin[:, None] * 1.0001 + 1e-9).astype(float)
    p /= p.sum(1, keepdims=True)
    H = c / np.maximum(dmin, 1e-4) ** 2
    e = np.unique(np.sort(np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]]), 1), axis=0)
    e = e[e[:, 0] != e[:, 1]]
    we = 1.0 / np.maximum(np.linalg.norm(verts[e[:, 0]] - verts[e[:, 1]], axis=1), 1e-5)
    deg = np.zeros(len(verts))
    np.add.at(deg, e[:, 0], we)
    np.add.at(deg, e[:, 1], we)
    rhs = H[:, None] * p
    w = p.copy()
    for _ in range(ITER):
        acc = np.zeros_like(w)
        np.add.at(acc, e[:, 0], we[:, None] * w[e[:, 1]])
        np.add.at(acc, e[:, 1], we[:, None] * w[e[:, 0]])
        w = (rhs + acc) / (H + deg)[:, None]
    for _ in range(smooth):
        acc = np.zeros_like(w)
        np.add.at(acc, e[:, 0], we[:, None] * w[e[:, 1]])
        np.add.at(acc, e[:, 1], we[:, None] * w[e[:, 0]])
        w = 0.5 * w + 0.5 * acc / deg[:, None]
    return limit(w)


def limit(w, keep=4):
    w = np.where(w < MIN_W, 0.0, w)
    idx = np.argsort(-w, 1)[:, :keep]
    top = np.take_along_axis(w, idx, 1)
    top /= np.maximum(top.sum(1, keepdims=True), 1e-12)
    return idx, top
