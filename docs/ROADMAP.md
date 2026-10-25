# Lộ trình Clashborn v2

> Trạng thái: **ĐÃ CHỐT** (D-31). Việc đang làm: xem bảng "Tiến độ" cuối file.

## Nguyên tắc lộ trình

1. **Mỗi mốc kết thúc bằng thứ chơi thử được** hoặc test chạy được. Không có mốc
   "chỉ viết code nền mà không thấy gì".
2. **Một mốc = nhiều việc nhỏ.** Mỗi việc làm xong trong một buổi, là một nhánh git,
   có tiêu chí xong riêng. Agent nhận **một việc mỗi lần**, không nhận cả mốc.
3. **Chỉ đi tiếp khi mốc trước xanh:** toàn bộ test qua, bạn đã chơi thử, không còn
   lỗi đã biết của mốc đó.
4. **Không làm trước tính năng của mốc sau.** Thấy cần thì ghi vào "Để sau" của mốc
   đó, không chen vào.

Ước lượng: S = 1 buổi, M = 2–3 buổi, L = khoảng 1 tuần, giả định bạn làm cùng
agent vài buổi mỗi tuần. Con số chỉ để so độ lớn các mốc, không phải cam kết.

---

## M0 — Nền móng (L)

Chưa có gameplay; dựng khung để mọi thứ sau đứng vững.

| Việc | Xong khi |
|---|---|
| M0.1 Tạo dự án Godot 4.7.2, cấu trúc thư mục, `.gitignore`, repo | Mở được, chạy scene trống |
| M0.2 Framework test + `tools/run_tests.ps1` (import rồi chạy hết test, trả mã lỗi) | Một test mẫu xanh, một test cố ý sai báo đỏ |
| M0.3 Mang công thức v1: StatCalculator, DamageCalculator, HitCalculator, BalanceSettings, SimClock + test công thức | Test công thức v1 chạy xanh trong v2 |
| M0.4 Mang map: tools/map_build, data/maps, MapLayout, MapNavigation, MapPainter + test_map | `test_map` xanh; scene xem map chạy |
| M0.5 Định nghĩa các Resource dữ liệu: HeroDef, AbilityDef (giá trị có tên), TalentDef, EffectDef, ModifierDef, TriggerDef, ActionDef, ItemDef, UnitDef | Test nội dung: nạp được, id không trùng, tham chiếu tồn tại, mảng theo cấp đủ 5 (Q/W) hoặc 3 (R) phần tử |
| M0.6 Nhập dữ liệu 4 hero và 9 món đồ theo CONTENT.md (chỉ số, skill, talent, id hình ảnh) + trang bị chỉ số của v1 | Test nội dung xanh; chưa cần chạy được skill |

## M1 — Mô phỏng tối thiểu: một hero chạy trên map (M)

| Việc | Xong khi |
|---|---|
| M1.1 World, Entity, StatBlock (modifier, nhóm duy nhất STAT-05, thuộc tính → chỉ số STAT-04), vòng tick theo ARCHITECTURE mục 4 (hệ thống rỗng) | Test: World chạy 1000 tick; chạy lại cùng seed + nhật ký Command → hash trạng thái trùng từng tick (D-30) |
| M1.2 Command + Order + CommandSystem (MoveTo, Stop), nhật ký lệnh + phát lại | Test CMD-01..05; phát lại nhật ký trùng trạng thái từng tick |
| M1.3 MovementSystem dùng MapNavigation, va chạm giữa đơn vị | Test: MoveTo → đơn vị tới nơi, không xuyên vật cản (dời từ M1.2); INV-01 với 30 đơn vị đi ngẫu nhiên |
| M1.4 View: vẽ map + đơn vị từ World, camera theo hero, ArtLibrary + hình tạm (A0) | Chạy được, nhìn thấy |
| M1.5 Input → Command: joystick ảo + WASD + chạm để đi; **xóa lệnh đi tuần tạm** trong `app/match_scene.gd` | **Chơi thử: điều khiển hero chạy quanh map trên PC** |

## M2 — Đánh nhau cơ bản: lính, trụ, thắng thua (L)

| Việc | Xong khi |
|---|---|
| M2.1 AttackSystem (có vung tay/thu tay CMB-06) + DamageSystem + đạn bay (công thức v1), DeathSystem | Test CMB-01..06 |
| M2.2 Objectives (STR-02) + trụ, T4, nhà chính, StructureController (STR-01) | Test từng dòng STR-01, STR-02 |
| M2.3 Đợt lính + LaneCreepController (CRP-01..08); **xóa hình nộm tạm** trong `app/match_scene.gd` | Test từng dòng CRP; INV-03, INV-04 |
| M2.4 Hero người chơi: nút ĐÁNH / đánh lính / đánh trụ, khóa mục tiêu (CTL-01..04, D-45, `Rules.pick_attack_target`), hồi sinh, fountain (STR-04) | Test CTL |
| M2.5 Điều kiện thắng/thua, màn hình kết quả, HUD tối thiểu (máu, vàng, thời gian) | **Chơi thử: một mình đẩy lane phá nhà chính** |
| M2.6 Test soak lính-đấu-lính 10 phút; đo và giảm thời gian một tick (hiện ~3 ms với 60 đơn vị, chủ yếu ở controller lính/trụ và đẩy nhau) | Bất biến INV-01..05, INV-08 xanh; tick đủ nhanh cho ×8 |

## M3 — Khung hiệu ứng, skill, talent + Brakk (L)

| Việc | Xong khi |
|---|---|
| M3.1 EffectSystem: thời hạn, cộng dồn, modifier, periodic, khiên (EFF-01..06) | Test EFF |
| M3.2 StateSystem + `Rules.*` cho STUNNED, ROOTED, SILENCED, DISARMED, INVULNERABLE, GHOST, DEAD | Test từng dòng bảng ST |
| M3.3 Sự kiện + TriggerSystem + Action: Damage, Heal, ApplyEffect, RemoveEffect, AreaAt | Test EFF-04, từng Action |
| M3.4 AbilitySystem: dùng chiêu, mana, hồi chiêu, tung có thời gian (ABL-01..03, 07) | Test ABL |
| M3.5 Lên cấp, điểm skill, +thuộc tính (ABL-04), kinh tế cơ bản (ECO-01..05) | Test ABL-04, ECO |
| M3.6 Talent (TAL-01..04) | Test từng TAL |
| M3.6b Nội tại và bị động (ABL-11, 12), giả ngẫu nhiên PRD (RNG-01), chí mạng và bash (CMB-07, 08) | Test; PRD: 10.000 lần thử ra đúng tỉ lệ khai báo ±1% |
| M3.6c Viên gạch bị động: vai trigger (EFF-08), biểu thức giá trị (EFF-09), sát thương phản hồi (CMB-09), ManaBurn (CMB-10), vùng giảm dần; hero thử nghiệm cho Centaur, Axe, Spectre, Anti-Mage | Test mỗi bị động trong thư viện; không có hai bên phản qua phản lại |
| M3.7 **Brakk** đầy đủ: nội tại, Q, W, R + 3 talent | Test mỗi skill/talent một kịch bản; **chơi thử Brakk** |
| M3.8 Nút skill trên HUD (PC + cảm ứng), hiển thị hồi chiêu, chọn talent | Chơi thử |

## M4 — Myra (M)

| Việc | Xong khi |
|---|---|
| M4.1 Action SpawnProjectile (đạn định hướng, pierce, chặn bởi địa hình) (ABL-05) | Test ABL-05 |
| M4.2 Vùng có độ trễ hiện cho hai đội (ABL-06), SpawnZone | Test ABL-06 |
| M4.3 Ngắm skill trên cảm ứng: kéo nút để chọn hướng/điểm (**đã làm ở M3.8**) | Chơi thử trên màn cảm ứng |
| M4.4 **Myra** đầy đủ: nội tại (sự kiện `attack_target_changed`), Q, W, R + 3 talent | Test; **chơi thử Myra** |

## M5 — Tầm nhìn, quái rừng, Noctis (L)

| Việc | Xong khi |
|---|---|
| M5.1 VisionSystem (VIS-01, 05) + sương mù + minimap | Test VIS; INV-07 |
| M5.2 INVISIBLE / REVEALED / UNTARGETABLE + true sight fountain (VIS-02..04, ST-12, ST-14) | Test từng dòng bảng tương tác |
| M5.3 Action Dash (ABL-08), ModifyCooldown | Test ABL-08 |
| M5.4 **Noctis** đầy đủ: nội tại chí mạng, Q, W, R + 3 talent | Test; **chơi thử Noctis** |
| M5.5 Trại rừng + JungleController (JGL-01..06) | Test JGL; soak có quái rừng |

## M6 — Vexa và trang bị có kỹ năng (L)

| Việc | Xong khi |
|---|---|
| M6.1 HEXED, MAGIC_IMMUNE, INVULNERABLE và kết hợp state (ST-15..17, PRI-05) | Test từng dòng bảng tương tác |
| M6.2 Thanh tẩy / tước (EFF-07), cờ xuyên miễn phép | Test EFF-07 |
| M6.3 Action Push — đẩy lùi (ABL-10) | Test ABL-10, không xuyên vật cản |
| M6.4 **Vexa** đầy đủ: nội tại hút Trí tuệ, Q, W, R + 3 talent | Test; **chơi thử Vexa** |
| M6.5 Ô đồ, đồ chủ động/bị động (ITM-01..05), nút đồ trên HUD; luật mua bán SIM (D-81): mua mọi nơi, shop ẩn S1/S1', đồ mở theo giờ, đồ độc nhất, bán lại | Test ITM + SHOP |
| M6.6 9 món đồ trong CONTENT.md, danh mục, shop kiểu Liên Quân | Test mỗi món một kịch bản |
| M6.7 Móc chặn chết, tái sinh tại chỗ (DTH-01..03), hero thử nghiệm Wraith King | Test DTH; thưởng vàng/XP đúng |
| M6.8 Ward: mắt vàng (tầm nhìn, tàng hình), mắt xanh (nguồn true sight, lộ ward địch), phá ward khi bị lộ (D-77) | Test từng dòng bảng tương tác; **chơi thử cắm/phá ward** |

## M7 — Bot hero (L)

| Việc | Xong khi |
|---|---|
| M7.1 `Rules.is_safe_for_hero` + test kịch bản (DEF-10) | Test |
| M7.2 BOT-01..03 (thoát trụ, về nhà, hồi) | Test |
| M7.3 BOT-04..09 | Test từng dòng; INV-06 |
| M7.4 Bot dùng skill và đồ theo `bot_usage` (BOT-13..15), nâng skill, chọn talent | Test mỗi loại bot_usage với cả 4 hero |
| M7.5 Soak bot đấu bot 10 phút × 3 seed × mọi cặp hero | Mọi INV xanh; **chơi thử 1v1 với bot** |
| M7.6 Chạy trọn trận bot đấu bot × 5 seed, đo thời lượng và phút đạt cấp 20 | Trung vị 20–30 phút, cấp 20 ở phút 20–25 (D-97); lệch thì chỉnh NUM |

## M8 — Cửa hàng, giao diện, mobile (L)

| Việc | Xong khi |
|---|---|
| M8.1 Command BuyItem/SellItem + ghép đồ (ECO-06); bot mua đồ | Test |
| M8.2 Shop UI, bảng chỉ số (bảng tỷ số chi tiết: KDA, đồ, vàng từng hero), màn chọn hero | Chơi thử |
| M8.3 UI co giãn theo màn hình, hoàn thiện điều khiển cảm ứng | Chạy trên điện thoại |
| M8.4 Xuất Android, đo hiệu năng (60 fps, 40+ đơn vị) | File APK chạy trên máy thật |

**Kết thúc M8 = bản chơi được đầy đủ trên điện thoại: 4 hero hoàn chỉnh, đồ có kỹ
năng, bot biết dùng skill và đồ, không mang theo nợ kỹ thuật của v1.**

## Đồ họa (chạy song song, chi tiết ở ART.md)

| Mốc | Nội dung | Chạy cùng |
|---|---|---|
| A0 | Bộ hình tạm thống nhất, ArtLibrary, hình tạm khi thiếu | M1 |
| A1 | Hình cho từng trạng thái + icon thanh máu | Khi state đó được code (M3–M6) |
| A2 | Vùng báo trước, đạn, hiệu ứng trúng | Khi skill đó được code (M3–M6) |
| A3 | Hero thật: cắt ghép, hoạt ảnh, chân dung, icon skill | Sau khi bộ skill hero đó đã chốt |
| A4 | Giao diện hoàn chỉnh, icon đồ, màn chọn hero, shop | M8 |
| A5 | Trang trí map, âm thanh, rung màn hình | Sau M8 |

Việc đồ họa cũng theo quy trình của AGENTS.md: một việc một lần, có tiêu chí xong,
không làm hình thật cho thứ lối chơi còn đang đổi.

## Sau M8 (chưa xếp lịch)

- Hero mới: mỗi hero = mục mới trong CONTENT.md + dữ liệu + test kịch bản. Cơ chế
  chưa có thì làm trước theo quy trình cơ chế mới.
- Boss pit, chống backdoor (STR-03), thêm đồ chủ động.
- Online 1v1 (D-30): Command đã sẵn để gửi qua mạng, SIM đã xác định và có test phát
  lại. Việc còn lại: chọn mô hình mạng, máy chủ/ghép trận, xử lý trễ.

## Tiến độ

Cập nhật mỗi khi một việc xong (agent ghi trong báo cáo cuối việc).

| Việc | Trạng thái | Ngày | Ghi chú |
|---|---|---|---|
| M0.1 | Xong | 2026-10-14 | Project mở được, scene khởi động chạy; repo GitHub chờ bạn tạo |
| M0.2 | Xong | 2026-10-14 | 5 test khung xanh; fixture cố ý sai bị bắt đỏ (sai assert, lỗi script, fail) |
| M0.3 | Xong | 2026-10-14 | 40 test xanh; công thức v1 thành hàm thuần (D-32); né/chính xác nhân dồn (D-33); luật nhóm duy nhất (D-34) và lên cấp chỉ cộng thuộc tính (D-35) ghi vào luật, code ở M1.1 |
| M0.4 | Xong | 2026-10-14 | 67 test xanh (+27 test map); build lại map ra đúng từng byte; màn xem map từ nút "Xem map" |
| M0.5 | Xong | 2026-10-14 | 92 test xanh (+25); 11 khuôn dữ liệu + 13 khuôn hành động, thư viện nội dung và bộ kiểm tra; điều kiện bot (`bot_conditions`) chưa kiểm tra, để M7 |
| M0.6 | Xong | 2026-10-14 | 106 test xanh; 4 hero (16 kỹ năng, 12 talent), 9 món đồ, 30 hiệu ứng; luật bổ sung D-37, chỉnh thiết kế D-38; đồ chỉ số v1 để M8 |
| **Hết M0** | | | |
| M1.1 | Xong | 2026-10-14 | 131 test xanh (+25); StatBlock (STAT-02/04/05, CMB-11), World 12 pha, StateSystem, băm trạng thái; 1000 tick hai lần cùng seed trùng từng tick |
| M1.2 | Xong | 2026-10-14 | 145 test xanh (+10); luật CMD-01..05; tiêu chí "đi tới nơi" dời sang M1.3 |
| M1.3 | Xong | 2026-10-14 | 155 test xanh (+9); luật MOV-01..05, đẩy nhau D-41; 30 đơn vị đi ngẫu nhiên 60 s không vào vật cản, không bị kẹt; sửa tìm đường để không cắt góc |
| M1.4 | Xong | 2026-10-14 | 167 test xanh (+12); UnitFactory, SimRunner 30 tick/s, UnitsView (nội suy, y-sort, bóng, hình tạm), ArtLibrary; nút "Vào trận (thử)"; Brakk đi tuần lane giữa (tạm) |
| M1.5 | Xong | 2026-10-14 | Đã chơi thử: giảm tốc chạy 12%, sửa map (D-43, D-44) |
| **Hết M1** | | | |
| M2.1 | Xong | 2026-10-14 | 192 test xanh (+13); lệnh ATTACK, vung tay/hồi đòn (hủy không tốn hồi đòn), đạn bay, DamageSystem, DeathSystem, sự kiện; điều khiển kiểu Liên Quân ghi vào luật (D-45); hình nộm đỏ tạm để thử |
| M2.2 | Xong | 2026-10-14 | 205 test xanh (+13); 22 trụ + 2 nhà chính từ content (D-47), khóa STR-02, trụ chọn mục tiêu STR-01, hệ số CMB-04, sự kiện giao tranh hero; luật đánh gió + phím J/K/L ghi vào CTL-02 (D-46, làm ở M2.4) |
| M2.3 | Xong | 2026-10-14 | 215 test xanh (+10) + 2 test soak; lính theo Dota (D-48), đợt lính CRP-08, controller CRP-01..10, mép trước DEF-07 sửa theo tầm thật; xóa hình nộm; thêm `tests/soak` (-Soak) |
| Map D-49 | Xong | 2026-10-14 | Map đối xứng xoay 180°, trụ 1 theo vai lane, boss pit trên trục sông; 218 test xanh; đợt đầu không bị trụ bắn, hai trụ 1 lane an toàn bắt đầu bắn cùng giây 70 |
| Map D-50 | Xong | 2026-10-14 | Bỏ 4 đoạn vách/bậc dốc sát chỗ mid cắt sông (MAP-05); sông và bờ kè giữ như D-49 |
| M2.4 | Xong | 2026-10-14 | 244 test xanh (+25) + 2 soak; `Rules.pick_attack_target`, lệnh ATTACK_AUTO chọn mục tiêu lúc áp, đánh gió (SWING), khóa mục tiêu; nút ĐÁNH/Lính/Trụ + J/K/L, giữ để đánh liên tục; hero chết chờ rồi hồi sinh ở fountain (ECO-04); fountain hồi 5%/s, bắn 300/s (STR-04, D-51); sau chơi thử giảm tầm tìm mục tiêu còn +100 (D-52) |
| M2.5 | Xong | 2026-10-14 | 257 test xanh (+12) + 2 soak; thắng/thua STR-05 (trận dừng), vàng last hit/trụ/thụ động ECO-01/07 (D-53), HUD (đồng hồ, máu, mana, vàng, last hit, đếm ngược hồi sinh), màn kết quả Chơi lại / Về menu, phím F tăng tốc thử |
| M2.6 | Xong | 2026-10-14 | 259 test xanh (+2) + 3 soak; soak 10 phút (lính, trụ, 2 hero dùng nút đánh) giữ INV-01..05 mỗi tick, chạy lại khớp từng mốc 30 s (INV-08), không bước nào bị chặn; sửa 2 lỗi lính (D-54); tick 3.25 → 2.85 ms |
| **Hết M2** | | | |
| M3.1 | Xong | 2026-10-14 | 275 test xanh (+15); hiệu ứng: biểu thức EFF-09, thời hạn, cộng dồn REFRESH/STACK/INDEPENDENT, nhiều nguồn, chu kỳ (Damage/Heal), khiên, gỡ khi chết (D-56); nhóm duy nhất theo ô đồ (D-55) |
| M3.2 | Xong | 2026-10-14 | 291 test xanh (+16); state từ hiệu ứng, `Rules.has_state/can_move/can_attack/can_cast/is_attackable/damage_factor`; choáng, trói, câm lặng, cấm đánh, bất tử (chặn debuff địch), ma, chết; kháng hiệu ứng ST-09; dấu hiệu trạng thái trên hình (D-57) |
| M3.3 | Xong | 2026-10-14 | 305 test xanh (+14); TriggerSystem (vai, điều kiện, chờ, nhóm, xác suất, 4 tầng), mất hiệu ứng theo sự kiện, hành động ApplyEffect/RemoveEffect/Area (tròn, chữ nhật, trễ)/Dispel/Purge (D-58) |
| M3.4 | Xong | 2026-10-14 | 317 test xanh (+12); kỹ năng trên hero (nội tại cấp 1, bị động theo cấp), lệnh CAST + lý do từ chối, mana/hồi chiêu lúc bắt đầu, thời gian tung, hủy khi bị khống chế, tầm/điểm/lệnh chờ (D-59), hồi máu/mana theo giây; Brakk có bash nội tại trong trận |
| M3.5 | Xong | 2026-10-14 | 327 test xanh (+10); XP và lên cấp tới 20, điểm kỹ năng (Q/W 2n−1, R 6/11/16, +thuộc tính ×7), nội tại tự lên bậc, XP chia trong 1200, vàng/XP hạ hero, mất vàng khi chết, bỏ deny (D-60); HUD cấp + thanh XP; tạm tự cộng điểm |
| M3.8 (một phần) | Xong | 2026-10-14 | 330 test xanh (+3); nút chiêu Q/W/R + phím 1/2/3 tung nhanh tự nhắm, hiện cấp/hồi chiêu; vòng nổ chiêu vùng, vòng khiên (D-61). Còn lại: kéo để nhắm, chọn talent |
| M3.6 | Xong | 2026-10-14 | 337 test xanh (+7); talent cấp 20 (TAL-01..04): sửa giá trị, thêm hành động, vá hiệu ứng; test bằng 3 talent thật của Brakk (Động Đất, Giáp Nổ, Hồn Trở Về) (D-62); HUD hiện talent; tạm tự chọn |
| M3.6b | Xong | 2026-10-14 | 346 test xanh (+9); PRD (10.000 lần thử đúng ±1%, chuỗi trượt bị chặn), chí mạng CMB-07, né/trượt CMB-11 (chữ "Trượt"), bash chờ theo từng nguồn (D-63) |
| M3.6c | Xong | 2026-10-14 | 353 test xanh (+7); phản hồi CMB-09 (không phản qua phản lại, không tính giao tranh hero, vẫn tính công), đốt mana CMB-10, vùng giảm dần; Centaur/Axe/Spectre/Anti-Mage làm bằng dữ liệu trong test (D-64) |
| M3.7 | Xong | 2026-10-14 | 359 test xanh (+6); Brakk đối chiếu bảng thiết kế (mọi bậc), kịch bản nội tại (không bash trụ, tỉ lệ đúng bậc), Q (mép 300, không trúng trụ, choáng theo cấp), W (hút, làm mới, hết giờ), R (GHOST, hồi 20%, +20% tốc); chữ nổi sát thương/chí mạng/CHOÁNG/Trượt, Brakk mờ khi GHOST |
| M3.8 | Xong | 2026-10-14 | 361 test xanh (+2); kéo nút chiêu để nhắm + vạch nhắm, ô Hủy, nút + / +TT cộng điểm, bảng talent cấp 20, phím PC nhắm theo chuột (D-65) |
| **Hết M3** | | | |
| M4.0 | Xong | 2026-10-14 | 364 test xanh (+3); hàng buff/debuff đáy màn hình, KDA + hỗ trợ 15 s (ECO-09), tỷ số hai đội (D-66) |
| M4.1 | Xong | 2026-10-14 | 370 test xanh (+6); đạn kỹ năng định hướng ABL-05: kẻ đầu tiên / xuyên, bề rộng, tầm, tốc độ, rừng/vách chặn, không trúng trụ/đồng minh (D-67) |
| M4.2 | Xong | 2026-10-14 | 376 test xanh (+6); vùng có độ trễ hiện cho hai đội, né được, talent đổi độ trễ (ABL-06); vùng tồn tại ZoneAction tác dụng định kỳ (ABL-17, D-68) |
| M4.4 | Xong | 2026-10-14 | 386 test xanh (+10); Myra: nội tại Nhịp Phép với sự kiện `attack_target_changed` (CMB-12), Q/W/R đúng bảng, 3 talent; chọn tướng ở màn khởi động để chơi thử (D-69) |
| **Hết M4** | | | |
| M5.1 | Xong | 2026-10-14 | 397 test xanh (+10); tầm nhìn VIS-01/05, INV-07; sương mù; minimap giữ để xem (D-71); sửa giật đợt lính đầu (D-70) |
| M5.1b | Xong | 2026-10-15 | 404 test xanh (+7); bụi cỏ VIS-06/07: 14 bụi trên map, ẩn/lộ, cùng bụi, ra tay lộ 1 s, trụ không thấy vào bụi (D-72) |
| M5.2 | Xong | 2026-10-15 | 413 test xanh (+9); tàng hình + hiện dần, lộ diện kiểu Track, true sight fountain, UNTARGETABLE; bảng tương tác trong GAME_RULES (D-73) |
| M5.3 | Xong | 2026-10-15 | 421 test xanh (+8); lướt ABL-08 (DashSystem): tới mép, xuyên đơn vị, bám mục tiêu, dừng ở địa hình/choáng/mất mục tiêu; ModifyCooldown ABL-18 (D-74) |
| M5.4 | Xong | 2026-10-15 | 431 test xanh (+10); Noctis: chí mạng, Q lướt, W tàng hình + phục kích, R dấu tử thần, 3 talent; chiêu ưu tiên mục tiêu khóa (D-75). Chờ chơi thử |
| M5.5 | Xong | 2026-10-15 | 441 test xanh (+10); 12 trại rừng, JGL-01..07, kéo quái (pull) ở trại 6, soak có quái rừng (D-76). Chờ chơi thử |
| M5.6 | Xong | 2026-10-16 | 444 test xanh (+3); ký hiệu map dev: lưới A1…P16, tên trụ/trại/bụi/dốc/rừng/khe, phím 6 / F2, docs/map_dev.png (D-77) |
| **Hết M5** | | | |
| M6.1 | Xong | 2026-10-16 | 453 test xanh (+9); INVULNERABLE, MAGIC_IMMUNE kiểu BKB, HEXED, kết hợp state PRI-05 (D-78) |
| M6.2 | Xong | 2026-10-16 | 454 test xanh (+1); thanh tẩy mức cơ bản/mạnh (từ M3), tước buff địch miễn phép cần xuyên miễn phép (D-79) |
| M6.3 | Xong | 2026-10-16 | 460 test xanh (+6); đẩy lùi ABL-10: khoảng cách/thời gian, choáng, hủy chiêu, chặn ở địa hình và thân trụ, miễn phép (D-82) |
| M6.4 | Xong | 2026-10-16 | 468 test xanh (+8); Vexa: hút Trí tuệ, Q ếch, W sóng đẩy lùi, R tước phép xuyên miễn phép, 3 talent (D-84). Chờ chơi thử |
| M6.5a | Xong | 2026-10-16 | 475 test xanh (+7); 6 ô đồ, chỉ số, bị động một bản, chủ động (câm lặng không chặn), hồi chiêu chung, số lần dùng; hàng ô đồ HUD, phím 4–9 (D-85) |
| M6.5b | Xong | 2026-10-16 | 481 test xanh (+6); mua bán SHOP-01..06: mua mọi nơi, shop ẩn S1/S1', đồ theo giờ, đồ độc nhất, bán 50% / hoàn đủ 10 s; bảng shop tạm (D-86). Chờ chơi thử |
| D-87 | Xong | 2026-10-16 | 481 test xanh; nút đồ chủ động tròn bên trái Q (tối đa 3), bỏ hàng 6 ô |
| D-88 | Xong | 2026-10-16 | 481 test xanh; buff/debuff nằm trên nút đồ, nút đồ nhỏ hơn nút chiêu, có tên dưới nút |
| M6.6 | Xong | 2026-10-16 | 490 test xanh (+9); danh mục, shop ẩn, giờ mở, độc nhất cho 9 món; kịch bản cho từng món; cửa hàng kiểu Liên Quân (D-90). Chờ chơi thử |
| M6.7 | Xong | 2026-10-16 | 496 test + 3 soak xanh (+6); chặn chết, tái sinh tại chỗ DTH-01..03, hero thử nghiệm kiểu Wraith King, dùng một lần kiểu Aegis (D-91) |
| M6.8a | Xong | 2026-10-16 | 504 test + 3 soak xanh (+8); ward SIM WRD-01..06, kho đội SHOP-08 (D-92) |
| M6.8b | Xong | 2026-10-17 | 506 test + 3 soak xanh (+2); vẽ ward, minimap, nhắm cắm mắt bằng kéo nút, kho trong shop (D-93). Chờ chơi thử cắm / phá ward |
| M7.1 | Xong | 2026-10-17 | 510 test xanh (+4); Rules.tower_threat_at / in_enemy_fountain / is_safe_for_hero (DEF-09, DEF-10), tham số bot vào BalanceSettings |
| M7.2 | Xong | 2026-10-17 | 513 test xanh (+3); BotController (pha CONTROLLER), BotState trên Entity.bot (trong hash), MatchSetup.add_bot; BOT-01..03 |
| M7.3 | Xong | 2026-10-17 | 523 test xanh (+10); BOT-04..09, farm rừng (D-94), BOT-10 cả đường đi tới chỗ đứng, test 3 phút bot đấu bot kiểm INV-06 / BOT-11 |
| M7.4 | Xong | 2026-10-17 | 533 test xanh (+10); bot dùng chiêu / đồ theo bot_usage, nâng điểm, talent, mua đồ, shop ẩn, cắm mắt vàng, độ khó; menu chọn bot (D-95). **Chơi thử 1v1 với bot** |
| M7.5 | Xong | 2026-10-17 | 534 test + 3 soak xanh; 48 trận bot đấu bot 10 phút sạch INV-06 / BOT-11 / INV-07 sau khi sửa (D-96); soak mới test_soak_bots |
| M7.6 | Xong (chấp nhận) | 2026-10-17 | Sau về thành + base kiểu Dota: bot đấu bot kết thúc 29–39 phút khi một bên hơn, ngang tài thì dài hơn. Người chơi chấp nhận: tốc độ kết thúc sẽ chỉnh sau bằng đồ (sát thương / tốc đánh), vàng và XP từ lính (D-105) |
| Icon 4a | Xong | 2026-10-21 | 550 test xanh; 4 icon mẫu đã duyệt và nhập vào game (D-109). Tiếp: Codex làm 4b + 4c (icon skill, trạng thái), rồi 4d (55 icon đồ) |
| Icon 4b+4c | Xong | 2026-10-21 | 550 test xanh; 14 icon skill + 12 icon trạng thái nhập vào game, nút Về dùng icon về thành. Tiếp: 4d (55 icon đồ) |
| Icon 4d lô 1 | Xong | 2026-10-22 | 550 test xanh; 10 icon đồ cơ bản nhập vào game, icon trong thẻ shop to hơn (bán kính 30 → 38). Còn 44 icon đồ |
| Icon 4d xong | Xong | 2026-10-22 | 550 test xanh; đủ 55 icon đồ trong shop, nút đồ, ô đồ. **Hết Đợt 4 (icon)** |
| Icon 4e | Xong | 2026-10-22 | 550 test xanh; icon nút Đánh / Lính / Trụ (D-110), import_icons cắt viền trong suốt cho icon nút |
| Âm thanh A1 | Xong | 2026-10-22 | 557 test xanh (+7); 62 tiếng ElevenLabs (D-111..113), bộ phát theo sự kiện + thông báo + nhạc, nút chế độ tiếng (D-114). **Chơi thử có tiếng** |
| D-115 | Xong | 2026-10-22 | 559 test xanh (+2); icon cho mọi hiệu ứng, icon đồ ở bảng tỷ số, cây ghép đồ trong shop |
| APK | Xong | 2026-10-22 | Bản APK cho Android / HarmonyOS 2–4 (D-116, docs/ANDROID_BUILD.md). **Chơi thử trên Huawei** |
| D-117 / D-118 | Xong | 2026-10-22 | 563 test + 4 soak xanh (+4); lính đánh trụ 4 / nhà chính lệch route (CRP-03b), nút mua nhanh (SHOP-10), camera tự do khi chết (CAM-01) |
| D-119..D-123 | Xong | 2026-10-22 | 574 test xanh; viền cấp chiêu, soạn đồ, Lưỡi Hái / Mảnh Trăng, +30% chỉ số mỗi cấp, tướng Gorran, màn chọn tướng. Chờ Codex: icon 4f + ảnh Gorran |
| D-124..D-126 | Xong | 2026-10-22 | 583 test + soak xanh; bảng thông số kiểu Dota, kinh tế mới, trụ 60% lên lính, Bình Mana, khuếch đại phép, camera theo bản đồ nhỏ. Bot đấu bot 8 trận: 6 kết thúc 18–38 phút (trung bình ~27), Brakk–Vexa vẫn quá 40 phút. Theo dõi: một lần BOT-11 (bot đứng yên ở RALLY phút 38) trên code trước bản sửa leash, chạy lại không tái hiện |
| D-130..D-133 | Xong | 2026-10-23 | 596 test + soak xanh; giao diện fantasy, icon đồ ô vuông + nút đánh vẽ bằng code (D-131), 7 món mới với xuyên giáp phép / giảm hồi chiêu (D-132), cân bằng Gorran / Brakk (D-133). Chờ chơi thử |
| D-134..D-137 | Xong | 2026-10-23 | 616 test + soak xanh; viền chạy quanh ô buff, hero Duy Anh · Hiệp Sĩ (Quyết Đấu có phản + hồi máu, quạt, Khiên Chắn chặn sát thương). Icon Codex đã nhập, chờ chơi thử |
| D-138 | Xong | 2026-10-23 | 615 test xanh; nút Test trong trận: +10k vàng / +1 cấp / cấp 20 cho mình và bot (CMD-06) |
| D-139 | Xong | 2026-10-23 | 621 test xanh; cân bằng đồ, hút máu, tầm chiêu, đồ tầm trung, dòng hút máu / né / kháng hiệu ứng / chống phép (13 món mới, tổng 82 món). Chờ Codex Đợt 10, chờ chơi thử |
| D-140 | Xong | 2026-10-24 | 625 test xanh; Giáp Thép phản đòn, Giáp Bất Khuất giảm sát thương vật lý, Trượng Hắc Vương (kiểu BKB). Chờ Codex Đợt 11 |
| D-141 | Xong | 2026-10-24 | 632 test + soak xanh; Tim Khổng Lồ hồi %, đồ hồi phục tầm trung, Trượng Định Mệnh, Áo Choàng Kiên Định, sửa Giáp Thép / Ngọc Băng Sương II / Cánh Bướm. Chờ Codex Đợt 12 |
| D-142 | Xong | 2026-10-24 | 629 test xanh; Tim Khổng Lồ cơ chế Dota mới, Hoa Câm Lặng (khóa chiêu). Icon Đợt 12 đã nhập, chờ Codex Đợt 13 |
| D-143 | Xong | 2026-10-24 | 633 test + soak xanh; Khiên Chắn của Duy Anh thành hất đòn (8→18%, trả 50→100%) |
| D-144 | Xong | 2026-10-24 | Hình tướng / lính / quái / công trình thật trong trận + hoạt ảnh biến đổi, hiệu ứng chiêu trên bản đồ, giao diện thử 4:3 / 16:10 / 20:9. M8.3 / M8.4: chờ người chơi đo FPS trên máy tính bảng |
| D-145, D-146 | Xong (D-157) | 2026-10-24 | Bản thử 3D: mặt đất 2D dán lên mặt phẳng, tướng và lính là nhân vật KayKit có vũ khí, màu đội và hoạt ảnh. Chờ người chơi đo FPS 2D / 3D trên máy tính bảng rồi chốt |
| D-147 | Xong | 2026-10-24 | Hiệu năng: nướng bản đồ thành ô ảnh, minimap vẽ một lần (1.731 → 468 lần gọi vẽ mỗi khung) |
| D-148 | Xong | 2026-10-24 | Tự cập nhật bản thử Android: nút "Cập nhật" ở màn chọn tướng tải và mở màn cài APK mới |
| D-149 | Xong | 2026-10-24 | Hiệu năng lúc giao tranh: chỉ vẽ đơn vị trong khung nhìn, nhớ ảnh đơn vị (2,6 → 1,0 ms mỗi khung trên máy thử) |
| D-150 | Xong | 2026-10-25 | Nâng hình bản 3D: MSAA, bóng mờ dưới chân, ánh sáng / màu, sương xa, vân mặt đất. Chờ người chơi đo FPS 3D lúc giao tranh (mục tiêu ≥ 50) |
| D-151 | Xong | 2026-10-25 | Hiệu năng 3D: lớp mặt đất chỉ phủ vùng camera thấy (4,2 → 1,5 triệu điểm ảnh), MSAA 2×, nút tắt khử răng cưa để so. Chờ người chơi đo 3D lúc giao tranh, có / không khử răng cưa (mục tiêu ≥ 50) |
| D-152, D-153 | Xong | 2026-10-25 | Công cụ đo SIM 5v5 (`tools/sim_profile.gd`): 5v5 tb 6,5 / p95 11 ms. Thử SIM luồng phụ: không tăng FPS, SIM chậm hơn trên máy → bỏ. Việc sau nếu cần: tối ưu tìm đường (tick vọt) và tầm nhìn |
| D-154 | Xong | 2026-10-25 | Mức đồ họa 3D (đủ / tắt khử răng cưa / 75% độ phân giải) để đo FPS 3D trên máy rồi chọn mặc định |
| D-156 | Xong | 2026-10-25 | Hết giật giây 22 (lần cắm mắt đầu dựng lưới tìm đường ~190 ms): dựng sẵn lúc vào trận |
| D-157 | Xong | 2026-10-25 | Chốt 3D: gộp vào main, bỏ vẽ đơn vị 2D, nút "Đồ họa" Thấp / Vừa / Cao (mặc định Thấp) |
| D-158 | Xong | 2026-10-25 | Trụ, nhà chính 3D (Medieval Hexagon); cây, đá, chợ, đổ nát tự dựng từ dữ liệu map |
| D-159 | Chơi thử | 2026-10-25 | Cảm giác đòn: điểm chém khớp tick ra đòn, khựng khung, lóe trắng, giật lùi, rung camera, hoạt ảnh riêng từng chiêu. Chờ người chơi đánh giá |
| D-160 | Chơi thử | 2026-10-25 | Cỡ tướng / lính / cây / trụ, lóe dịu, sông gợn sóng, bụi cỏ tạm, pháp sư rừng 3D. Chờ asset thú rừng (gấu, trâu, sói) và bụi cỏ |
