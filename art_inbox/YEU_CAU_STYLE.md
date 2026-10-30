# Yêu cầu ảnh — Phong cách đồ họa mới (bước 1)

Phiếu việc cho **Codex tạo ảnh nền (texture)**. Người ghép (Claude) dựng mô hình cây / đá / tường bằng Blender
(màu và sáng tối vẽ sẵn vào mô hình) rồi dán ảnh của phiếu này lên mặt đất, lane, tường thành, mặt đá.
Codex **chỉ làm ảnh**. Không sửa file nào ngoài `art_inbox/`.

**Ảnh đích (đã duyệt):** `art_inbox/08_style/concept.webp` — đính kèm khi tạo mọi ảnh và giữ đúng tinh thần:
vẽ tay kiểu tranh, màu dịu, cỏ ô-liu có mảng xanh lam đậm, đường đất vàng nâu nhạt, đá xám lam, nước xanh lam
sẫm, điểm lá cam mùa thu. Camera cố định nhìn chéo từ trên xuống (khoảng 45°).

Phiếu này **thay hướng** của `YEU_CAU_KIT_MAP.md` (bản 3): không còn khối đá lớn Tripo cho từng khối map.

## Cách làm việc (bắt buộc)

1. Làm theo thứ tự trong bảng. Xong cả đợt T **DỪNG**, báo người dùng duyệt rồi mới làm tiếp.
2. Lưu `art_inbox/08_style/<tên>.png`, đúng tên. Làm lại thì ghi đè, không thêm `_v2`.
3. Làm xong ảnh nào đánh dấu `[x]`; làm lại thì ghi ngắn lý do.

## Yêu cầu kỹ thuật chung cho ảnh nền

- **Vuông 1024 × 1024, LẶP LIỀN MÉP (seamless) cả ngang lẫn dọc** — ghép 2 × 2 không thấy đường nối. Kiểm
  bằng cách ghép thử 3 × 3 trước khi nộp.
- **Nhìn thẳng từ trên xuống** (ảnh phẳng như bản đồ), **không phối cảnh, không bóng đổ theo hướng nắng**,
  không vật thể nổi khối (không đá to, không cây, không người). Chỉ vân bề mặt.
- **Không lặp mẫu dễ thấy:** không có một đốm hay một hòn đá nổi bật lặp đi lặp lại.
- **Độ tương phản vừa phải** (sẽ được trộn và nhân màu trong game). Không chữ, không viền.

## Đợt T — ảnh nền

| Xong | Tên | Nội dung | Ảnh 1024 phủ |
|---|---|---|---|
| [x] | `grass` | Cỏ nền: ô-liu `#6E7C50`, mảng đậm xanh lam `#45584A`, nét cọ cỏ ngắn, vài đốm hoa / lá vàng nhỏ li ti | 7 m |
| [x] | `grass_dark` | Nền rừng dưới tán: cỏ tối xanh lam `#3E5048`, lá thông rụng, ít ánh sáng | 7 m |
| [x] | `dirt` | Đường đất / bãi đất: vàng nâu nhạt `#9C8A62`, vệt bánh xe mờ, sỏi nhỏ | 6 m |
| [x] | `pave` | Đá lát lane: phiến đá xám `#8A8A80` không đều, khe sẫm, rêu xanh trong khe | 5 m |
| [x] | `rock_face` | Mặt đá vách (dán lên khối đá chặn): đá xám lam `#7C8490` – `#5A6270`, vân nứt dọc vài đường, mảng đẽo phẳng | 3 m |
| [x] | `wall_face` | Mặt tường thành cổ: các lớp đá khối lớn xếp hàng ngang (mỗi viên ~1 × 0,6 m), mạch vữa sẫm, rêu ở mép dưới; **lặp liền mép theo chiều ngang** (chiều dọc cũng lặp) | 4 m |
| [x] | `riverbed` | Đáy sông nông: sỏi, đá cuội xanh lam sẫm `#2C4C58`, vài cọng rong | 6 m |

## Đợt T2 — vân tán lá (thêm sau vòng 2 cảnh mẫu) — **ĐÃ BỎ (D-182)**

Người dùng chơi thử: tán cây không vân (chỉ màu mô hình) gọn mắt hơn. Ảnh đã gỡ khỏi game, không làm lại.

Tán cây là mô hình low-poly đã tô màu sẵn; ảnh này chỉ dán lên để có **nét cọ lá** (game lấy sáng tối của ảnh,
giữ màu mô hình). Cùng yêu cầu kỹ thuật như đợt T (1024, lặp liền mép, nhìn thẳng, không bóng theo hướng).

| Xong | Tên | Nội dung | Ảnh 1024 phủ |
|---|---|---|---|
| [x] | `foliage_pine` | Lá kim thông vẽ tay: các cụm lá nhọn rủ xuống, xếp chồng như vảy, xanh lam đậm `#2E5454` – sáng `#5C7E60` | 2 m |
| [x] | `foliage_leaf` | Lá cây tán tròn vẽ tay: các chùm lá tròn nhỏ chồng lớp, ô-liu `#70864A` – sáng `#9AAE66` | 2 m |

## Đợt T3 — làm lại đường đất và đá tường / rào (D-182, sau chơi thử)

Người dùng chơi thử: **`pave` (đá lát lane), `rock_face`, `riverbed`, `grass` đạt** — giữ nguyên. Hai ảnh dưới
"lệch quẻ" so với `pave` và phải làm lại:

- `dirt` cũ: **cam quá đậm**, vệt chéo cùng một hướng lặp lại rõ, nhìn như cát sa mạc, không cùng họ với cỏ và
  đá lát.
- `wall_face` cũ: **gạch xanh xám lạnh xếp đều như gạch lát hiện đại**, mặt phẳng, không cùng họ với `pave`.

**Mẫu cần bám: `assets/textures/style/pave.png`** (đính kèm khi tạo, cùng `concept.webp`) — cùng nét cọ, cùng độ
tương phản, cùng tông ấm xám ô-liu, viên đá mép bo tròn, rêu xanh nhạt trong khe. Hai ảnh mới đặt cạnh `pave`
phải trông như cùng một bộ.

| Xong | Tên | Nội dung | Ảnh 1024 phủ |
|---|---|---|---|
| [x] | `dirt` | Đường đất nện trong rừng: be xám ấm `#A69676` – sẫm `#8C7C5E` (ngả về màu khe của `pave`, **không cam**), mặt đất phẳng mịn có mảng sáng tối loang **không theo hướng nào**, sỏi dẹt nhỏ li ti rải thưa, vài mảng cỏ khô nhỏ màu ô-liu nhạt. Không vệt bánh xe, không vệt chéo. Làm lại: bỏ cam / vệt chéo, đồng bộ nét cọ với `pave`. | 6 m |
| [x] | `wall_face` | Mặt tường thành / rào đá: **cùng loại đá với `pave`** (xám ấm `#8A8A80`, sáng `#A4A296`, tối `#6C6C64`) nhưng xếp thành hàng khối lớn **không đều** (cao 0,5–0,7 m, dài 0,8–1,6 m), mép bo tròn vẽ tay, mạch vữa sẫm ấm, rêu xanh nhạt ở mạch dưới. Mỗi hàng lệch nhau, không kẻ thẳng tắp như gạch. **Lặp liền mép cả ngang lẫn dọc**. Làm lại: bỏ lưới gạch lạnh đều, dùng đá bo tròn cùng họ `pave`. | 4 m |

Nộp xong `dirt` và `wall_face` thì **DỪNG**, báo người dùng.

## Đợt C — thẻ so màu (sau khi đợt T được duyệt)

| Xong | Tên | Nội dung |
|---|---|---|
| [ ] | `palette` | Một ảnh 1024 × 256: 12 ô màu chuẩn lấy từ concept (cỏ sáng / đậm, đất, đá lát, đá sáng / vừa / tối, thông sáng / tối, cây tròn, lá cam, nước nông / sâu) kèm mã hex dưới mỗi ô |
