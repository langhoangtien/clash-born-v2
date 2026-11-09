#!/usr/bin/env python3
"""D-310: ảnh nền đá lát cho đất cao (base) — phiến đá to nhỏ không đều ghép khít, mép vát sáng / tối theo nắng,
mạch sẫm có rêu, vẽ kiểu tay theo ảnh mẫu người chơi (art_inbox/08_style/ref/highground_ref.png, phương án A).
Lặp liền mép (Voronoi trên mặt xuyến). Không cần API ảnh.

  python3 tools/textures/flagstones.py assets/textures/style/flagstones.png [--size 1024] [--cells 7] [--seed 310]
"""
import argparse
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

STONE_WARM = np.array([158, 150, 138], float)
STONE_COOL = np.array([138, 142, 146], float)
SEAM = np.array([78, 72, 64], float)
MOSS = np.array([96, 116, 62], float)
LIGHT = np.array([-0.55, -0.6, 0.58])  # nắng từ trên-trái màn hình (như bộ asset style_kit)


def seeds(cells, rng):
    """Lưới lệch ngẫu nhiên; bỏ bớt vài hạt (phiến to) và thêm hạt rời (phiến nhỏ) cho cỡ phiến chênh nhau."""
    g = (np.stack(np.meshgrid(np.arange(cells), np.arange(cells)), -1).reshape(-1, 2) + 0.5) / cells
    p = (g + rng.uniform(-0.38, 0.38, g.shape) / cells) % 1.0
    keep = rng.random(len(p)) > 0.18  # bỏ vài hạt → phiến to
    extra = rng.random((int(cells * cells * 0.35), 2))  # thêm hạt rời → phiến nhỏ chen giữa
    return np.concatenate([p[keep], extra])


def nearest_two(p, n):
    """Khoảng cách tới hạt gần nhất / nhì (mặt xuyến) và chỉ số hạt gần nhất cho lưới n×n."""
    ys, xs = np.mgrid[0:n, 0:n] / n
    d1 = np.full((n, n), 9.0); d2 = np.full((n, n), 9.0); idx = np.zeros((n, n), int)
    for i, (sx, sy) in enumerate(p):
        dx = np.abs(xs - sx); dx = np.minimum(dx, 1 - dx)
        dy = np.abs(ys - sy); dy = np.minimum(dy, 1 - dy)
        d = np.hypot(dx, dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, d, d1)
    return d1, d2, idx


def tile_noise(n, cells, rng):
    """Nhiễu mềm lặp liền mép (phóng to ô ngẫu nhiên, bao vòng)."""
    a = rng.random((cells, cells))
    a = np.tile(a, (3, 3))
    big = np.array(Image.fromarray((a * 255).astype(np.uint8)).resize((n * 3, n * 3), Image.BICUBIC), float) / 255
    return big[n:2 * n, n:2 * n]


def wrap_blur(a, r):
    return ndimage.gaussian_filter(a, r, mode="wrap")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--cells", type=int, default=7)
    ap.add_argument("--seed", type=int, default=310)
    a = ap.parse_args()
    n, rng = a.size, np.random.default_rng(a.seed)
    p = seeds(a.cells, rng)
    # Méo toạ độ trước khi tính Voronoi → mép phiến cong nhẹ như vẽ tay.
    d1, d2, idx = nearest_two(p, n)
    edge = (d2 - d1) * n  # px tới mạch (xấp xỉ ×2)
    wob = (tile_noise(n, 24, rng) - 0.5) * 7
    edge = edge + wob
    seam_w = 5.0
    height = np.clip((edge - seam_w) / 22.0, 0, 1) ** 0.6  # mép vát tròn
    height = wrap_blur(height, 1.2)
    gy, gx = np.gradient(height)
    nz = np.ones_like(height) * 0.06
    norm = np.stack([-gx, -gy, nz], -1)
    norm /= np.linalg.norm(norm, axis=-1, keepdims=True)
    light = np.clip(norm @ (LIGHT / np.linalg.norm(LIGHT)), 0, 1)
    shade = 0.82 + 0.32 * (light - light.mean())  # vát sáng phía nắng, tối phía khuất
    # Màu từng phiến: ấm / lạnh, sáng tối lệch nhau.
    k = rng.random(len(p)); v = rng.uniform(0.88, 1.08, len(p))
    base = STONE_WARM[None] * k[:, None] + STONE_COOL[None] * (1 - k[:, None])
    col = base[idx] * v[idx][..., None]
    # Vân trong phiến: nhiễu lớn + nét cọ (nhiễu kéo dài theo một hướng).
    big = tile_noise(n, 9, rng) - 0.5
    stroke = wrap_blur(rng.random((n, n)), (2.5, 5.0)) - 0.5
    blot = tile_noise(n, 40, rng) - 0.5  # đốm màu cỡ nét cọ
    col *= (1 + big * 0.14 + stroke * 0.35 + blot * 0.1)[..., None]
    # Vết nứt mảnh trên vài phiến.
    crack = np.zeros((n, n))
    for _ in range(a.cells):
        x, y = rng.integers(0, n, 2); ang = rng.uniform(0, np.pi)
        for t in range(int(n * 0.06)):
            x = (x + np.cos(ang) + rng.normal(0, 0.6)) % n; y = (y + np.sin(ang) + rng.normal(0, 0.6)) % n
            crack[int(y), int(x)] = 1
    crack = wrap_blur(crack, 0.7) * (height > 0.9)
    col *= (1 - np.clip(crack * 2.5, 0, 0.35))[..., None]
    col *= shade[..., None]
    # Mạch: sẫm, chỗ có rêu xanh (nhiễu), mạch rộng hơn mép vát.
    seam = 1 - np.clip((edge - seam_w * 0.4) / (seam_w * 1.2), 0, 1)
    moss_m = np.clip((tile_noise(n, 11, rng) - 0.45) * 4, 0, 1)
    seam_col = SEAM[None, None] * (1 - moss_m[..., None]) + MOSS[None, None] * moss_m[..., None]
    moss_spill = np.clip(1 - (edge - seam_w) / 14, 0, 1) * moss_m * 0.55  # rêu lấn nhẹ lên mép phiến
    col = col * (1 - moss_spill[..., None]) + MOSS[None, None] * moss_spill[..., None]
    col = col * (1 - seam[..., None]) + seam_col * seam[..., None]
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    img = img.filter(ImageFilter.SMOOTH)
    img.save(a.out)
    print(a.out, n, "px,", len(p), "phiến")


if __name__ == "__main__":
    main()
