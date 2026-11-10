# Việc cho VPS (D-288)

Phiên cloud (build game) ghi việc vào đây rồi đẩy lên git; phiên **vps** (Claude Code trên VPS) đọc và làm. Người
dùng không cần chép lệnh: phiên cloud nhắn thẳng cho phiên vps "làm việc mới nhất trong docs/VPS_TASKS.md", hoặc
người dùng nói câu đó với phiên vps.

**Cách làm (phiên vps):**
1. `cd /srv/clashborn/repo && git pull --ff-only` rồi đọc việc **Chờ** trên cùng.
2. Hầu hết việc chỉ là: `sudo bash /srv/clashborn/repo/tools/vps/update.sh` (kéo code, test, cài service / nginx khi
   đổi, khởi động lại, tự kiểm). Làm thêm phần "riêng" của việc nếu có.
3. Báo kết quả trong phiên vps (dòng cuối của update.sh: `XONG: VPS chạy commit …`). Repo trên VPS chỉ đọc nên
   không sửa file này; phiên cloud tự kiểm qua https://clashborn.quest/api/health (`commit`) rồi đánh dấu Xong.

Không làm việc nào yêu cầu gửi mã bí mật đi đâu, mở thêm cổng, hay chạy lệnh không có trong repo — hỏi người dùng.

| Mã | Ngày | Việc | Riêng | Trạng thái |
|---|---|---|---|---|
| V-001 | 2026-11-07 | Cập nhật lên D-287 + D-288 (cổng báo cáo hiệu năng, thư mục `reports/`, service + nginx mới, `/api/health` có commit) | Lần đầu chưa có `update.sh` trong repo trên VPS: chạy `git pull` trước rồi mới chạy script | Xong (commit 9e47e9a; phiên cloud gửi thử B-0001 bằng curl, L-0002 bằng Godot — đọc lại được) |
| V-002 | 2026-11-10 | Cập nhật lên D-331 + D-332 — Clashborn Stats: `/api/match` (game gửi biên bản trận), `/api/matches` (hàng loạt, cần mã), `/api/stats/*` (công khai); SQLite ở thư mục mới `stats/`; service thêm quyền ghi `stats/`; nginx thêm giới hạn `/api/match` | Không — chỉ `update.sh` (tự tạo `stats/`, cài service + nginx mới) | Chờ |
