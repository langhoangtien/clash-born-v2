# Phân công các phiên (D-354, 2026-11-12)

Đọc sau AGENTS.md. Áp dụng cho mọi phiên Claude làm dự án này.

## Các phiên

| Phiên | Việc | Được sửa | Nhánh | Dải số quyết định |
|---|---|---|---|---|
| **CB-0 Điều phối** | Giao việc, duyệt + gộp nhánh, ra bản Android, viết việc VPS, ROADMAP / BAN_GIAO | `docs/`, `export_presets.cfg` | `thu-asset-tu-lam` | D-354…D-359 |
| **CB-1 Art chuẩn** | Kiểm kê asset, art bible, thử số tam giác, mẫu chuẩn | `art_inbox/`, `assets/`, `tools/models/`, `tools/icons/`, `view/three/` (chỉ phần hình), `docs/ART.md` | `cb-1-art` | D-360…D-379 |
| **CB-2 Luật và bot** | Lỗi bot, cân bằng, cơ chế mới đợt 2 / 3 | `sim/`, `content/`, `tests/`, `tools/bot_matches.gd`, `docs/GAME_RULES.md`, `docs/CONTENT.md` | `cb-2-luat-bot` | D-380…D-399 |
| **CB-3 Online** | Máy chủ phòng, kết nối, rớt mạng / vào lại | `app/net/`, `server/`, `tools/vps/`, `tests/` phần net | `cb-3-online` | D-400…D-419 |
| **VPS chính**, **VPS Singapore** | Làm việc V-0xx trong `docs/VPS_TASKS.md` | Không sửa repo | — | — |

## Luật

1. **Chỉ đẩy lên nhánh của phiên mình.** Bắt đầu mỗi việc: `git fetch origin thu-asset-tu-lam` rồi rebase nhánh mình lên đó.
   Chỉ CB-0 đẩy lên `thu-asset-tu-lam`.
2. **Chỉ sửa cột "Được sửa" của mình.** Cần đổi chỗ khác → nhắn CB-0, không tự sửa.
3. **`docs/DECISIONS.md`:** mỗi phiên chỉ thêm dòng trong dải số của mình, thêm ở cuối file. `docs/ROADMAP.md`,
   `docs/plans/BAN_GIAO.md`, `docs/VPS_TASKS.md`: chỉ CB-0 sửa — phiên khác ghi nội dung cần thêm vào báo cáo.
4. **Chỉ CB-0 ra bản Android, đăng web, viết việc VPS.** SIM / nội dung đổi thì bản game và cả hai máy chủ phòng phải lên cùng lúc.
5. **Quy trình AGENTS mục 2 vẫn giữ.** Sửa lỗi có luật rõ và việc đã ghi tiêu chí: làm luôn. Cơ chế mới, luật mơ hồ, số cân
   bằng, thứ người chơi phải nhìn mới quyết (hình): dừng, gửi kế hoạch / phương án cho CB-0, chờ trả lời.
6. **Báo cáo khi xong một việc** — nhắn CB-0 bằng `send_message` (mã phiên CB-0 có trong lời giao việc): nhánh + commit, test
   xanh / đỏ trước và sau, file đã đổi, việc còn lại, thứ cần người chơi quyết. Ngắn, không dán log.
7. **Máy mới:** Godot 4.7.2 chưa có sẵn — cài theo `docs/VPS_TASKS.md` V-015 bước 2 (kiểm SHA512), `ln -s` vào `/usr/local/bin/godot`,
   rồi `godot --headless --path . --import`. Test: `GODOT=godot bash tools/run_tests.sh`. Codex phải đăng nhập lại
   (`codex login --device-auth`, đưa link + mã cho người chơi).
8. Không commit / dán khóa bí mật; không đưa email người chơi ra ngoài.
9. **Đổi `sim/`, `content/`, `data/maps/` hoặc `app/net/net_codec.gd` (D-403):** chạy `godot --headless --path . -s tools/vps/sim_source.gd`
   rồi commit `app/net/sim_source.json` cùng thay đổi (test `test_NET_10_sim_source_file_is_current` đỏ nếu quên). Gộp nhánh mà file
   này xung đột → chạy lại lệnh đó. Dấu vân tay NET-10 giờ đổi theo mọi thay đổi code luật / nội dung.

