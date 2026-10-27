# Yêu cầu ảnh — Đồ họa map (bản 3)

Phiếu việc cho **Codex tạo ảnh tham chiếu**. Ảnh sau đó đưa vào Tripo (tạo 3D từ ảnh); gọi Tripo, giảm lưới,
tô màu và đưa vào game do người ghép (Claude) làm. Codex **chỉ làm ảnh**.

**Bản 3 (2026-10-27) thay bản 1–2.** Hướng mới, giống Liên Quân / Tốc Chiến:
- Map gồm **khối đá lớn** (mỗi khối một mô hình riêng, vẽ theo bản vẽ khối của map) + **bụi cỏ**, thỉnh
  thoảng **vài cây thông điểm xuyết** trên khối đá. Không có rừng cây.
- **Bờ sông** cũng là vài khối đá riêng theo dáng sông.
- **Rào base** và **rìa bản đồ** dùng **khối đá thẳng** ghép nối tiếp thẳng tắp.
- **Quan trọng nhất: mọi thứ cùng một bảng màu, cùng độ tươi** — đồ họa khớp nhau, không vật nào chói hơn.

Thứ tự: **S (bảng phong cách) → R (rào, rìa, bụi, cây) → B (khối đá, có bản vẽ riêng từng khối sau khi phác
xong map)**.

## Cách làm việc (bắt buộc)

1. Làm **theo đợt**. Xong mỗi đợt **DỪNG**, báo người dùng duyệt rồi mới làm đợt sau.
2. Từ đợt R trở đi, mỗi ảnh đính kèm **`art_inbox/07_kit/bang_phong_cach.png`** (đã duyệt) và giữ đúng
   bảng màu của nó. Ảnh chụp game tham khảo người dùng đưa chỉ lấy **tinh thần**, không chép vật thể.
3. Lưu `art_inbox/07_kit/<tên>.png`, đúng tên trong bảng. Không thêm `_v2`, `_final`; làm lại thì ghi đè.
4. Làm xong ảnh nào đánh dấu `[x]`. Làm lại thì ghi ngắn lý do.
5. Không sửa file nào ngoài `art_inbox/`.

## Phong cách và bảng màu

- **Ít khối, khối to**, mặt mượt, cạnh bo mềm. Không vân gạch, không đá vụn, không vết nứt nhỏ.
- **Khối đá chặn đường có hai tầng rõ ràng:** vách dưới cao, tầng trên là vài mỏm lớn gồ lệch; không để
  mặt phẳng rộng trên đỉnh khiến người chơi tưởng có thể blink lên đứng. Dùng ít mặt đá lớn để tiết kiệm tam giác.
- **Sáng tối vẽ sẵn, chuyển mềm:** mặt trên sáng ấm, xuống dưới tối lạnh dần; khe giữa khối tối; mép trên
  viền sáng nhẹ.
- **Màu dịu, không tươi gắt** (bản trước cây cỏ quá tươi, nhìn bết). Độ bão hòa vừa phải, các vật cùng tông.
- Bảng màu gợi ý (giữ gần, không bắt buộc đúng mã):

| Vật | Sáng | Tối |
|---|---|---|
| Nền cỏ | `#7E9A55` | `#55703A` |
| Đường đất | `#B09A72` | `#7E6A4C` |
| Đá | `#A7AEAC` (xám ấm hơi xanh) | `#4E5862` |
| Cỏ phủ đỉnh đá | `#88A257` | `#5A7438` |
| Bụi cỏ | `#86A35A` | `#33553A` |
| Cây thông | `#7E9C62` | `#2C4E44` |
| Nước | `#4FA3B5` | `#25667A` |

## Quy tắc ảnh vật thể (để Tripo dựng 3D đúng)

- **Một vật thể, nhìn trọn vẹn**, giữa khung, cách mép ≥ 8%, không vật thể phụ.
- **Góc 3/4 từ trên xuống** (~45°), lệch ~20° để thấy mặt trên, một mặt dài, một đầu.
- **Nền trắng trơn `#FFFFFF`**, không bóng đổ xuống nền, không mặt đất, **đáy phẳng**.
- Ánh sáng dịu từ trên–trái, không bóng gắt. **Tỉ lệ đúng như bảng** (kích thước thật trong game).

### Câu lệnh gốc (ghép trước mô tả từng ảnh vật thể)

```
Stylized hand-painted 3D game asset concept for a top-down mobile MOBA map (Wild Rift / Arena of Valor
feel), few large simple shapes, smooth broad surfaces, soft rounded edges, no small details, muted
harmonious colors matching the attached style board, painted soft gradient lighting: lighter warm top,
darker cool bottom, dark occlusion in gaps, single object fully visible and centered, 3/4 top-down view
at about 45 degrees, plain pure white background, no cast shadow, no ground, flat bottom, no text.
```

---

## Đợt S — Bảng phong cách (1 ảnh) — làm rồi DỪNG

- [x] `bang_phong_cach.png` — **một góc map nhìn từ camera game** (nghiêng ~46° từ trên xuống), vuông,
  không phải ảnh vật thể nền trắng. Gồm: nền cỏ có một lối đất; **một khối đá lớn** (cao hơn nhân vật,
  đỉnh phủ cỏ nhưng không phẳng trống, có hai mỏm đá lớn khác dáng nhô liền từ thân vách) và **2 cây thông**
  điểm trên đỉnh; cây là asset riêng, có thể thêm/bớt khi ghép map. Có **một vùng bụi cỏ**; một khúc **mép sông** có 1–2 khối đá bờ;
  một đoạn **rào đá thẳng**; một nhân vật nhỏ cao ~1,2 m để so tỉ lệ. Dùng đúng bảng màu trên, màu dịu,
  mọi vật hài hòa với nhau. Đây là ảnh neo cho mọi ảnh sau.

Đợt S đã duyệt hướng mỏm đá liền thân vách (phương án C); khi dựng 3D ưu tiên vài mặt lớn và đo số tam giác thực tế sau Tripo.

## Đợt R — Rào, rìa map, bụi, cây (vật thể nền trắng)

| | Tên | Dài × dày × cao (m) | Mô tả |
|---|---|---|---|
| [ ] | `rao_48` | 4,8 × 0,8 × 0,9 | Rào base: đá đẽo khối to mượt xếp thẳng, viền vàng kim nhẹ trên đỉnh. **Hai đầu cắt phẳng, mặt cắt giống nhau** (nối thẳng tắp) |
| [ ] | `rao_cot` | 0,9 × 0,9 × 1,4 | Cột rào vuông, chóp vàng kim (đặt ở đầu rào, cạnh cổng) |
| [ ] | `rim_48` | 4,8 × 2,4 × 2,5 | Rìa map: vách đá cao thẳng, đỉnh phủ cỏ. **Hai đầu cắt phẳng, mặt cắt giống nhau**. Mặt phía trong map đẹp, mặt sau đơn giản |
| [ ] | `rim_goc` | 2,4 × 2,4 × 2,5 | Góc vuông rìa map (chữ L), hai đầu cánh cắt phẳng khớp `rim_48` |
| [ ] | `bui_a` | 1,2 × 1,2 × 0,6 | Bụi cỏ: **ít lá, lá to bản** dày (8–12 lá), khối đặc; ngọn sáng gốc tối |
| [ ] | `bui_b` | 1,8 × 1,2 × 0,5 | Bụi cỏ thấp rộng, cùng kiểu lá |
| [ ] | `tile_co` | ô 1024 px ≈ 4 × 4 m | **Ảnh nền lặp** (không phải vật thể): cỏ nhìn thẳng từ trên xuống, giống nền cỏ trong bảng phong cách, **lặp liền mép 4 cạnh**, không vật thể, không bóng |
| [ ] | `tile_dat` | ô 1024 px ≈ 4 × 4 m | Ảnh nền lặp: đất lối đi như bảng phong cách, lặp liền mép |
| [ ] | `tile_nuoc` | ô 1024 px ≈ 4 × 4 m | Ảnh nền lặp: mặt nước như bảng phong cách, lặp liền mép |
| [ ] | `cay_thong` | tán Ø 1,8, cao 3,0 | Thông 3–4 tầng lá to, mỗi tầng một sắc, màu dịu theo bảng |

## Đợt B — Khối đá (sau khi phác xong map)

Người ghép sẽ thêm ở đây **bản vẽ từng khối** (`art_inbox/07_kit/ban_ve/khoi_XX.png`: hình chiếu từ trên
xuống có thước mét, chiều cao, chỗ đặt cây thông). Mỗi khối vẽ một ảnh **góc 3/4** giữ đúng dáng hình chiếu.
Bờ sông cũng là các khối riêng trong đợt này.

## Ghi chú cho người ghép (không phải việc của Codex)

- 1 m = 100 đơn vị thế giới. Lane rộng 2,9 m. Vật cản của khối = hình chiếu chân mô hình thật (đo sau
  Tripo), map chỉnh theo khối; kiểm tra lại MAP-03 (lối hẹp) sau khi thay.
- Tripo: khối đá 3.000–5.000 mặt, texture 2048; rào / rìa ≤ 900; cột ≤ 300; bụi 200–400; thông 300–500.
- Fountain: làm sau, phiếu riêng (bắn theo STR-04 sẵn có). Ngoài rìa map để trống.
- Mảnh K0 bản 2 (`vach_48`, `bo_song_48`, `cay_tron_a`, `bui_a` trong `art_inbox/3d/kit/`) chỉ để thử.
