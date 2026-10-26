# Yêu cầu ảnh — Bộ mảnh chuẩn dựng map (kit map)

Phiếu việc cho **Codex tạo ảnh tham chiếu**. Mỗi ảnh sau đó được đưa vào Tripo (tạo 3D từ ảnh) — việc
gọi Tripo, giảm lưới, tô màu và đưa vào game do người ghép (Claude) làm, Codex **chỉ làm ảnh**.

Map được dựng lại hoàn toàn từ bộ mảnh này: vách đá, bờ sông, rào là **dãy dài** game tự uốn theo
đường cong; rừng là **mảng nguyên khối**; bụi cỏ là **cụm nhỏ** rải kín vùng bụi. Vật cản lấy đúng theo
chân của mảnh, nên **hình dáng và tỉ lệ trong ảnh là yêu cầu quan trọng nhất**.

## Cách làm việc (bắt buộc)

1. Làm **theo đợt**. Xong mỗi đợt **DỪNG**, báo người dùng duyệt rồi mới làm đợt sau.
2. Mỗi ảnh đính kèm hai ảnh tham chiếu: `art_inbox/00_style/style_3d_sheet.png` và
   `docs/art/reference_style_01.png`. Không thấy file → `git pull` trước, không dùng ảnh khác thay.
3. Lưu `art_inbox/07_kit/<tên>.png`, đúng tên trong bảng (chữ thường, gạch dưới). Không thêm `_v2`, `_final`.
4. Làm xong ảnh nào đánh dấu `[x]` ở dòng đó. Làm lại thì ghi ngắn lý do.
5. Không sửa file nào ngoài `art_inbox/`.

## Quy tắc chung cho ảnh (để Tripo dựng 3D đúng)

- **Một vật thể, nhìn trọn vẹn**, nằm giữa khung, cách mép ≥ 8%, không bị cắt, không vật thể phụ.
- **Góc nhìn:** 3/4 từ trên xuống (camera nghiêng ~45°), nhìn vào **cạnh dài** của vật, hơi lệch ~20°
  để thấy cả mặt trên, mặt dài và một đầu.
- **Nền trắng trơn `#FFFFFF`**, không gradient, không bóng đổ xuống nền, không mặt đất, không cỏ quanh chân.
- **Ánh sáng dịu đều** từ trên–trái, không bóng gắt (bóng gắt bị nướng sai vào 3D).
- **Đáy phẳng:** vật đặt trên mặt phẳng, chân không bo vào trong, không lơ lửng.
- **Tỉ lệ đúng như bảng** (dài : dày : cao). Đây là kích thước thật trong game, sai tỉ lệ thì ghép không khít.
- **Phong cách:** vẽ tay cách điệu như ảnh neo — khối to, cạnh vát tròn, ít chi tiết vụn, màu tươi.
  Đá: **xám xanh lạnh**, mặt trên có rêu xanh lá, khe tối. Không chữ, không logo.
- **Mặt hướng về sau / đáy** không cần chi tiết.

### Riêng các dãy dài (vách, bờ sông, rào) — điều kiện để nối khít

- **Hai đầu cắt phẳng thẳng đứng**, vuông góc với chiều dài, như khúc bánh mì cắt ngang.
- **Mặt cắt hai đầu giống hệt nhau** (cùng dày, cùng cao, cùng dáng): đặt đầu mảnh này sát đầu mảnh kia
  phải liền như một khối.
- **Dày và cao đều suốt chiều dài**, không phình giữa, không thót hai đầu. Mép trên được gợn nhẹ.
- Chi tiết (tảng, khe, rêu) phân bố đều dọc chiều dài, không có điểm nhấn lớn ở một chỗ (vì sẽ lặp lại).

### Câu lệnh gốc (ghép trước mô tả từng ảnh)

```
Stylized hand-painted 3D game asset concept for a mobile MOBA, chunky rounded shapes, low detail,
soft beveled edges, saturated colors, same art style as the attached reference images,
single object fully visible and centered, 3/4 top-down view at about 45 degrees,
plain pure white background, soft even light from top-left, no cast shadow, no ground,
flat bottom, no text, no watermark.
```

Thêm cho dãy dài:

```
Long straight modular wall segment, both ends cut perfectly flat and vertical with identical
cross-section, constant thickness and height along the whole length, evenly distributed details.
```

---

## Đợt K0 — Thử phong cách (3 ảnh) — làm rồi DỪNG

- [ ] `vach_48.png` — vách đá dài 4,8 m, dày 1,2 m, cao 1,2 m (**4 : 1 : 1**). Tảng đá xám xanh xếp
  liền thành bức tường thấp, mặt trên có rêu.
- [ ] `rung_tron_m.png` — mảng rừng tròn Ø 7,2 m, cao 2,6–3 m. Khoảng 6–8 cây tán tròn bồng **dính liền
  thành một khối tán**, tán phủ ra sát mép chân khối, thân chỉ lộ chút ở rìa.
- [ ] `bui_a.png` — cụm cỏ 1,2 × 1,2 m, cao 0,6 m. Lá to nhọn, **khối đặc** (không lá mỏng tách rời).

## Đợt K1 — Dãy đá (game uốn cong theo đường)

| | Tên | Dài × dày × cao (m) | Tỉ lệ | Mô tả |
|---|---|---|---|---|
| [ ] | `vach_24` | 2,4 × 1,2 × 1,2 | 2:1:1 | Như `vach_48`, ngắn |
| [ ] | `vach_48b` | 4,8 × 1,2 × 1,2 | 4:1:1 | Biến thể thứ hai của `vach_48` (tảng khác chỗ) |
| [ ] | `vach_dau` | 1,2 × 1,2 × 1,2 | 1:1:1 | Đầu bo: **một đầu cắt phẳng** (nối vào dãy), **đầu kia bo tròn** |
| [ ] | `vach_goc` | 2,4 × 2,4 × 1,2 | — | Góc vuông 90°: hình chữ L, hai cánh dày 1,2 m, hai đầu cánh cắt phẳng |
| [ ] | `bo_song_24` | 2,4 × 1,2 × 0,5 | — | Bờ sông: một cạnh dài là **mặt dốc đá ướt sẫm xuống nước**, cạnh kia mép cỏ |
| [ ] | `bo_song_48` | 4,8 × 1,2 × 0,5 | — | Như trên, dài |
| [ ] | `bo_song_dau` | 1,2 × 1,2 × 0,5 | — | Đầu bờ sông bo tròn thấp dần xuống đất (cạnh lối xuống sông) |
| [ ] | `rao_24` | 2,4 × 0,8 × 0,8 | 3:1:1 | Rào base: khối đá đẽo vuông xếp, viền vàng kim nhẹ trên đỉnh |
| [ ] | `rao_48` | 4,8 × 0,8 × 0,8 | 6:1:1 | Như trên, dài |
| [ ] | `rao_cot` | 0,9 × 0,9 × 1,3 | — | Cột rào vuông, chóp vàng kim (đặt ở đầu / chỗ gập rào) |

## Đợt K2 — Khối núi (lấp vùng đá lớn, viền map; không uốn)

Cao 3–4 m, nhiều tảng chồng thành một khối núi, đỉnh có rêu, chân to chạm đất kín.

| | Tên | Chân (m) | Cao (m) |
|---|---|---|---|
| [ ] | `nui_s` | 4,8 × 4,8 | 3 |
| [ ] | `nui_m` | 9,6 × 4,8 | 3,5 |
| [ ] | `nui_l` | 9,6 × 9,6 | 4 |

## Đợt K3 — Mảng rừng (8 mảng, lưới 2,4 m)

Nhiều cây tán tròn bồng (xen 1–2 cây thông) **dính liền một khối tán**, cao 2,5–3 m. **Tán phủ đúng tới
mép chân khối** — chân khối chính là vùng chặn đường. Mép ngoài tán gợn tròn tự nhiên, không phẳng như hộp.

| | Tên | Chân (m) | Dáng |
|---|---|---|---|
| [ ] | `rung_tron_s` | Ø 4,8 | tròn nhỏ |
| [ ] | `rung_tron_l` | Ø 9,6 | tròn lớn |
| [ ] | `rung_ovan` | 9,6 × 4,8 | ô van dài |
| [ ] | `rung_dai` | 9,6 × 2,4 | dải mỏng một hàng cây |
| [ ] | `rung_cung` | ¼ vòng: bán kính trong 4,8, ngoài 9,6 | cung cong |
| [ ] | `rung_l` | 9,6 × 9,6, cánh rộng 4,8 | chữ L (góc) |
| [ ] | `rung_nem` | tam giác vuông cạnh 7,2 | nêm lấp góc nhọn |

## Đợt K4 — Bụi cỏ (rải kín vùng bụi) và fountain

| | Tên | Cỡ (m) | Mô tả |
|---|---|---|---|
| [ ] | `bui_b` | 1,8 × 1,2 × 0,5 | cụm cỏ thấp rộng |
| [ ] | `bui_c` | 1,0 × 1,0 × 0,7 | cụm cỏ cao thẳng |
| [ ] | `fountain_set_blue` | Ø 12 | Vòng rào đá thấp (cao 0,8 m, dày 0,8 m) quanh nền đá tròn; **một cổng hở 55°** ở phía trước; giữa là đài suối pha lê xanh `#3D8BFF` phát sáng; sát rào phía sau một **trụ bắn nhỏ** cao ~2,5 m, chóp pha lê xanh. Nhìn từ phía cổng. |
| [ ] | `fountain_set_red` | Ø 12 | **Đính kèm bản xanh**, chỉ đổi pha lê và phần màu phe sang đỏ `#FF4D4D`, giữ nguyên hình |

## Ghi chú cho người ghép (không phải việc của Codex)

- Tỉ lệ đơn vị: 1 m = 100 đơn vị thế giới. Lane rộng 2,9 m; vách hiện dày ~1 m → kit dày 1,2 m.
- Tripo: image-to-3D, giới hạn mặt — dãy 2,4 m ≤ 500, dãy 4,8 m ≤ 900, đầu / cột ≤ 300, núi 1.500–2.500,
  mảng rừng 1.500–3.000, bụi 200–400, fountain 4.000–6.000.
- Dãy đá: bỏ ảnh màu Tripo, dùng màu đỉnh + một texture đá lặp phủ theo toạ độ thế giới; chia lưới đều
  dọc chiều dài để uốn; co giãn không đều cho đúng kích thước chuẩn. Rừng / bụi / núi: gộp ảnh màu vào
  một atlas. Chân mọi mảnh pha dần sang màu nền.
- Fountain bắn theo STR-04 sẵn có; trụ trong bộ chỉ là hình. Shop vẫn là mô hình riêng theo `shops`.
