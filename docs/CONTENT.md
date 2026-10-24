# Thiết kế nội dung: hero và trang bị

> Trạng thái: **ĐỀ XUẤT — chờ chốt số liệu sau khi chơi thử.**
> Đây là bản thiết kế nội dung. Số liệu thật nằm trong `content/heroes/`,
> `content/abilities/`, `content/effects/`, `content/items/`. Khi hai nơi lệch nhau, sửa file này cho
> khớp dữ liệu sau mỗi lần cân bằng.
> Trong dữ liệu, % và xác suất lưu dạng phân số (15% → `0.15`) (D-38). Bản đầu nhập
> ở M0.6: 4 hero, 9 món đồ; 14 món đồ chỉ số của v1 để M8.

## Khung chung (luật ở GAME_RULES mục ABL, TAL)

- Mỗi hero có 3 skill: **Q** và **W** (5 cấp), **R** là ultimate (3 cấp), cộng một
  **nội tại** (bị động) có sẵn từ đầu, tự lên 6 bậc ở hero cấp 1/4/8/12/16/20,
  không tốn điểm (ABL-11).
- Lên cấp hero nhận 1 điểm. Q/W cấp n cần hero cấp 2n−1 (1, 3, 5, 7, 9).
  R cần hero cấp 6 / 11 / 16. Điểm cũng có thể đổi lấy **+2 mọi thuộc tính**
  (tối đa 7 lần). 13 điểm skill + 7 điểm thuộc tính = 20 cấp.
- Cấp 20: chọn **1 trong 3 talent**, mỗi talent nâng một skill lên "tầng II".
- Talent chỉ được sửa con số và thêm hành động; **không được đổi cách một state
  vận hành** (TAL-03).

Mỗi hero được chọn để mang vào game một nhóm cơ chế. Làm xong 4 hero này và các
món đồ ở cuối tài liệu thì gần như mọi hero, món đồ sau chỉ còn là dữ liệu.

| Hero | Vai trò | Cơ chế mang vào game |
|---|---|---|
| Brakk · Thiết Quyền | Đỡ đòn, cận chiến, Sức mạnh | Vùng quanh mình, STUNNED, khiên (SHIELD), GHOST, hồi máu theo thời gian |
| Myra · Pháp sư | Phép, đánh xa, Trí tuệ | Đạn định hướng (skillshot), vùng có độ trễ, làm chậm, ROOTED, SILENCED, vùng cháy (talent) |
| Noctis · Sát Ảnh | Sát thủ, cận chiến, Nhanh nhẹn | Lướt (DASH, UNTARGETABLE), INVISIBLE, REVEALED, DISARMED, khuếch đại sát thương nhận vào, hồi chiêu khi hạ gục (talent) |
| Vexa · Phù Thủy | Khống chế, đánh xa, Trí tuệ | HEXED (biến hình), đẩy lùi (KNOCKBACK), tước bỏ hiệu ứng có lợi (PURGE), skill xuyên miễn phép |

## Bảng phủ hiệu ứng

Mỗi hiệu ứng trong luật phải có ít nhất một nguồn trong bản đầu, để được code và
test bằng tình huống thật:

| Hiệu ứng (GAME_RULES) | Nguồn hero | Nguồn trang bị |
|---|---|---|
| STUNNED | Brakk Q, R II | Búa Choáng (bị động) |
| ROOTED | Myra W | — |
| SILENCED | Myra R, Noctis R II | — |
| DISARMED | Noctis W | — |
| Làm chậm (modifier) | Myra Q, Vexa R | Ngọc Băng Sương |
| INVISIBLE | Noctis W | Lưỡi Ẩn Thân |
| REVEALED | Noctis R | Bột Lộ Diện |
| GHOST | Brakk R | Gậy Hồn Ma |
| UNTARGETABLE | Noctis Q (lúc lướt) | Gậy Lốc Xoáy |
| INVULNERABLE | — | Gậy Lốc Xoáy |
| MAGIC_IMMUNE | — | Giáp Bất Khuất |
| HEXED | Vexa Q | Lưỡi Hái Biến Hình |
| Khiên (EFF-06) | Brakk W | — |
| Đẩy lùi (ABL-10) | Vexa W | — |
| Thanh tẩy cơ bản / mạnh (EFF-07) | Vexa R (tước của địch) | Giáp Bất Khuất, Bùa Thanh Tẩy (của mình) |
| Xuyên miễn phép (ST-15) | Vexa R | — |
| Khuếch đại sát thương nhận | Noctis R | — |
| Sát thương theo thời gian | Myra R II | — |
| Hồi máu | Brakk R | — |
| Bị động: bash (choáng ngẫu nhiên, CMB-08) | Brakk nội tại | Búa Choáng |
| Bị động: chí mạng (CMB-07) | Noctis nội tại | — |
| Bị động: cộng dồn tốc đánh, mất khi đổi mục tiêu | Myra nội tại | — |
| Bị động: hút chỉ số (của mình tăng, của địch giảm) | Vexa nội tại | — |
| Bị động: cộng chỉ số thẳng (vd +% sát thương gốc) | (modifier thường — xem ghi chú) | mọi món đồ |
| Giả ngẫu nhiên PRD (RNG-01) | Brakk, Noctis nội tại | Búa Choáng |

Ghi chú: % tăng/giảm (MULTIPLY) của nhiều nguồn cộng với nhau (STAT-02, D-40).

Ghi chú: bị động kiểu "+10/15/20/25/30/35% sát thương gốc" chỉ là một modifier
vĩnh viễn, cơ chế đã có sẵn nhờ trang bị, nên không cần hero riêng để kiểm chứng.
Có thể làm nội tại cho hero thứ 5 hoặc talent về sau mà không cần code.

Chỉ số gốc và tăng trưởng lấy từ hero v1 cùng tên (`tank_growth`, `mage_growth`,
`assassin_growth`), cân lại sau khi chơi thử. Tăng trưởng chỉ gồm STR/AGI/INT, không
có sát thương mỗi cấp (STAT-04).

---

## Brakk · Thiết Quyền

Cận chiến (tầm 150), thuộc tính chính Sức mạnh. Máu cao, lao vào khống chế, chịu đòn.
BAT 1.7, mỗi cấp +1.5 Nhanh nhẹn, +1.5 Trí tuệ (D-133).

### Nội tại — Đòn Chấn Động (kiểu Faceless Void)

| Bậc (hero cấp) | 1 (1) | 2 (4) | 3 (8) | 4 (12) | 5 (16) | 6 (20) |
|---|---:|---:|---:|---:|---:|---:|
| Xác suất (PRD) | 15% | 17% | 19% | 21% | 23% | 25% |
| Sát thương vật lý thêm | 30 | 40 | 50 | 60 | 70 | 80 |
| Choáng (giây) | 0.5 | 0.6 | 0.7 | 0.8 | 0.9 | 1.0 |

Đòn đánh trúng hero/lính/quái (không phải công trình) có xác suất choáng và gây
thêm sát thương. Không có thời gian chờ (bash của Brakk; mỗi nguồn bash tự khai báo, D-63).

### Q — Đấm Chấn Địa (không chọn mục tiêu, vùng quanh mình)

| Cấp | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|
| Sát thương vật lý | 70 | 110 | 150 | 190 | 230 |
| Choáng (giây) | 0.8 | 1.0 | 1.2 | 1.4 | 1.6 |
| Hồi chiêu (giây) | 14 | 13 | 12 | 11 | 10 |
| Mana | 90 | 95 | 100 | 105 | 110 |

Bán kính 300 quanh Brakk, trúng mọi kẻ địch (không trúng công trình). Thời gian
tung 0.3 s.
Hành động: `AreaAt(self, 300) → Damage(PHYSICAL, damage) + ApplyEffect(stun, stun_duration)`.

### W — Giáp Sắt (không chọn mục tiêu, bản thân)

| Cấp | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|
| Khiên chặn sát thương | 120 | 180 | 240 | 300 | 360 |
| Thời gian (giây) | 6 | 6 | 6 | 6 | 6 |
| Hồi chiêu | 18 | 17 | 16 | 15 | 14 |
| Mana | 80 | 85 | 90 | 95 | 100 |

Khiên hút sát thương mọi loại trước khi trừ máu. Hết lượng khiên hoặc hết giờ thì
mất. Dùng lại khi còn khiên thì làm mới khiên.

### R — Hồn Bất Diệt (ultimate, bản thân)

| Cấp | 1 | 2 | 3 |
|---|---:|---:|---:|
| Thời gian GHOST (giây) | 4 | 5 | 6 |
| Hồi máu theo % máu tối đa trong thời gian đó | 20% | 30% | 40% |
| Tốc chạy | +20% | +25% | +30% |
| Hồi chiêu | 90 | 80 | 70 |
| Mana | 150 | 175 | 200 |

Brakk thành GHOST: miễn sát thương vật lý, không đánh thường được, nhận thêm
sát thương phép (ST-11). Hồi máu chia đều mỗi 0.5 s.

### Talent cấp 20 (chọn 1)

| Talent | Thay đổi |
|---|---|
| Q II — Động Đất | Bán kính +100, choáng +0.6 s |
| W II — Giáp Nổ | Khi khiên **bị phá hết** (không phải hết giờ): nổ gây sát thương phép bằng lượng khiên ban đầu, bán kính 300 |
| R II — Hồn Trở Về | GHOST +2 s; khi GHOST kết thúc, choáng kẻ địch trong 300 trong 1 s |

---

## Myra · Pháp sư

Đánh xa (tầm 550), thuộc tính chính Trí tuệ. Gây sát thương phép từ xa và khống chế.

### Nội tại — Nhịp Phép (kiểu Troll Warlord)

| Bậc (hero cấp) | 1 (1) | 2 (4) | 3 (8) | 4 (12) | 5 (16) | 6 (20) |
|---|---:|---:|---:|---:|---:|---:|
| Tốc đánh mỗi lần cộng dồn | +5% | +6% | +7% | +8% | +9% | +10% |
| Tối đa cộng dồn | 8 | 8 | 8 | 8 | 8 | 8 |

Mỗi đòn đánh trúng **cùng một mục tiêu** thêm 1 lần cộng dồn (giữ 4 s). Đổi mục
tiêu thì mất hết (`removed_by attack_target_changed`), tính lúc bắt đầu vung vào mục tiêu khác (CMB-12). Đánh trụ cũng cộng.

### Q — Tia Băng (chọn hướng, đạn định hướng)

| Cấp | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|
| Sát thương phép | 90 | 140 | 190 | 240 | 290 |
| Làm chậm | 30% | 30% | 30% | 30% | 30% |
| Thời gian chậm (giây) | 1.5 | 1.75 | 2.0 | 2.25 | 2.5 |
| Hồi chiêu | 8 | 7.5 | 7 | 6.5 | 6 |
| Mana | 80 | 90 | 100 | 110 | 120 |

Đạn bay thẳng 1000, rộng 120, tốc 1400, trúng kẻ địch **đầu tiên** (không phải
công trình) thì dừng.

### W — Vòng Phong Ấn (chọn điểm, vùng có độ trễ)

| Cấp | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|
| Sát thương phép | 60 | 100 | 140 | 180 | 220 |
| Trói chân (giây) | 1.0 | 1.25 | 1.5 | 1.75 | 2.0 |
| Hồi chiêu | 16 | 15 | 14 | 13 | 12 |
| Mana | 100 | 110 | 120 | 130 | 140 |

Tầm dùng 800, bán kính 280. Vòng hiện cho cả hai bên thấy, **sau 0.8 s** mới tác
dụng lên kẻ địch đang đứng trong vòng lúc đó (né được).

### R — Mưa Sao Băng (ultimate, chọn điểm)

| Cấp | 1 | 2 | 3 |
|---|---:|---:|---:|
| Sát thương phép | 250 | 375 | 500 |
| Câm lặng (giây) | 2.0 | 2.5 | 3.0 |
| Hồi chiêu | 80 | 70 | 60 |
| Mana | 150 | 200 | 250 |

Tầm dùng 900, bán kính 400, độ trễ 1.0 s.

### Talent cấp 20 (chọn 1)

| Talent | Thay đổi |
|---|---|
| Q II — Tia Xuyên Băng | Đạn xuyên qua mọi kẻ địch trên đường, không dừng ở mục tiêu đầu |
| W II — Phong Ấn Tức Thì | Độ trễ còn 0.3 s, bán kính +100 |
| R II — Hỏa Ngục | Sau khi rơi, để lại vùng cháy 4 s, 60 sát thương phép mỗi giây |

---

## Noctis · Sát Ảnh

Cận chiến (tầm 150), thuộc tính chính Nhanh nhẹn. Ẩn mình, áp sát, hạ mục tiêu yếu.

### Nội tại — Tử Kiếm (kiểu Phantom Assassin)

| Bậc (hero cấp) | 1 (1) | 2 (4) | 3 (8) | 4 (12) | 5 (16) | 6 (20) |
|---|---:|---:|---:|---:|---:|---:|
| Xác suất chí mạng (PRD) | 10% | 12% | 14% | 16% | 18% | 20% |
| Hệ số chí mạng | 1.6× | 1.8× | 2.0× | 2.2× | 2.4× | 2.6× |

Chí mạng theo CMB-07: chỉ nhân sát thương vật lý của đòn đánh, không nhân đòn
phục kích của W. Không chí mạng lên công trình.

### Q — Lưỡi Bóng (chọn đơn vị địch, lướt)

| Cấp | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|
| Sát thương vật lý | 80 | 120 | 160 | 200 | 240 |
| Hồi chiêu | 12 | 11 | 10 | 9 | 8 |
| Mana | 70 | 75 | 80 | 85 | 90 |

Tầm dùng 600. Lướt tới mục tiêu với tốc 2000; trong lúc lướt Noctis là
UNTARGETABLE. Tới nơi gây sát thương.

### W — Màn Đêm (không chọn mục tiêu, bản thân)

| Cấp | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|
| Thời gian tàng hình (giây) | 6 | 7 | 8 | 9 | 10 |
| Tốc chạy khi tàng hình | +10% | +15% | +20% | +25% | +30% |
| Sát thương đòn phục kích | 60 | 90 | 120 | 150 | 180 |
| Cấm đánh lên mục tiêu (giây) | 1.0 | 1.2 | 1.4 | 1.6 | 1.8 |
| Hồi chiêu | 20 | 19 | 18 | 17 | 16 |
| Mana | 80 | 80 | 80 | 80 | 80 |

Sau 0.6 s (fade in) Noctis INVISIBLE. Đánh hoặc dùng chiêu thì hiện hình. Đòn đánh
đầu tiên trong thời gian này (dù đã hiện hình vì chính đòn đó) gây thêm sát thương
vật lý và DISARMED mục tiêu.

Biểu diễn bằng hai hiệu ứng áp cùng lúc:
- `shadow_veil`: INVISIBLE, modifier tốc chạy, `removed_by [attack_started, ability_cast]`.
- `ambush_ready`: không có state; trigger `attack_landed` → Damage + ApplyEffect(disarm) →
  tự xóa; `removed_by [ability_cast]`.

### R — Dấu Tử Thần (ultimate, chọn đơn vị địch)

| Cấp | 1 | 2 | 3 |
|---|---:|---:|---:|
| Mục tiêu nhận thêm sát thương (mọi nguồn) | 15% | 22% | 30% |
| Thời gian (giây) | 6 | 6 | 6 |
| Hồi chiêu | 60 | 50 | 40 |
| Mana | 100 | 125 | 150 |

Tầm dùng 500. Mục tiêu bị đánh dấu: REVEALED với đội Noctis (khắc chế tàng hình
của địch về sau) và chỉ số `damage_taken_multiplier` tăng.

### Talent cấp 20 (chọn 1)

| Talent | Thay đổi |
|---|---|
| Q II — Lưỡi Săn Mồi | Sát thương +100; nếu Noctis hạ gục bất kỳ ai trong 1.3 s kể từ lúc tung Q (lướt ~0.3 s + 1 s), hồi lại toàn bộ hồi chiêu Q (D-38; nghe sự kiện `unit_died`, D-75) |
| W II — Bóng Không Hình | Fade in 0 s; khi tàng hình hồi 3% máu tối đa mỗi giây |
| R II — Án Tử | Khuếch đại +10%; khi đánh dấu, câm lặng mục tiêu 1.5 s |

---

## Vexa · Phù Thủy

Đánh xa (tầm 550), thuộc tính chính Trí tuệ. Không gây nhiều sát thương, nhưng
khống chế mạnh và phá các hiệu ứng có lợi của đối thủ. Chỉ số gốc lấy từ mẫu
`mage_growth` của v1, giảm sát thương phép, tăng mana.

### Nội tại — Hút Trí Tuệ (kiểu Slark, hút Trí tuệ)

| Bậc (hero cấp) | 1 (1) | 2 (4) | 3 (8) | 4 (12) | 5 (16) | 6 (20) |
|---|---:|---:|---:|---:|---:|---:|
| Trí tuệ hút mỗi đòn | 1 | 1 | 2 | 2 | 3 | 3 |
| Thời gian (giây) | 20 | 20 | 25 | 25 | 30 | 30 |

Mỗi đòn đánh trúng **hero** địch: hero địch −x Trí tuệ, Vexa +x Trí tuệ, mỗi lần là
một bản riêng hết hạn riêng (INDEPENDENT). Không bị thanh tẩy (`dispel: NONE`).
Biểu diễn bằng hai hiệu ứng áp cùng lúc; không cần action "hút" riêng.

### Q — Hóa Ếch (chọn đơn vị địch)

| Cấp | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|
| Biến hình (giây) | 1.5 | 2.0 | 2.5 | 3.0 | 3.5 |
| Hồi chiêu | 20 | 18 | 16 | 14 | 12 |
| Mana | 100 | 110 | 120 | 130 | 140 |

Tầm dùng 600. Mục tiêu bị HEXED (ST-16): thành con ếch, không đánh, không dùng
chiêu/đồ, tốc chạy cố định thấp, bị động tắt.

### W — Sóng Gió (chọn hướng)

| Cấp | 1 | 2 | 3 | 4 | 5 |
|---|---:|---:|---:|---:|---:|
| Sát thương phép | 60 | 100 | 140 | 180 | 220 |
| Đẩy lùi (khoảng cách) | 300 | 300 | 300 | 300 | 300 |
| Hồi chiêu | 14 | 13 | 12 | 11 | 10 |
| Mana | 90 | 95 | 100 | 105 | 110 |

Vùng hình chữ nhật dài 700, rộng 250 phía trước Vexa, tác dụng ngay. Mọi kẻ địch
trong vùng nhận sát thương và bị đẩy ra xa Vexa 300 trong 0.3 s (ABL-10).

### R — Tước Phép (ultimate, chọn đơn vị địch)

| Cấp | 1 | 2 | 3 |
|---|---:|---:|---:|
| Làm chậm | 50% | 60% | 70% |
| Thời gian chậm (giây) | 3 | 3.5 | 4 |
| Sát thương phép mỗi hiệu ứng bị tước | 80 | 120 | 160 |
| Hồi chiêu | 70 | 60 | 50 |
| Mana | 150 | 175 | 200 |

Tầm dùng 700. **Xuyên miễn phép** (ST-15). Tước mọi hiệu ứng có lợi trên mục tiêu
mà mức thanh tẩy cơ bản gỡ được (EFF-07): khiên, tàng hình, tăng tốc… Mỗi hiệu ứng
bị tước gây thêm sát thương phép. Sau đó làm chậm.

### Talent cấp 20 (chọn 1)

| Talent | Thay đổi |
|---|---|
| Q II — Ếch Khốn Khổ | Mục tiêu đang HEXED nhận thêm 20% sát thương mọi nguồn |
| W II — Bão Táp | Rộng +100, sát thương +100, đẩy lùi +150 |
| R II — Phong Ấn | Hồi chiêu −20; làm chậm = 0% và thêm ROOTED 2 s (D-38) |

## Gorran · Giả Kim

Đánh gần, Sức mạnh, BAT 1.7, đẩy trụ bằng đòn đánh (kiểu Alchemist). D-122. Mỗi cấp +1.4 Nhanh nhẹn (D-133).

### Nội tại — Sức Mạnh Giả Kim
+15 / 20 / 25 / 30 / 35 / 35 sát thương (bậc ở cấp 1, 4, 8, 12, 16, 20).

### Q — Vũng Axit (chọn điểm, tầm 900)
Vùng bán kính 400 trong 10 s, 10 / 20 / 30 / 40 / 50 sát thương phép mỗi giây, không giảm giáp.
Hồi chiêu 20 s, mana 90–130.

### W — Đuôi Rồng (chọn đơn vị địch, tầm 700)
80 / 100 / 120 / 140 / 160 sát thương phép, choáng 1.5 / 1.8 / 2.1 / 2.4 / 2.7 s. Hồi chiêu 12 s, mana 100.

### R — Cuồng Hóa (ultimate, bản thân)
25 s: BAT 1.7 → 1.4 / 1.3 / 1.2, hồi máu +15 / 25 / 35 mỗi giây (D-133), tốc chạy +30 / 40 / 50.
Hồi chiêu 55 s, mana 50 / 100 / 150.

### Talent cấp 20 (chọn 1)
- Q: Vũng Axit bán kính +100, +15 sát thương mỗi giây.
- W: choáng +1 s.
- R: BAT giảm thêm 0.1 khi Cuồng Hóa (cấp 3: 1.1); bỏ +50 sát thương (D-133).

## Thư viện bị động (dành sẵn cho hero sau)

Bị động kiểu Dota không cần làm hết ngay. Cần làm ngay là **các viên gạch** để mọi
bị động dưới đây chỉ còn là dữ liệu. Mỗi bị động trong bảng được kiểm thử bằng một
**hero thử nghiệm** chỉ có trong `tests/` (không xuất hiện trong game), nên viên gạch
được test thật mà không phải thiết kế hero hoàn chỉnh.

| Bị động (giống) | Biểu diễn bằng dữ liệu | Viên gạch cần | Trạng thái |
|---|---|---|---|
| Né đòn (PA Blur) | Modifier `evasion` | Né của v1 (CMB-11) | Có sẵn |
| +% sát thương gốc | Modifier `physical_damage` MULTIPLY | Modifier | Có sẵn |
| Bash (Void) | Brakk nội tại | PRD, CMB-08 | Làm ở M3 với Brakk |
| Chí mạng (PA) | Noctis nội tại | CMB-07 | M5 với Noctis |
| Cộng dồn tốc đánh (Troll) | Myra nội tại | `removed_by attack_target_changed` | M4 với Myra |
| Hút chỉ số (Slark) | Vexa nội tại | INDEPENDENT, 2 hiệu ứng | M6 với Vexa |
| Trả đòn theo Sức mạnh (Centaur Return) | Trigger `attack_landed as TARGET` → Damage(attacker, PHYSICAL, `20 + 0.3 * self.strength`), `reflected` | Vai trigger (EFF-08), biểu thức (EFF-09), CMB-09 | Gạch ở M3, hero thử nghiệm |
| Xoáy phản công (Axe Counter Helix) | Trigger `attack_landed as TARGET`, chance 20% PRD → AreaAt(self, 275) Damage PURE | Vai trigger, PRD | Gạch ở M3, hero thử nghiệm |
| Phân tán sát thương (Spectre Dispersion) | Modifier `damage_taken_multiplier` −x%; trigger `damage_taken as TARGET` → AreaAt(self, 1100, giảm dần theo khoảng cách) Damage(`event.damage * x`), `reflected` | Biểu thức có `event.*`, vùng giảm dần, CMB-09 | Gạch ở M3, hero thử nghiệm |
| Đốt mana (Anti-Mage Mana Break) | Trigger `attack_landed as SOURCE` → ManaBurn(target, 30) → Damage(target, PHYSICAL, `event.burned_mana * 0.5`) | Action ManaBurn (CMB-10), biểu thức | Gạch ở M3, hero thử nghiệm |
| Tái sinh 2 mạng (Wraith King) | Hiệu ứng `prevent_death`, hồi chiêu 120 s, tốn 160 mana | Móc chặn chết (DTH-01..03) | M6, hero thử nghiệm |
| Phản sát thương (đồ kiểu Blade Mail, có từ v1) | Modifier `damage_reflect` | CMB-09 | M3 |

Khi muốn một hero mới có bị động trong bảng: chép dòng đó vào thiết kế hero, chỉnh
số, thêm test kịch bản. Không cần code.

## Cách bot dùng skill

Bot không có code riêng cho từng skill. Mỗi skill khai báo `bot_usage` trong dữ
liệu, bot chỉ có logic cho từng **loại** (GAME_RULES BOT-13):

| Skill | bot_usage | Điều kiện dữ liệu |
|---|---|---|
| Brakk Q | DISABLE | ≥ 1 hero địch trong bán kính |
| Brakk W | SELF_DEFENSE | Máu < 70% và đang nhận sát thương |
| Brakk R | ESCAPE | Máu < 30% hoặc bị trụ nhắm |
| Myra Q | POKE | Hero địch trong tầm, dự đoán vị trí |
| Myra W | DISABLE | Hero địch đứng yên hoặc đang bị khống chế |
| Myra R | FINISH / TEAMFIGHT | Hero địch máu < sát thương skill, hoặc ≥ 2 kẻ địch trong vùng |
| Noctis Q | ENGAGE | Máu mục tiêu < 50% và vị trí đích an toàn |
| Noctis W | ENGAGE / ESCAPE | Chuẩn bị áp sát, hoặc máu < 30% |
| Noctis R | ENGAGE | Trước khi áp sát mục tiêu |
| Vexa Q | DISABLE | Hero địch trong tầm, ưu tiên khi nó đang áp sát |
| Vexa W | ESCAPE / POKE | Hero địch quá gần, hoặc trúng được nhiều kẻ địch |
| Vexa R | DISABLE | Hero địch có ≥ 1 hiệu ứng có lợi gỡ được, hoặc đang bỏ chạy (`enemy_has_purgeable_buff_or_fleeing`) |
| Đồ (D-95) | theo món | Gậy Hồn Ma, Giáp Bất Khuất: máu < 70% và đang nhận sát thương; Bùa Thanh Tẩy: có debuff gỡ được; Gậy Lốc Xoáy: ESCAPE khi máu < 30% / DISABLE khi hero địch trong tầm; Lưỡi Hái: hero địch trong tầm; Lưỡi Ẩn Thân: ENGAGE khi chuẩn bị áp sát / ESCAPE khi máu < 30% |

Thứ tự lên đồ của bot (`bot_item_build`, D-95): Brakk — Búa Choáng, Ngọc Băng Sương, Giáp Bất Khuất, Bùa Thanh Tẩy; Myra — Gậy Hồn Ma, Gậy Lốc Xoáy, Ngọc Băng Sương, Lưỡi Hái; Noctis — Lưỡi Ẩn Thân, Búa Choáng, Giáp Bất Khuất, Ngọc Băng Sương; Vexa — Gậy Lốc Xoáy, Gậy Hồn Ma, Lưỡi Hái, Bùa Thanh Tẩy.

Nội tại không cần `bot_usage` vì tự kích hoạt. Riêng Myra: bot ưu tiên giữ nguyên mục
tiêu để không mất cộng dồn Nhịp Phép (điều kiện dữ liệu `prefer_same_target`).

## Duy Anh · Hiệp Sĩ (D-135)

Sức mạnh, cận chiến (tầm 150), kiếm và khiên; BAT 1.7, sát thương gốc 58, tốc chạy 270; STR 26 (+4.5),
AGI 18 (+1.9), INT 15 (+2.3) — số gốc do Claude đặt theo Brakk / Gorran, chờ chơi thử. Đấu sĩ bắt chủ lực,
ép đấu tay đôi, mạnh dần qua các trận Quyết Đấu thắng.

### Nội tại — Khiên Chắn (D-137)
Đòn đánh thường nhắm vào hiệp sĩ: 50% (PRD) bị chặn 20 / 30 / 40 / 50 / 60 / 70 sát thương trước giáp
(bậc theo cấp hero 1 / 4 / 8 / 12 / 16 / 20, ABL-11); đòn của đơn vị đánh xa chặn một nửa (CMB-15).

### Q — Xung Phong
+30 / 35 / 40 / 45 / 50% tốc chạy 5 s. Hồi 18 / 17 / 16 / 15 / 14 s, 40 mana. Không giải khống chế.

### W — Hoành Kiếm
Quạt 150°, tầm 350 phía trước (ABL-20): 100 / 150 / 200 / 250 / 300 + 80% sát thương đánh thường, vật lý.
Hồi 7 s, mana 50 / 55 / 60 / 65 / 70. Không lên công trình, không chí mạng / hút máu / hiệu ứng đòn đánh.

### R — Quyết Đấu
Tầm 500, chỉ tướng địch. Lao tới (vẫn bị nhắm, ABL-08b), tới nơi bắt đầu Quyết Đấu (DUL) rồi bổ
150 / 250 / 350 vật lý. 3 / 4 / 5 s: hai bên bị ép đánh nhau; hiệp sĩ +60 / 80 / 100% tốc đánh và phản
20 / 25 / 30% sát thương đòn đánh trước giáp của đối thủ. Ai chết trước thua: thắng +10 / 15 / 20 sát thương vĩnh
viễn và +150 / 225 / 300 vàng (cả khi đối thủ thắng); hiệp sĩ thua −10 / 15 / 20. Hồi 70 / 60 / 50 s, mana
100 / 125 / 150.

### Talent cấp 20 (chọn 1)
| Talent | Hiệu ứng |
|---|---|
| Q II — Xung Phong Bền Bỉ | +2 s (7 s) |
| W II — Hoành Kiếm Phá Trận | +100 sát thương cơ bản |
| R II — Quyết Đấu Bất Bại | Miễn phép (MAGIC_IMMUNE) từ lúc tung tới hết Quyết Đấu |

## Trang bị có kỹ năng

Kỹ năng chủ động và bị động của đồ dùng **đúng hệ thống của skill hero**
(`AbilityDef`, `EffectDef`). Một món đồ chỉ khác ở chỗ gắn vào ô đồ thay vì ô skill,
có thể có số lần dùng, và không có cấp. Vì vậy nhiều món dùng lại hiệu ứng của hero.

Chỉ số cộng thêm (máu, sát thương, thuộc tính…) lấy theo thang trang bị v1. Giá chỉ
là đề xuất, cân lại khi chơi thử.

| Món | id | Giá | Chỉ số | Chủ động / bị động |
|---|---|---:|---|---|
| Gậy Hồn Ma | `ghost_scepter` | 1400 | +7 mọi thuộc tính | **Chủ động** (hồi 22 s): bản thân GHOST 4 s |
| Trượng Hắc Vương | `black_king_bar` | 3300 | +10 STR, +25 sát thương | **Chủ động** (hồi 70 s): thanh tẩy cơ bản bản thân rồi MAGIC_IMMUNE 6 s (D-140, trước là Giáp Bất Khuất) |
| Giáp Thép | `steel_armor` | 2100 | +10 giáp, +20 sát thương | **Bị động**: tướng địch đánh thường trúng nhận lại 20% sát thương đòn trước giáp (D-141) |
| Ngọc Băng Sương | `frost_orb` | 2000 | +250 máu, +10 mọi thuộc tính | **Bị động**: đòn đánh làm chậm 20% tốc chạy và 20% tốc đánh trong 2 s (đánh xa) / 3 s (cận chiến) |
| Bột Lộ Diện | `reveal_dust` | 80 | — | **Chủ động**, 2 lần dùng (hồi 30 s): REVEALED mọi kẻ địch trong 900 quanh mình 8 s |
| Gậy Lốc Xoáy | `cyclone_staff` | 2400 | +10 INT, +2.5 hồi mana | **Chủ động** (hồi 23 s, tầm 575): một đơn vị bị nhấc lên 2.5 s — INVULNERABLE + UNTARGETABLE + STUNNED. Dùng lên bản thân để né; dùng lên địch đang MAGIC_IMMUNE thì không được |
| Lưỡi Ẩn Thân | `shadow_blade` | 2500 | +25 sát thương, +30% tốc đánh | **Chủ động** (hồi 28 s): dùng lại hiệu ứng `shadow_veil` + `ambush_ready` của Noctis W (cấp 2) với thời gian 12 s |
| Lưỡi Hái Biến Hình | `hex_scythe` | 4200 | +35 INT, +10 STR, +10 AGI | **Chủ động** (hồi 22 s, tầm 600): HEXED mục tiêu 3.5 s |
| Bùa Thanh Tẩy | `cleansing_charm` | 1500 | +6 giáp, +4 hồi máu | **Chủ động** (hồi 18 s): thanh tẩy cơ bản bản thân |
| Búa Choáng | `stun_hammer` | 2600 | +25 sát thương | **Bị động**: đòn đánh 20% (cận chiến) / 10% (đánh xa) choáng 1.5 s, +100 sát thương vật lý; nhóm `bash`, thời gian chờ chung `bash_cooldown` (CMB-08, D-38) |
| Trượng Lôi Kích | `thunder_staff` | 3800 | +40% tốc đánh | **Bị động**: mỗi đòn trúng (không lên công trình) +70 sát thương phép, không khuếch đại phép (D-132) |
| Rìu Xiềng Xích | `chain_axe` | 2500 | +10 STR, +20 sát thương | **Bị động**: đòn đánh 30% (cận chiến) / 10% (đánh xa) trói 1 s, +80 / +40 sát thương vật lý; PRD, không hồi, không lên công trình, tung riêng với Búa Choáng (D-132) |
| Mắt Vàng | `observer_ward` | 50 | — | **Chủ động**, tầm 500: cắm mắt vàng (tầm nhìn 1400, 4 phút); gộp 4; kho đội 2 / +1 mỗi 135 s / tối đa 4 (WRD, D-92) |
| Mắt Xanh | `sentry_ward` | 50 | — | **Chủ động**, tầm 500: cắm mắt xanh (true sight 900, 5 phút); gộp 6; kho đội 3 / +1 mỗi 90 s / tối đa 6 |

### Toàn bộ đồ (D-106, sinh từ content/items — sửa số ở đó)

Ghép đồ SHOP-09: giá = giá món; mua khi đã có thành phần thì chỉ trả phần thiếu.

| Danh mục | Món | id | Giá | Chỉ số | Ghép từ |
|---|---|---|---:|---|---|
| Tấn công | Vòng Ma | `wraith_band` | 420 | +8 Nhanh nhẹn, +3 Sức mạnh, +3 Trí tuệ, +2 Giáp | Dép Nhanh Nhẹn + Vòng Đầu |
| Tấn công | Kiếm Chí Mạng | `crit_blade` | 2200 | +32 Sát thương | Lưỡi Công + Trường Kiếm |
| Tấn công | Cung Gió | `wind_bow` | 2300 | +60% Tốc đánh, +16 Nhanh nhẹn, +12 Sát thương | Găng Nhanh + Lưỡi Nhanh |
| Tấn công | Lưỡi Hút Hồn | `vampire_blade` | 2300 | +30 Sát thương, +20% Hút máu, +4 Hồi máu | Mặt Nạ Khát Máu + Trường Kiếm + Nhẫn Hồi Phục |
| Tấn công | Búa Choáng | `stun_hammer` | 2400 | +25 Sát thương, +6 Sức mạnh | Trường Kiếm + Đai Sức Mạnh |
| Tấn công | Rìu Xiềng Xích | `chain_axe` | 2500 | +10 Sức mạnh, +20 Sát thương | Rìu Khổng Lồ + Trường Kiếm |
| Tấn công | Lưỡi Ẩn Thân | `shadow_blade` | 2500 | +25 Sát thương, +30% Tốc đánh | Đại Kiếm + Găng Nhanh |
| Tấn công | Rìu Chiến | `battle_axe` | 2500 | +60 Sát thương, +5 Hồi máu | Trường Kiếm + Đại Kiếm |
| Tấn công | Trượng Hắc Vương | `black_king_bar` | 3300 | +10 Sức mạnh, +25 Sát thương | Rìu Khổng Lồ + Đại Kiếm |
| Tấn công | Song Đao | `twin_blades` | 3400 | +20 Nhanh nhẹn, +20 Sức mạnh, +20% Tốc đánh, +20 Sát thương, +20% Tốc chạy | Rìu Khổng Lồ + Lưỡi Nhanh + Gậy Chiến + Giày |
| Tấn công | Lưỡi Hái Hủy Diệt | `desolator` | 3500 | +60 Sát thương | Kiếm Quỷ + Lưỡi Mòn |
| Tấn công | Trượng Lôi Kích | `thunder_staff` | 3800 | +40% Tốc đánh, +10 Trí tuệ | Găng Nhanh ×2 + Gậy Phù Thủy |
| Tấn công | Mảnh Trăng | `moon_shard` | 4000 | +150% Tốc đánh | Đá Siêu Tốc + Móng Cuồng Nộ |
| Tấn công | Gậy Định Tâm | `focus_staff` | 4200 | +80 Sát thương, +75% Xuyên né | Kiếm Quỷ + Đại Kiếm + Lưỡi Công |
| Tấn công | Cánh Bướm | `butterfly` | 4400 | +30 Nhanh nhẹn, +30 Sát thương, +30% Tốc đánh, +30% Né tránh | Lông Đại Bàng + Gậy Chiến + Bùa Né Tránh |
| Tấn công | Kiếm Ảnh Vũ | `shadow_dance_blade` | 5100 | +20 Sức mạnh, +10 Nhanh nhẹn, +10 Trí tuệ, +35 Sát thương, +30% Né tránh | Ngọc Ảo Ảnh + Rìu Khổng Lồ + Đại Kiếm |
| Tấn công | Đại Đao Thần | `divine_blade` | 5100 | +85 Sát thương | Kiếm Chí Mạng + Thánh Tích |
| Tấn công | Kiếm Huyết Ma | `satanic` | 5200 | +25 Sức mạnh, +35 Sát thương, +25% Hút máu, +4 Hồi máu | Rìu Thần Lực + Lưỡi Hút Hồn |
| Phép | Bùa Trí Tuệ | `null_talisman` | 420 | +8 Trí tuệ, +3 Nhanh nhẹn, +3 Sức mạnh, +0.8 Hồi mana | Áo Choàng Trí Tuệ + Vòng Đầu |
| Phép | Gậy Hồn Ma | `ghost_scepter` | 1400 | +7 Sức mạnh, +7 Nhanh nhẹn, +7 Trí tuệ | Đai Sức Mạnh + Vòng Nhanh Nhẹn + Áo Pháp Sư |
| Phép | Sách Phép Cổ | `ancient_tome` | 2000 | +16 Trí tuệ, +15% Khuếch đại phép | Gậy Phù Thủy + Áo Pháp Sư |
| Phép | Gậy Lốc Xoáy | `cyclone_staff` | 2400 | +16 Trí tuệ, +2.5 Hồi mana | Gậy Phù Thủy + Đá Hư Không + Áo Pháp Sư |
| Phép | Quyền Trượng Bão | `storm_staff` | 2400 | +18 Trí tuệ, +300 Mana, +2 Hồi mana, +200 Tầm chiêu, +10% Khuếch đại phép | Gậy Phù Thủy + Ngọc Mana + Đá Hư Không |
| Phép | Xuyên Tâm Trượng | `piercing_staff` | 2600 | +25 Trí tuệ, +3 Hồi mana, +10 Xuyên giáp phép | Gậy Phù Thủy + Áo Pháp Sư + Đá Hư Không + Áo Kháng Phép |
| Phép | Trượng Định Mệnh | `fate_staff` | 2800 | +20 Trí tuệ, +2 Hồi mana, +0.25 debuff_amplification | Gậy Phù Thủy + Áo Pháp Sư + Đá Hư Không |
| Phép | Ngọc Thời Không | `time_orb` | 3500 | +20% Giảm hồi chiêu, +3 Hồi mana, +450 Máu, +250 Mana | Đá Sinh Lực ×2 + Ngọc Mana + Đá Hư Không |
| Phép | Lưỡi Hái Biến Hình | `hex_scythe` | 4700 | +35 Trí tuệ, +10 Sức mạnh, +10 Nhanh nhẹn | Gậy Huyền Bí + Rìu Khổng Lồ + Lưỡi Nhanh |
| Phép | Quyền Trượng Ma Thuật | `arcane_scepter` | 4800 | +42 Trí tuệ, +30% Khuếch đại phép, +5 Hồi mana | Sách Phép Cổ + Gậy Huyền Bí |
| Phòng thủ | Vòng Tay Sắt | `bracer` | 420 | +8 Sức mạnh, +3 Trí tuệ, +3 Nhanh nhẹn, +2 Hồi máu | Găng Sức Mạnh + Vòng Đầu |
| Phòng thủ | Áo Choàng Phép | `magic_cloak` | 1000 | +10 Kháng phép, +8 Hồi máu | Áo Kháng Phép + Nhẫn Hồi Phục |
| Phòng thủ | Bùa Thanh Tẩy | `cleansing_charm` | 1300 | +6 Giáp, +4 Hồi máu | Giáp Xích + Nhẫn Hồi Phục |
| Phòng thủ | Ngọc Băng Sương | `frost_orb` | 2000 | +250 Máu, +10 Sức mạnh, +10 Nhanh nhẹn, +10 Trí tuệ | Đá Sinh Lực + Đai Sức Mạnh + Vòng Nhanh Nhẹn |
| Phòng thủ | Giáp Thép | `steel_armor` | 2100 | +10 Giáp, +20 Sát thương | Giáp Xích + Nhẫn Bảo Hộ + Trường Kiếm |
| Phòng thủ | Áo Choàng Kiên Định | `warding_cloak` | 2600 | +14 Kháng phép, +8 Hồi máu, +20% Kháng hiệu ứng | Áo Choàng Phép + Bùa Kiên Định |
| Phòng thủ | Ngọc Ảo Ảnh | `mirage_orb` | 2700 | +10 Sức mạnh, +10 Nhanh nhẹn, +10 Trí tuệ, +20% Né tránh | Bùa Né Tránh + Đai Sức Mạnh + Vòng Nhanh Nhẹn + Áo Pháp Sư |
| Phòng thủ | Giáp Bất Khuất | `resolute_armor` | 2900 | +15 Giáp, +10% Giảm sát thương vật lý | Giáp Tấm + Giáp Xích |
| Phòng thủ | Giáp Kiên Cường | `steadfast_armor` | 3100 | +15 Giáp, +20% Kháng hiệu ứng | Giáp Tấm + Bùa Kiên Định + Giáp Xích |
| Phòng thủ | Áo Choàng Hiền Giả | `sage_cloak` | 3200 | +12 Kháng phép, +10% Giảm hồi chiêu, +250 Máu, +250 Mana, +8 Hồi máu, +2 Hồi mana | Áo Choàng Phép + Đá Sinh Lực + Ngọc Mana + Đá Hư Không |
| Phòng thủ | Ngọc Băng Sương II | `frost_orb_ii` | 3400 | +470 Máu, +13 Sức mạnh, +13 Nhanh nhẹn, +13 Trí tuệ | Ngọc Băng Sương + Đá Sinh Lực + Vòng Đầu |
| Phòng thủ | Giáp Thần Công | `assault_plate` | 4000 | +15 Giáp, +60% Tốc đánh | Giáp Tấm + Đá Siêu Tốc |
| Phòng thủ | Tim Khổng Lồ | `giant_heart` | 4000 | +30 Sức mạnh, +600 Máu, +10 Hồi máu | Rìu Thần Lực + Đá Sinh Lực + Nhẫn Sinh Lực |
| Tiện ích | Mắt Vàng | `observer_ward` | 50 |  |  |
| Tiện ích | Bình Mana | `mana_potion` | 50 |  |  |
| Tiện ích | Mắt Xanh | `sentry_ward` | 50 |  |  |
| Tiện ích | Chùm Nho | `grapes` | 80 |  |  |
| Tiện ích | Bột Lộ Diện | `reveal_dust` | 80 |  |  |
| Tiện ích | Giày Tốc Chiến | `boots_haste` | 1150 | +55 Tốc chạy, +35% Tốc đánh | Giày + Găng Nhanh |
| Tiện ích | Giày Hộ Vệ | `boots_guard` | 1150 | +55 Tốc chạy, +6 Giáp | Giày + Giáp Xích |
| Tiện ích | Giày Pháp Sư | `boots_arcane` | 1150 | +55 Tốc chạy, +250 Mana, +1.5 Hồi mana | Giày + Ngọc Mana |
| Cơ bản | Cành Sắt | `iron_branch` | 50 | +2 Sức mạnh, +2 Nhanh nhẹn, +2 Trí tuệ |  |
| Cơ bản | Găng Sức Mạnh | `gauntlets` | 140 | +4 Sức mạnh |  |
| Cơ bản | Áo Choàng Trí Tuệ | `mantle` | 140 | +4 Trí tuệ |  |
| Cơ bản | Dép Nhanh Nhẹn | `slippers` | 140 | +4 Nhanh nhẹn |  |
| Cơ bản | Vòng Đầu | `circlet` | 150 | +3 Sức mạnh, +3 Nhanh nhẹn, +3 Trí tuệ |  |
| Cơ bản | Nhẫn Hồi Phục | `ring_regen` | 175 | +2 Hồi máu |  |
| Cơ bản | Mặt Nạ Hiền Triết | `sages_mask` | 175 | +0.8 Hồi mana |  |
| Cơ bản | Nhẫn Bảo Hộ | `ring_protection` | 175 | +2 Giáp |  |
| Cơ bản | Lưỡi Công | `blades_attack` | 400 | +10 Sát thương |  |
| Cơ bản | Đai Sức Mạnh | `belt_strength` | 450 | +6 Sức mạnh |  |
| Cơ bản | Găng Nhanh | `gloves_haste` | 450 | +18% Tốc đánh |  |
| Cơ bản | Giày | `boots` | 450 | +40 Tốc chạy |  |
| Cơ bản | Áo Pháp Sư | `robe_magi` | 450 | +6 Trí tuệ |  |
| Cơ bản | Vòng Nhanh Nhẹn | `band_elvenskin` | 450 | +6 Nhanh nhẹn |  |
| Cơ bản | Áo Kháng Phép | `cloak` | 450 | +4 Kháng phép |  |
| Cơ bản | Giáp Xích | `chainmail` | 500 | +5 Giáp |  |
| Cơ bản | Ngọc Mana | `energy_booster` | 500 | +220 Mana |  |
| Cơ bản | Đá Sinh Lực | `vitality_booster` | 500 | +220 Máu |  |
| Cơ bản | Nhẫn Sinh Lực | `ring_health` | 700 | +5 Hồi máu |  |
| Cơ bản | Đá Hư Không | `void_stone` | 700 | +1.5 Hồi mana |  |
| Cơ bản | Gậy Chiến | `quarterstaff` | 800 | +10 Sát thương, +10% Tốc đánh |  |
| Cơ bản | Lưỡi Mòn | `corrosion_blade` | 800 | +20 Sát thương |  |
| Cơ bản | Rìu Khổng Lồ | `ogre_axe` | 900 | +10 Sức mạnh |  |
| Cơ bản | Lưỡi Nhanh | `blade_alacrity` | 900 | +10 Nhanh nhẹn |  |
| Cơ bản | Trường Kiếm | `broadsword` | 900 | +18 Sát thương |  |
| Cơ bản | Gậy Phù Thủy | `staff_wizardry` | 900 | +10 Trí tuệ |  |
| Cơ bản | Bùa Né Tránh | `evasion_charm` | 1000 | +15% Né tránh |  |
| Cơ bản | Mặt Nạ Khát Máu | `morbid_mask` | 1000 | +10 Sát thương, +15% Hút máu |  |
| Cơ bản | Bùa Kiên Định | `status_charm` | 1000 | +10% Kháng hiệu ứng |  |
| Cơ bản | Giáp Tấm | `platemail` | 1200 | +10 Giáp |  |
| Cơ bản | Đại Kiếm | `claymore` | 1200 | +25 Sát thương |  |
| Cơ bản | Móng Cuồng Nộ | `claws_fury` | 1500 | +50% Tốc đánh |  |
| Cơ bản | Ngọc Kiên Trì | `perseverance` | 1600 | +6 Hồi máu, +2 Hồi mana | Nhẫn Sinh Lực + Đá Hư Không |
| Cơ bản | Đá Siêu Tốc | `hyperstone` | 1700 | +60% Tốc đánh |  |
| Cơ bản | Kiếm Quỷ | `demon_edge` | 1800 | +38 Sát thương |  |
| Cơ bản | Rìu Thần Lực | `reaver` | 2400 | +25 Sức mạnh |  |
| Cơ bản | Gậy Huyền Bí | `mystic_staff` | 2400 | +25 Trí tuệ |  |
| Cơ bản | Lông Đại Bàng | `eaglesong` | 2400 | +25 Nhanh nhẹn |  |
| Cơ bản | Thánh Tích | `sacred_relic` | 2600 | +50 Sát thương |  |

Danh mục, shop ẩn, giờ mở và độc nhất của từng món: D-90 (SHOP-07). Luật của trang bị: GAME_RULES mục ITM.

## Lính và công trình (D-47, D-48)

Số thật nằm trong `content/units/`. BAT = thời gian đánh gốc (giây/đòn khi tốc đánh 100%).

| Đơn vị | Máu | Sát thương | Giáp | BAT | Vung tay | Tầm | Tốc chạy | Vàng (D-53) | XP (D-60) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Lính cận chiến | 450 | 20 | 2 | 1.0 | 0.467 | 100 | 240 | 36 | 57 |
| Lính đánh xa | 300 | 24 | 0 | 1.0 | 0.5 | 500 | 240 | 45 | 69 |
| Lính công thành | 800 | 40 | 0 | 2.7 | 0.7 | 690 | 220 | 70 | 88 |
| Trụ 1 / 2 / 3 / 4 | 1800 / 2200 / 2500 / 2600 | 110 / 130 / 150 / 150 | 10 / 12 / 14 / 15 | 1.0 | 0.1 | 550 | — | 150 / 200 / 225 / 250 | 0 |
| Nhà chính | 4000 | — | 15 | — | — | — | — | — | — |

## Quái rừng (M5.5, D-76)

Mỗi phe 6 trại: 2 nhỏ, 2 vừa, 2 lớn (boss pit để sau). Chỉ số không tăng theo thời gian.

| Quái (`id`) | Máu | Sát thương | Giáp | Tốc đánh gốc | Tầm | Tốc chạy | Vàng / XP |
|---|---:|---:|---:|---:|---:|---:|---:|
| Sói con (`neutral_wolf`) | 350 | 18 | 1 | 1.2 | 100 | 320 | 30 / 40 |
| Gấu đá (`neutral_bear`) | 700 | 32 | 3 | 1.35 | 100 | 300 | 55 / 70 |
| Pháp sư rừng (`neutral_shaman`) | 400 | 26 | 0 | 1.5 | 450 | 300 | 45 / 60 |
| Trâu rừng (`neutral_buffalo`) | 1200 | 50 | 4 | 1.5 | 120 | 300 | 90 / 110 |

| Trại (`content/camps`) | Quái | Tổng vàng |
|---|---|---:|
| Nhỏ | 2 Sói con | 60 |
| Vừa | Gấu đá + Pháp sư rừng | 100 |
| Lớn | Trâu rừng + 2 Sói con | 150 |

Tầm nhìn quái 800 (để thấy kẻ đánh mình). Trại lớn số 6 mỗi phe cách lane 896: điểm kéo
quái (pull) của lane đó; các trại khác ≥ 1166, không pull được.

## Khung chỉ số cấp 1 (D-39)

Máu và giáp **cấp 1, đã tính thuộc tính** phải nằm trong khung (test kiểm tra mọi hero):

| Thuộc tính chính | Máu | Giáp |
|---|---|---|
| Sức mạnh | 500–700 | 1–5 |
| Nhanh nhẹn | 400–600 | 2–7 |
| Trí tuệ | 400–600 | 1–4 |

Bản hiện tại: Brakk 650 máu / 3.4 giáp; Noctis 500 / 5.5; Myra 460 / 2.7 (giáp phép 4.5);
Vexa 460 / 2.4 (giáp phép 4.2). Máu gốc 50–100, phần còn lại từ Sức mạnh (20 máu mỗi
điểm); hồi máu gốc 1.5/giây.

Tốc chạy gốc: 250–270 (Brakk, Myra, Vexa 255; Noctis 265), giảm ~12% sau lần chơi thử
đầu tiên để còn chỗ cho giày và skill tăng tốc.

## Mẫu cho hero mới

Thêm hero mới: sao chép một mục ở trên, điền bảng số, ghi rõ:
1. Skill nào dùng cơ chế **chưa có** trong GAME_RULES (xem bảng phủ hiệu ứng). Có thì đó là việc "cơ chế mới"
   (AGENTS mục 3), phải làm trước.
2. `bot_usage` của từng skill.
3. Một kịch bản test cho mỗi skill và mỗi talent.
