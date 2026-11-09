# Bàn giao — Clashborn v2 (2026-11-05)

Đọc AGENTS.md trước. Quyết định chi tiết: `docs/DECISIONS.md` (mới nhất D-304). Nhánh làm việc: **`thu-asset-tu-lam`**
(commit + push thẳng lên nhánh này; Codex cũng đẩy lên đây — `git pull --rebase` trước khi push).

## 1. Trạng thái

- 838 test xanh (soak 842) (`GODOT=... bash tools/run_tests.sh`). APK mới nhất **0.1.500** (65 MB; hiệu ứng D-296..303, Myra băng, nội tại cộng điểm D-301) trên https://clashborn.quest — bản đầu tiên chỉ phát hành qua VPS; gh-pages dừng ở 0.1.479 (D-283). Đo hiệu năng: log D-268 / Benchmark A/B D-272.
- Android: trình vẽ **Mobile (Vulkan)**, đồ họa mặc định Cao 100% (D-259); làm nóng shader lúc vào trận (D-260).
  Hiệu năng máy tính bảng (D-261..277): tối ưu SIM, sương thành ảnh nhỏ, chia tick (D-273), nạp trước hình / icon;
  Benchmark A/B gần nhất (0.1.470) ổn. Khựng đầu trận đã sửa (D-285).
- Hero 3D đã làm theo quy trình mới: **Duy Anh** (đạt), **Noctis** (bản T9d không áo choàng, chờ người chơi duyệt),
  **Brakk** (afk.ai), **Myra / Vexa** (D-304: bản người lớn, concept vẽ bằng `tools/concept_gen.py`, tay không). Gorran còn
  mô hình KayKit cũ.
- Hiệu ứng chiêu 3D (D-247..256): Duy Anh W (vệt chém vẽ tay + sóng bụi + tia lóe), Q (vệt tốc độ bám đường chạy).
  Chưa có: Duy Anh R, toàn bộ Noctis, các hero khác.

## 2. Quy trình hero 3D (D-235, D-242, D-244, D-249)

1. Codex vẽ (hoặc `tools/concept_gen.py` vẽ tờ 3 góc nhìn → `tools/split_turnaround.py`, D-304) **tay không** (A-pose, tay tách thân, không áo choàng / vạt dài) + vũ khí vẽ riêng (phiếu
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

0. **Kiểm tra 0.1.492 trên máy** (log trận so L-0008, xem cột Đạn / Sự kiện; chơi thử R Duy Anh qua vách, khấc máu): game tự thấy bản mới từ clashborn.quest, tải + kiểm sha256 + cài được (lần đầu chỉ
   qua VPS); hết khựng lúc mở trận (D-285); hình mô hình không xấu đi (D-286). Chạy lại Benchmark A/B (Cài đặt →
   "Đo hiệu năng tự động") để đo D-277. Từ D-287 người chơi bấm **"Gửi lên máy chủ"** (kèm ghi chú) rồi nhắn mã
   (B-0042 / L-0043): đọc bằng `bash tools/fetch_reports.sh <mã|latest>` (không có tham số = danh sách).
1. Chọn hướng tiếp (người dùng chọn):
   - **A. Chế độ 5v5** — cần luật mới trong GAME_RULES (đội, bot đồng đội, chia đường) + đo lại hiệu năng 10 tướng.
   - **B. Hoàn thiện tướng 3D / hiệu ứng** — ĐANG LÀM. Hiệu ứng đợt 1 xong (D-296: shader dịu, cả 6 tướng Q / W / R,
     chờ người chơi xem). Tiếp: chỉnh theo góp ý; mô hình tướng bớt chibi (người chơi: Brakk đẹp nhất — tỷ lệ người
     thật hơn), Myra / Vexa / Gorran theo quy trình mục 2.
   - **C. Âm thanh / giọng nói** — ElevenLabs (key trong biến môi trường): tiếng chiêu, đánh, trụ, câu thoại tướng.
   - **D. 1v1 trực tuyến** — SIM đã tất định (D-30), hướng đồng bộ lệnh (lockstep) qua máy chủ trên VPS.
2. Cú lao R của Duy Anh bay qua vách / rừng / thân trụ (ABL-08c, D-292) — chờ chơi thử.
3. Hiệu năng còn để dành (chỉ làm nếu đo thấy cần, nhất là khi lên 5v5): giảm lệnh vẽ (cây / đá thành MultiMesh,
   gộp vật liệu), HUD `_draw`, Vision / trụ / đẩy tách mỗi 2 tick.
4. APK hiện 65 MB: phần lớn là thư viện Godot (~23 MB nén), cảnh (~5 MB), nhạc (~4 MB). Ảnh `*_Color_*` thừa còn ~1 MB.

## 4. Công cụ

- **Phát hành từ VPS** `https://clashborn.quest` (D-278..283): `bash tools/build_android.sh` rồi `bash tools/publish_vps.sh "ghi chú"`
  (xem ANDROID_BUILD.md mục 5–7, VPS_SETUP.md). GitHub Pages không đăng APK nữa (dừng ở 0.1.479).
  Trang giới thiệu: sửa `web/site/` rồi `GODOT=... bash tools/site/publish_site.sh` (D-284).
  **Việc cho VPS**: ghi vào `docs/VPS_TASKS.md`, đẩy lên, rồi nhắn phiên **vps** (mcp send_message; tìm bằng
  list_sessions, tiêu đề "vps"); kiểm `curl https://clashborn.quest/api/health` → `commit` (D-288).
  Báo cáo hiệu năng người chơi gửi lên: `bash tools/fetch_reports.sh [mã|latest]` (D-287). Test máy chủ:
  `python3 -m unittest discover -s tools/vps -p 'test_*.py'`.

- Godot 4.7.2: tải `Godot_v4.7.2-stable_linux.x86_64` về scratchpad. Import: `godot --headless --path . --import`.
- Blender (bpy) cho `to_mixamo.py`, `mixamo_pack.py`, `bake_shading.py`: venv Python có gói `bpy`.
- Build APK: xem `docs/ANDROID_BUILD.md` (mục "Dựng môi trường trong container mới").
- Tripo: key ở biến `TRIPO_API_KEY` hoặc `~/.secrets/tripo_key`. Credit còn ~770.

## 5. Phiếu cho Codex

- `art_inbox/YEU_CAU_STYLE.md` — concept 3D (T8*, T9* hero: T9d Noctis xong).
- `art_inbox/YEU_CAU_ANH.md` — icon, ảnh hiệu ứng (V1, V2 xong; bản gốc trong `art_inbox/07_vfx/`, game chỉ chép
  ảnh đang dùng vào `assets/vfx/`).
