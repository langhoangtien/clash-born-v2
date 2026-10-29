# Bàn giao — Clashborn v2 (2026-10-29)

Tóm tắt để phiên làm việc mới (tài khoản Claude mới) làm tiếp. Đọc file này rồi đọc `AGENTS.md`
(quy trình bắt buộc), `docs/DECISIONS.md` (các dòng D-167 → D-178) và `art_inbox/YEU_CAU_STYLE.md`.

## 1. Trạng thái repo

- Repo: `langhoangtien/clash-born-v2`. Game Godot **4.7.2**, MOBA 3D, máy thử: Huawei MatePad 11.5.
- **Nhánh đang làm: `thu-asset-tu-lam`** (nhánh thử hình / map, **chưa gộp vào `main`**).
  `main` dừng ở D-167. Mọi thay đổi D-168 → D-178 chỉ có trên nhánh này.
- Test (`GODOT=... bash tools/run_tests.sh [--soak]`): xem số mới nhất trong dòng D-178 của ROADMAP / tin nhắn cuối.
- **Không build APK / web khi người dùng chưa bảo** (người dùng thử trên PC).
- Người dùng nói tiếng Việt; muốn **bàn trước khi làm** việc lớn. Không kiểm tra id hero / chiêu / đồ trong code.
  File ≤ 300 dòng, hàm ≤ 40 dòng.

## 2. Đã làm (tóm tắt theo quyết định)

| Mã | Nội dung |
|---|---|
| D-168…D-172 | Map v3 theo bản vẽ người dùng (`tools/map_build/sketch/map_sketch.png`), 9216 × 9216, sông, base, lane, trụ. Bản vẽ giờ chỉ còn cho sông / base / shop (D-178). |
| D-173, D-174 | Quái rừng 3D tự mang xương (`jungle_boar`), `tools/models/reweight_skin.py` sửa da. Người dùng chưa xác nhận trong game. |
| D-175…D-177 | Thử khối đá Tripo, rừng cây low-poly, làm mờ cây — **đều đã thay bằng D-178** (code / asset đã gỡ, còn trong lịch sử git). D-177 cũng sửa lỗi sự kiện hoạt ảnh 3D. |
| **D-178** | **Đồ họa mới + map bục rừng.** Phong cách theo concept `art_inbox/08_style/concept.webp`: camera cố định → màu + sáng tối vẽ sẵn vào mô hình (Blender, `tools/models/style_kit.py` → `assets/models/style/`), vẽ không đèn; ảnh nền Codex (`assets/textures/style/`, nén GPU). Map: `plateau_design.py` (mạng lối đi → bục rừng 13 / nửa, đá bờ sông, rìa map, 8 trại / phe: rừng carry 5, lane khó 3) → `build_map.py` → `decor.py` (vị trí cảnh vật + mặt nạ nền + bóng, `data/maps/clashborn_decor.json`, chỉ VIEW đọc). VIEW: `Terrain3D` (mặt đất ảnh nền theo mặt nạ, nước, vật liệu), `Scenery3D` (cảnh vật). Rìa map: rào đá + tường thành (nam thấp). Luật MAP-01/02/07/08/11/12. |

## 3. Đang dở / việc tiếp theo (theo thứ tự)

1. **D-178 chờ người dùng chơi thử + đo FPS trên MatePad** (giao tranh trong rừng, nhìn rìa map, sông).
   Chỉnh nhanh: bề rộng lối `MAIN / SIDE / GAP`, vị trí trại `CAMPS`, mạng lối `PATHS` trong
   `tools/map_build/plateau_design.py` → `--write` → `build_map.py` → `decor.py`. Mật độ / quy tắc cảnh vật:
   `tools/map_build/decor_place.py`. Màu / dáng mô hình: `tools/models/style_kit.py` (cần bpy).
2. Tướng / lính / trụ / nhà chính vẫn là KayKit (bản tạm) — lệch phong cách concept; người dùng sẽ làm asset động
   sau (tướng, quái rừng, creep, hoạt ảnh). Trụ, nhà chính, chợ nên làm lại theo concept.
3. Minimap / màn xem map còn vẽ phẳng kiểu cũ (MapPainter) — đổi màu theo bảng mới nếu người dùng muốn.
4. Quái rừng khác: Mixamo (hình người) / Tripo rig quadruped (4 chân), sửa da bằng `reweight_skin.py` nếu hỏng.
5. Khi người dùng chơi thử ổn: chạy soak, cập nhật ROADMAP (thêm D-168 → D-178), gộp `thu-asset-tu-lam` vào `main`.

## 4. Công cụ và lệnh

- **Blender trong container (D-177):** tải trang blender.org bị chặn, nhưng gói `bpy` (Blender 5.0.1 dạng thư viện
  Python, cần Python 3.11) cài được qua pip — mất 2–3 phút mỗi phiên mới:
  `uv venv -p /usr/bin/python3.11 <scratchpad>/bvenv && VIRTUAL_ENV=<scratchpad>/bvenv uv pip install bpy`,
  rồi chạy script dựng mô hình bằng `<scratchpad>/bvenv/bin/python script.py` (xuất .glb bằng `bpy.ops.export_scene.gltf`).
- **Godot trong container:** tải `Godot_v4.7.2-stable_linux.x86_64.zip` từ GitHub releases vào scratchpad.

- Godot: `GODOT=<đường dẫn godot> bash tools/run_tests.sh [--filter=...] [--soak]`. Import trước khi chạy cảnh:
  `godot --headless --path . --import`.
- Dựng map (D-178): `python3 tools/map_build/plateau_design.py ảnh.png --write` (in MAP-08, bề rộng lối) →
  `python3 tools/map_build/build_map.py` (in `validation OK`) → `python3 tools/map_build/decor.py` (cảnh vật).
  `from_sketch.py --write` chỉ khi đổi sông / base / shop trên bản vẽ. Ảnh map có tên:
  `xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/map_dev_png.gd` → `docs/map_dev.png`.
- Tripo (tạo 3D từ ảnh): `python3 tools/tripo_gen.py ảnh.png --faces N --out thư_mục` — **key đọc từ biến
  `TRIPO_API_KEY` hoặc `~/.secrets/tripo_key`, không nằm trong repo**. Mạng phải mở `api.tripo3d.ai` và
  `*.tripo3d.com`. Credit còn ~610 (mỗi mô hình 30). Key cũ đã lộ trong chat — người dùng nên thu hồi và tạo key mới.
- Mô hình: `tools/models/style_kit.py` (bộ asset D-178, cần bpy), `glb_slim.py`, `paint_vc.py`, `reweight_skin.py` (D-174).
- Chụp cảnh trong game (`.local/capture.gd`, bị gitignore — tạo lại nếu cần: SceneTree mở `app/match_scene.tscn`,
  đặt `hero.position` = (x, y) ở khung 5, lưu ảnh viewport sau `giây` × 30 khung):
  `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://.local/capture.gd -- out.png x y [giây]`.

## 5. Phiếu cho Codex (người dùng chuyển)

- `art_inbox/YEU_CAU_STYLE.md` — ảnh nền + vân lá theo concept (đợt T, T2 xong; đợt C thẻ màu chưa làm).
- `art_inbox/YEU_CAU_KIT_MAP.md` — bản 3 cũ (khối đá Tripo), **đã thay bằng YEU_CAU_STYLE (D-178)**.
- `art_inbox/YEU_CAU_3D.md` — quái / công trình 3D (jungle_boar đã làm).
- Mỗi lần Codex làm xong: `git pull origin thu-asset-tu-lam`, xem ảnh, dựng Tripo, ghép, chụp gửi người dùng.
