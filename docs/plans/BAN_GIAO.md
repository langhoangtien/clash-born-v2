# Bàn giao cho phiên Claude mới (2026-11-11)

Câu mở phiên mới (người chơi dán):

> Đọc AGENTS.md rồi docs/plans/BAN_GIAO.md, làm theo mục "Việc tiếp theo". Nhánh `thu-asset-tu-lam`.

## 1. Làm việc thế nào (đã quen ở phiên trước)

- Nhánh **`thu-asset-tu-lam`**. Codex và phiên VPS cũng đẩy lên nhánh này, nên **luôn `git pull --rebase` trước khi đẩy**.
  Mọi thay đổi commit + push ngay (hook bắt buộc).
- **Godot 4.7.2** (`/usr/local/bin/godot`):
  - Test: `GODOT=godot bash tools/run_tests.sh [--filter=X] [--soak]`. Hai dòng `SCRIPT ERROR … call on null` là fixture cố ý, không phải lỗi.
  - `test_bench` thỉnh thoảng đỏ ngay sau `--import` (lỗi texture giả); chạy lại thì xanh.
  - Thêm `class_name` mới thì chạy `godot --headless --path . --import`.
- **Bản Android:**
  1. `GODOT=godot bash tools/build_android.sh`
  2. `bash tools/publish_vps.sh "ghi chú"`
  3. So sha256 của file tải về với `build/android/clashborn.apk`.
  4. Commit `export_presets.cfg` với tin "Bản 0.1.N".
- **Trang web:** `GODOT=godot bash tools/site/publish_site.sh`.
- **Việc trên VPS:**
  - Ghi thành dòng V-0xx trong `docs/VPS_TASKS.md`.
  - Người chơi bảo phiên VPS: *"làm việc mới nhất trong docs/VPS_TASKS.md"*.
  - Kiểm `https://clashborn.quest/api/health` (commit đang chạy).
  - Proxy của phiên Claude đã gắn sẵn mã quản trị cho `clashborn.quest`, nên `/api/admin/*` gọi thẳng được.
- **Chụp màn hình kiểm hình:**
  - `xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan [--fixed-fps 30] -s .local/X.gd`.
  - Mẫu script có trong `.local/`: `selectshot.gd`, `newhero_shot.gd`, `onlineshot.gd`, `killshot.gd`.
- **Bí mật:**
  - Không bao giờ commit / dán khóa.
  - Mật khẩu Gmail, Google OAuth và mã quản trị chỉ nằm ở `/etc/clashborn/` trên VPS.
  - Không đưa email người chơi ra ngoài.

## 2. Codex CLI (vẽ ảnh: chân dung, icon, ảnh toàn thân)

Mỗi phiên mới là một máy mới, nên phải **đăng nhập lại Codex**:
- Người chơi gõ trong phiên mới: `! codex login --device-auth`.
- Mở đường link hiện ra (trên điện thoại cũng được), nhập mã, đăng nhập ChatGPT.
- Kiểm: `codex login status`.

Codex có công cụ tạo ảnh (`image_generation`). Cách gọi đã dùng:

```bash
codex exec --sandbox workspace-write --skip-git-repo-check -C /home/user/clash-born-v2 "Dùng công cụ tạo ảnh … Lưu PNG vào art_inbox/…"
```

Chạy nhiều luồng song song (`&` … `wait`), mỗi ảnh khoảng 2–4 phút. Mẫu lệnh nằm ở mục "Hình" bên dưới.

## 3. Trạng thái hiện tại

- **Đợt 1 tướng mới xong (D-347), bản 0.1.607 đã lên VPS:**
  - Tướng: Huyết Cự Nhân, Phong Tiễn, Thợ Săn, Thạch Giáp. Đồ: Gậy Đẩy.
  - Cơ chế mới STAT-06 (modifier theo thuộc tính).
  - Thiết kế: `docs/CONTENT.md` (cuối file). Kế hoạch: `docs/plans/D-347_tuong_moi.md`, đã có câu trả lời người chơi.
- **Mô hình 3D của 4 tướng còn tạm mượn tướng cũ** (`assets/models/units_3d.json`, trường `_tam`).
- **Chơi online (M9.6) chạy được**, nhưng VPS hiện tại cách VN ~200 ms nên lag. Người chơi **đã thuê VPS Singapore** (mục 4).
- **V-014 chưa làm.** Máy chủ phòng phải cập nhật lên dữ liệu tướng mới; dấu vân tay `2-f93e3e9b8f8d1cbb`.

## 4. Việc tiếp theo (theo thứ tự)

0. **Phong Tiễn chạy, cung lệch vào chân — CHỜ NGƯỜI CHƠI CHỌN (D-351):**
   - Đã gửi video `art_inbox/3d/phong_tien/preview/phong_tien_run_options.mp4` (A hiện tại / B giơ cung ngang vai / C cung sát
     người / D tay ngắm; ba góc nhìn). Tư thế đứng không đổi. Game chưa đổi.
   - Người chơi chọn xong: sửa dòng `phong_tien` trong `tools/models/build_units.py`, `Run_Female=run` thành
     B `Run_Female&Bow_Walk#clavicle_l=run` / C `Run_Female&Idle_Torch#clavicle_l=run` / D `Run_Female&Bow_Aim_Idle#clavicle_l=run`
     → `python3 -I tools/models/build_units.py phong_tien` → quay trong trận → bản Android mới.
   - Công cụ: `tools/models/glb_overlay.py` (ghép nhánh xương), `tools/models/preview/anim_compare.gd` (quay cạnh nhau),
     `tools/models/preview/bow_clearance.gd` (đo hở cung ↔ chân). Các script `.local/` cũ đã mất theo máy — đừng tìm.
     GLB 593 hoạt ảnh nạp thẳng vào Godot rất chậm (> 10 phút): luôn lọc bằng `glb_anims.py --keep` trước.
1. **Ảnh toàn thân 4 tướng đợt 1 — ĐÃ GỬI bảng `_bang_duyet_than.png`, CHỜ DUYỆT** (kèm `thach_giap_body_v2.png`: Thạch Giáp bỏ áo choàng dài cho dễ dựng 3D; Thợ Săn còn rìu đeo hông + mũ sói — hỏi người chơi có giữ không). Phong Tiễn ĐÃ XONG 3D (chuẩn D-348); còn Huyết Cự Nhân, Thợ Săn, Thạch Giáp — làm y quy trình mục 5.
   - Người chơi yêu cầu: *gửi ảnh thân để duyệt trước lúc làm 3D*.
   - Ảnh ở `art_inbox/concepts/body/<id>_body.png`; nếu thiếu thì vẽ lại bằng Codex, theo đúng chân dung đã duyệt, mặt trước, tư thế chữ A, nền trắng.
   - Gửi người chơi duyệt (SendUserFile, ghép bảng như `art_inbox/concepts/_bang_duyet.png`). Sửa theo ý họ.
   - **Chỉ khi đã duyệt** mới dựng 3D:
     - Tripo (`TRIPO_API_KEY` trong biến môi trường) → retarget xương Creature như các tướng cũ;
     - xem `tools/models/` và ART.md; hoạt ảnh qua Mixamo (`mixamo_pack.py`, `retarget.py`).
   - Thay mục `_tam` trong `units_3d.json`.
2. **Máy chủ phòng ở Singapore — đã viết xong phần repo (D-352), chờ người chơi:**
   - Người chơi: tạo bản ghi A `sg.clashborn.quest` → IP VPS Singapore; mở phiên Claude Code trên VPS đó, bảo *"làm V-015 trong
     docs/VPS_TASKS.md"* (cài lần đầu, từng lệnh).
   - Kiểm từ phiên cloud: `curl -s https://sg.clashborn.quest/rooms-health` (commit + dấu vân tay). Đúng dấu vân tay bản game
     thì mới đổi hằng `URL` trong `app/net/online_session.gd` → `wss://sg.clashborn.quest/play` + ra bản Android.
   - Mỗi lần SIM / nội dung đổi phải cập nhật CẢ HAI máy: VPS chính `update.sh`, VPS SG `update_rooms.sh`.
3. **Cân bằng + lỗi bot (D-353):**
   - BOT-11 ở RALLY: **đã sửa** (lỗi có từ trước, không do tướng mới). BOT-11 ở ESCAPE_TOWER: chưa sửa, cách tái hiện trong
     ROADMAP mục "Sau M8".
   - Phong Tiễn: số liệu trong ROADMAP; chờ người chơi chọn hướng giảm (đề xuất: tốc chạy 290 → 270, hoặc Q né 100% → 3 s còn
     2 s). Sửa trong `content/`, chạy lại `tools/bot_matches.gd --full --pairs=phong_tien:noctis,phong_tien:brakk,myra:phong_tien`
     (mỗi trận 3–10 phút máy; chạy nền nhiều tiến trình).
   - Bản game chưa ra lại sau D-353 (SIM đổi) — ra bản Android + `update.sh` VPS khi gom đủ thay đổi.
4. **Đợt 2** (cơ chế mới, theo AGENTS mục 3: luật → DECISIONS → code một chỗ → test từng dòng):
   - tướng 1 Thiết Vệ: trạng thái TAUNTED, bộ đếm "cứ 4 đòn bị đánh";
   - tướng 8 Pháo Thủ: nội tại bắn 2 phát;
   - Thương rồng: modifier chỉ cho tướng đánh xa.
5. **Đợt 3:**
   - tướng 2 Trí Tàng: INT vĩnh viễn khi hạ, chuỗi chiêu ×2..×4;
   - tướng 6 Bùa Ảnh: lấy chỉ số tạm 10–50 s; R tàng hình không gì lộ + hồi máu / tốc chạy khi địch không thấy.
   - Sách và bùa bay quanh không đưa vào mô hình 3D, làm thành mảnh nhỏ bay quanh / hiệu ứng.
6. Còn trong ROADMAP:
   - M9.7: rớt mạng → bot đánh thay.
   - M9.8: vào lại trận.
   - ST.5: máy chủ tự ghi trận online.
   - Cân bằng Duy Anh.

## 5. Quy trình 3D tướng mới — CHUẨN = Phong Tiễn (D-348, đọc kỹ dòng D-348 trong DECISIONS)

Tờ 3 góc tay không + vũ khí riêng (người chơi duyệt) → Tripo → afk.ai → gắn vũ khí → chọn hoạt ảnh bằng ảnh dải → build_units →
video xem trước gửi người chơi. Tránh áo choàng / vạt dài (khó dựng). Công cụ: `tools/tripo_gen.py`, `tools/split_turnaround.py`,
`tools/models/{glb_yaw,place_prop,glb_anims,build_units}.py`, `npx afk-rig`, `.local/{glbshot,animreel,ptrec}.gd`.

## 6. Hình (mẫu lệnh Codex đã chạy tốt)

- **Chân dung:**
  - Ảnh chuẩn DUY NHẤT `assets/art/brakk_portrait.png`.
  - Chỉ đầu + vai, đầu khoảng 40–45% khung, nhìn 3/4 sang phải, viền đậm, nền trong suốt.
  - Người chơi chê "đầu to quá" ở bản đầu.
- **Icon chiêu:**
  - Mẫu `assets/art/brakk_q.png`: huy hiệu tròn, viền vàng cho chiêu chủ động, viền bạc cho nội tại.
  - Lưu vào `art_inbox/icons/`, rồi thu 256×256 vào `assets/art/<art_id>.png`.
- **Ảnh toàn thân:** theo chân dung đã duyệt, mặt trước, tư thế chữ A, thấy cả bàn chân, nền trắng (để Tripo dựng 3D).
