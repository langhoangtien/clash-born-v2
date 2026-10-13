# Nhật ký quyết định

Chỉ thêm dòng mới, không sửa dòng cũ. Đổi ý thì thêm quyết định mới ghi
"thay D-xx". Mỗi quyết định: bối cảnh ngắn, quyết định, hệ quả.

## Đã chốt

| Mã | Ngày | Quyết định | Lý do / hệ quả |
|---|---|---|---|
| D-01 | 2026-10-13 | Làm dự án mới `clashborn_v2`; mang sang công thức chiến đấu, dữ liệu 12 hero, trang bị và map từ v1. Không mang tầng trận đấu, AI, UI | v1 có lõi tốt nhưng tầng trận đấu chồng chéo, khó sửa dần |
| D-02 | 2026-10-13 | Godot 4.7.2, GDScript, renderer Compatibility, 2D flat vector, nhắm Android trước | Giữ công cụ quen thuộc; mobile là mục tiêu chính |
| D-10 | 2026-10-13 | Bản đầu v2 có **3 hero đầy đủ** (Brakk, Myra, Noctis) thay vì 12 hero 1 bị động. Trả lời D-03 | Lối chơi có chiều sâu; 3 bộ skill phủ toàn bộ cơ chế cần có, hero sau chủ yếu là dữ liệu |
| D-11 | 2026-10-13 | Mỗi hero: Q, W (5 cấp), R ultimate (3 cấp). Q/W cấp n cần hero cấp 2n−1; R ở cấp 6/11/16; điểm thừa đổi +2 mọi thuộc tính (tối đa 7 lần) | 13 + 7 = 20 điểm cho 20 cấp (ABL-04) |
| D-12 | 2026-10-13 | Cấp 20 chọn 1 trong 3 talent, mỗi talent nâng một skill lên tầng II; talent chỉ sửa giá trị có tên và thêm hành động, không đổi luật state | Talent là dữ liệu, không cần code riêng (TAL-01..04) |
| D-13 | 2026-10-13 | Bộ state định nghĩa luật từ đầu: STUNNED, ROOTED, SILENCED, DISARMED, INVISIBLE, REVEALED, INVULNERABLE, GHOST, UNTARGETABLE, DEAD; code khi hero đầu tiên cần | Định nghĩa sớm thì rẻ và tránh chồng chéo; code muộn để có test thật |
| D-14 | 2026-10-13 | Thêm `docs/HEROES.md` làm tài liệu thứ 6 (thiết kế nội dung hero) | Bộ skill cần chỗ thiết kế trước khi thành dữ liệu; vẫn cấm tạo thêm tài liệu khác |
| D-15 | 2026-10-13 | Bot dùng skill theo loại (`bot_usage`), không viết logic cho từng skill | Thêm hero không phải sửa bot (BOT-13) |
| D-16 | 2026-10-13 | Thêm hero thứ 4 **Vexa** (biến hình, đẩy lùi, tước hiệu ứng, xuyên miễn phép); thay một phần D-10 | Để mọi hiệu ứng trong luật đều có nguồn thật để code và test |
| D-17 | 2026-10-13 | Trang bị có kỹ năng chủ động/bị động dùng chung hệ AbilityDef/EffectDef với skill; bản đầu có 9 món (Gậy Hồn Ma, Giáp Bất Khuất, Ngọc Băng Sương…) | Không cần hệ thống riêng cho đồ (ITM-02) |
| D-18 | 2026-10-13 | Thêm state MAGIC_IMMUNE (kiểu BKB: miễn sát thương phép và debuff từ chiêu địch) và HEXED; thêm thanh tẩy 2 mức (EFF-07) | Theo yêu cầu; quy tắc kết hợp ở ST-17, PRI-05 |
| D-19 | 2026-10-13 | Đổi tên `HEROES.md` thành `CONTENT.md` (thêm trang bị); thêm `ART.md`; tổng 7 tài liệu, thay D-14 | Thiết kế nội dung và đồ họa cần chỗ riêng; vẫn cấm tạo thêm |
| D-20 | 2026-10-13 | Đồ họa: đặt chỗ hình ảnh (id, hợp đồng hoạt ảnh) từ M0; làm hình thật theo từng đợt sau khi lối chơi phần đó đã chốt; hoạt ảnh cắt ghép trên SVG | Không phí công vẽ thứ còn đổi; thay hình không đụng code (ART.md) |
| D-21 | 2026-10-13 | Đòn đánh có vung tay / thu tay kiểu Dota (CMB-06), hoạt ảnh chạy theo mô phỏng | Cảm giác đánh đúng và hình không làm lệch cân bằng |
| D-22 | 2026-10-13 | Mỗi hero có thêm một **nội tại** (bị động) tự lên 6 bậc theo cấp hero, không tốn điểm; Q/W cũng được phép là bị động | Có đủ nhóm cơ chế bị động mà không cần hero thứ 5 (ABL-11, 12) |
| D-23 | 2026-10-13 | Nội tại 4 hero: Brakk bash (kiểu Void), Myra cộng dồn tốc đánh (kiểu Troll), Noctis chí mạng (kiểu PA), Vexa hút Trí tuệ (kiểu Slark) | Phủ bash, chí mạng, cộng dồn có điều kiện mất, hút chỉ số |
| D-24 | 2026-10-13 | Xác suất của bị động dùng giả ngẫu nhiên PRD như Dota | Tránh chuỗi may/rủi trong 1v1 (RNG-01) |
| D-25 | 2026-10-13 | Phong cách đồ họa theo ảnh mẫu `docs/art/reference_style_01.png`: góc 3/4 nghiêng, chibi, raster PNG, y-sort; map giữ bố cục, đổi cách vẽ (rải cây theo polygon). Thay "flat vector" của D-02 | Theo yêu cầu; logic vẫn 2D nên không ảnh hưởng mô phỏng |
| D-26 | 2026-10-13 | Hoạt ảnh hero mặc định dùng cắt ghép (mảnh PNG + Skeleton2D); nguồn hình: asset mua sẵn + tạo ảnh AI + họa sĩ khi cần | Ít hình phải vẽ, hợp chibi, nhẹ cho điện thoại |
| D-27 | 2026-10-13 | Không làm hết bị động kiểu Dota ngay; làm **viên gạch** (vai trigger, biểu thức giá trị, sát thương phản hồi, đốt mana, vùng giảm dần, chặn chết) và kiểm thử bằng hero thử nghiệm chỉ có trong test | Bị động sau này chỉ là dữ liệu; không phải thiết kế hero hoàn chỉnh để test (CONTENT "Thư viện bị động") |
| D-28 | 2026-10-13 | Ảnh do Codex tạo theo phiếu `art_inbox/YEU_CAU_ANH.md` (6 đợt, có điểm dừng duyệt). Hero bản đầu: ảnh thân đơn + hoạt ảnh do code; cắt ghép nhiều mảnh để sau (thay một phần D-26) | Ảnh AI khó giữ nhân vật giống nhau qua nhiều mảnh/khung; ảnh đơn làm được ngay |
| D-29 | 2026-10-14 | Một trận nhắm **15–20 phút** (trả lời D-05). Hero 1v1 phải lên được cấp 20 khoảng phút 14–17 để talent có ý nghĩa | Quyết định máu trụ, XP, vàng, thời gian hồi sinh; đo bằng soak bot đấu bot (M7.5), chỉnh số trong NUM chứ không đổi luật |
| D-30 | 2026-10-14 | **Sẽ có chơi online người với người**, làm sau M8 (trả lời D-04). Từ bây giờ SIM phải xác định tuyệt đối: cùng seed + cùng nhật ký Command → cùng trạng thái từng tick. Chọn mô hình mạng (lockstep hay server quyết định) khi bắt đầu làm online | Không phải viết lại SIM khi làm online; có thêm lợi ích: phát lại trận để tái hiện lỗi |
| D-31 | 2026-10-14 | Chốt D-06..D-09 theo đề xuất: joystick + nút đánh tự chọn mục tiêu (PC: WASD + phím); kiến trúc ARCHITECTURE.md; luật GAME_RULES.md với số NUM khởi đầu; dùng `class_name` cho kiểu chính của SIM, `run_tests` luôn import trước | Hết mục chờ chốt; bắt đầu code từ M0.1 |
| D-32 | 2026-10-14 | Mang **công thức và con số** của v1 sang (chỉ số, sát thương, né), viết lại thành hàm thuần có kiểu trong `sim/core/`; không chép nguyên file. Tung xúc xắc trúng/chí mạng chờ PRD (M3.6b); bộ đếm tốc độ khung hình sang tầng APP | File v1 trả Dictionary, phụ thuộc lớp cũ và đọc thời gian khung hình — trái AGENTS mục 4 và D-30 |
| D-33 | 2026-10-14 | Né và chính xác đều nhân dồn nhiều nguồn; trượt = né × (1 − chính xác); bỏ trần né 75% của v1 (`evasion_cap` = 1.0) | Theo yêu cầu: 2 món né 50% → 75%; né 100% gặp 80% chính xác → trúng 80%; 2 món 80% → trúng 96% (CMB-11) |
| D-34 | 2026-10-14 | Thêm **nhóm duy nhất** `unique_group`: cùng nhóm chỉ nguồn mạnh nhất có tác dụng. Bash (hero + Búa Choáng), giày, bị động của 2 món giống nhau | Tránh cộng dồn quá mạnh hoặc quá hên xui; skill và đồ khác nhóm vẫn kết hợp (STAT-05) |
| D-35 | 2026-10-14 | Lên cấp chỉ cộng STR/AGI/INT; bỏ "sát thương mỗi cấp" của v1. Sát thương, máu, giáp, tốc đánh tăng qua thuộc tính | Giống Dota; một nguồn tăng trưởng duy nhất, dễ cân bằng (STAT-04) |
| D-36 | 2026-10-14 | Khuôn dữ liệu (M0.5): mỗi loại hành động một khuôn riêng; trong Def `String` = biểu thức, `StringName` = tên; id duy nhất toàn thư viện; `content/balance/` là thiết lập, không phải dữ liệu có id | Sửa trong Godot có ô đúng cho từng tham số; validator tự kiểm tra mọi khuôn theo quy ước, gõ sai tên bị test bắt |
| D-37 | 2026-10-14 | Bổ sung luật khi nhập 4 hero: vùng chữ nhật theo hướng (ABL-13); cờ của hành động là giá trị có tên (ABL-14); `removed_by` chỉ tính sự kiện do chủ hiệu ứng gây ra, trigger chạy trước khi xóa (EFF-05); điều kiện `this_effect_depleted`, `this_effect_ended` (EFF-08); tên gốc chọn bản `_melee`/`_ranged` (ITM-05) | Vexa W, Myra Q II, Noctis W, Brakk W II / R II, Ngọc Băng Sương và Búa Choáng cần; không thêm hệ thống mới |
| D-38 | 2026-10-14 | Chỉnh thiết kế để khỏi thêm cơ chế: Noctis Q II hồi Q khi Noctis hạ gục bất kỳ ai trong cửa sổ sau Q; Vexa R II đặt làm chậm = 0 và thêm trói 2 s; Búa Choáng dùng thời gian chờ bash chung (CMB-08) | Kết quả trong 1v1 như thiết kế cũ; xác suất và % lưu dạng phân số (0.15 = 15%) trong dữ liệu |

## Chờ chốt

Hiện không còn mục nào. Câu hỏi mới thêm vào bảng dưới, kèm đề xuất.

| Mã | Câu hỏi | Đề xuất |
|---|---|---|
| ~~D-03~~ | ~~Hero bản đầu: 1 bị động hay có chủ động?~~ | Đã chốt bằng D-10 |
| ~~D-04~~ | ~~Có định làm chơi online không?~~ | Đã chốt bằng D-30: có, sau M8 |
| ~~D-05~~ | ~~Thời lượng trận mục tiêu?~~ | Đã chốt bằng D-29: 15–20 phút |
| ~~D-06~~ | ~~Điều khiển: joystick + nút đánh tự chọn mục tiêu như Liên Quân?~~ | Đã chốt bằng D-31 |
| ~~D-07~~ | ~~Kiến trúc trong `ARCHITECTURE.md` (3 tầng, Entity có kiểu, Modifier, Effect/Trigger/Action dữ liệu)~~ | Đã chốt bằng D-31 |
| ~~D-08~~ | ~~Luật trong `GAME_RULES.md` (đặc biệt số trong bảng NUM)~~ | Đã chốt bằng D-31 |
| ~~D-09~~ | ~~Dùng `class_name` cho các kiểu chính của SIM (Entity, World…)~~ | Đã chốt bằng D-31 |
