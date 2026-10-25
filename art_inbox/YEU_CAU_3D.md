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
2. **Đợt 0 là mẫu neo phong cách** (1 cây, 1 bụi, 1 đá). Sau khi được duyệt, mọi mô hình sau phải
   cùng phong cách, cùng bảng màu với mẫu neo.
3. Lưu đúng **thư mục và tên file** trong bảng (chữ thường, gạch dưới). Không thêm hậu tố như
   `_final`, `_v2`. Mỗi mô hình kèm 1 ảnh xem trước `<tên>_preview.png` (chụp góc nghiêng từ trên
   xuống như trong game).
4. Làm xong mô hình nào thì đánh dấu `[x]` ở dòng đó trong file này, ghi số tam giác thực tế. Mô hình
   phải làm lại thì ghi ngắn lý do sau dòng đó.
5. Không sửa bất kỳ file nào ngoài thư mục `art_inbox/`. Việc đưa vào game (đặt gốc, chỉnh cỡ, khai báo
   `assets/models/units_3d.json`) do người ghép làm.

## Quy tắc chung cho mọi mô hình

**Định dạng**
- Xuất **GLB** (glTF nhị phân), ảnh màu **nằm trong file**.
- Trục Y hướng lên, 1 đơn vị = 1 mét. **Mặt trước quay về +Z.**
- Gốc (origin) ở **giữa chân / gốc cây, sát mặt đất** (Y = 0). Đã áp (apply) mọi xoay / tỉ lệ.
- **Một vật liệu, một ảnh màu** mỗi mô hình (vũ khí dùng chung ảnh của nhân vật nếu được).
- Chỉ cần ảnh màu (albedo / base color). **Không** normal map, roughness, metallic, emission, AO.
- Không có đèn, camera, mặt đất, bệ đỡ trong file.

**Phong cách**
- Low poly cách điệu, khối to tròn dễ đọc, tỉ lệ hơi chibi (đầu to cỡ 1/3–1/4 người), màu tươi
  bão hòa, tô phẳng hoặc vẽ tay đơn giản. Tham khảo phong cách bộ KayKit đang có trong game
  (`assets/models/kaykit/`, `assets/models/medieval/`).
- **Chi tiết vẽ lên ảnh màu** (nếp áo, vân gỗ, bóng tối dưới tán lá) thay vì thêm lưới.
- Dồn tam giác vào phần camera nhìn thấy: **đầu, vai, vũ khí, tán cây, mái trụ**. Đáy, lưng, mặt dưới
  làm đơn giản.
- Không lỗ hở, không mặt thừa bên trong, không mặt hai lớp chồng nhau.

**Màu phe** (Blue `#3D8BFF`, Red `#FF4D4D`)
- Đồ có phe (trụ, nhà chính, lính, tướng): làm **một mô hình**, xuất **hai ảnh màu cùng UV**:
  `<tên>_blue.png` và `<tên>_red.png` (đặt cạnh file GLB; file GLB dùng bản xanh). Chỉ đổi phần
  màu phe (áo, cờ, mái, pha lê), giữ nguyên da, gỗ, đá, kim loại.
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

## Đợt 0 — Mẫu neo phong cách (DỪNG chờ duyệt)

Thư mục `art_inbox/3d/nature/`

- [ ] `tree_a.glb` — cây rừng tán to tròn, thân ngắn chắc. **800–1.500 tam giác.**
- [ ] `bush_a.glb` — bụi cỏ tròn rậm, rộng hơn cao. **300–700 tam giác.**
- [ ] `rock_a.glb` — khối đá vách góc cạnh, xám ấm. **200–400 tam giác.**

## Đợt 1 — Cây cối, bụi, đá

Thư mục `art_inbox/3d/nature/`

- [ ] `tree_b.glb` — cây tán nhọn (kiểu thông). **800–1.500 tam giác.**
- [ ] `tree_c.glb` — cây tán lệch / hai tầng, cho rừng đỡ lặp. **800–1.500 tam giác.**
- [ ] `tree_a_lite.glb`, `tree_b_lite.glb`, `tree_c_lite.glb` — bản nhẹ cùng dáng cùng UV để rải sâu
  trong rừng. **200–400 tam giác.** (Không bắt buộc, nhưng cho phép cây chính đẹp hơn mà không tụt FPS.)
- [ ] `bush_b.glb`, `bush_c.glb` — hai kiểu bụi khác dáng. **300–700 tam giác.**
- [ ] `rock_b.glb`, `rock_c.glb` — đá vách khác dáng (một khối dẹt, một khối cao). **200–400 tam giác.**
- [ ] `pebble_a.glb` — cụm sỏi nhỏ trang trí. **≤ 100 tam giác.**
- [ ] `grass_tuft_a.glb`, `flower_a.glb` — cụm cỏ / hoa lẻ rải trên nền (không bắt buộc). **≤ 100 tam giác.**

## Đợt 2 — Quái rừng

Thư mục `art_inbox/3d/jungle/`. Có thể **thiết kế lại hình dạng** theo ý người dùng, nhưng giữ đúng vai
trò và cỡ (mã `id` là chỗ game nối dữ liệu, giữ nguyên tên file). Khuyên làm dạng **đứng hai chân** để
dùng Mixamo.

| File | Vai trò (dữ liệu hiện tại) | Gợi ý thiết kế | Tam giác | Ảnh màu |
|---|---|---|---|---|
| [ ] `neutral_wolf` | Sói con — quái nhỏ, đánh gần, nhanh, đi theo cặp | thú nhỏ nhanh nhẹn (goblin, người sói con…) | **2.000–4.000** | 512–1024 |
| [ ] `neutral_bear` | Gấu đá — quái vừa, đánh gần, trâu | khối to, đá / rêu (người đá, gấu đứng) | **3.000–6.000** | 1024 |
| [ ] `neutral_shaman` | Pháp sư rừng — quái vừa, **đánh xa** 450 | pháp sư nhỏ cầm gậy / bùa | **2.000–4.000** | 512–1024 |
| [ ] `neutral_buffalo` | Trâu rừng — quái lớn, đầu trại | to nhất trong rừng, có sừng / giáp | **4.000–8.000** | 1024 |

Mỗi quái: bộ hoạt ảnh "Lính, quái rừng" ở trên.

## Đợt 3 — Công trình (không xương, không hoạt ảnh)

Thư mục `art_inbox/3d/structures/`. Đồ có phe: một GLB + hai ảnh `_blue` / `_red`.

| File | Mô tả | Tam giác | Ảnh màu |
|---|---|---|---|
| [ ] `tower_t1` | Trụ ngoài cùng, gọn, mái nhọn | **2.000–5.000** | 1024 |
| [ ] `tower_t2` | Trụ thứ hai, to hơn, thêm giáp / cờ | **2.000–5.000** | 1024 |
| [ ] `tower_t3` | Trụ chặn nhà lính, có máy bắn / pha lê | **3.000–6.000** | 1024 |
| [ ] `tower_t4` | Trụ gác nhà chính, thấp chắc | **2.000–5.000** | 1024 |
| [ ] `core` | Nhà chính (lâu đài / tinh thể lớn) | **5.000–10.000** | 1024–2048 |
| [ ] `fountain` | Suối hồi máu ở base | **2.000–5.000** | 1024 |
| [ ] `shop` | Cửa hàng ẩn trong rừng (lều / quầy) | **1.500–3.000** | 512–1024 |
| [ ] `rubble` | Đống đổ nát chỗ trụ đã đổ (không phe) | **500–1.500** | 512 |
| [ ] `ward_observer` | Mắt vàng (cắm xuống đất) | **≤ 300** | 256 |
| [ ] `ward_sentry` | Mắt xanh (nhìn tàng hình) | **≤ 300** | 256 |

## Đợt 4 — Lính đường

Thư mục `art_inbox/3d/creeps/`. Có phe (hai ảnh màu). Lính đông nhất trên màn hình (20–30 con lúc giao
tranh) nên **giữ nhẹ**.

| File | Mô tả | Tam giác | Ảnh màu |
|---|---|---|---|
| [ ] `creep_melee` | Lính cận chiến (kiếm + khiên) | **2.000–4.000** | 512 |
| [ ] `creep_ranged` | Lính đánh xa (nỏ / cung / phép) | **2.000–4.000** | 512 |
| [ ] `creep_siege` | Xe công thành / lính phá trụ | **3.000–6.000** | 512–1024 |

Mỗi lính: bộ hoạt ảnh "Lính, quái rừng". Xe công thành nếu là xe thì `run` = bánh lăn, `attack` = bắn.

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
| Bụi cỏ | 300–700 | dùng chung | không |
| Đá vách | 200–400 | dùng chung | không |
| Sỏi, cỏ, hoa trang trí | ≤ 100 | dùng chung | không |
| Trụ (4 bậc) | 2.000–5.000 (bậc 3 tới 6.000) | 1024, `_blue` / `_red` | không |
| Nhà chính | 5.000–10.000 | 1024–2048, `_blue` / `_red` | không |
| Suối hồi máu, cửa hàng | 1.500–5.000 | 512–1024 | không |
| Đổ nát | 500–1.500 | 512 | không |
| Mắt (ward) | ≤ 300 | 256 | không |
| Lính đường | 2.000–4.000 (xe 3.000–6.000) | 512, `_blue` / `_red` | No Fingers, 5 hoạt ảnh |
| Quái rừng nhỏ / vừa | 2.000–6.000 | 512–1024 | No Fingers, 5 hoạt ảnh |
| Quái rừng lớn | 4.000–8.000 | 1024 | No Fingers, 5 hoạt ảnh |
| Tướng | 8.000–15.000 (tối đa 20.000) | 1024 (tối đa 2048), `_blue` / `_red` | No Fingers / Three Chains, ~11 hoạt ảnh |

Vượt mức trên một chút không sao (người ghép có thể giảm lưới), nhưng **gấp đôi trở lên** thì làm lại.
