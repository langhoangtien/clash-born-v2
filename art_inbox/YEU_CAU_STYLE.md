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

## Đợt T4 — nền lane "đất nện có phiến đá" (D-190, người dùng gửi ảnh mẫu)

**Ảnh mẫu:** ảnh người dùng gửi (đường đất vàng nâu, các cụm phiến đá xám lớn, cỏ hai bên) — người dùng đính kèm
khi giao phiếu. Trong game đang dùng bản Claude vẽ bằng code: `assets/textures/style/dirt_stones.png` (đúng bố cục
và tỉ lệ mong muốn, nhưng mảng màu phẳng như vector). Codex vẽ lại **cùng bố cục đó nhưng chất vẽ tay như ảnh mẫu**.

| Xong | Tên | Nội dung | Ảnh 1024 phủ |
|---|---|---|---|
| [x] | `dirt_stones` | Đất nện be vàng dịu loang mềm, vài vết mòn; trên đó **3–5 cụm phiến đá xám-be nhạt**, phiến lớn và vừa là chính, rất ít mảnh nhỏ; mặt đá phẳng gần như chìm ngang mặt đất, viền mảnh mềm, không bóng khối; rêu / cỏ chỉ lấm tấm trong vài khe. Đá chiếm **khoảng 25–30%**, phần còn lại là khoảng đất trống rộng. Làm lại: bám ảnh concept người dùng gửi, giảm mật độ và độ nổi của đá. | 7 m |

Bắt buộc (ngoài yêu cầu chung ở trên):
- **NHÌN THẲNG TỪ TRÊN XUỐNG** như bản đồ: phiến đá không có mặt bên, không phối cảnh, không bóng đổ dài.
  (Ảnh mẫu vẽ góc nghiêng — chỉ lấy chất vẽ và màu, không lấy góc nhìn.)
- **Lặp liền mép** cả ngang và dọc: cụm đá ở mép phải nối tiếp với mép trái, ghép 3 × 3 không thấy đường nối,
  không thấy một cụm nổi bật lặp đi lặp lại.
- Không cỏ dày, không cây, không vật nổi khối. Cỏ hai bên đường game tự trộn.
- Nộp `art_inbox/08_style/dirt_stones.png` (1024 × 1024) rồi **DỪNG**, báo người dùng.

## Đợt T5 — tường thành rìa map liền mép lane (D-195)

Người dùng bỏ "rào thấp + khoảng trống + tường thành" ở rìa map (người chơi tưởng blink vào khe được): thay bằng
**một bức tường thành cao liền sát mép lane / rìa map** (ảnh mẫu: tường đá xám khối lớn chạy dọc lane). Claude dựng
khối tường bằng Blender (hình hộp có gờ, trụ ốp), Codex chỉ làm **ảnh vân dán lên mặt tường**.

| Xong | Tên file (lưu `art_inbox/08_style/`) | Nội dung | Ảnh 1024 phủ |
|---|---|---|---|
| [x] | `castle_wall_face.png` | **Mặt đứng** tường thành nhìn thẳng chính diện (không phối cảnh): các khối đá lớn xếp hàng ngang, mép bo nhẹ vẽ tay, mạch sẫm. **Lặp liền mép ngang và dọc.** Bản người dùng chọn theo concept 1 có tông xám lam; có thể cần chỉnh sang xám ấm khi nhập. | 4 m |
| [x] | `castle_wall_top.png` | **Mặt đỉnh** tường nhìn thẳng từ trên xuống: phiến đá lát lớn cùng họ với mặt đứng, mép sáng hơn, vài vết nứt. **Lặp liền mép**; khi ghép 3 × 3 vết nứt còn nhận ra nhịp lặp. | 4 m |

Yêu cầu chung như các đợt trên (1024 × 1024, vẽ tay đồng bộ với `dirt_stones`, không chữ). Tông màu phải cùng họ
đá với đá rừng và phiến đá lane (`assets/textures/style/dirt_stones.png`, `rock_face.png`) — Claude sẽ chạy
`tools/textures/recolor.py` chỉnh lại nếu lệch, nhưng càng gần càng tốt. Nộp cả hai file rồi **DỪNG**, báo người dùng.

## Đợt T6 — vực ngoài rìa map kiểu Liên Quân (D-197, thử nhiều kiểu)

Người dùng gửi ảnh mẫu: lan can đá thấp dọc mép lane, phía sau là **vách núi đổ xuống vực sâu mờ sương**. Claude
dựng lan can + khối vách + đáy vực; Codex làm ảnh dán. Camera game cố định một hướng nên **mỗi loại chỉ một ảnh**,
không cần ảnh theo hướng. Đáy vực thử **3 kiểu** để người dùng chọn trong game.

| Xong | Tên file (lưu `art_inbox/08_style/`) | Nội dung |
|---|---|---|
| [ ] | `cliff_face.png` | **Mặt vách núi đứng** nhìn thẳng chính diện: đá xám lam vẽ tay thành các mảng dọc lớn, gờ ngang lác đác có rêu / cỏ nhỏ, càng xuống dưới càng tối và xanh. **Lặp liền mép ngang**, dọc cũng lặp (vách sâu ~20 m, ảnh phủ 8 m) |
| [ ] | `abyss_floor_a.png` | Kiểu A — **hẻm núi sương** (giống ảnh mẫu): nhìn từ trên xuống thấy đỉnh vách đá nhỏ xa, rừng thông li ti, sương xanh lam phủ loang |
| [ ] | `abyss_floor_b.png` | Kiểu B — **rừng thông sâu**: tán rừng thông xanh đậm dày đặc nhìn từ trên xuống, vài mảng sương mỏng |
| [ ] | `abyss_floor_c.png` | Kiểu C — **biển mây**: mây / sương trắng xanh cuộn, lấp ló vài đỉnh núi đá tối |

Yêu cầu chung: 1024 × 1024, vẽ tay đồng bộ phong cách concept, **nhìn thẳng từ trên xuống** với ảnh đáy vực (không
đường chân trời, không phối cảnh), **lặp liền mép** cả ngang và dọc, tông lạnh xanh lam để tách khỏi lane đất vàng.
Không chữ. Nộp đủ 4 file rồi **DỪNG**, báo người dùng.

**Bản thử để xem trong game:** đã tạo đủ bốn ảnh, chưa đánh dấu duyệt. Khi ghép 3 × 3 còn thấy nhịp lặp;
ba ảnh đáy vực vẫn hơi có cảm giác nhìn xiên, đặc biệt ở cây và đá. Kiểu A có các cụm đá rải đều hơn ảnh mẫu;
cần xem sau khi ghép với mô hình vách và sương trước khi quyết định làm lại.

## Đợt T7 — thêm 2 kiểu đáy vực (D-201)

Người dùng chọn kiểu A (`abyss_floor_a`, hẻm núi sương) là đẹp nhất nhưng **hơi lệch so với đồ họa trong game**
(game: mảng màu vẽ tay mềm, ít chi tiết nhỏ, tông xanh lam xám dịu như mặt nước sông và vách `cliff_face`).
Làm thêm 2 biến thể **dựa trên A** để so trong game. Cùng yêu cầu kỹ thuật đợt T6 (1024 × 1024, nhìn thẳng từ
trên xuống, lặp liền mép ngang + dọc, không chữ, không đường chân trời).

| Xong | Tên file (lưu `art_inbox/08_style/`) | Nội dung |
|---|---|---|
| [x] | `abyss_floor_d.png` | Kiểu A **giản lược**: cùng bố cục hẻm núi sương nhưng ít chi tiết hơn — đỉnh vách đá thành mảng lớn bo tròn (ít, to), cụm thông gom thành vài mảng xanh đậm, sương loang rộng; tông xanh lam xám dịu `#3E5F7A` – `#5E7F96`, đá đỉnh vách `#8A949C`. Nét vẽ mềm như `dirt_stones` / `cliff_face`, không nét mảnh li ti |
| [x] | `abyss_floor_e.png` | Kiểu A **có chiều sâu**: các bậc vách đá xếp tầng (gần sáng hơn, xa chìm sương đậm hơn), dòng nước / thác nhỏ mờ chảy giữa các bậc, vài cụm thông; tông như D nhưng tương phản sáng tối rõ hơn giữa đỉnh vách và đáy sương |

Nộp đủ 2 file, **commit và push lên nhánh `thu-asset-tu-lam`** (repo `langhoangtien/clash-born-v2`), đánh dấu
`[x]` trong bảng, rồi **DỪNG** báo người dùng.

Đã nộp hai bản để thử trong game: khi ghép 3 × 3 vẫn nhận ra nhịp lặp các cụm, một số mặt đá / cây còn hơi
nhìn xiên; cần đánh giá ở góc camera game trước khi duyệt kỹ thuật.

## Đợt C — thẻ so màu (sau khi đợt T được duyệt)

| Xong | Tên | Nội dung |
|---|---|---|
| [ ] | `palette` | Một ảnh 1024 × 256: 12 ô màu chuẩn lấy từ concept (cỏ sáng / đậm, đất, đá lát, đá sáng / vừa / tối, thông sáng / tối, cây tròn, lá cam, nước nông / sâu) kèm mã hex dưới mỗi ô |

## Đợt T8 — concept trụ, lính, quái rừng để dựng bằng Tripo (D-204)

Mục tiêu: **concept để người dùng duyệt**, sau đó đưa vào Tripo (ảnh → 3D) rồi gắn xương (Mixamo cho dáng người,
Tripo rig cho 4 chân). Phong cách giống ảnh mẫu quái rừng người dùng đã gửi (`art_inbox/08_style/ref/jungle_concept.webp`):
**low-poly mặt phẳng, khối to gọn, mảng màu phẳng**, tông ấm như map. Thiết kế **đơn giản** — ít chi tiết nhỏ thì
Tripo dựng ít tam giác mà vẫn đẹp.

### Quy tắc vẽ để Tripo dựng tốt (bắt buộc)

1. **Một nhân vật một ảnh**, toàn thân, ở giữa khung, **nền xám nhạt trơn**. KHÔNG đĩa đất / cỏ / đá dưới chân,
   KHÔNG bóng đổ, KHÔNG sương, KHÔNG chữ.
2. **Tư thế trung tính**: dáng người đứng **A-pose** (tay dang chéo ~45°, chân hơi tách, nhìn thẳng). Thú 4 chân
   đứng thẳng cả 4 chân, đầu nhìn trước, miệng **ngậm hoặc hé**, đuôi duỗi ra sau. Không gầm, không chồm, không vũ
   khí vung lên (hoạt ảnh sẽ làm sau).
3. **Khối to, ít phần mảnh**: không ngón tay rời, không lông / tua / dây mảnh, không áo choàng nhiều lá rời, không
   bộ phận bay lơ lửng. Vũ khí / gậy dày, cầm sát người.
4. **Không hiệu ứng phát sáng tỏa ra** (quầng sáng, hạt, lửa). Mắt / rune sáng chỉ là **mảng màu cam phẳng**.
5. Mỗi nhân vật nộp **3 ảnh cùng kiểu**: chính diện (`_front`), nghiêng phải (`_side`), sau lưng (`_back`).
6. Lính và trụ có **phe xanh / đỏ**: màu phe là **mảng lớn rõ** (vải, cờ, mũ, mái…) để đổi màu dễ; chỉ vẽ bản
   **xanh**, bản đỏ game tự đổi màu.
7. Ảnh 1024 × 1024, PNG.

### Danh sách (lưu `art_inbox/09_units/`)

| Xong | Tên file (thêm `_front/_side/_back`) | Nội dung |
|---|---|---|
| [x] | `neutral_wolf` | Sói xám (trại nhỏ), giống ảnh mẫu nhưng đứng thẳng 4 chân, miệng ngậm |
| [x] | `neutral_buffalo` | Golem đá rêu (trại vừa), giống ảnh mẫu: thân và tay là vài khối đá lớn, rêu là mảng xanh trên đỉnh khối, rune cam ở ngực. **A-pose** (xem đợt T8b) |
| [x] | `neutral_bear` | Gấu nâu vằn cam (trại lớn), giống ảnh mẫu, đứng 4 chân, miệng ngậm |
| [x] | `neutral_shaman` | Pháp sư rừng (trại lớn) — **đơn giản hơn ảnh mẫu**: áo choàng lá là **một khối liền** có vài nếp lớn (không lá rời), sừng gắn liền mũ, gậy gỗ dày có viên đá cam. A-pose, gậy cầm tay phải thẳng đứng sát người |
| [x] | `creep_melee` | Lính cận chiến: dáng người thấp đậm, giáp da + mũ sắt đơn giản, khiên tròn + kiếm ngắn dày; mảng màu phe ở áo và khiên |
| [x] | `creep_ranged` | Lính đánh xa: áo choàng ngắn có mũ trùm, **gậy phép ngắn** (không cung / nỏ); mảng màu phe ở áo và đá đầu gậy |
| [x] | `creep_siege` | Xe công thành nhỏ: khung gỗ khối vuông, 4 bánh tròn dày, máy bắn đá đơn giản; mảng màu phe ở cờ / tấm che |
| [x] | `tower` | Trụ phòng thủ: **đế đá lớn + thân trụ đá thon + đỉnh có viên tinh thể / ngọn lửa phe**, ít chi tiết, cao gấp ~3 lần lính. Chỉ cần một mẫu (bậc 1–4 game đổi cỡ / phụ kiện sau). Không cần ảnh `_back` |
| [x] | `core` | Nhà chính: khối đá tròn rộng có tinh thể lớn ở giữa, màu phe ở tinh thể và cờ. Không cần ảnh `_back` |

Làm **trước 2 mẫu thử**: `neutral_wolf` và `creep_melee` (đủ 3 hướng), **commit và push lên nhánh
`thu-asset-tu-lam`** (repo `langhoangtien/clash-born-v2`), đánh dấu `[x]`, rồi **DỪNG** báo người dùng. Người dùng
duyệt hai mẫu này xong mới làm các mục còn lại.

Làm lại `creep_melee` (3 hướng): dang hai tay A-pose ~45°, cầm khiên và kiếm ra xa thân để không che ngực,
giữ nguyên thiết kế cũ.

## Đợt T8b — làm tiếp các mục còn lại (2 mẫu thử đã duyệt, 2026-11-02)

Người dùng đã duyệt `neutral_wolf` và `creep_melee`; cả hai đã dựng Tripo và đưa vào game (D-205, D-207). Làm tiếp
các mục `[ ]` trong danh sách T8, giữ nguyên quy tắc vẽ ở trên, **thêm các quy tắc sau** rút ra từ 2 mẫu thử:

### Quy tắc thêm (Tripo dựng thừa bộ phận khi các hướng vẽ không khớp nhau)

Sói: chân trước phải trong ảnh `_side` bị Tripo dựng thành một **khối thừa như bàn chân co lên**. Lính: Tripo dựng
**thêm một thanh kiếm thứ hai** lơ lửng. Nguyên nhân: các hướng vẽ không khớp, hoặc một bộ phận bị che hay chồng lên
bộ phận khác. Vì vậy:

1. **Ba ảnh phải là cùng một tư thế**, chỉ xoay camera. Vị trí tay, chân, vũ khí, khiên **y hệt nhau** giữa
   `_front`, `_side`, `_back` (ảnh `_back` là đúng mặt sau của `_front`: kiếm ở tay phải thì trong ảnh sau lưng kiếm
   nằm bên trái ảnh).
2. **Không bộ phận nào che hay chạm bộ phận khác** trong bất kỳ hướng nào: bốn chân thú tách rõ, nhìn ngang thấy
   đủ 4 chân (chân xa hơi lệch ra sau / trước, không trùng khít chân gần); vũ khí / khiên cách thân và cách chân
   một khoảng trống.
3. Vũ khí, gậy **dính liền bàn tay** (nắm chặt), không thả lơ lửng.
4. Dáng người phải là **A-pose thật** (để gắn xương Mixamo tự động): tay dang ~45°, khuỷu thẳng, chân tách bằng vai,
   bàn tay không chạm hông.

### Thứ tự làm và ghi chú từng mục

| Thứ tự | Tên file | Ghi chú thêm |
|---|---|---|
| 1 | `creep_ranged` | **Gậy phép + mũ trùm, không cung** (dây cung mảnh Tripo không dựng được). Gậy ngắn dày, đầu gậy là viên đá **màu phe** (mảng xanh lớn). Áo choàng ngắn liền thân, mũ trùm liền áo. Dáng thấp đậm như `creep_melee` để cùng bộ. A-pose, gậy cầm tay phải dựng xiên ra ngoài, không chạm người |
| 2 | `neutral_buffalo` | Golem đá **2 chân dáng người** (gắn xương Mixamo): thân, đầu, tay, chân là các khối đá to rõ khớp vai / khuỷu / hông / gối; **A-pose**, tay dang 45°, không buông xuôi sát thân (sửa lại ghi chú T8 cũ). Rêu xanh trên đỉnh khối, rune cam ở ngực |
| 3 | `creep_siege` | Như T8 (không cần A-pose, không gắn xương người) |
| 4 | `tower` | Như T8 |
| 5 | `core` | Như T8 |
| 6 | `neutral_bear` | Như T8 + quy tắc thêm 2 (4 chân tách rõ) |
| 7 | `neutral_shaman` | Như T8 + A-pose thật, gậy nắm chặt tay phải, xiên ra ngoài |

Làm **từng cặp** (1 + 2 trước), commit và push lên nhánh `thu-asset-tu-lam`, đánh dấu `[x]` trong bảng T8, rồi
**DỪNG** báo người dùng duyệt trước khi làm cặp tiếp theo.

## Đợt T8c — vẽ lại golem `neutral_buffalo` theo ảnh mẫu (2026-11-02)

Bản T8b **không đạt**: thành người máy đá thon, tay nhỏ, màu hồng be — không giống golem người dùng gửi. Lỗi do phiếu
T8b ghi "dáng người, A-pose tay dang 45°". **Bám sát ảnh mẫu `art_inbox/08_style/ref/golem_ref.png`** (cắt từ
`jungle_concept.webp`), chỉ đổi tư thế cho đủ đứng thẳng để gắn xương:

- **Tỉ lệ khỉ đột**: hai **cẳng tay + nắm đấm là khối đá to nhất** (mỗi nắm đấm to gấp đôi đầu), tay dài buông tới
  ngang gối; **vai là hai tảng đá khổng lồ** nhô cao hơn đầu; **đầu nhỏ thụt giữa hai vai, không cổ**, mắt cam,
  hàm khối vuông; ngực một khối lớn có rune cam xoắn; **chân ngắn, mập**, đứng rộng.
- **Màu**: đá **xám** (xám trung tính hơi lạnh như ảnh mẫu), **không** hồng / be; rêu vàng xanh phủ đỉnh các tảng
  (vai, đầu, cẳng tay).
- **Tư thế để gắn xương**: đứng thẳng (hơi gù được), **hai tay buông dang ra ngoài ~20–30°**, có **khe hở rõ** giữa
  tay với thân và với chân; nắm đấm **ngang gối, không chạm đất**; miệng ngậm. Không nghiêng người, không vung tay.
- Ba ảnh `_front`, `_side`, `_back` cùng tư thế (quy tắc T8b), nền xám nhạt trơn, không đĩa đất.

Làm xong golem thì commit + push nhánh `thu-asset-tu-lam`, rồi **DỪNG** báo người dùng duyệt.

Đã làm lại đủ 3 hướng: thay dáng người máy đá thon, màu be bằng tỉ lệ khỉ đột và đá xám theo `golem_ref.png`.

## Đợt T8d — gấu + pháp sư rừng (golem T8c đã duyệt, 2026-11-02)

Golem T8c, lính xa T8b đã dựng 3D và vào game (D-211, D-213). Quy trình bên mình giờ là: ảnh của bạn → Tripo (chỉ dùng
ảnh **trước + sau**, ảnh nghiêng chỉ để tham khảo) → afk.ai tự gắn xương + hoạt ảnh. Vì vậy **ảnh `_front` và `_back`
quan trọng nhất**: phải đúng cùng một tư thế, mặt sau đúng là mặt sau của mặt trước.

Ảnh mẫu đã cắt sẵn từ concept người dùng: `art_inbox/08_style/ref/bear_ref.png`, `shaman_ref.png`.
**Bám sát dáng và màu ảnh mẫu** (đừng "người hóa" hay làm gọn đi — lỗi golem T8b), chỉ đổi tư thế cho trung tính:

| Thứ tự | Tên file | Ghi chú |
|---|---|---|
| 1 | `neutral_bear` | Gấu nâu vằn cam như ảnh mẫu: thân khối to tròn, vai gù, mảng ngực be, vằn cam lớn trên lưng và chân trước, móng be to. **Đứng 4 chân** (afk.ai dùng bộ xương thú 4 chân): 4 chân thẳng, tách rõ, nhìn từ trước và sau thấy đủ khe giữa các chân; **miệng ngậm** (không gầm), mắt cam; tai tròn nhỏ. Không nhổm, không giơ chân |
| 2 | `neutral_shaman` | Pháp sư rừng như ảnh mẫu: áo choàng lá xanh trùm đầu, mặt tối mắt cam, hai sừng ngà, yếm be có hình thoi cam, gậy gỗ có tinh thể cam. Để gắn xương người: **A-pose** (tay dang ~45°, có khe với thân), **áo choàng dài tới gối** để thấy **hai chân tách nhau** (afk.ai cần chân); sừng gắn liền mũ trùm; gậy nắm chặt tay phải, dựng xiên ra ngoài, không chạm người và không chạm đất; lá áo là vài mảng lớn liền khối, không lá rời |

Làm xong cả hai thì commit + push nhánh `thu-asset-tu-lam`, đánh dấu `[x]` trong bảng T8, rồi **DỪNG** báo người dùng.
Sau đó (đợt sau, chờ phiếu): `creep_siege`, `tower`, `core`.

## Đợt T8e — xe công thành, trụ, nhà chính (gấu + pháp sư T8d đã duyệt, 2026-11-02)

Gấu, pháp sư đã dựng 3D và vào game (D-215) — cả bộ quái rừng và 2 loại lính đã xong. Còn 3 mục cuối của T8.
Giữ mọi quy tắc T8 / T8b. Nhắc lại điều quan trọng nhất: **ảnh `_front` và `_back` phải đúng cùng một vật**, mặt sau
đúng là mặt sau của mặt trước; ảnh `_side` cũng phải khớp hai ảnh kia (Tripo dùng ảnh nghiêng để lấy bề dày — vẽ lệch
là Tripo dựng thừa bộ phận).

Màu phe: chỉ vẽ bản **xanh** (`#3D8BFF` hoặc xanh dương đậm như `creep_melee`), màu phe là **mảng lớn liền**, các phần
khác **không dùng màu xanh dương / xanh ngọc** (game đổi mọi điểm ảnh xanh dương sang đỏ cho phe kia).

| Thứ tự | Tên file | Ghi chú |
|---|---|---|
| 1 | `creep_siege` | Xe công thành nhỏ cùng bộ với hai lính (gỗ nâu khối to, viền sắt xám): khung gỗ vuông thấp, **4 bánh tròn dày tách rõ khỏi thân** (nhìn trước / sau / nghiêng đều thấy khe), cần máy bắn đá **dày, ngắn** dựng nghiêng ra sau, gầu đá ở đầu cần; tấm chắn trước và một lá cờ **màu phe** (cờ là tấm dày, không phấp phới mảnh). Không dây thừng, không bánh răng nhỏ. Chiều cao ~1,3 lần lính |
| 2 | `tower` | Trụ phòng thủ như T8: **đế đá lớn + thân trụ đá thon + đỉnh có viên tinh thể màu phe** (tinh thể to, mảng màu phe lớn), ít chi tiết, cao ~3 lần lính, đá xám ấm như golem. Không cần ảnh `_back` (trụ gần đối xứng); `_side` vẫn cần |
| 3 | `core` | Nhà chính như T8: khối đá tròn rộng, tinh thể lớn màu phe ở giữa, vài cờ / mái màu phe; to hơn trụ, thấp và rộng. Không cần ảnh `_back` |

Làm từng mục, commit + push nhánh `thu-asset-tu-lam`, đánh dấu `[x]` trong bảng T8; xong cả ba thì **DỪNG** báo người dùng.

## Đợt T8f — vẽ lại trụ + xe công thành theo concept người dùng (2026-11-03)

Bản T8e (`creep_siege`, `tower`, `core`) **không đạt**: quá đơn giản, thiếu chất (trụ như quân cờ, nhà chính là đống
đá, xe trơn). Người dùng đã có concept — **bám sát ảnh mẫu**, chỉ chuyển sang dạng ảnh dựng 3D (một vật một ảnh, nền
xám nhạt trơn, không cỏ / đá / bóng / chữ / khung):

- `art_inbox/08_style/ref/tower_ref.png` — trụ (ảnh mẫu có 4 cấp; chỉ cần 2 mẫu, xem bảng).
- `art_inbox/08_style/ref/siege_ref.png` — xe công thành (có sẵn các hướng trước / sau / nghiêng — vẽ lại đúng các hướng đó).

Phong cách chung của hai ảnh mẫu: đá xám ấm khối vát, **viền vàng đồng**, mảng **xanh dương phe** lớn (băng rôn, tấm
chắn), tinh thể xanh. Giữ đúng như vậy, chỉ sửa cho Tripo dựng được:

1. **Không quầng sáng / tia / vòng phát sáng / hạt** quanh tinh thể (ảnh mẫu có — bỏ đi). Tinh thể là khối xanh phẳng,
   có thể sáng hơn mảng xanh khác một chút.
2. Màu xanh dương **chỉ** ở phần màu phe (băng rôn, tấm chắn, tinh thể); viền vàng, đá xám, gỗ nâu giữ nguyên (game
   đổi xanh dương → đỏ cho phe kia, mọi chỗ xanh khác cũng sẽ bị đổi).
3. Chi tiết nhỏ (hình tháp trắng trên cờ, đinh, vân gỗ) vẽ phẳng lên mặt, **không** làm khối nổi riêng.
4. Ba hướng cùng một vật, khớp nhau tuyệt đối (quy tắc T8b).

| Thứ tự | Tên file | Ghi chú |
|---|---|---|
| 1 | `tower` + `tower_core` | **Hai mẫu** (người dùng chốt 2026-11-03): `tower` dùng chung cho trụ **cấp 1, 2, 3** (game chỉnh độ to từng cấp) — vẽ theo trụ cấp 2–3 trong ảnh mẫu: thân đá, viền vàng, 2 băng rôn màu phe hai bên thân, vương miện gai vàng ôm tinh thể trên đỉnh. `tower_core` cho trụ **cấp 4** canh nhà chính: **cùng thiết kế** `tower` nhưng bệ đế rộng hơn có **4 cột đá nhỏ** quanh chân, tinh thể lớn hơn, **vòng vàng lớn** quanh đỉnh (khối thật, không phải vòng sáng). Mỗi mẫu `_front` + `_side` (gần đối xứng, không cần `_back`). Đế là bệ đá tròn, không kèm sàn lát / bậc thềm rộng xung quanh |
| 2 | `creep_siege` | Xe máy bắn đá như ảnh mẫu: thân gỗ, khung đá xám viền vàng, 4 bánh đá xám có đĩa vàng-xanh giữa bánh, cần gỗ dài với gầu đá chứa viên đá tinh thể, tấm chắn trước + băng rôn bên **màu phe**. `_front`, `_side`, `_back` **đúng tư thế nghỉ** (cần hạ, như các hướng trong ảnh mẫu — không vẽ cảnh đang bắn). Dây buộc cần vẽ thành **đai dày** liền khối. Thêm một ảnh `creep_siege_projectile.png`: viên đá tinh thể (như ô Projectile của ảnh mẫu) |

Nhà chính (`core`) và fountain **chưa làm**: concept người dùng (`base_ref.png`, `fountain_ref.png`) nhiều chi tiết rời
quá cho Tripo, chờ người dùng chốt bản giản lược.

Xong cả hai mục thì commit + push nhánh `thu-asset-tu-lam`, rồi **DỪNG** báo người dùng.

Đã nộp T8f: thay ảnh `tower` và `creep_siege` theo concept, thêm `tower_core` và
`creep_siege_projectile`; `core` và fountain giữ nguyên, chờ phiếu giản lược.

## Đợt T8g — nhà chính + fountain bản giản lược (trụ, xe T8f đã duyệt và vào game, 2026-11-03)

Trụ, xe công thành T8f đã dựng 3D và vào game (D-218) — rất tốt vì bám sát ảnh mẫu. Đợt này làm nốt **nhà chính** và
**fountain**, cùng phong cách (đá xám ấm khối vát, viền vàng đồng, mảng xanh phe lớn, tinh thể xanh). Ảnh mẫu của người
dùng: `art_inbox/08_style/ref/base_ref.png`, `fountain_ref.png` — **giữ phong cách và tinh thần**, nhưng **giản lược
mạnh** vì ảnh mẫu có quá nhiều mảnh rời nhỏ (Tripo sẽ dính hoặc dựng thừa). Quy tắc T8b / T8f vẫn áp dụng (không quầng
sáng / hạt / nước chảy; xanh dương chỉ ở phần màu phe; chi tiết nhỏ vẽ phẳng lên mặt; các hướng khớp nhau).

| Thứ tự | Tên file | Nội dung |
|---|---|---|
| 1 | `core` | Nhà chính: **tinh thể lớn màu phe** dựng giữa trên **bệ đá tròn 2–3 bậc** viền vàng; quanh bệ **4 cột đá thấp**, mỗi cột treo **một băng rôn màu phe** (tấm dày, liền cột). **Bỏ** các gai cong lớn, vòng gai, các mảnh rời quanh tinh thể. Thấp, rộng, to hơn trụ cấp 4 rõ rệt (bề ngang ~2 lần trụ). Ảnh `_front` + `_side` (gần đối xứng) |
| 2 | `fountain` | Fountain hồi máu: **bỏ tượng thiên thần**. **Bồn đá tròn 2 tầng** viền vàng; giữa bồn một **trụ tinh thể thấp màu phe** (khối liền, không tia nước); **mặt nước là một mảng xanh nhạt phẳng** trong lòng bồn; hai bên có **2 cột băng rôn màu phe**. Bậc thềm đá thấp một phía (phía nhà chính). Ảnh `_front` + `_side` + `_back` |

Xong cả hai thì commit + push nhánh `thu-asset-tu-lam`, rồi **DỪNG** báo người dùng.

Đã nộp T8g: vẽ lại `core` bản giản lược (`_front`, `_side`) và thêm `fountain`
(`_front`, `_side`, `_back`) theo hai ảnh mẫu.

## Đợt T8h — xe pháo thay máy bắn đá (nhà chính + fountain T8g đã duyệt, 2026-11-03)

Nhà chính, fountain T8g đã vào game (D-221). Người dùng đổi xe công thành từ **máy bắn đá** sang **xe pháo** (kiểu
Liên Quân) theo concept `art_inbox/08_style/ref/cannon_ref.png`. Bám phong cách và bố cục ảnh mẫu (thân gỗ, khung đá
viền vàng, nòng pháo đá xám vành vàng, khối tinh thể năng lượng phía sau nòng, tấm chắn màu phe phía trước, 4 bánh đá
có viên kim cương), nhưng **giản lược** để Tripo dựng sạch và bên mình gắn xương làm hoạt ảnh được:

1. **Nòng pháo là một khối riêng, rõ ràng**: ống tròn dày, ngắn, thẳng, chĩa **ra trước, hơi ngóc lên ~15°**, gắn trên
   một **trục ngang** kẹp giữa hai má đá ở hai bên. Giữa nòng và thân xe có **khe hở nhìn thấy được** từ hướng nghiêng
   (để nòng giật lùi khi bắn). Miệng nòng vẽ **đĩa tối phẳng** ở đầu nòng — **không** khoét lỗ sâu.
2. **Khối tinh thể sau nòng** là khối đặc **gắn liền thân xe** (bệ vàng ôm tinh thể), không lơ lửng, không lồng vào nòng.
3. **Bốn bánh tách rõ khỏi thân**: đĩa đá dày, có khe giữa bánh và thùng xe nhìn từ trước / sau / nghiêng; viên kim
   cương giữa bánh **vẽ phẳng** lên mặt bánh (không nổi khối).
4. **Tấm chắn màu phe** phía trước là **tấm dày liền thân** (bản trước Tripo làm mất tấm mỏng); hình đinh ba trắng vẽ
   phẳng. Bỏ các dải băng rôn mỏng hai bên (hoặc vẽ thành mảng màu trên thành xe).
5. Không khói, lửa, quầng sáng, hạt, tia; không khung / chữ / nền tối — **nền xám nhạt trơn**, một vật một ảnh.
6. Màu xanh dương **chỉ** ở tấm chắn, tinh thể, kim cương bánh (game đổi sang đỏ cho phe kia).
7. Ba hướng **cùng tư thế nghỉ**, khớp nhau tuyệt đối (quy tắc T8b): xe quay mặt (miệng nòng) về phía trước.

| Thứ tự | Tên file | Ghi chú |
|---|---|---|
| 1 | `creep_siege` (`_front`, `_side`, `_back`) | Vẽ đè lên bản máy bắn đá cũ (bản cũ còn trong lịch sử git). Thấp, chắc, cao ~1,3 lần lính; nòng chiếm ~nửa chiều dài xe |
| 2 | `creep_siege_projectile.png` | Đạn pháo: **mảnh tinh thể xanh dài** như ảnh mẫu (khối liền, không vệt sáng / đuôi) — vẽ đè lên viên đá cũ |

Xong thì commit + push nhánh `thu-asset-tu-lam`, rồi **DỪNG** báo người dùng.

Đã nộp T8h: thay ba hướng `creep_siege` bằng xe pháo tư thế nghỉ và thay
`creep_siege_projectile.png` bằng mảnh tinh thể xanh liền khối.

## Đợt T9 — concept 3D cho 6 hero (xe pháo T8h đã vào game, 2026-11-03)

Xe pháo T8h đã dựng 3D và vào game (D-224). Trụ, lính, quái rừng, công trình **đã xong cả bộ**; chỉ còn **6 hero** vẫn
là mẫu tạm KayKit. Đợt này vẽ concept 3D cho hero để dựng Tripo + afk.ai (bộ xương người, có sẵn ~200 hoạt ảnh).

**Phong cách (ĐỔI 2026-11-03 theo người dùng): bám ảnh mẫu `art_inbox/08_style/ref/hero_ref.png`** — tỉ lệ anh hùng
chắc nịch (đầu ~1/4 thân, vai và tay to, chân ngắn chắc), giáp khối vát có **viền vàng**, mảng màu chủ đạo lớn, tinh thể
ma lực xanh, chất liệu rõ (kim loại mờ, vải, da) như bảng màu & vật liệu trong ảnh mẫu. Ảnh mẫu chính là thiết kế
**Duy Anh** (kiếm một tay + khiên). Các hero khác giữ gương mặt, tóc, màu, vũ khí theo **ảnh chân dung**
(`assets/art/<id>_portrait.png`) nhưng vẽ theo phong cách ảnh mẫu. Bỏ phần "chibi như lính" của bản đầu.

Quy tắc (bắt buộc, giống T8 / T8b — để Tripo dựng sạch và afk.ai gắn xương tự động):
1. Một hero một bộ ảnh `_front`, `_side`, `_back`, nền xám nhạt trơn, không bóng / đĩa đất / chữ / hiệu ứng phép.
2. **A-pose thật**: tay dang ~45°, khuỷu thẳng, có khe hở giữa tay và thân; chân tách bằng vai; nhìn thẳng.
3. Ba ảnh **cùng một tư thế**, chỉ xoay camera. Ảnh `_side` nhìn từ **bên phải** của hero (mặt hero quay về **phía
   phải ảnh**) — bản xe pháo vẽ nhìn từ bên trái nên phải dựng lại.
4. Vũ khí / sách / găng **nắm chặt trong tay**, dày, ra xa thân; không lơ lửng, không chạm đất.
5. Không mảnh rời mảnh: tóc là khối liền (vài lọn lớn), áo choàng / khăn là khối liền dài tới gối, không tua rua,
   không dây mảnh, không lửa / khói / hào quang (tinh thể, ngọn lửa xanh của Vexa vẽ thành khối màu phẳng).
6. Màu phe **không** áp cho hero (hero giữ màu riêng) — được dùng xanh dương thoải mái.

| Thứ tự | `id` | Ghi chú (theo chân dung) |
|---|---|---|
| 1 | `brakk` | Chiến binh râu nâu, giáp thép xám cam lớn (vai tròn to), tay **găng sắt to** (đấm bằng tay, không vũ khí) |
| 2 | `myra` | Pháp sư tóc trắng dài (khối liền), áo choàng trắng xanh, tinh thể xanh trên tóc; cầm **gậy phép tinh thể xanh** tay phải (đánh xa) |
| 3 | `duy_anh` | Hiệp sĩ trẻ tóc đen ngắn, giáp bạc viền vàng xanh; **kiếm một tay** tay phải, **khiên** tay trái |
| 4 | `gorran` | Orc xanh to béo, quần yếm da có quai, **yêu tinh nhỏ đội mũ phi công** ngồi trên vai (gắn liền vai, không lơ lửng); hai tay không |
| 5 | `noctis` | Sát thủ mũ trùm tím đen, khăn che mặt, mắt xanh ngọc; **hai dao găm ngắn** mỗi tay một |
| 6 | `vexa` | Phù thủy mũ chóp tím có trăng vàng, tóc tím đen, tai nhọn; **sách phép** tay trái, tay phải xòe (lửa xanh lá vẽ thành khối nhỏ trên lòng bàn tay hoặc bỏ) |

Làm **trước 2 hero** `duy_anh` (theo đúng ảnh mẫu) và `brakk`, commit + push nhánh `thu-asset-tu-lam`, đánh dấu, rồi **DỪNG** báo người dùng
duyệt. Duyệt xong mới làm 4 hero còn lại.

Đã nộp T9 (mẫu thử): `[x] duy_anh`, `[x] brakk` đủ `_front`, `_side`, `_back`.
Bốn hero còn lại đã nộp theo phần **T9 — ĐỔI 2026-11-04** bên dưới; chờ duyệt trước khi dựng 3D.

## Đợt T10 — shop ẩn + đống đổ nát trụ (2026-11-03)

Cùng phong cách bộ công trình đã duyệt (đá xám ấm khối vát, viền vàng đồng, gỗ nâu; quy tắc T8b / T8f: nền xám nhạt
trơn, một vật một ảnh, không quầng sáng / khói / hạt, chi tiết nhỏ vẽ phẳng, các hướng khớp nhau).

| Thứ tự | Tên file | Nội dung |
|---|---|---|
| 1 | `secret_shop` (`_front`, `_side`) | Shop ẩn trong rừng (không thuộc phe nào — **không** dùng xanh dương phe): quầy hàng nhỏ dưới mái lều vải **tím sẫm** liền khối, hai cột gỗ, trên quầy vài rương / bình / cuộn giấy khối to, một chiếc đèn lồng vàng treo ở mái (khối, không phát sáng). Thấp, rộng, cao ~1,5 lần lính |
| 2 | `tower_rubble` (`_front`, `_side`) | Đống đổ nát của trụ đã bị phá: **bệ trụ** (giống chân `tower`: đá xám vát, viền vàng) còn nguyên, thân trụ gãy cụt ngang thấp, vài khối đá và mảnh viền vàng vỡ đổ quanh chân, **tinh thể tắt** màu xám tro nằm nghiêng trên đống đá. Không màu phe |

Xong thì commit + push nhánh `thu-asset-tu-lam`, rồi **DỪNG** báo người dùng.

Đã nộp T10: `[x] secret_shop` và `[x] tower_rubble`, mỗi mẫu đủ `_front`, `_side`.


### T9 — ĐỔI 2026-11-04: hero vẽ **tay không**, vũ khí vẽ riêng

Gắn xương tự động (afk.ai) đặt sai xương tay khi hero cầm vũ khí to dang ra (Duy Anh bị "4 cái tay", phải cắt kiếm /
khiên ra sau). Từ nay mỗi hero nộp **hai nhóm ảnh**:

1. **Thân tay không** `<id>_front/_side/_back.png`: A-pose như cũ nhưng **hai bàn tay nắm rỗng** (nắm đấm khép, không cầm
   gì), ngón khép thành khối; đai / bao kiếm / sách đeo người thì vẽ liền thân, gọn sát người.
2. **Mỗi vũ khí một bộ ảnh riêng** `<id>_<vũ khí>_front.png` + `<id>_<vũ khí>_side.png` (vd `myra_staff`, `noctis_dagger`,
   `vexa_book`): chỉ vũ khí, đặt **thẳng đứng, chuôi / tay cầm ở dưới**, nền xám nhạt trơn, cùng phong cách và **cùng tỉ lệ
   với thân** (vẽ kèm một chấm nhỏ đánh dấu chỗ bàn tay nắm). Dao đôi chỉ cần vẽ một cây.

Game tự gắn vũ khí vào bàn tay. Brakk (găng liền tay) và Gorran (tay không) không cần ảnh vũ khí. Duy Anh trước đó
chạy tạm bằng cách cắt vũ khí; T9b bên dưới thay bằng bộ ảnh tay không và đạo cụ riêng.

Đã nộp T9 bản tay không, xem tổng hợp `09_units/_preview_t9.png`:

- [x] `myra_front/side/back.png` — thân A-pose hai tay nắm rỗng.
- [x] `myra_staff_front/side.png` — gậy tinh thể xanh riêng, chấm vị trí cầm ở chuôi.
- [x] `gorran_front/side/back.png` — tay không, yêu tinh gắn trên vai phải.
- [x] `noctis_front/side/back.png` — thân A-pose không cầm dao.
- [x] `noctis_dagger_front/side.png` — một dao mẫu dùng cho cả đôi, chấm vị trí cầm ở chuôi.
- [x] `vexa_front/side/back.png` — hai tay nắm rỗng, sách nhỏ đeo hông.
- [x] `vexa_book_front/side.png` — sách phép tách riêng cùng tỉ lệ với thân.


### T9b — Duy Anh vẽ lại tay không + kiếm, khiên riêng (2026-11-04)

Duy Anh bản cầm kiếm / khiên: Tripo dựng khiên **dính liền bàn tay** (chung đỉnh với ngón) → gắn xương xong khiên cong
như tấm vải khi làm hoạt ảnh, sửa trọng số không hết. Vẽ lại theo quy tắc T9 mới, **giữ nguyên thiết kế** ảnh mẫu
`art_inbox/08_style/ref/hero_ref.png` và bản `duy_anh_front.png` hiện tại (mặt, tóc, giáp, khăn xanh, màu):

1. `duy_anh_front/_side/_back.png` — **tay không**: A-pose, tay dang ~45°, **hai nắm tay khép rỗng** (không cầm gì),
   có khe rõ giữa tay với thân. Ảnh nghiêng nhìn từ bên phải (mặt quay về phía phải ảnh). Vẽ đè lên bản cũ.
2. `duy_anh_sword_front.png` + `duy_anh_sword_side.png` — chỉ thanh kiếm như ảnh mẫu, **dựng thẳng đứng, mũi lên, chuôi
   dưới**, chấm nhỏ đánh dấu chỗ nắm, cùng tỉ lệ với thân.
3. `duy_anh_shield_front.png` + `duy_anh_shield_side.png` — chỉ tấm khiên như ảnh mẫu (mặt trước + nhìn nghiêng thấy
   bề dày và **quai cầm** phía sau), đứng thẳng, chấm đánh dấu chỗ nắm quai. Khiên là **một khối dày cứng**, viền vàng
   liền khối.

Nền xám nhạt trơn, không bóng / chữ. Xong thì commit + push nhánh `thu-asset-tu-lam`, rồi **DỪNG** báo người dùng.

Đã nộp T9b, xem tổng hợp `09_units/_preview_t9b.png`:

- [x] `duy_anh_front/side/back.png` — vẽ đè bản cũ; A-pose, hai tay nắm rỗng, không còn kiếm / khiên dính vào tay.
- [x] `duy_anh_sword_front/side.png` — kiếm đứng riêng, có chấm vị trí cầm trên chuôi.
- [x] `duy_anh_shield_front/side.png` — khiên khối dày, viền vàng liền, mặt nghiêng thấy quai cầm sau lưng khiên.


### T9c — Noctis vẽ lại áo choàng gọn (2026-11-05)

Bản `noctis_front/side/back.png` hiện tại dựng 3D bị **rườm rà**: áo choàng dài rách mép (Tripo dựng thành mép te tua),
**hai vạt áo buông phía trước** hai bên thân và dải vải tím trước bụng — khi gắn xương các vạt này bám theo tay, vung tay là
bị kéo thành dải như cánh. Vẽ lại `noctis_front/_side/_back.png` (đè bản cũ), **giữ** mũ trùm tím, khăn che mặt đen, mắt
xanh ngọc, tóc xanh lộ dưới mũ, giáp đen viền bạc, đá ngọc xanh, tỉ lệ chibi như cũ; **đổi**:

1. **Áo choàng một mảnh gọn, chỉ ở sau lưng**: gắn ở vai, buông thẳng tới khoảng **đầu gối** (không chạm đất), mép
   dưới **liền, cắt gọn** (không rách, không tua, không vạt nhọn). Nhìn thẳng từ trước chỉ thấy viền áo choàng sau
   vai — **không có vạt nào vòng ra trước** hai bên thân.
2. **Bỏ dải vải tím buông trước bụng** (tabard) và mọi dải / tua lủng lẳng; thắt lưng gọn.
3. **Khe hở rõ giữa tay và áo choàng / thân** (A-pose, tay dang ~45°, hai nắm tay khép rỗng, không cầm dao) — để gắn
   xương tay không dính áo.
4. Giáp tay / vai bớt chi tiết nhỏ: khối lớn, rõ ràng, đọc được từ camera trên cao.
5. Ảnh nghiêng nhìn từ **bên phải** (mặt quay về phía phải ảnh); ảnh sau thấy áo choàng phẳng, một mảng.

Dao `noctis_dagger_front/side.png` giữ nguyên. Nền xám nhạt trơn, không bóng / chữ. Xong thì commit + push nhánh
`thu-asset-tu-lam`, rồi **DỪNG** báo người dùng.

- [x] `noctis_front.png`
- [x] `noctis_side.png`
- [x] `noctis_back.png`


### T9d — Noctis bỏ áo choàng (2026-11-05)

T9c đã dựng vào game, nhưng gắn xương trên Mixamo **áo choàng vẫn dính** vào chân / tay, làm hoạt ảnh khó. Người dùng
chọn **bỏ hẳn áo choàng**. Vẽ lại `noctis_front/_side/_back.png` (đè bản T9c), **giữ** mọi thứ khác của T9c (mũ trùm
tím, khăn che mặt đen, mắt xanh ngọc, tóc xanh lộ dưới mũ, giáp đen viền bạc, đá ngọc xanh, tỉ lệ chibi, A-pose tay dang
~45°, hai nắm tay khép rỗng); **đổi**:

1. **Không áo choàng, không vạt / tà / dải vải** nào buông từ vai, lưng hay hông. Mũ trùm chỉ phủ đầu và **dừng ở vai**
   (như mũ áo hoodie), không kéo dài xuống lưng.
2. Khăn quàng cổ **ngắn, ôm sát cổ**, không có đuôi khăn buông.
3. Lưng và mông thấy rõ bộ đồ bó / giáp (vẽ cho đẹp vì giờ nhìn thấy): áo giáp da tím – đen ôm người, thắt lưng gọn.
4. Giữa hai chân, giữa tay và thân có **khe hở rõ** (không có gì nối chúng).
5. Ảnh nghiêng nhìn từ **bên phải** (mặt quay về phía phải ảnh).

Dao giữ nguyên. Nền xám nhạt trơn, không bóng / chữ. Xong thì commit + push nhánh `thu-asset-tu-lam`, rồi **DỪNG** báo
người dùng.

- [x] `noctis_front.png`
- [x] `noctis_side.png`
- [x] `noctis_back.png`


## Đợt T11 — Người Đá thay rồng + bãi đấu vòng tường đá (2026-11-09)

Người dùng thấy rồng "đánh không có lực" → **thay hai con rồng bằng Người Đá** (boss kiểu Roshan, mạnh dần theo phút,
cả đội hạ được thì cùng nhận vàng + kinh nghiệm). Hang rồng hiện là vòng đá nhỏ sát bờ sông (ô F5/F6 và chỗ đối xứng
bên kia sông) → đổi thành **bãi đấu rộng, vòng tường đá thấp bao quanh** như ảnh mẫu.

**Ảnh mẫu chính: `art_inbox/08_style/ref/golem_arena_ref.png`** (người dùng gửi). Phong cách chung: ảnh neo
`art_inbox/00_style/style_sheet.png` (đá, cỏ, cây). Mọi ảnh vẽ đúng phong cách game: khối mềm vẽ tay, màu đất dịu,
low-poly vừa phải, **rune / mắt là mảng màu cam phẳng, không quầng sáng tỏa ra**.

**Cập nhật 2026-11-09 (D-308): Claude đã tự làm T11c và dựng bãi thật trong game** (`art_inbox/12_golem_arena/`, ảnh tờ
+ mô hình `assets/models/style/arena_*.glb`); **T11a bỏ** (xem bãi thật trong game). **Codex chỉ còn làm T11b** (người
đá) — vẽ cho hợp với bãi đã có: tường đá xám ấm, rêu vàng xanh, rune cam.

Thứ tự làm (cũ): **T11a → DỪNG duyệt → T11b + T11c**. Lưu vào `art_inbox/12_golem_arena/`. Xong mỗi bước thì đánh dấu `[x]`,
commit + push nhánh `thu-asset-tu-lam`, rồi **DỪNG** báo người dùng.

### T11a — ảnh toàn cảnh để người dùng hình dung (làm trước)

Hai ảnh 1536 × 1024, góc camera như trong game (nhìn chéo từ trên xuống ~46°, như ảnh mẫu), cảnh nằm sát bờ sông:

- [-] (bỏ) `arena_mockup_moss.png` — bãi đấu **Người Đá Rêu** (bản giống ảnh mẫu): đá xám, rêu vàng xanh, rune cam.
- [-] (bỏ) `arena_mockup_lava.png` — cùng bãi, cùng bố cục, **Người Đá Dung Nham**: đá nâu sẫm, vết nứt cam đỏ thay rêu, rune
  vàng cam. **Cùng hình khối** với bản rêu (game dùng chung một mô hình, chỉ đổi ảnh màu).

Yêu cầu bố cục (game sẽ dựng đúng như vậy):

1. Bãi đất nện **tròn, đường kính ≈ 9 m**; người đá cao ≈ 2,6 m đứng giữa; vẽ 3–4 tướng cao ≈ 1,25 m đang đánh quanh
   nó để thấy tỉ lệ (tướng chừng một nửa chiều cao người đá).
2. **Vòng tường đá thấp** (cao ≈ 1 m, ngang hông tướng) bao quanh, ghép từ **6 đoạn cong giống hệt nhau**, chừa
   **2 cửa rộng ≈ 2,5 m**: một cửa mở ra sông, một cửa mở vào rừng phía đối diện.
3. Điểm nhấn (ít thôi): 2 trụ đá rune ở hai bên một cửa, 1 cổng vòm đá đổ ở cửa phía rừng, 2 cột cờ vải cam.
4. Nền trong bãi có **vòng rune cam mờ trên đất** quanh chân người đá (vẽ phẳng trên đất, không phát sáng).

### T11b — Người Đá (3 hướng, để dựng bằng Tripo rồi gắn xương)

- [ ] `golem_boss_front.png`  - [ ] `golem_boss_side.png`  - [ ] `golem_boss_back.png`

- Thiết kế theo người đá trong ảnh mẫu: thân là các **tảng đá to khối**, vai hai tảng lớn nhô cao hơn đầu, đầu nhỏ
  thụt giữa vai, mắt cam, **rune cam xoắn ở ngực**, rêu vàng xanh phủ đỉnh tảng.
- **Phải khác rõ golem trại vừa đang có** (`art_inbox/09_units/neutral_buffalo_*.png`, đợt T8c): người đá boss **to
  và "cổ" hơn** — thêm **vương miện / sừng đá** trên đầu, vài **khối đá khắc rune nhỏ** ở vai và cẳng tay, tảng đá
  lưng có **rêu dày hơn và vài cây cỏ / hoa nhỏ mọc trên đó**, đế chân to vững. Nhìn là biết boss.
- Quy tắc vẽ để Tripo dựng tốt: như đợt T8 / T8b (nền xám nhạt trơn, không đĩa đất, không bóng, không chữ; ba hướng
  **cùng một tư thế**; đứng thẳng, hai tay buông dang ra ngoài ~25° có **khe hở rõ** với thân và chân, nắm đấm ngang
  gối không chạm đất; miệng ngậm). Ảnh nghiêng nhìn từ **bên phải**. 1024 × 1024 PNG.
- Chỉ vẽ **bản rêu**; bản dung nham game tự đổi màu ảnh (giữ mảng rêu là mảng màu riêng, rõ ràng để dễ đổi).

### T11c — bộ ghép tường bãi đấu (vật tĩnh, không gắn xương)

Mỗi món 3 ảnh: **nghiêng 3/4 từ trên xuống** (`_front`), **nhìn ngang** (`_side`), **nhìn thẳng từ trên** (`_top`).
Nền xám nhạt trơn, không đất / cỏ dưới chân (trừ cỏ / rêu mọc **trên** đá), không bóng.

| Xong | Tên file (thêm `_front/_side/_top`) | Nội dung | Tam giác tối đa |
|---|---|---|---|
| [x] Claude, 600 tam giác | `arena_wall_arc` | **Một đoạn tường cong liền khối** = 1/6 vòng tròn bán kính ≈ 4,8 m (dài ≈ 5 m theo cung), cao ≈ 1 m, dày ≈ 1 m. Trông như nhiều phiến đá xếp nhưng **là một khối liền** (các khe chỉ là nét vẽ / khắc nông, không tách rời). Rêu vàng xanh trên đỉnh vài chỗ. Hai đầu đoạn vát gọn để 6 đoạn đặt nối nhau khít | 600 |
| [x] Claude, 250 tam giác | `arena_rune_stone` | Trụ đá rune đứng (cao ≈ 1,6 m), mặt trước khắc rune cam phẳng | 200 |
| [x] Claude, 500 tam giác | `arena_arch` | Cổng vòm đá đổ một nửa (cao ≈ 2,8 m, rộng ≈ 2,5 m): hai chân cột, nửa vòm còn lại, vài viên rơi sát chân | 500 |
| [x] Claude, 194 tam giác | `arena_banner` | Cột gỗ có thanh ngang treo cờ vải cam (rune phẳng), cờ là **một tấm dày**, không tua rua | 150 |

**Vì sao tường làm đoạn cong liền khối** (người dùng hỏi): ghép từ nhiều viên đá nhỏ thì mỗi viên tốn tam giác riêng
(25–30 viên × 100–150 = 3 000–4 000 tam giác cho một vòng) và các mặt tiếp xúc giữa viên bị thừa; một đoạn cong liền
khối ≈ 600 tam giác, đặt lại 4–6 lần quanh vòng ≈ 2 400–3 600 nhưng **đẹp hơn ở cùng số tam giác** (chi tiết nằm ở ảnh
màu, không ở số mặt) và game vẽ cả vòng bằng **một lệnh vẽ** (MultiMesh cùng một mô hình). Không làm cả vòng thành
một mô hình duy nhất vì cần chừa cửa và ảnh màu sẽ bị kéo giãn (mờ) trên vòng dài.
