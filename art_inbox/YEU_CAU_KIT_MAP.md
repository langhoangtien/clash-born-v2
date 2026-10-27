# Yêu cầu ảnh — Bộ mảnh chuẩn dựng map (kit map) — bản 2

Phiếu việc cho **Codex tạo ảnh tham chiếu**. Mỗi ảnh sau đó được đưa vào Tripo (tạo 3D từ ảnh); gọi Tripo,
giảm lưới, tô màu và đưa vào game do người ghép (Claude) làm. Codex **chỉ làm ảnh**.

**Bản 2 (2026-10-27) thay toàn bộ bản 1.** Bản 1 (vách kiểu tường gạch, mảng rừng nguyên khối) không đạt.
Ảnh mới **ghi đè** ảnh cũ cùng tên trong `art_inbox/07_kit/`.

Cách dựng map: mỗi khối rừng / khối đá có **viền đá bo** (dãy đá dài, game tự uốn theo đường cong) —
viền đá chính là vùng chặn đường. **Bên trong** viền thả **cây riêng lẻ** (chỉ trang trí). Bờ sông, rào base
cũng là dãy dài. Bụi cỏ là cụm nhỏ rải kín vùng bụi.

## Cách làm việc (bắt buộc)

1. Làm **theo đợt**. Xong mỗi đợt **DỪNG**, báo người dùng duyệt rồi mới làm đợt sau.
2. Mỗi ảnh đính kèm ảnh tham chiếu phong cách người dùng đưa (ảnh chụp game kiểu Liên Quân / Tốc Chiến).
   Lấy **tinh thần** phong cách, không chép nguyên vật thể nào trong ảnh tham chiếu.
3. Lưu `art_inbox/07_kit/<tên>.png`, đúng tên trong bảng. Không thêm `_v2`, `_final`.
4. Làm xong ảnh nào đánh dấu `[x]`. Làm lại thì ghi ngắn lý do.
5. Không sửa file nào ngoài `art_inbox/`.

## Phong cách (kiểu Liên Quân / Tốc Chiến)

- **Ít khối, khối to.** Mặt đá rộng, mượt, cạnh bo tròn mềm. **Không** vân gạch, không viên đá nhỏ xếp
  đều, không vết nứt vụn. Nhìn xa vẫn đọc rõ dáng.
- **Sáng tối vẽ sẵn, chuyển mềm:** mặt trên sáng ấm, xuống dưới tối lạnh dần, chân tối hẳn; khe giữa các
  khối tối (tạo chiều sâu); mép trên có viền sáng nhẹ. Đây là thứ làm vật thể đơn giản vẫn đẹp.
- **Đá:** xám xanh lạnh (hơi ngả xanh lam / ngọc). **Mép trên có lớp cỏ phủ, tràn nhẹ xuống mép** —
  vách nhìn như mép đất nhô lên có cỏ, không phải tường xây.
- **Cây:** ít chùm lá, mỗi chùm to tròn. **Mỗi tầng lá một sắc:** tầng trên vàng xanh sáng, tầng giữa
  xanh lá, tầng dưới xanh lam đậm; khe giữa các chùm tối. Thân ngắn, nâu ấm, chỉ lộ chút dưới tán.
- **Cỏ / bụi:** lá to, khối đặc; ngọn sáng vàng xanh, gốc tối.
- Màu tươi nhưng không gắt. Không chữ, không logo.

## Quy tắc ảnh (để Tripo dựng 3D đúng)

- **Một vật thể, nhìn trọn vẹn**, giữa khung, cách mép ≥ 8%, không vật thể phụ.
- **Góc nhìn 3/4 từ trên xuống** (~45°), nhìn vào **cạnh dài**, lệch ~20° để thấy mặt trên, mặt dài, một đầu.
- **Nền trắng trơn `#FFFFFF`**, không bóng đổ xuống nền, không mặt đất, không cỏ rời quanh chân.
- **Ánh sáng dịu đều** từ trên–trái (sáng tối vẽ trên vật thể như mục Phong cách, nhưng không bóng gắt).
- **Đáy phẳng**, vật đặt trên mặt phẳng.
- **Tỉ lệ đúng như bảng** (dài : dày : cao) — kích thước thật trong game.

### Riêng dãy dài (vách, bờ sông, rào) — để nối khít

- **Hai đầu cắt phẳng thẳng đứng**, vuông góc chiều dài; **mặt cắt hai đầu giống hệt nhau**.
- **Dày và cao đều suốt chiều dài**, không phình giữa, không thót đầu. Mép trên được gợn nhẹ.
- Khối đá to phân bố đều dọc chiều dài, không có điểm nhấn lớn ở một chỗ (vì sẽ lặp lại).

### Câu lệnh gốc (ghép trước mô tả từng ảnh)

```
Stylized hand-painted 3D game asset concept in the style of top-down mobile MOBA maps (Wild Rift /
Arena of Valor feel), few large simple shapes, smooth broad surfaces, soft rounded edges, no small
details, no brick pattern, painted soft gradient lighting: bright warm top, darker cool bottom, dark
ambient occlusion in gaps, subtle rim highlight on top edges, single object fully visible and centered,
3/4 top-down view at about 45 degrees, plain pure white background, no cast shadow, no ground,
flat bottom, no text, no watermark.
```

Thêm cho dãy dài:

```
Long straight modular rock edge segment, a few big smooth boulders merged into one low ridge,
thick grass cap on top slightly overhanging the edges, both ends cut perfectly flat and vertical
with identical cross-section, constant thickness and height along the whole length.
```

---

## Đợt K0 — Thử phong cách (4 ảnh) — làm rồi DỪNG

- [x] `vach_48.png` — viền đá 4,8 × 1,2 × khoảng 1,5 m. 2–3 khối đá lớn, mặt rộng mượt liền thành vách cao gần mặt tướng,
  đủ rõ là vùng không đi qua; mặt đá trơ, không dựng cây/bụi trên vách.
- [x] `bo_song_48.png` — bờ sông 4,8 × 1,2 × 0,5 m. Gờ đá thấp: một cạnh dài mép cỏ, cạnh kia **mặt đá
  dốc tối ướt** xuống nước.
- [x] `cay_tron_a.png` — một cây tán tròn, tán Ø 2,4 m, cao 2,8 m; 4–5 chùm lá to, ba tầng sắc
  (vàng xanh / xanh lá / xanh lam đậm) như mục Phong cách.
- [x] `bui_a.png` — cụm cỏ 1,2 × 1,2 × 0,6 m, lá to, khối đặc, ngọn sáng gốc tối.

K0 làm lại theo bản 2: bản 1 có vách giống tường gạch và mảng rừng nguyên khối, không đạt phong cách mới.
K0 chỉnh tiếp theo ảnh Tốc Chiến người dùng gửi: cây và đá tự nhiên hơn, màu xanh rêu/xám đá trầm hơn; thay bốn ảnh K0 để đồng bộ.
K0 chỉnh theo ảnh trận mới: cây mẫu đổi sang dáng thông (giữ tên `cay_tron_a.png` để không đứt luồng thử hiện tại); viền đá và bờ sông chỉ còn khối đá lớn, không dựng cây/bụi trên đá để giảm số tam giác khi chuyển 3D. Cần chốt tên cây chính thức khi duyệt.
K0 tăng chiều cao riêng `vach_48` từ 1,2 m lên khoảng 1,5 m theo góp ý: mặt vách tới gần mặt tướng để nhận ra vật cản. `bo_song_48` vẫn là bờ thấp 0,5 m.
K0 giảm chỗ gồ trên `vach_48`: dùng dãy đá dài lặp lại làm phần lớn đường chặn, chỉ đặt ít cây riêng để tạo điểm nhấn; vết nứt/chuyển sắc nên nằm trong ảnh màu để tiết kiệm tam giác 3D.

## Đợt K1 — Dãy đá (game uốn cong theo đường)

| | Tên | Dài × dày × cao (m) | Mô tả |
|---|---|---|---|
| [ ] | `vach_24` | 2,4 × 1,2 × 1,2 | Như `vach_48`, ngắn |
| [ ] | `vach_48b` | 4,8 × 1,2 × 1,2 | Biến thể thứ hai của `vach_48` (khối đá khác chỗ) |
| [ ] | `vach_dau` | 1,2 × 1,2 × 1,2 | Đầu bo: **một đầu cắt phẳng** (nối dãy), **đầu kia bo tròn** như đầu nấm |
| [ ] | `bo_song_24` | 2,4 × 1,2 × 0,5 | Như `bo_song_48`, ngắn |
| [ ] | `bo_song_dau` | 1,2 × 1,2 × 0,5 | Đầu bờ sông bo tròn, thấp dần xuống đất (cạnh lối xuống sông) |
| [ ] | `rao_24` | 2,4 × 0,8 × 0,8 | Rào base: đá đẽo khối to mượt, viền vàng kim nhẹ trên đỉnh |
| [ ] | `rao_48` | 4,8 × 0,8 × 0,8 | Như trên, dài |
| [ ] | `rao_cot` | 0,9 × 0,9 × 1,3 | Cột rào vuông, chóp vàng kim |

## Đợt K2 — Cây (thả bên trong viền đá) và bụi

| | Tên | Cỡ | Mô tả |
|---|---|---|---|
| [ ] | `cay_tron_b` | tán Ø 2,0 m, cao 2,4 m | Tán tròn lệch, 3–4 chùm |
| [ ] | `cay_thong` | tán Ø 1,8 m, cao 3,2 m | Thông 3–4 tầng lá to, mỗi tầng một sắc |
| [ ] | `cay_thap` | Ø 2,4 m, cao 1,4 m | Cây bụi thấp tán rộng (đặt sát mép trong viền đá, không che tướng) |
| [ ] | `bui_b` | 1,8 × 1,2 × 0,5 m | Cụm cỏ thấp rộng |
| [ ] | `bui_c` | 1,0 × 1,0 × 0,7 m | Cụm cỏ cao thẳng |

## Đợt K3 — Fountain

| | Tên | Cỡ | Mô tả |
|---|---|---|---|
| [ ] | `fountain_set_blue` | Ø 12 m | Vòng rào đá thấp (cao 0,8 m, dày 0,8 m) quanh nền đá tròn; **một cổng hở 55°** phía trước; giữa là đài suối pha lê xanh `#3D8BFF` phát sáng; sát rào phía sau một **trụ bắn nhỏ** cao ~2,5 m, chóp pha lê xanh. Nhìn từ phía cổng. |
| [ ] | `fountain_set_red` | Ø 12 m | **Đính kèm bản xanh**, chỉ đổi pha lê và phần màu phe sang đỏ `#FF4D4D`, giữ nguyên hình |

## Ghi chú cho người ghép (không phải việc của Codex)

- 1 m = 100 đơn vị thế giới; lưới chuẩn 1,2 m; bán kính uốn nhỏ nhất ~3 m. Lane rộng 2,9 m.
- Tripo image-to-3D, giới hạn mặt: dãy 2,4 m ≤ 500, dãy 4,8 m ≤ 900, đầu / cột ≤ 300, cây 300–500,
  bụi 200–400, fountain 4.000–6.000.
- Dãy dài: co giãn không đều cho đúng kích thước chuẩn, uốn theo đường (thử K0 bản 1: nối liền, không giãn).
- Cây / bụi: thêm màu đỉnh theo độ cao và khe (tools/models/paint_vc.py) để tăng sáng tối.
- Fountain bắn theo STR-04 sẵn có; trụ trong bộ chỉ là hình. Shop vẫn là mô hình riêng theo `shops`.
- Ngoài mép map để trống / nền đơn giản (không rải núi, cây ngoài map).
