# Bàn giao — Clashborn v2 (2026-10-29)

Tóm tắt để phiên làm việc mới (tài khoản Claude mới) làm tiếp. Đọc file này rồi đọc `AGENTS.md`
(quy trình bắt buộc), `docs/DECISIONS.md` (các dòng D-167 → D-175) và `art_inbox/YEU_CAU_KIT_MAP.md`.

## 1. Trạng thái repo

- Repo: `langhoangtien/clash-born-v2`. Game Godot **4.7.2**, MOBA 3D, máy thử: Huawei MatePad 11.5.
- **Nhánh đang làm: `thu-asset-tu-lam`** (nhánh thử hình / map, **chưa gộp vào `main`**).
  `main` dừng ở D-167. Mọi thay đổi D-168 → D-176 chỉ có trên nhánh này.
- Test: **662 xanh**, có soak **666 xanh** (D-176) (`GODOT=... bash tools/run_tests.sh`); bản có soak (`--soak`) xanh lần cuối ở D-172
  (660) và ở D-176 (666).
- **Không build APK / web khi người dùng chưa bảo** (người dùng thử trên PC).
- Người dùng nói tiếng Việt; muốn **bàn trước khi làm** việc lớn. Không kiểm tra id hero / chiêu / đồ trong code.
  File ≤ 300 dòng, hàm ≤ 40 dòng.

## 2. Đã làm (tóm tắt theo quyết định)

| Mã | Nội dung |
|---|---|
| D-168…D-170 | Map v3 cũ: núi đá, vòng đá ổ quái, rào base/fountain (MAP-09/10), MOV-07, dải bờ sông… (phần lớn đã thay bằng D-171) |
| **D-171** | **Map vẽ lại theo bản vẽ của người dùng** (kiểu Dota/Tốc Chiến): `tools/map_build/sketch/map_sketch.png` → `tools/map_build/from_sketch.py --write` → `map_source.json` → `build_map.py` → `data/maps/clashborn_map.json`. Màu bản vẽ: vàng xanh đi được, đen khối đá, xanh sông, xanh xám base, chấm đỏ trại, chấm xanh dương shop ẩn. Lấy nửa Blue (dưới đường sông qua tâm) xoay 180°. Khối đá = bờ sông + hốc trại (MAP-07/08 viết lại). Bỏ boss, bậc thang, RiverBank3D, ramps, vòng đá ổ quái. 7 bụi mỗi nửa tự đặt. |
| **D-172** | Map **9216 × 9216** (khung guide 36..612, scale 16), base nhỏ lại (`BASE_R` 0,29), T3 mid trong đất cao, T2 giữa T1–T3, đá bờ sông không thu + lấn sông 3 ô, lối cắt xuyên khối cạnh T1 mid (`CUTS`), bo tròn khối (`ROUND`), bỏ vệt mảnh (`MIN_THICK`, `rock_min_thick` 6), `tower_clear_radius` 16, góc lane bán kính 28 ô. Dải đá bờ sông mảnh trong bản vẽ giữ mảnh như rào đá thấp (`BANK_LAND_THIN` 0,5). |
| **D-173** | Quái rừng 3D tự mang xương + hoạt ảnh: rig `own` trong `assets/models/units_3d.json`, Actor3D dùng AnimationPlayer của chính mô hình. `jungle_boar` (Codex làm) thay ảnh `neutral_buffalo`, cao 1,15 m, `yaw` 180. |
| **D-174** | jungle_boar của Codex bị lỗi da (gần hết đỉnh dính xương gốc → đi như tấm ảnh). `tools/models/reweight_skin.py` gán lại trọng số da theo khoảng cách xương — đã chạy, chân/đầu/đuôi chuyển động. **Người dùng chưa xác nhận đã ổn trong game.** |
| **D-176** | Rừng cây thay đá trong rừng (xem mục 3.1, DECISIONS D-176). Vùng rừng: vật cản 38,9% → 21%, lối rộng trung vị 264 → 512. 3.264 cây × 52–110 tam giác. |
| **D-175** | **Thử 3 khối đá dựng sẵn** (đợt B0): ảnh Codex `art_inbox/07_kit/khoi_19.png, khoi_13.png, bo_song_16.png` → Tripo → `assets/models/custom/kit/*.glb` → `tools/models/fit_block.py` (xoay / cỡ cho chân khớp khối trong map) → `block_models` trong `map_source.json` → `render.block_models` → `Scenery3D._add_block`. Khối có mô hình thì không rải đá tạm (`Mountains3D.built`) và không vẽ nền đá. Tạm tắt cổ thụ (`scenery.giants.chance` = 0) vì che tướng. Cao 1,3 m (khối), 0,5 m (bờ sông) — không che tướng. |

## 3. Đang dở / việc tiếp theo (theo thứ tự)

1. **D-176 chờ chơi thử** (người dùng thấy khối đá D-175 thấp, lối hẹp, giao tranh chật → chọn phương án 3):
   đá chỉ ở bờ sông, còn lại là rừng cây low-poly (`tools/map_build/forest.py`, `tools/models/make_low_trees.py`),
   lối rừng rộng hơn, khe xuyên khối rừng lớn, cây che tướng vẽ thưa (`TreeFade`). Luật MAP-11. Chờ người dùng
   chơi thử và **đo FPS trên MatePad** lúc giao tranh trong rừng. Chỉnh độ rộng: `FOREST_SHRINK` trong forest.py
   (6 ô; 4 = chật hơn, 8 = gần như trống), rồi `from_sketch.py --write` + `build_map.py`.
2. Đợt B (khối đá Tripo cho cả map) **không cần nữa** trừ bờ sông: khối trong rừng giờ là cây. Mô hình thử
   khoi_19 / khoi_13 đã bỏ (còn trong lịch sử git); bo_song_16 giữ. Nếu làm thêm đá bờ sông thì vật cản lấy từ
   chân mô hình (độ trùng hiện 61%, `fit_block.py`).
3. **Đợt R của phiếu** (chưa làm): rào base, rìa map, 2 bụi lá to, ô nền lặp cỏ / đất / nước, cây thông.
   Nền map (map_painter) cần đổi sang ô nền lặp cùng chất bảng phong cách đã duyệt
   (`art_inbox/07_kit/bang_phong_cach.png`).
4. Quái rừng khác: người dùng tự làm hình người bằng Mixamo; quái 4 chân thì Tripo rig quadruped (chỉ có
   hoạt ảnh "walk") / Blender, sửa da bằng `reweight_skin.py` nếu hỏng. Golem Tripo của người dùng (4.537 tam
   giác) chưa có xương — người dùng làm trên Tripo Studio rồi gửi.
5. Khi người dùng chơi thử ổn: chạy soak, cập nhật ROADMAP, gộp `thu-asset-tu-lam` vào `main`.

## 4. Công cụ và lệnh

- Godot: `GODOT=<đường dẫn godot> bash tools/run_tests.sh [--filter=...] [--soak]`. Import trước khi chạy cảnh:
  `godot --headless --path . --import`.
- Dựng map: `python3 tools/map_build/from_sketch.py --write` (đọc bản vẽ, cần map đã build một lần để đặt bụi
  tránh trụ — chạy 2 lượt) rồi `python3 tools/map_build/build_map.py` (in `validation OK`). Ảnh map có tên:
  `xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/map_dev_png.gd` → `docs/map_dev.png`.
- Tripo (tạo 3D từ ảnh): `python3 tools/tripo_gen.py ảnh.png --faces N --out thư_mục` — **key đọc từ biến
  `TRIPO_API_KEY` hoặc `~/.secrets/tripo_key`, không nằm trong repo**. Mạng phải mở `api.tripo3d.ai` và
  `*.tripo3d.com`. Credit còn ~610 (mỗi mô hình 30). Key cũ đã lộ trong chat — người dùng nên thu hồi và tạo key mới.
- Mô hình: `tools/models/glb_slim.py` (giảm ảnh màu), `paint_vc.py`, `reweight_skin.py` (D-174),
  `fit_block.py` (D-175).
- Chụp cảnh trong game (dev, thư mục `.capture/` bị gitignore — tạo lại nếu cần): `capture.gd -- 3d out.png
  giây chỗ [tham số]` với chỗ `lane | core | jungle <i> | bush <i> | tower <i> | at <x> <y>`.
  Bản gọn D-176 (`.local/capture.gd`, cũng bị gitignore — tạo lại nếu cần): mở match_scene, đặt tướng tại (x, y)
  rồi chụp: `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://.local/capture.gd -- out.png x y [giây]`.

## 5. Phiếu cho Codex (người dùng chuyển)

- `art_inbox/YEU_CAU_KIT_MAP.md` — đồ họa map bản 3: bảng phong cách (đã duyệt), đợt R, đợt B / B0 (B0 xong).
- `art_inbox/YEU_CAU_3D.md` — quái / công trình 3D (jungle_boar đã làm).
- Mỗi lần Codex làm xong: `git pull origin thu-asset-tu-lam`, xem ảnh, dựng Tripo, ghép, chụp gửi người dùng.
