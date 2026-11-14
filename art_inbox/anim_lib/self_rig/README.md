# Tự gắn xương afk bằng code (thử nghiệm D-399) — Phong Tiễn style mới

Nguồn (chỉ đọc từ `origin/cb-1-art`): `art_inbox/3d/phong_tien_v3/phong_tien_v3_front.glb` (Tripo, chưa gắn xương),
`phong_tien_v3_afk.glb` (đáp án afk — chỉ dùng để so). Bộ xương mẫu: `art_inbox/3d/vexa_v2_afk.glb`.

```
python3 -I tools/models/anim_lib/self_rig.py art_inbox/3d/vexa_v2_afk.glb phong_tien_v3_front.glb phong_tien_v3_tu_gan.glb
python3 -I tools/models/anim_lib/apply_anims.py art_inbox/3d/vexa_v2_afk.glb phong_tien_v3_tu_gan.glb ra.glb --anims Idle_A,Run,…
python3 -I tools/models/anim_lib/fit_skeleton.py mẫu_afk.glb lưới.glb --check đáp_án_afk.glb --height 1.3
python3 -I tools/models/anim_lib/deform_check.py afk.glb tự_gắn.glb --anims …
```

## Cách làm

1. **Vị trí khớp** (`landmarks.py`, `fit_skeleton.py`): cắt lưới theo lát ngang → vòng tiết diện; dò đường tâm hai
   chân (từ bàn chân lên tới đũng), hai tay (từ đầu ngón ra ngoài nhất lên tới nách), thân; mốc đáy / đũng / nách /
   cổ hẹp nhất / đỉnh. Khớp mẫu = điểm trên đường tâm + độ lệch → chuyển sang lưới mới. Cổ / đầu theo mốc của chính
   lưới (afk đặt cổ Vexa trong mũ). Trái / phải lấy trung bình gương. Ngón tay theo bàn tay.
2. **Trục nghỉ** — quy ước afk tìm được (7 tướng, không dùng Phong Tiễn v3): gốc / hông / cột sống / cổ / đầu có xoay
   thế giới cố định giống nhau ở mọi tướng; xương còn lại trục +Y chĩa đúng khớp con; cuộn: đùi Z → −Z thế giới (sai
   0,4°), bàn chân X → +X, ngón chân X → −X, xương đòn Z → +Y, cánh tay trên Z → +Z (sai TB 8°); cẳng tay / cẳng
   chân = khung cha xoay ngắn nhất; bàn tay = khung cẳng tay (+1,4° cố định). Với track afk (cùng số xoay cục bộ cho
   mọi tướng, D-398), dáng xương khi chạy hoạt ảnh chỉ còn phụ thuộc độ dài xương: hướng xương tự gắn = afk (lệch 0°).
3. **Trọng số da** (`heat_weights.py`): Blender `bpy` KHÔNG cài được (môi trường chặn `pip install bpy`) → bone heat
   bằng numpy: (L + H) w = H p trên đồ thị cạnh lưới (nhiệt chỉ lan theo mặt lưới), H = 0,3 / d², thêm 10 vòng làm
   mượt, ≤ 4 xương / đỉnh. Hằng số chọn sau khi quét (bản đầu H = 1 / d², không làm mượt: lỗi gấp ~2 lần afk).

## Số đo (lech_khop.txt, bien_dang.txt)

| Lưới (mẫu Vexa) | lệch khớp thân+tay+chân TB (max) | trục TB (max) |
|---|---|---|
| Phong Tiễn v3 | 4,4 cm (13,5 — đùi) | 10,6° (35° — ngón chân) |
| Phong Tiến cũ | 6,3 cm (25,3) | 16,4° |
| Noctis | 4,7 cm (11,5) | 10,4° |
| Gorran (to) | 12,9 cm (36,7) | 13,9° |

afk tự nó không nhất quán (hông: 12–40 % bề ngang chân ở 6 tướng, 104 % ở Phong Tiễn v3) → lệch ~5 cm nằm trong độ
dao động của chính afk. Lưới khi chạy hoạt ảnh lệch bản afk: thân 2–4 cm, tay / chân 6–9 cm (do vị trí khớp).

Biến dạng, 8 hoạt ảnh từ kho Vexa (đỉnh có cạnh > 2× / tam giác lật / tam giác lún < 10 % diện tích):
xem `bien_dang.txt` — tự gắn ít hơn afk ở mọi hoạt ảnh. Thử chéo (xương afk thật + trọng số tự tính bản đầu) cho
cùng mức lỗi như tự gắn → khác biệt nằm ở trọng số, không ở xương.

Thời gian: tự gắn 8–9 s (ướm xương 1,4 s + trọng số 7,5 s) trên máy cloud; afk: 144–176 s trên máy chủ + 23–95 s
bước giữ tay trên máy.

Video (trái afk, phải tự gắn, cùng hoạt ảnh kho): `afk_vs_tu_gan.mp4` (8 hoạt ảnh), `can_chay.mp4`, `can_keo_cung.mp4`.
