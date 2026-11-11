# Kế hoạch D-347 — 8 tướng mới + 2 món đồ (chờ duyệt)

Ý tưởng của người chơi (2026-11-11), Claude phân loại theo AGENTS mục 3:
- **C** = ghép từ cơ chế có sẵn (chỉ thêm `content/` + test kịch bản).
- **M** = **cơ chế mới**: viết luật + bảng tương tác vào GAME_RULES, ghi DECISIONS, code đúng một chỗ, test từng dòng.

Tên tướng là tạm (đặt khi làm). Game có Q, W, R + nội tại, nên "skill 3" của người chơi = **R** (chiêu cuối, mở ở cấp 6 / 11 / 16).

## Cơ chế đã có, dùng lại được

- Hiệu ứng cộng dồn: REFRESH / STACK / INDEPENDENT, mỗi tầng hết hạn riêng.
- Trigger theo sự kiện, gồm "bị đánh" và "đánh trúng".
- Biểu thức số theo chỉ số (STR / AGI / INT của mình và của mục tiêu).
- Các chỉ số né, giảm sát thương, tầm đánh.
- Các action:
  - lướt, đẩy (`push_action`, chưa món nào dùng);
  - giải (`dispel` / `purge`), vùng, vùng trễ (cảnh báo mặt đất);
  - Quyết Đấu (D-135: ép hai bên đánh nhau);
  - đốt mana, dịch chuyển.
- Trạng thái: choáng, trói, câm, tàng hình, lộ, …
- Bụi lộ hình (`reveal_dust`), mắt xanh.

## Từng tướng

| # | Tướng | Nội tại | Q | W | R | Cơ chế mới |
|---|---|---|---|---|---|---|
| 1 | Tanker STR | đánh trúng: +10% tốc đánh, 20 tầng, mỗi tầng 2 s — **C** (hoặc phương án b: −2% sát thương nhận + hồi 0,1% máu, 16 tầng — C) | Khiêu khích AoE: địch quanh mình buộc đánh mình (kiểu Axe) — **M: trạng thái TAUNTED** | +30% tốc chạy, +6–14 giáp, 3–5 s — C | cứ 4 đòn bị đánh → phản sát thương xung quanh — **M: bộ đếm đòn** | TAUNTED, bộ đếm đòn |
| 2 | Pháp sư INT | hạ hero: +1/1/2/2/3 INT vĩnh viễn — **M: chỉ số vĩnh viễn từ sự kiện** | sát thương AoE theo INT + chậm 15%; dùng chiêu khác trong lúc hiệu ứng còn → x2 sát thương / chậm, tối đa x4 — **M: chuỗi chiêu** | ném, sát thương thuần theo % INT — C | (INT mình − INT nó) × 3/4/5 — C (biểu thức) | cộng vĩnh viễn, chuỗi chiêu |
| 3 | Phong Tiễn AGI (đánh xa) | +tốc đánh = 60% AGI — C | +25% tốc chạy, né 100% đòn đánh 3 s — C | gió độc: chậm + câm — C | +25/35/45 AGI thường trực (R bị động) — C | không |
| 4 | Huyết Cự Nhân STR | +5/7/9/11 máu mỗi STR — C | AoE vật lý theo STR, tự mất máu — C | phản 10–25% STR mỗi lần bị đánh (vật lý) — C (trigger bị đánh) | dậm 550, choáng 1,5–2,5 s, 150–350 + 100% STR, hồi 90–70 s, tung 0,6 s có cảnh báo — C | không |
| 5 | Ganker STR | không có nội tại: 5 điểm nội tại = +2 mọi thuộc tính mỗi điểm (tổng +10) — C (nội tại bị động cộng chỉ số) | đơn mục tiêu + chậm — C | câm 1 hero — C | bật: +tốc chạy, +tốc đánh, +sát thương ngắn — C | không |
| 6 | Thợ săn bùa (kiểu Slark) | mỗi đòn đánh: lấy 2 thuộc tính chính của địch thành 2 AGI của mình (hoặc 1 STR + 1 AGI + 1 INT → 3 AGI) — **M: lấy chỉ số** | nuốt bùa 1 s rồi giải liên tục 1 s, mỗi hiệu ứng xấu giải được +20 tốc đánh — **M nhỏ: đếm số hiệu ứng giải** | lướt tới, trúng mục tiêu đầu tiên → trói / chậm 3 s — C hoặc M nhỏ (lướt dừng khi chạm) | tàng hình **không bị gì lộ** (trụ, mắt xanh, bụi) + hồi máu + tốc chạy — **M: tàng hình tuyệt đối**, trái VIS hiện tại | lấy chỉ số, tàng hình tuyệt đối |
| 7 | Tanker | khiên: giảm sát thương sau giáp — C | dậm choáng AoE — C | chậm + giảm sát thương địch + gây sát thương — C | chạy tốc độ tối đa 3 s — C (+tốc chạy lớn; "tối đa" = trần tốc chạy) | không |
| 8 | Xạ thủ súng bom | tầm đánh tăng dần theo cấp — C | lựu đạn AoE + chậm 25% 3 s — C | bắn giảm giáp + thêm sát thương (bật) — C; hoặc nội tại bắn 2 phát — **M** | Headshot: ngắm 2 s, bắn 1 mục tiêu xa — C (tung chậm 2 s, bị ngắt thì hủy, ABL-03) | tùy W |

## Hai món đồ

- **Thương rồng** (cộng tầm đánh, chỉ tướng đánh xa, kiểu Dragon Lance): cộng tầm đánh có điều kiện "đánh xa". Đã có điều kiện `self_is_melee` cho trigger, nhưng chưa có cho modifier → **M nhỏ: modifier có điều kiện cận / xa**.
- **Gậy đẩy** (kiểu Force Staff): chủ động đẩy mục tiêu (mình / đồng minh / địch) 600 về phía nó đang nhìn → **C** (`push_action` có sẵn).

## Hình (phần tốn công nhất)

Mỗi tướng cần:
- mô hình 3D, theo quy trình cũ: Tripo → Mixamo → retarget;
- hoạt ảnh đánh / chiêu;
- chân dung, icon chiêu;
- hiệu ứng chiêu.

Mô hình chưa có thì tướng tạm dùng mô hình có sẵn đổi màu, để chơi thử cơ chế trước.

## Đề xuất thứ tự (mỗi đợt một nhánh việc, chơi thử rồi mới sang đợt sau)

1. **Đợt 1 — chỉ ghép, ít rủi ro:**
   - tướng 3, 4, 5, 7;
   - Gậy đẩy;
   - tướng 8 (nếu W chọn bản bật).
2. **Đợt 2 — cơ chế mới vừa:**
   - TAUNTED + bộ đếm đòn → tướng 1;
   - modifier điều kiện → Thương rồng.
3. **Đợt 3 — cơ chế mới khó:**
   - chỉ số vĩnh viễn + chuỗi chiêu → tướng 2;
   - lấy chỉ số + tàng hình tuyệt đối → tướng 6.

Mỗi đợt: số liệu vào CONTENT.md → test kịch bản từng chiêu → bot dùng được chiêu → chơi thử cân bằng (bot vs bot thống kê tỉ lệ thắng).

## Câu hỏi cho người chơi (chặn việc)

1. Tướng 1, nội tại: (a) tốc đánh +10% × 20 tầng, hay (b) giảm sát thương + hồi máu × 16 tầng?
2. Tướng 6, nội tại: (a) lấy 2 thuộc tính chính → 2 AGI, hay (b) 1 mỗi loại → 3 AGI? Phần lấy được giữ **tạm thời** (kiểu Slark, mất sau vài chục giây) hay **vĩnh viễn**?
3. Tướng 6, R: tàng hình không gì lộ được thì không có cách bắt. Đề xuất: không bị trụ / mắt / bụi lộ, nhưng **lộ khi đánh hoặc trúng sát thương**, thời gian ngắn (2–4 s). Đồng ý không?
4. Tướng 8, W: (a) bật bắn giảm giáp + thêm sát thương, hay (b) nội tại có tỉ lệ bắn 2 phát?

## Trả lời của người chơi (2026-11-11) — đã chốt

1. Tướng 1, nội tại: **(b)** mỗi đòn đánh trúng −2% sát thương nhận + hồi 0,1% máu, 16 tầng, mỗi tầng 2 s.
2. Tướng 6, nội tại: mỗi đòn đánh lấy của địch **2 thuộc tính chính + 1 mỗi thuộc tính phụ** → mình **+4 AGI**. **Tạm thời**: thời lượng
   10–50 s (tăng theo bậc nội tại 1→5: 10/20/30/40/50 s — Claude đề xuất, chốt khi làm), mỗi lần lấy hết hạn riêng.
3. Tướng 6, R: **như Slark** — tàng hình **không gì lộ được** (trụ, mắt xanh, bụi, đánh). Thêm bị động: khi **không nằm trong tầm nhìn
   của địch** thì tăng hồi máu + tốc chạy. (Cơ chế mới: tàng hình tuyệt đối + điều kiện "không bị địch nhìn thấy" theo VIS.)
4. Tướng 8, W: **(b)** nội tại có tỉ lệ bắn 2 phát liên tiếp (cơ chế mới: đòn đánh phụ ngay sau đòn chính).

Hình: người chơi muốn **Codex CLI tạo ảnh (chân dung / ý tưởng nhân vật) để duyệt** trước khi làm mô hình 3D.

## Tiến độ

- **Đợt 1 xong** (D-347):
  - Huyết Cự Nhân (4), Phong Tiễn (3), Thợ Săn (5), Thạch Giáp (7), Gậy Đẩy.
  - Cơ chế mới STAT-06 (modifier theo thuộc tính) cho nội tại 3 và 4.
  - Mô hình 3D còn tạm mượn tướng cũ.
- Tướng 8 (Pháo Thủ): người chơi chọn nội tại bắn 2 phát = cơ chế mới → **đợt 2** cùng tướng 1 (TAUNTED, bộ đếm đòn)
  và Thương rồng (modifier điều kiện đánh xa).
- Đợt 3: tướng 2, tướng 6.
- Còn lại cho mỗi tướng: mô hình 3D riêng (Tripo / Mixamo theo chân dung), hoạt ảnh chiêu.
