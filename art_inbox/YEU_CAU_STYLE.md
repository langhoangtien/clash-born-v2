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

- `art_inbox/08_style/ref/tower_ref.png` — trụ 4 cấp.
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
| 1 | `tower_t1` … `tower_t4` | 4 trụ theo đúng 4 cấp trong ảnh mẫu (cấp cao hơn: to hơn, nhiều tầng / gai vàng hơn, tinh thể lớn hơn). Mỗi cấp `_front` + `_side` (trụ gần đối xứng, không cần `_back`). Đế trụ là bệ đá tròn, không kèm sàn lát / bậc thềm rộng xung quanh. Không vòng sáng xanh quanh thân cấp 4 |
| 2 | `creep_siege` | Xe máy bắn đá như ảnh mẫu: thân gỗ, khung đá xám viền vàng, 4 bánh đá xám có đĩa vàng-xanh giữa bánh, cần gỗ dài với gầu đá chứa viên đá tinh thể, tấm chắn trước + băng rôn bên **màu phe**. `_front`, `_side`, `_back` **đúng tư thế nghỉ** (cần hạ, như các hướng trong ảnh mẫu — không vẽ cảnh đang bắn). Dây buộc cần vẽ thành **đai dày** liền khối. Thêm một ảnh `creep_siege_projectile.png`: viên đá tinh thể (như ô Projectile của ảnh mẫu) |

Nhà chính (`core`) và fountain **chưa làm**: concept người dùng (`base_ref.png`, `fountain_ref.png`) nhiều chi tiết rời
quá cho Tripo, chờ người dùng chốt bản giản lược.

Xong cả hai mục thì commit + push nhánh `thu-asset-tu-lam`, rồi **DỪNG** báo người dùng.
