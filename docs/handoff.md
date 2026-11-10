# Bàn giao — Clashborn v2 (cập nhật 2026-11-09)

Đọc AGENTS.md trước. Quyết định chi tiết: `docs/DECISIONS.md` (mới nhất **D-337**). Nhánh làm việc: **`thu-asset-tu-lam`**
(commit + push thẳng lên nhánh này; Codex cũng đẩy lên đây — `git pull --rebase` trước khi push).
Người dùng hay theo dõi trên **điện thoại**: kết quả hình ảnh thì chụp trong game (xvfb) và gửi ảnh JPG.

## 1. Trạng thái

- **889 test xanh** (`GODOT=... bash tools/run_tests.sh`; soak `--soak` chạy trước khi đóng mốc). APK mới nhất trên
  https://clashborn.quest (xem `curl -s https://clashborn.quest/version.json`); phát hành mục 4.
- Android: trình vẽ Mobile (Vulkan), đồ họa mặc định Cao 100% (D-259); làm nóng shader lúc vào trận (D-260).
  Hiệu năng máy tính bảng ổn (D-261..277, D-285). Tên miền `clashborn.quest` từng bị registry treo (serverHold) — đã
  chạy lại; người dùng đang cân nhắc **đổi tên game** để mua tên miền `.com` (gợi ý: Clashveil, Clashara, RiftClash…).
- Hero 3D (afk.ai, quy trình mục 2): Duy Anh, Noctis, Brakk, **Myra / Vexa bản người lớn** (D-304). Gorran dựng lại D-321 (không còn KayKit), D-322 giảm còn 3,4k mặt + 2 kiếm, R da đỏ (EffectLook); D-323/324 đánh thường đấm, kiếm trong bao sau lưng; R rút kiếm + chém chéo từ trên xuống luân phiên hai tay — D-325/326/327 đòn chém vòng cung ngang + xoay hông dựng bằng code (`A!`, glb_slash.py; soi gương `A^` / `A%`) + vệt chém SwordTrail3D.
- Hiệu ứng chiêu 3D: shader dịu `vfx_soft` cho cả 6 tướng (D-296..306); Q Duy Anh là **làn khí kiểu Triệu Vân**
  (D-303, 305, 306); **chậm vì băng phủ màu băng lên người** (D-305, `tint` trong `_effects` của vfx.json).
- **Bản đồ 10598 × 10598** (D-307: lớn thêm 15%, lane giữ 288). Dựng lại: `python3 tools/map_build/build_map.py` rồi
  `python3 tools/map_build/decor.py` (cần numpy, shapely, scipy, opencv-python-headless, pillow); ảnh ký hiệu
  `docs/map_dev.png` (`xvfb-run -a godot --path . -s tools/map_dev_png.gd`, lưới A1…P16).
- **Boss rừng kiểu Roshan** (D-307 → D-309, luật JGL-10..14): hai **Người Đá** (Rêu ở ô F5 sát F6 — nửa đỏ, Dung Nham
  ở chỗ xoay 180° — nửa xanh) trong **bãi đấu vòng tường đá** (D-308/308b, `tools/map_build/arena.py`): xuất hiện phút 5,
  hồi 5 phút sau khi hạ, mạnh dần mỗi phút, **dậm đất** gây sát thương + choáng quanh mình (hồi 7 s), cả đội hạ được
  thì mỗi người nhận vàng + XP. Bot không tự đánh boss. **Trại tê giác** (1 to + 2 con) thay một trại 2 sói ở rừng
  carry mỗi phe. Bảng số: `docs/CONTENT.md` mục "Quái rừng boss".
- **Bảng màu chốt (D-312)**: mọi đá cùng họ xám trung tính → xanh lạnh (như lan can rìa map, người dùng thích); đất vàng
  ấm; cỏ xanh vàng (Codex T14). Lane = ảnh Codex `lane_dirt` + cụm cỏ / dương xỉ / đá nhỏ dọc mép (`lane_decor.py`).
  D-313/314: đá lát base phiến lớn trơn (Codex T14 qua `stone_tint.py`), không vòng viền, rêu quanh chân trụ; rào base /
  fountain = lan can rìa map; hang người đá **một cửa ra sông**, đá chung style_kit cao dần về phía đối diện cửa; sông bờ
  lượn, sóng vệt dài, đáy đứng yên, người lội lún + vòng gợn (`Wading3D`). **Người dùng thích đá Blender (style_kit) hơn
  Tripo / Codex** — vật đá mới ưu tiên dựng bằng style_kit. **bpy**: `python3 -m venv <scratch>/bpyenv &&
  <scratch>/bpyenv/bin/pip install bpy` (~10 phút, bpy 5.2, Python 3.13), rồi `<scratch>/bpyenv/bin/python
  tools/models/style_kit.py [tên…]`. D-317: đồ trại + trang trí rừng (`style_props.py`, `decor_camps.py`).
- **Màu điện thoại ≠ máy tính** (D-316): máy tính chạy Compatibility (OpenGL, sRGB), APK chạy Mobile (Vulkan, tuyến tính).
  Kiểm màu điện thoại trên máy cloud: `apt-get install -y mesa-vulkan-drivers`, rồi `xvfb-run -a godot --path .
  --rendering-method mobile --rendering-driver vulkan ...` (lavapipe). Màu đỉnh / hằng màu trong shader phải qua
  `srgb_in` hoặc `source_color`; hệ số chỉnh theo sRGB đổi qua `Terrain3D.linear_space()`.
- **Đất cao (base) kiểu ảnh mẫu A** (D-310..312, chưa phát hành APK): nền cỏ + dải đất nện + đá lát xám lạnh `flagstones`
  (ảnh Codex T12 qua `tools/textures/stone_tint.py`; mặt nạ `base` trong decor.json, `tools/map_build/base_decor.py`), sân lát + vòng đá viền quanh mọi trụ / nhà chính / fountain, tường rào
  `base_wall` + cột đèn cờ `base_pillar_blue/red` (Tripo text-to-model). **API ảnh OpenAI hết credit** — concept_gen
  không chạy được tới khi người dùng nạp thêm. **Codex CLI cài được trong phiên cloud**: `npm i -g @openai/codex`,
  `codex login --device-auth` (người dùng nhập mã), giao việc bằng `codex exec -s workspace-write "..."` (Codex có skill
  `imagegen` vẽ ảnh bằng tài khoản ChatGPT của người dùng).

## 2. Quy trình mô hình 3D (hero, quái, vật)

1. Concept: `python3 tools/concept_gen.py <ra.png> "mô tả tờ 3 góc nhìn" <ảnh mẫu…>` (API ảnh OpenAI, key
   `OPEN_AI_API_KEY` — hết credit từ 2026-11-09). Luôn đòi **nền xám phẳng một màu** (hay bị nền loang → vẽ lại), dáng trung tính, 3 hướng cùng
   tư thế. Muốn hợp style game thì đưa thêm Brakk (`art_inbox/09_units/brakk_front.png`) + ảnh chụp trận làm mẫu.
2. Tách: `python3 -I tools/split_turnaround.py <tờ.png> <thư_mục>/<tên>` → `_front/_side/_back.png` (cắt sát, cùng khung,
   tự tách hình chạm nhau / xóa mẩu thừa).
3. `python3 tools/tripo_gen.py <thư_mục>/<tên> --multiview --views front,side,back --faces N --out art_inbox/3d/<nhóm>`
   (ảnh nghiêng nhìn từ trái → `side_left`; vật tĩnh một ảnh: bỏ `--multiview`). Key `TRIPO_API_KEY`; **credit còn ~170**.
4. `python3 -I tools/models/glb_yaw.py <tên>.glb <tên>_front.glb --deg -90` (Tripo nhìn +X → +Z).
5. afk.ai: `NODE_USE_ENV_PROXY=1 npx -y afk-rig <tên>_front.glb --type <human|dragon|horse|kaiju|bird…> --facing 0 -a all
   -o <tên>_afk.glb` (key `AFK_API_KEY`; ~5¢ từ tín dụng Lifetime). Kiểm: `afk-rig render <glb> --animation X --views
   front,left`; mảnh bị kéo văng: `afk-rig fix-stretching`.
6. `python3 -I tools/models/build_units.py <tên>` → `assets/models/style/...`; cột thứ 7 = tham số thêm cho `glb_slim`
   (vd `--saturation`, `--tint`). Khai báo `assets/models/units_3d.json` (`height`, `impact`…).
7. Vật tĩnh cảnh vật: `glb_slim.py --size 512` → `assets/models/style/<tên>.glb`; tên bắt đầu `arena_` giữ ảnh màu riêng
   (`own_material` trong style). Tường cong: `tools/models/bend_arc.py` uốn đoạn thẳng thành cung.
8. Chụp kiểm tra: Godot + xvfb, script chụp ở `.local/` (gitignore — tạo lại khi cần, mẫu: nạp `app/match_scene.tscn`,
   dừng `runner`, đặt tướng / sinh trại bằng `JungleSpawner.spawn`, chụp `root.get_texture()`).

## 3. Việc tiếp theo

0. **Người dùng xem base mới (D-310)** — chỉnh `flag_m`, `curb_color`, độ phủ đá (`PAVE_SHARE`), bán kính sân
   (`PLAZA_R`) theo góp ý; lan can rìa map (`parapet`) cạnh fountain vẫn kiểu cũ — có thể đổi sang `base_wall` nếu
   người dùng muốn đồng bộ. Rồi phát hành APK.
   **Người dùng chơi thử 0.1.5xx mới nhất**: người đá (dậm đất có đủ mạnh / quá mạnh?), bãi đấu, trại tê giác, bản đồ lớn.
   Chỉnh số trong `content/` theo góp ý.
1. ~~Hiệu ứng dậm đất~~ — xong D-320 (sự kiện `effect_triggered`, mục `_triggers` trong vfx.json, mảnh `quake`).
2. Người Đá Rêu: mảnh đá thừa ở tay đã bỏ (D-318, `drop_loose.py` đọc đúng GLB xen kẽ của afk.ai).
3. Tài khoản (D-333, ROADMAP ACC): `/api/auth/*`, `app/account/account_client.gd`, `view/menu/account_panel.gd`; bí mật mail / Google ở VPS (V-003); D-334/335 quản trị `/admin/` (quyền mod / admin trên tài khoản) (`tools/vps/admin.py`), lịch sử trận, trang người chơi.
4. Clashborn Stats (D-331, ROADMAP ST): trang `clashborn.quest/stats/`, biên bản trận `/api/match`; bot vs bot hàng loạt `tools/stats/sim_matches.gd`.
5. Hướng lớn: **đang làm M9 — 3v3 online** (D-328, ROADMAP M9; M9.1 xong — 3v3 offline với bot, D-329; M9.3 xong — điện thoại arm64 khớp x86 (D-336); M9.4 xong — `app/net/` lockstep (D-337, luật NET); tiếp M9.5 máy chủ phòng trên VPS); còn lại: âm thanh (ElevenLabs), đổi tên game.
4. ~~Gorran KayKit~~ — xong D-321 (Gorran afk.ai, W Lọ Độc ném; KayKit đã gỡ hẳn).

## 4. Công cụ

- **Phát hành**: `GODOT=... bash tools/build_android.sh` rồi `bash tools/publish_vps.sh "ghi chú"`; kiểm sha256 file
  `https://clashborn.quest/releases/clashborn-0.1.<code>.apk`; commit `export_presets.cfg` (số bản). Chỉ phát hành khi
  **toàn bộ test xanh** (0.1.514 từng lỡ phát hành khi đỏ — D-308b).
- **Việc cho VPS**: ghi `docs/VPS_TASKS.md`, đẩy lên, nhắn phiên **vps** (send_message; tìm bằng list_sessions, tiêu đề
  "vps"; phiên đó không nhắn lại được — đọc kết quả bằng list_events). Báo cáo người chơi: `bash tools/fetch_reports.sh`.
- Godot 4.7.2: tải `Godot_v4.7.2-stable_linux.x86_64` về scratchpad. Import: `godot --headless --path . --import`
  (bắt buộc sau khi thêm script / mô hình).
- Build APK: `docs/ANDROID_BUILD.md` (mục "Dựng môi trường trong container mới").
- Key chỉ ở biến môi trường (OPEN_AI_API_KEY, TRIPO_API_KEY, AFK_API_KEY); không bao giờ commit hay dán vào chat.

## 5. Phiếu cho Codex

- `art_inbox/YEU_CAU_STYLE.md` — concept 3D (T8*, T9*, T11 — T11 Claude đã làm hết).
- `art_inbox/YEU_CAU_ANH.md` — icon, ảnh hiệu ứng.
