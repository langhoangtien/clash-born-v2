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

1. **Ảnh toàn thân 4 tướng đợt 1, duyệt trước khi làm 3D.**
   - Người chơi yêu cầu: *gửi ảnh thân để duyệt trước lúc làm 3D*.
   - Ảnh ở `art_inbox/concepts/body/<id>_body.png`; nếu thiếu thì vẽ lại bằng Codex, theo đúng chân dung đã duyệt, mặt trước, tư thế chữ A, nền trắng.
   - Gửi người chơi duyệt (SendUserFile, ghép bảng như `art_inbox/concepts/_bang_duyet.png`). Sửa theo ý họ.
   - **Chỉ khi đã duyệt** mới dựng 3D:
     - Tripo (`TRIPO_API_KEY` trong biến môi trường) → retarget xương Creature như các tướng cũ;
     - xem `tools/models/` và ART.md; hoạt ảnh qua Mixamo (`mixamo_pack.py`, `retarget.py`).
   - Thay mục `_tam` trong `units_3d.json`.
2. **Máy chủ phòng ở Singapore** (giảm lag online):
   - **DNS:** bản ghi A `sg.clashborn.quest` → IP VPS Singapore (người chơi làm ở nơi mua tên miền, hoặc nhờ phiên VPS).
   - **Trên VPS Singapore** (một việc V-0xx mới, viết kỹ từng lệnh như V-007):
     - cài Godot 4.7.2 đúng bản (kiểm SHA512);
     - clone repo, chỉ chạy `clashborn-rooms` (xem `tools/vps/clashborn-rooms.service`, `server/main.gd`) với `--api=https://clashborn.quest` (kiểm phiên đăng nhập qua máy chủ chính, `server/api_auth.gd`);
     - nginx + certbot cho `sg.clashborn.quest`, `location = /play` → `127.0.0.1:8790` (giống nginx của VPS chính).
     - Nên có script cập nhật riêng chỉ cho máy chủ phòng (vd `tools/vps/update_rooms.sh`).
   - **Game:** `app/net/online_session.gd` hằng `URL` → `wss://sg.clashborn.quest/play`. Chỉ đổi khi SG đã chạy và đúng dấu vân tay; có thể giữ máy cũ làm dự phòng.
   - Thống kê, tài khoản, web vẫn ở VPS chính.
3. **Cân bằng + lỗi bot.** Trận bot đấu bot (`tools/bot_matches.gd --full --pairs=…`):
   - Phong Tiễn có vẻ quá mạnh: thắng Brakk ở phút 18 / 32, thắng Noctis ở phút 13.
   - Có lỗi **BOT-11** (bot đứng yên > 2 s ở chế độ RALLY) ở vài trận, cả với Brakk / Noctis. Xem có xảy ra ở cặp tướng cũ không (vd `brakk:noctis`) để biết lỗi do tướng mới hay có từ trước.
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

## 5. Hình (mẫu lệnh Codex đã chạy tốt)

- **Chân dung:**
  - Ảnh chuẩn DUY NHẤT `assets/art/brakk_portrait.png`.
  - Chỉ đầu + vai, đầu khoảng 40–45% khung, nhìn 3/4 sang phải, viền đậm, nền trong suốt.
  - Người chơi chê "đầu to quá" ở bản đầu.
- **Icon chiêu:**
  - Mẫu `assets/art/brakk_q.png`: huy hiệu tròn, viền vàng cho chiêu chủ động, viền bạc cho nội tại.
  - Lưu vào `art_inbox/icons/`, rồi thu 256×256 vào `assets/art/<art_id>.png`.
- **Ảnh toàn thân:** theo chân dung đã duyệt, mặt trước, tư thế chữ A, thấy cả bàn chân, nền trắng (để Tripo dựng 3D).
