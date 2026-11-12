# Câu chờ người chơi quyết (CB-0 giữ, cập nhật mỗi khi có câu mới / câu được trả lời)

Trả lời gọn theo mã, vd `N1 ok, N2 B, M1 ok`. "Đề nghị" = phương án phiên làm việc + CB-0 nghiêng về.

## Gấp — chặn việc ra bản game mới

| Mã | Câu hỏi | Đề nghị | Trả lời |
|---|---|---|---|
| N1 | Thứ tự máy chủ phòng: Singapore trước, máy chính dự phòng; chuyển máy khi không nối được / quá 6 s / lệch phiên bản; sai phiên đăng nhập thì báo luôn; sảnh hiện tên máy, dự phòng ghi "(trễ cao)" (NET-13, NET-14) | Duyệt | **Đổi hướng (2026-11-12):** tự chọn máy chủ theo độ trễ đo được (sau này có máy US thì người ở US tự vào máy US), có chỗ chọn tay nếu người chơi muốn; máy không nối được thì thử máy kế |
| N2 | Mã phòng: **A** giữ 5 chữ số, game tự dò máy (có xác suất nhỏ vào nhầm phòng) / **B** chữ số đầu chỉ máy chủ (SG 1–5, chính 6–9; phải cập nhật cả hai máy chủ, bản cũ bị từ chối) (NET-15) | B | **B**, mã toàn số (dễ gõ trên điện thoại): 6 chữ số, chữ số đầu = máy chủ (1 Singapore, 2 máy chính, 3… cho máy mới) |
| N3 | "Máy chủ bận" (thử lại 2 lần rồi rơi dự phòng) thay cho báo sai "Phiên hết hạn"; máy chính miễn giới hạn `/api/auth/` cho IP máy SG | Duyệt cả hai | Duyệt cả hai |

## Sớm

| Mã | Câu hỏi | Đề nghị | Trả lời |
|---|---|---|---|
| M1 | Bấm đi tới điểm đứng được nhưng không có đường tới đúng điểm (sát mép vách) → hiện nhân vật không nhích. Luật mới MOV-09: đi tới ô đi được gần điểm đó nhất | Duyệt | Duyệt — đi tới ô đi được gần điểm đó nhất |
| P1 | Giảm Phong Tiễn? Ma trận 216 trận (hiện tại / tốc 270 / Q né 2 s / cả hai, SIM 23dabc5): tổng thắng-thua-chưa xong 27/16/11 · 27/18/9 · 26/17/11 · 28/16/10 — cả ba phương án gần như không đổi bên thắng ở cặp nào; Gorran và Duy Anh thắng 6/6 ở mọi bản, Noctis và Vexa thua 6/6 ở mọi bản; tốc 270 làm cặp Myra từ 2/4 thành 0/6 | **Giữ nguyên** 290 và Q 3 s; CB-2 tìm nguyên nhân thật của các cặp 6/0 (có thể là lỗi bot) | |
| A1 | Tướng chuẩn về style (bảng kiểm kê: https://claude.ai/artifact/B8Dux87FGphzoHgvuHkyJ4). Tướng đang chia hai họ tỉ lệ: mập 3–4,5 đầu (Brakk, Noctis, Duy Anh, Gorran) và mảnh 6–6,5 đầu (Myra, Vexa, Phong Tiễn). Chọn: **Brakk** (mập; dựng lại 3 tướng mảnh) / **Gorran** (giữa hai họ; chỉnh cả hai bên, mỗi bên ít hơn) / **Phong Tiễn** (mảnh; làm lại nhiều nhất, khó đọc nhất trong trận) | CB-1 đề nghị Brakk | |
| A2 | Mức tam giác chuẩn cho tướng (3k / 6k / 12k, giữ xương ngón tay) | Chờ video thử của CB-1 | |
| A4 | Cảnh vật (ảnh trước / sau ở mục "Đề xuất chuẩn" của trang kiểm kê): **PA1** lá cây về phía đá-đất — lá có vân nét cọ, tông trầm, tướng và lính nổi hơn (chưa đo fps trên máy thật) / **PA2** đá về phía lá — đá bỏ vân, nhẹ máy nhất nhưng lệch với mặt đất, vách, trụ | PA1 | |
| A5 | Khung icon: **PA1** khung dày, chiêu cuối viền đôi (về sau vẽ lại dần 24 icon của 6 tướng đầu) / **PA2** viền mảnh (vẽ lại 16 icon của 4 tướng mới). Cả hai: đóng khung lại toàn bộ bằng công cụ, vẽ lại 4 chân dung (Duy Anh, Myra, Vexa, Noctis) | PA1 | |
| A6 | Thu nhỏ lá cam / lá xanh (đang to bằng nửa tướng) | Có | |
| A3 | Thạch Giáp: bản có áo choàng hay bản `thach_giap_body_v2.png` bỏ áo choàng; Thợ Săn giữ rìu đeo hông + mũ sói không | Bản bỏ áo choàng | |

## Online: rớt mạng / vào lại (kế hoạch CB-3, `docs/plans/M9_7_M9_8.md`)

| Mã | Câu hỏi | Đề nghị | Trả lời |
|---|---|---|---|
| R1 | Im lặng bao lâu thì coi là rớt và bot đánh thay | 5 giây, bot độ khó Thường | Duyệt (5 giây, bot Thường) |
| R2 | Người chủ động thoát có được vào lại không | Có, như người rớt mạng | Được vào lại; tài khoản đang có trận chưa xong thì không vào / tạo phòng khác (chống vào nhiều trận rồi thoát phá game) — cách hiểu của CB-0, chờ người chơi xác nhận |
| R3 | Trận mà mọi người đều rớt: chạy tiếp bằng bot rồi hủy; có tính thống kê không | Không tính | Hủy, không tính |
| R4 | Ô do bot đánh thay lúc kết thúc có tính thắng / thua cho tài khoản đó | Có, kèm cờ "đã rời" | Tính thắng / thua bình thường, trừ khi tất cả người chơi đã thoát |
| R5 | Máy bị lệch trận: bot đánh thay người đó ở các máy còn lại + tự gửi báo lỗi | Duyệt | Duyệt |
| R6 | Vào lại trận bằng cách tua lại toàn bộ lệnh (đo trên máy tính bảng Android BTKR-W09: trận đã đánh 5 phút ≈ 1 phút chờ, 10 phút ≈ 2–2,5 phút, 20 phút ≈ 4–5 phút; điện thoại yếu hơn sẽ lâu hơn); chỉ làm "ảnh chụp trạng thái" nếu quá chậm | Duyệt | Duyệt |
| R7 | Tách "tìm trận tự động" và "5v5" khỏi M9.8 thành việc riêng | Duyệt | Duyệt |

## Đợt 2 tướng mới (kế hoạch CB-2, `docs/plans/D-382_dot_2.md`) — chưa gấp

| Mã | Câu hỏi | Đề nghị | Trả lời |
|---|---|---|---|
| T1 | Thương Rồng: +12 AGI, +10 STR, +140 tầm đánh (chỉ tướng đánh xa), ~1900 vàng; tướng cận mua được nhưng không nhận tầm | Duyệt | |
| T2 | Khiêu khích (TAUNTED): xuyên miễn phép; chỉ thanh tẩy mạnh gỡ; kháng hiệu ứng rút ngắn; công trình và boss không bị | Duyệt | |
| T3 | Thiết Vệ nội tại "hồi 0,1% máu": hiểu là mỗi tầng +0,1% máu tối đa / giây (16 tầng = 1,6% / s); "−2% sát thương nhận" cộng dồn (16 tầng = −32%) | Duyệt cách hiểu này? | |
| T4 | Pháo Thủ bắn phát thứ hai: khi người bắn bị choáng / mục tiêu chết / ra khỏi tầm trong lúc chờ → hủy (Dota thì vẫn bắn) | Hủy | |
| T5 | Bộ số đề xuất của Thiết Vệ và Pháo Thủ (trong file kế hoạch) | Xem file rồi duyệt / sửa | |
