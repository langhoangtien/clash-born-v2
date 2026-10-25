# Clashborn v2

MOBA 1v1 với bot cho mobile, kiểu Dota 2 đơn giản hóa. Godot 4.7.2, trận vẽ 3D góc nghiêng kiểu Liên Quân
(D-157, xem `docs/ART.md`).

## Chơi thử

- **Bản web** (máy tính, iPhone Safari): https://langhoangtien.github.io/clash-born-v2/
- **Bản Android** (APK, HarmonyOS 2–4): https://langhoangtien.github.io/clash-born-v2/clashborn.apk —
  bản đã cài tự báo khi có bản mới (D-148).

**Trạng thái:** xem `docs/ROADMAP.md` (việc gần nhất ở cuối bảng).

## Chạy game và test (Windows)

Sau mỗi lần `git pull`, chạy game **bằng script**, không mở thẳng file exe: script
cho Godot import trước để nhận các script mới (nếu không sẽ gặp lỗi
`Identifier "..." not declared`). Mở dự án trong Godot Editor cũng tự import.

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_game.ps1    # chạy game
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1   # chạy test
```

## Đọc theo thứ tự

| File | Để làm gì |
|---|---|
| `AGENTS.md` | Quy tắc làm việc cho agent và người: quy trình, 4 loại thay đổi, luật code, định nghĩa "xong" |
| `docs/GAME_RULES.md` | Luật chơi, mỗi luật có mã (`CRP-05`, `VIS-02`…) |
| `docs/ARCHITECTURE.md` | Cách code được tổ chức; ví dụ thêm hero tàng hình ở mục 6 |
| `docs/ROADMAP.md` | Các mốc M0–M8 và đồ họa A0–A5, việc nhỏ và tiêu chí xong |
| `docs/CONTENT.md` | Thiết kế 4 hero (skill, số theo cấp, talent, cách bot dùng) và 9 món đồ có kỹ năng |
| `docs/ART.md` | Phong cách đồ họa, hoạt ảnh, giao diện, lộ trình đồ họa |
| `docs/DECISIONS.md` | Quyết định đã chốt và đang chờ chốt |

Chỉ có 7 tài liệu này (D-19). Không tạo thêm tài liệu luật hay kế hoạch khác; cần
ghi gì thì thêm vào đúng một trong 7 file.
