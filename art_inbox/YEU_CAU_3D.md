# Yêu cầu tạo mô hình 3D — Clashborn v2

Phiếu việc cho công cụ / người tạo mô hình 3D (Codex, Tripo, Meshy, Blender…). **Đọc hết phần
"Cách làm việc" và "Quy tắc chung" trước khi tạo bất kỳ mô hình nào.** Bảng tóm tắt số tam giác ở
mục cuối.

Game: MOBA trên máy tính bảng, camera nghiêng ~46° nhìn từ trên xuống kiểu Liên Quân, đồ họa mức
thấp (không bóng đổ thật, không normal map). Mô hình hiện ra trên màn hình khá nhỏ: tướng cao khoảng
150–200 điểm ảnh.

## Cách làm việc (bắt buộc)

1. Làm **theo từng đợt**, đúng thứ tự. Mỗi đợt xong thì **DỪNG**, báo người dùng để duyệt. Chỉ làm
   đợt sau khi người dùng đồng ý.
2. **Ảnh neo phong cách đã có** (đợt 0 xong): `art_inbox/00_style/style_3d_sheet.png` (công trình,
   cây, cỏ, đá) và `art_inbox/00_style/style_3d_units.png` (lính, quái rừng). Mọi mô hình phải cùng
   phong cách, cùng bảng màu với hai ảnh này. **Nếu không thấy hai file đó hoặc nội dung phiếu khác
   với mô tả ở đây, chạy `git pull` trước** — đừng dùng ảnh khác thay thế.
3. Lưu đúng **thư mục và tên file** trong bảng (chữ thường, gạch dưới). Không thêm hậu tố như
   `_final`, `_v2`. Mỗi mô hình kèm 1 ảnh xem trước `<tên>_preview.png` (chụp góc nghiêng từ trên
   xuống như trong game).
4. Làm xong mô hình nào thì đánh dấu `[x]` ở dòng đó trong file này, ghi số tam giác thực tế. Mô hình
   phải làm lại thì ghi ngắn lý do sau dòng đó.
5. Không sửa bất kỳ file nào ngoài thư mục `art_inbox/`. Việc đưa vào game (đặt gốc, chỉnh cỡ, khai báo
   `assets/models/units_3d.json`) do người ghép làm.

## Cách làm khuyến nghị: tạo 3D từ ảnh (image-to-3D)

Chất "vẽ tay" của ảnh neo nằm ở **ảnh màu**, không ở số tam giác. Dựng lưới bằng code / khối cơ bản rồi
tô ô màu phẳng sẽ không ra được phong cách này. Cách hợp nhất:

1. Lấy ảnh tách sẵn của từng mô hình trong **`art_inbox/00_style/crops/<tên>.png`** (cắt từ hai ảnh neo).
2. Đưa ảnh đó vào công cụ **image-to-3D** (Tripo, Meshy, Hunyuan3D, Rodin…) — công cụ dựng lưới và **nướng
   ảnh màu giống ảnh gốc**.
3. Chọn chế độ **low poly / giới hạn số mặt (face limit / target polycount)** theo bảng tóm tắt cuối file;
   công cụ không có thì xuất bản thường, ghi rõ số tam giác — người ghép sẽ giảm lưới giữ nguyên ảnh màu.
4. Xuất GLB có ảnh màu (1024). Đồ có phe: làm bản xanh, rồi tạo ảnh `_red.png` cùng UV (đổi phần xanh
   phe → đỏ trong ảnh màu).
5. Nhân vật / quái: sau đó mới gắn xương (Mixamo cho hình người, Blender cho thú — xem mục Hoạt ảnh).

## Quy tắc chung cho mọi mô hình

**Định dạng**
- Xuất **GLB** (glTF nhị phân), ảnh màu **nằm trong file**.
- Trục Y hướng lên, 1 đơn vị = 1 mét. **Mặt trước quay về +Z.**
- Gốc (origin) ở **giữa chân / gốc cây, sát mặt đất** (Y = 0). Đã áp (apply) mọi xoay / tỉ lệ.
- **Một vật liệu, một ảnh màu** mỗi mô hình (vũ khí dùng chung ảnh của nhân vật nếu được).
- Chỉ cần ảnh màu (albedo / base color). **Không** normal map, roughness, metallic, emission, AO.
- Không có đèn, camera, mặt đất, bệ đỡ trong file.

**Phong cách — ảnh neo: `art_inbox/00_style/style_3d_sheet.png`** (đính kèm ảnh này mỗi lần tạo)
- Kiểu **vẽ tay cách điệu (stylized hand-painted)** như trong ảnh neo: khối to, cạnh vát tròn, tỉ lệ
  hơi chibi, màu tươi; đá xám ấm, gỗ nâu, **viền / chóp vàng kim**, **pha lê xanh phát sáng** làm điểm
  nhấn công trình; lá cây tròn bồng (cây tán tròn) hoặc tầng nhọn (cây thông); cỏ lá to nhọn.
- **Bản GLB là bản tối giản của ảnh neo:** giữ đúng **dáng tổng thể, tỉ lệ, bảng màu**; bỏ chi tiết
  nhỏ khỏi lưới (gạch, vân đá, nếp lá, đinh tán) và **vẽ chúng lên ảnh màu** (sáng ở mặt trên, tối dần
  xuống dưới, viền sáng ở cạnh — kiểu tô gradient vẽ tay). Đừng cố làm lưới giống hệt ảnh 2D.
- Ánh sáng **vẽ sẵn trong ảnh màu** (game chỉ có một đèn yếu): mặt trên sáng, mặt dưới / khe tối.
- Dồn tam giác vào phần camera nhìn thấy: **đầu, vai, vũ khí, tán cây, mái / chóp / pha lê trụ**.
  Đáy, lưng, mặt dưới làm đơn giản.
- Lá cỏ, lá cây có thể làm bằng **mặt phẳng + ảnh có nền trong suốt** (alpha cắt cứng, không mờ dần),
  hoặc lưới đặc — miễn trong giới hạn tam giác.
- Không lỗ hở, không mặt thừa bên trong, không mặt hai lớp chồng nhau.

**Màu phe** (Blue `#3D8BFF`, Red `#FF4D4D`)
- Đồ có phe (trụ, nhà chính, lính, tướng): làm **một mô hình**, xuất **hai ảnh màu cùng UV**:
  `<tên>_blue.png` và `<tên>_red.png` (đặt cạnh file GLB; file GLB dùng bản xanh). Chỉ đổi phần
  màu phe (áo, cờ, mái, băng vải, **pha lê**: xanh → đỏ), giữ nguyên đá, gỗ, viền vàng, da.
- Đồ không có phe (cây, đá, bụi, quái rừng): một ảnh màu.

**Cỡ trong game** (để tạo đúng tỉ lệ; người ghép vẫn chỉnh lại được)

| Vật | Chiều cao trong game |
|---|---|
| Tướng | ~1,2 m (tướng to như Gorran ~1,55 m) |
| Lính | ~0,85 m (xe công thành ~1,0 m) |
| Quái rừng nhỏ / lớn | ~0,8 m / ~1,4 m |
| Trụ | 3,2–4,2 m |
| Nhà chính | ~5,8 m |
| Cây rừng | 2,3–3,1 m |
| Bụi cỏ | ~0,5 m (che tới đầu gối tướng) |
| Đá vách | 0,3–1,0 m |

## Hoạt ảnh (nhân vật có xương: tướng, lính, quái rừng)

Dùng **Mixamo** (nhân vật hình người hai chân) hoặc tự gắn xương trong Blender.

- Mixamo chỉ tự gắn xương cho **nhân vật hình người**. Thú bốn chân phải gắn xương bằng Blender hoặc
  công cụ khác → nên thiết kế quái rừng dạng đứng hai chân (xem đợt 2).
- *Skeleton LOD* khi tải từ Mixamo: lính, quái rừng → **No Fingers**; tướng → **No Fingers** hoặc
  **Three Chains**. Không dùng bản đủ ngón trừ khi tướng thật sự cần.
- Tải nhân vật: FBX, **With Skin**, tư thế T-pose. Từng hoạt ảnh: FBX, **Without Skin**, 30 khung/giây,
  hoạt ảnh di chuyển chọn **In Place**.
- Lưu: `art_inbox/3d/<nhóm>/<tên>/<tên>.fbx` (nhân vật) và
  `art_inbox/3d/<nhóm>/<tên>/anims/<tên_hoạt_ảnh>.fbx`. Gộp sẵn thành một GLB trong Blender cũng được.
- Tên hoạt ảnh tự đặt, chỉ cần rõ nghĩa (`idle`, `run`, `attack_1`…).

| Bộ hoạt ảnh | Cần có |
|---|---|
| Lính, quái rừng | `idle`, `run`, `attack` (1 đòn, có điểm chém rõ), `hit` (trúng đòn, ngắn), `death` (ngã và nằm yên ở khung cuối) |
| Tướng | như trên + `attack_2` (đòn thứ hai để luân phiên), `skill_q`, `skill_w`, `skill_r` (theo mô tả chiêu ở đợt 5), `dash` (lướt / nhảy, nếu tướng có chiêu lướt), `channel` (đứng kênh về thành, lặp được) |

Đòn đánh nên **vung nhanh, chém mạnh, thu tay chậm**: điểm chém ở khoảng 35–45% độ dài hoạt ảnh.

---

## Đợt 0 — Ảnh neo phong cách — XONG

- [x] `art_inbox/00_style/style_3d_sheet.png` — bảng phong cách đã duyệt (trụ 1–4, nhà chính, suối,
  cửa hàng, đổ nát, mắt, cỏ, cây, đá). Tên file mô hình dưới đây khớp nhãn trong ảnh.

Mô hình đầu tiên (làm rồi DỪNG chờ duyệt, để kiểm tra cách tối giản): `tree_a`, `grass_a`, `rock_a`
(đợt 1) và `tower_t1` (đợt 3).

## Đợt 1 — Cây cối, bụi cỏ, đá

Thư mục `art_inbox/3d/nature/`. Tên và dáng theo ảnh neo.

- [x] `tree_a.glb` — cây tán tròn bồng nhiều cụm, thân xoắn ngắn. **996 tam giác.**
- [ ] `tree_b.glb` — cây thông nhiều tầng lá nhọn. **800–1.500 tam giác.**
- [ ] `tree_c.glb` — cây tán tròn lệch hai tầng, thân cong. **800–1.500 tam giác.**
- [ ] `tree_a_lite.glb`, `tree_b_lite.glb`, `tree_c_lite.glb` — bản nhẹ cùng dáng cùng UV để rải sâu
  trong rừng. **200–400 tam giác.** (Không bắt buộc, nhưng cho phép cây chính đẹp hơn mà không tụt FPS.)
- [x] `grass_a.glb` — **bụi cỏ** (vùng núp, VIS-06): cụm lá to nhọn, xòe vừa. **576 tam giác.**
- [ ] `grass_b.glb`, `grass_c.glb` — bụi cỏ (vùng núp, VIS-06): cụm lá to nhọn,
  a = xòe vừa, b = thấp rộng, c = cao thẳng. Cao ~0,5–0,7 m. **300–700 tam giác.**
- [x] `rock_a.glb` — khối tròn to, **320 tam giác.**
- [ ] `rock_b.glb` (khối cao nhọn), `rock_c.glb` (khối dẹt dài) — đá vách.
  **200–400 tam giác.**
- [ ] `ground_detail.glb` — cụm cỏ nhỏ + hoa vàng rải lác đác trên nền. **≤ 100 tam giác.**

## Đợt 2 — Quái rừng

Thư mục `art_inbox/3d/jungle/`. **Ảnh neo: `art_inbox/00_style/style_3d_units.png`** (đính kèm cùng
`style_3d_sheet.png`). Tên file khớp nhãn trong ảnh. Không phe (một ảnh màu).

**Thú bốn chân** (sói, heo, gấu, bọ, rồng con) **không dùng được Mixamo** → gắn xương bằng Blender
(Rigify / tự đặt xương) hoặc công cụ AI có tự gắn xương cho thú. Quái đứng hai chân (golem, troll,
shaman, boss) dùng Mixamo được.

Cần trước (đang có trong game — cột "thay cho" là mã dữ liệu hiện tại):

| File | Thay cho | Vai trò | Dáng | Tam giác | Ảnh màu |
|---|---|---|---|---|---|
| [ ] `jungle_wolf` | `neutral_wolf` (Sói con) | quái nhỏ, đánh gần, đi cặp | bốn chân | **2.000–4.000** | 512–1024 |
| [ ] `jungle_bear` | `neutral_bear` (Gấu đá) | quái vừa, đánh gần, trâu | bốn chân | **3.000–6.000** | 1024 |
| [ ] `jungle_shaman` | `neutral_shaman` (Pháp sư rừng) | quái vừa, **đánh xa** 450 | hai chân | **2.000–4.000** | 512–1024 |
| [ ] `jungle_boar` | `neutral_buffalo` (Trâu rừng) | đầu trại lớn, to nhất rừng hiện nay | bốn chân | **4.000–8.000** | 1024 |

Làm sau (chưa có trong game — cần thiết kế trại / chỉ số trước khi dùng):

| File | Gợi ý vai trò | Dáng | Tam giác |
|---|---|---|---|
| [ ] `jungle_golem` | quái vừa trâu, chậm | hai chân | **3.000–6.000** |
| [ ] `jungle_troll` | quái vừa / lớn, đánh mạnh | hai chân | **3.000–6.000** |
| [ ] `jungle_beetle` | quái nhỏ giáp cứng | sáu chân | **2.000–4.000** |
| [ ] `jungle_drake` | quái lớn | bốn chân + đuôi | **4.000–8.000** |
| [ ] `jungle_boss` | boss giữa bản đồ (boss pit) | hai chân | **6.000–12.000**, ảnh 1024–2048 |

Mỗi quái: bộ hoạt ảnh "Lính, quái rừng". Phần sáng màu (mắt, pha lê) vẽ sáng hẳn trong ảnh màu.

## Đợt 3 — Công trình (không xương, không hoạt ảnh)

Thư mục `art_inbox/3d/structures/`. Đồ có phe: một GLB + hai ảnh `_blue` / `_red`.

| File | Mô tả | Tam giác | Ảnh màu |
|---|---|---|---|
| [x] `tower_t1` | Tháp mái nhọn, ống ngắm bên hông, băng vải phe — **3.372 tam giác** | **2.000–5.000** | 1024 |
| [ ] `tower_t2` | Như t1 nhưng to hơn, thêm cờ bay | **2.000–5.000** | 1024 |
| [ ] `tower_t3` | Tháp có càng vàng ôm pha lê lớn trên đỉnh | **3.000–6.000** | 1024 |
| [ ] `tower_t4` | Pháo đài thấp chắc, pha lê giữa, gác nhà chính | **2.000–5.000** | 1024 |
| [ ] `core` | Thành nhiều chóp nhọn, pha lê lớn ở giữa | **5.000–10.000** | 1024–2048 |
| [ ] `fountain` | Bể đá tròn, nước xanh, pha lê giữa (không cần nước động trong lưới) | **2.000–5.000** | 1024 |
| [ ] `shop` | Quầy gỗ mái vải xanh, đèn treo, bình / sách / cuộn giấy | **1.500–3.000** | 512–1024 |
| [ ] `rubble` | Đống đá vỡ khối vuông (không phe) | **500–1.500** | 512 |
| [ ] `ward_observer` | Cọc gỗ, mắt vàng, băng vải phe | **≤ 300** | 256 |
| [ ] `ward_sentry` | Cọc gỗ, mắt xanh, băng vải phe | **≤ 300** | 256 |

## Đợt 4 — Lính đường

Thư mục `art_inbox/3d/creeps/`. **Ảnh neo: `art_inbox/00_style/style_3d_units.png`.** Có phe (hai ảnh
màu: áo, chùm lông mũ, khiên, áo choàng, pha lê gậy, sơn xe). Lính đông nhất trên màn hình (20–30 con
lúc giao tranh) nên **giữ nhẹ**.

| File | Mô tả (theo ảnh neo) | Tam giác | Ảnh màu |
|---|---|---|---|
| [ ] `creep_melee` | Lính kiếm + khiên, mũ có chùm lông | **2.000–4.000** | 512 |
| [ ] `creep_ranged` | Pháp sư trùm mũ, gậy pha lê (đánh xa) | **2.000–4.000** | 512 |
| [ ] `siege_cart` | Xe pháo gỗ bốn bánh (thay `creep_siege`) | **3.000–6.000** | 512–1024 |

- Lính kiếm, lính phép: bộ hoạt ảnh "Lính, quái rừng" (Mixamo được).
- **Xe pháo không cần xương:** tách lưới riêng và đặt tên `wheel_fl`, `wheel_fr`, `wheel_bl`, `wheel_br`
  (gốc mỗi bánh ở trục bánh) và `barrel` (gốc ở chỗ nối nòng). Game tự quay bánh khi chạy và giật nòng
  khi bắn.

## Đợt 5 — Tướng

Thư mục `art_inbox/3d/heroes/<id>/`. Có phe (hai ảnh màu). **8.000–15.000 tam giác** (tối đa ~20.000),
ảnh màu **1024** (tối đa 2048). Vũ khí là một phần của mô hình hoặc lưới riêng gắn vào xương tay.
Mô tả chiêu đầy đủ ở `docs/CONTENT.md`.

| Thư mục | Tướng | Hình dung | Hoạt ảnh chiêu |
|---|---|---|---|
| [ ] `brakk` | Brakk · Thiết Quyền | đấu sĩ cơ bắp, đấm tay không, găng sắt, chịu đòn | Q đấm xuống đất · W gồng giơ giáp · R hóa hồn ma (dang tay trỗi dậy) |
| [ ] `myra` | Myra · Pháp sư | pháp sư băng, gậy phép | Q phóng tia băng · W niệm vòng phong ấn · R giơ gậy gọi mưa sao băng |
| [ ] `noctis` | Noctis · Sát Ảnh | sát thủ bóng tối, trùm đầu, hai dao | Q lướt tới bổ hai dao · W ẩn mình (cúi người, khoác áo) · R đâm đánh dấu |
| [ ] `vexa` | Vexa · Phù Thủy | phù thủy rừng, gậy + sách phép | Q phóng phép hóa ếch · W quét sóng gió · R rút phép (giơ tay hút) |
| [ ] `gorran` | Gorran · Giả Kim | gã to lớn, rìu lớn, bình axit, đuôi rồng | Q ném vũng axit · W quất đuôi rồng · R cuồng hóa (gầm, đập ngực) |
| [ ] `duy_anh` | Duy Anh · Hiệp Sĩ | hiệp sĩ kiếm + khiên | Q gồng khiên lao tới · W chém ngang hình quạt · R nhảy bổ (Quyết Đấu) |

Mỗi tướng: bộ hoạt ảnh "Tướng" ở trên.

---

## Tóm tắt số tam giác

| Loại | Tam giác | Ảnh màu | Xương / hoạt ảnh |
|---|---|---|---|
| Cây rừng | 800–1.500 (bản nhẹ 200–400) | 512–1024, dùng chung | không |
| Bụi cỏ (`grass_*`) | 300–700 | dùng chung | không |
| Đá vách | 200–400 | dùng chung | không |
| Cỏ, hoa trang trí (`ground_detail`) | ≤ 100 | dùng chung | không |
| Trụ (4 bậc) | 2.000–5.000 (bậc 3 tới 6.000) | 1024, `_blue` / `_red` | không |
| Nhà chính | 5.000–10.000 | 1024–2048, `_blue` / `_red` | không |
| Suối hồi máu, cửa hàng | 1.500–5.000 | 512–1024 | không |
| Đổ nát | 500–1.500 | 512 | không |
| Mắt (ward) | ≤ 300 | 256 | không |
| Lính đường | 2.000–4.000 (xe 3.000–6.000) | 512, `_blue` / `_red` | No Fingers, 5 hoạt ảnh (xe: không xương, tách bánh / nòng) |
| Quái rừng nhỏ / vừa | 2.000–6.000 | 512–1024 | 5 hoạt ảnh (thú: xương Blender; hai chân: Mixamo No Fingers) |
| Quái rừng lớn | 4.000–8.000 | 1024 | như trên |
| Boss rừng | 6.000–12.000 | 1024–2048 | Mixamo, 5 hoạt ảnh (+ đòn diện rộng nếu thiết kế) |
| Tướng | 8.000–15.000 (tối đa 20.000) | 1024 (tối đa 2048), `_blue` / `_red` | No Fingers / Three Chains, ~11 hoạt ảnh |

Vượt mức trên một chút không sao (người ghép có thể giảm lưới), nhưng **gấp đôi trở lên** thì làm lại.
