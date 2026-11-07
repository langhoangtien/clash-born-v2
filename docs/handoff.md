# Bàn giao — Clashborn v2 (2026-11-05)

Đọc AGENTS.md trước. Quyết định chi tiết: `docs/DECISIONS.md` (mới nhất D-283). Nhánh làm việc: **`thu-asset-tu-lam`**
(commit + push thẳng lên nhánh này; Codex cũng đẩy lên đây — `git pull --rebase` trước khi push).

## 1. Trạng thái

- 808 test xanh (`GODOT=... bash tools/run_tests.sh`). APK mới nhất **0.1.479** trên https://clashborn.quest (cũng là bản chuyển tiếp cuối trên gh-pages, D-283). Đo hiệu năng: log D-268 / Benchmark A/B D-272.
- Android: trình vẽ **Mobile (Vulkan)**, đồ họa mặc định Cao 100% (D-259); làm nóng shader lúc vào trận (D-260).
  Máy tính bảng người chơi: ~60 fps đầu trận → 4x fps sau một lúc; tắt phần vẽ / đổi độ phân giải không đổi FPS
  → nghẽn CPU (xem mục 3). Giật 50 → 11 fps đã hết sau D-260.
- Hero 3D đã làm theo quy trình mới: **Duy Anh** (đạt), **Noctis** (bản T9d không áo choàng, chờ người chơi duyệt),
  **Brakk** (afk.ai). Myra / Vexa / Gorran còn mô hình KayKit cũ; concept T9 của họ đã có trong `art_inbox/09_units/`.
- Hiệu ứng chiêu 3D (D-247..256): Duy Anh W (vệt chém vẽ tay + sóng bụi + tia lóe), Q (vệt tốc độ bám đường chạy).
  Chưa có: Duy Anh R, toàn bộ Noctis, các hero khác.

## 2. Quy trình hero 3D (D-235, D-242, D-244, D-249)

1. Codex vẽ **tay không** (A-pose, tay tách thân, không áo choàng / vạt dài) + vũ khí vẽ riêng (phiếu
   `art_inbox/YEU_CAU_STYLE.md`, đợt T9*).
2. `python3 tools/tripo_gen.py art_inbox/09_units/<tên> --multiview --views front,side,back --faces 2500`
   (ảnh nghiêng nhìn từ trái thì `side_left`); vũ khí `--views front,side --faces 500`.
3. `python3 -I tools/models/glb_yaw.py <tên>.glb <tên>_front.glb --deg -90` (Tripo nhìn +X → +Z).
4. afk.ai: `AFK_API_KEY=$(cat ~/.secrets/afk_key) NODE_USE_ENV_PROXY=1 npx -y afk-rig <tên>_front.glb --type human
   --facing 0 -a all -o <tên>_afk.glb` (5¢; key chỉ ở `~/.secrets`, không commit).
5. Vũ khí: `tools/models/place_prop.py` (đặt vào nắm tay theo xương), gắn cứng qua cột vũ khí trong
   `tools/models/build_units.py`. Áo bị kéo theo tay: `cloth_weights.py`. Đổi chất liệu: `recolor_prop.py`.
6. Thiếu động tác: xuất `<tên>_mixamo.fbx` (`to_mixamo.py`, cùng thân `<tên>_front.glb`), người dùng gắn xương +
   tải hoạt ảnh trên Mixamo → `mixamo_pack.py` → `retarget.py` sang rig afk → dùng `MX <tên>` trong build_units.
   File gốc Mixamo lưu ở `art_inbox/3d/mixamo/<hero>/` (README ở đó).
7. `python3 -I tools/models/build_units.py <tên>` → `assets/models/style/heroes/<tên>.glb`; cấu hình hoạt ảnh /
   điểm trúng ở `assets/models/units_3d.json` (`impact`, `skill_impact`, `attack_alt`, `stealth`, `dash_hop`…).
8. Render kiểm tra: Godot + xvfb (script chụp ở `.local/`, bị gitignore — tạo lại khi cần).

Người chơi thích phong cách afk.ai (hợp đồ họa); Mixamo chỉ để bù động tác.

## 3. Việc tiếp theo (theo thứ tự đề xuất)

0. **Đo hiệu năng**: bật Cài đặt → "Ghi log hiệu năng" rồi chơi; hết trận gửi file JSON / CSV hoặc dán tóm tắt (D-268).
   Benchmark A/B tự động (D-272): menu → Cài đặt → "Đo hiệu năng tự động" (~2,5 phút) → dán kết quả.

1. **Hiệu năng CPU**: bước A xong (D-261: bảng đo từng phần trong Chẩn đoán, `tools/view_profile.gd` chạy trận thật
   dưới xvfb; D-262: object tăng chỉ là `command_log`, không rò rỉ). Máy tính bảng 0.1.438: 40 fps ổn định, nghẽn luồng
   chính 25 ms. B1 + B2 xong (D-263): TB 49,7 fps. B3 (D-264): tối ưu không đổi kết quả chỉ được
   ~3–5 % SIM. D-265: lính đi đường nghĩ thưa, quái rừng ngủ, trung lập chỉ nhìn khi trại đánh → SIM −18–20 %.
   Còn đề xuất chưa làm: Vision / trụ / đẩy tách mỗi 2 tick (cần người dùng duyệt). 0.1.447: CPU ~13 ms, nghẽn
   GPU 11–14 ms (D-266). Nghi shader đất (sương duyệt ≤ 64 mắt / điểm ảnh) → G2: sương thành ảnh nhỏ. Còn B4, B5: SIM (Vision / Movement, bot gửi ~9 lệnh / giây), HUD `_draw` (4,6 ms trên PC), giảm lệnh vẽ (571 lệnh / 57k tam giác — cây / đá thành MultiMesh, gộp vật liệu, ảnh vũ khí gộp vào
   ảnh thân, bóng mờ dưới chân một MultiMesh). Tìm vì sao FPS giảm dần theo thời gian trận (số đơn vị / đạn / xác /
   danh sách chữ nổi tăng?).
2. APK sát giới hạn 100 MiB của GitHub: thu ảnh trùng (`*_Color_*` Godot tách từ GLB công trình, ~18,7 MB).
3. Hiệu ứng Duy Anh R (dải bám đường nhảy + cú bổ chạm đất); bộ hiệu ứng Noctis.
4. Duyệt Noctis trong game; làm Myra / Vexa / Gorran theo quy trình mục 2.
5. Đề xuất đang chờ người dùng: cho cú lao R của Duy Anh nhảy qua vách / cây / trụ (đổi luật ABL-08).

## 4. Công cụ

- **Phát hành từ VPS** `https://clashborn.quest` (D-278..283): `bash tools/build_android.sh` rồi `bash tools/publish_vps.sh "ghi chú"`
  (xem ANDROID_BUILD.md mục 5–7, VPS_SETUP.md). GitHub Pages không đăng APK nữa (dừng ở 0.1.479).

- Godot 4.7.2: tải `Godot_v4.7.2-stable_linux.x86_64` về scratchpad. Import: `godot --headless --path . --import`.
- Blender (bpy) cho `to_mixamo.py`, `mixamo_pack.py`, `bake_shading.py`: venv Python có gói `bpy`.
- Build APK: xem `docs/ANDROID_BUILD.md` (mục "Dựng môi trường trong container mới").
- Tripo: key ở biến `TRIPO_API_KEY` hoặc `~/.secrets/tripo_key`. Credit còn ~770.

## 5. Phiếu cho Codex

- `art_inbox/YEU_CAU_STYLE.md` — concept 3D (T8*, T9* hero: T9d Noctis xong).
- `art_inbox/YEU_CAU_ANH.md` — icon, ảnh hiệu ứng (V1, V2 xong; bản gốc trong `art_inbox/07_vfx/`, game chỉ chép
  ảnh đang dùng vào `assets/vfx/`).
