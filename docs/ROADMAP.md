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
| M1.2 Command + Order + CommandSystem (MoveTo, Stop) | Test: Command MoveTo → đơn vị tới nơi, không xuyên vật cản |
| M1.3 MovementSystem dùng MapNavigation, va chạm giữa đơn vị | Test INV-01 với 30 đơn vị đi ngẫu nhiên |
| M1.4 View: vẽ map + đơn vị từ World, camera theo hero, ArtLibrary + hình tạm (A0) | Chạy được, nhìn thấy |
| M1.5 Input → Command: joystick ảo + WASD + chạm để đi | **Chơi thử: điều khiển hero chạy quanh map trên PC** |

## M2 — Đánh nhau cơ bản: lính, trụ, thắng thua (L)

| Việc | Xong khi |
|---|---|
| M2.1 AttackSystem (có vung tay/thu tay CMB-06) + DamageSystem + đạn bay (công thức v1), DeathSystem | Test CMB-01..06 |
| M2.2 Objectives (STR-02) + trụ, T4, nhà chính, StructureController (STR-01) | Test từng dòng STR-01, STR-02 |
| M2.3 Đợt lính + LaneCreepController (CRP-01..08) | Test từng dòng CRP; INV-03, INV-04 |
| M2.4 Hero người chơi: lệnh đánh (CTL-02, CTL-03), hồi sinh, fountain (STR-04) | Test CTL |
| M2.5 Điều kiện thắng/thua, màn hình kết quả, HUD tối thiểu (máu, vàng, thời gian) | **Chơi thử: một mình đẩy lane phá nhà chính** |
| M2.6 Test soak lính-đấu-lính 10 phút | Bất biến INV-01..05, INV-08 xanh |

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
| M4.3 Ngắm skill trên cảm ứng: kéo nút để chọn hướng/điểm | Chơi thử trên màn cảm ứng |
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
| M6.5 Ô đồ, đồ chủ động/bị động (ITM-01..05), nút đồ trên HUD; cho đồ bằng lệnh debug | Test ITM |
| M6.6 9 món đồ trong CONTENT.md | Test mỗi món một kịch bản |
| M6.7 Móc chặn chết, tái sinh tại chỗ (DTH-01..03), hero thử nghiệm Wraith King | Test DTH; thưởng vàng/XP đúng |

## M7 — Bot hero (L)

| Việc | Xong khi |
|---|---|
| M7.1 `Rules.is_safe_for_hero` + test kịch bản (DEF-10) | Test |
| M7.2 BOT-01..03 (thoát trụ, về nhà, hồi) | Test |
| M7.3 BOT-04..09 | Test từng dòng; INV-06 |
| M7.4 Bot dùng skill và đồ theo `bot_usage` (BOT-13..15), nâng skill, chọn talent | Test mỗi loại bot_usage với cả 4 hero |
| M7.5 Soak bot đấu bot 10 phút × 3 seed × mọi cặp hero | Mọi INV xanh; **chơi thử 1v1 với bot** |
| M7.6 Chạy trọn trận bot đấu bot × 5 seed, đo thời lượng và phút đạt cấp 20 | Trung vị 15–20 phút, cấp 20 ở phút 14–17 (D-29); lệch thì chỉnh NUM |

## M8 — Cửa hàng, giao diện, mobile (L)

| Việc | Xong khi |
|---|---|
| M8.1 Command BuyItem/SellItem + ghép đồ (ECO-06); bot mua đồ | Test |
| M8.2 Shop UI, bảng chỉ số, màn chọn hero | Chơi thử |
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
| M0.6 | Chờ duyệt kế hoạch | | |
