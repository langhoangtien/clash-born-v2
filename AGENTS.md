# Quy tắc làm việc — Clashborn v2

Áp dụng cho mọi AI agent và cho cả người. Đọc hết trước khi làm việc đầu tiên.

## 1. Đọc gì trước

1. `docs/GAME_RULES.md` — luật chơi. Hành vi nào không có ở đây thì chưa được phép tồn tại.
2. `docs/ARCHITECTURE.md` — tầng, thư mục, mô hình dữ liệu, cách mở rộng.
3. `docs/ROADMAP.md` — việc nào đang làm, tiêu chí xong của nó.
4. `docs/DECISIONS.md` — các quyết định đã chốt; không làm ngược lại.
5. `docs/CONTENT.md` — khi làm việc liên quan tới hero, skill, talent, trang bị.
6. `docs/ART.md` — khi làm việc phần hình ảnh, hoạt ảnh, giao diện.

## 2. Quy trình một việc

```
1. Nhận đúng MỘT việc trong ROADMAP (vd M2.3).
2. Lập kế hoạch, CHƯA sửa code:
   - mã luật liên quan (vd CRP-01..08)
   - file sẽ tạo / sửa / xóa
   - test sẽ viết (tên theo mã luật)
   - luật nào còn mơ hồ → hỏi lại, không tự đoán
3. Người duyệt kế hoạch.
4. Viết test trước → chạy thấy đỏ.
5. Viết code → chạy toàn bộ test (tools/run_tests.ps1).
6. Báo cáo: test xanh/đỏ trước và sau, file đã đổi, việc còn lại ghi vào ROADMAP.
```

Một việc = một nhánh git = một commit gộp khi xong. Nhánh `main` luôn xanh.

## 3. Bốn loại thay đổi và cách làm từng loại

| Loại | Ví dụ | Làm gì | Có sửa code? |
|---|---|---|---|
| **Số cân bằng** | Tăng máu trụ, đổi hồi chiêu | Sửa file trong `content/` | Không |
| **Nội dung mới** | Hero mới, món đồ mới, skill/talent ghép từ cơ chế có sẵn | Thiết kế trong CONTENT.md → thêm file `content/` → test kịch bản cho mỗi skill và talent | Không |
| **Cơ chế mới** | Tàng hình lần đầu, khiên chặn sát thương, kéo/đẩy | (1) viết luật + bảng tương tác vào GAME_RULES, (2) ghi DECISIONS, (3) code đúng một hệ thống/Action/State, (4) test từng dòng bảng tương tác, (5) mới thêm nội dung dùng nó | Có, một chỗ |
| **Sửa lỗi** | Lính đứng yên cạnh trụ | (1) xác định luật bị vi phạm (mã), (2) viết test tái hiện, đỏ, (3) sửa, xanh. Không có luật nào nói hành vi đúng là gì → đó là lỗi của luật, sửa GAME_RULES trước | Có |

Nếu "nội dung mới" mà phải sửa code thì nó thực chất là "cơ chế mới". Dừng lại và
làm theo dòng cơ chế mới.

## 4. Luật cứng về code

**Kiến trúc**
- SIM không import gì từ `view/` hay `app/`. SIM không dùng Node, `Time`, `OS`,
  `randf()` toàn cục, input, tín hiệu UI.
- VIEW chỉ đọc World. Muốn thay đổi trận đấu → tạo Command.
- Mỗi hệ thống chỉ ghi phần dữ liệu của mình (ARCHITECTURE mục 4).
- Không đổi chỉ số trực tiếp; chỉ qua Modifier.
- Không kiểm tra hiệu ứng theo id trong code (`has_effect("stun")`); hỏi state qua `Rules.*`.
- **Không `if hero_id == ...`, `if ability_id == ...`, `if item_id == ...` trong code.**
  Khác biệt giữa hero/kỹ năng/đồ phải nằm trong dữ liệu.
- Không hệ thống song song: thay thế thứ gì thì xóa cái cũ trong cùng việc.
- SIM và `content/` không chứa đường dẫn file hình; hình tra theo id qua `ArtLibrary`.

**Dữ liệu**
- Mọi con số gameplay nằm trong `content/`. Code không chứa số ma thuật, trừ hằng
  số kỹ thuật (kích thước ô lưới…) có ghi chú.
- Trạng thái đơn vị là class có kiểu, không dùng Dictionary.

**Phong cách GDScript**
- Gõ kiểu tĩnh mọi nơi (`var x: int`, `-> void`, `Array[Entity]`).
- Một file ≤ 300 dòng, một hàm ≤ 40 dòng. Vượt thì tách.
- Tên tiếng Anh trong code; tài liệu và chú thích người đọc tiếng Việt được.
- Chú thích ghi mã luật khi code thực thi một luật: `# CRP-05`.
- Duyệt đơn vị theo `id` tăng dần; RNG chỉ lấy từ `world.rng`.
- SIM không đọc `Time`, `Input`, `OS`, `randf()`/`randi()` toàn cục, delta khung hình hay
  bất cứ thứ gì ngoài World và Command. Mọi thời gian tính bằng tick (D-30).

**Test**
- Tên test chứa mã luật: `test_CRP_05_creep_stops_before_next_tower`.
- Mỗi luật có ít nhất một test. Mỗi lỗi đã sửa có một test tái hiện.
- Không sửa test cho xanh khi chưa hiểu vì sao nó đỏ. Test sai thì nói rõ vì sao.

## 5. Định nghĩa "xong" (cho mọi việc)

- [ ] Tiêu chí xong trong ROADMAP đạt.
- [ ] `tools/run_tests.ps1` xanh toàn bộ, không chỉ test mới.
- [ ] GAME_RULES / ARCHITECTURE cập nhật nếu hành vi hoặc cấu trúc đổi.
- [ ] DECISIONS có dòng mới nếu có quyết định thiết kế.
- [ ] Không còn code chết, code cũ bị thay thế, TODO không có việc tương ứng trong ROADMAP.
- [ ] Mốc có ghi "chơi thử": người duyệt đã chơi.

## 6. Khi gặp tình huống không có trong luật

Dừng, mô tả tình huống, đề xuất 1–2 phương án luật kèm mã mới, chờ duyệt.
**Không tự nghĩ ra hành vi rồi code.** Đây là nguồn gốc lỗi chồng chéo của v1.

## 7. Chạy game và test

Chạy game: `tools\run_game.ps1` (import trước rồi mới chạy; bắt buộc sau khi có script
mới, nếu không Godot báo `Identifier "..." not declared` vì danh sách class_name cũ).

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
```

Chạy một phần: thêm `-Filter CRP_05` (lọc theo tên file:tên test), `-VerboseTests` để
in từng test. Godot lấy từ `-Godot`, biến môi trường `GODOT`, hoặc đường dẫn mặc định
trong script. Mã thoát: 0 xanh, 1 đỏ, 2 không có test nào chạy, 3 không thấy Godot.
Trên Linux/macOS: `GODOT=... tools/run_tests.sh [--filter=...] [--verbose]`.

Viết test: file `tests/**/test_*.gd`, `extends TestCase`, mỗi hàm `test_*` là một test;
có `assert_true/false/eq/ne/near` và `fail`. Lỗi script trong test cũng tính là đỏ.
`tests/fixtures/` chứa file cố ý sai cho chính khung test, không tự chạy.
