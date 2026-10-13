# Luật chơi Clashborn v2

> Trạng thái: **ĐÃ CHỐT** (D-08, D-31); số trong NUM chỉnh khi chơi thử.
> Đây là nguồn sự thật duy nhất về cách trận đấu vận hành. Code làm khác tài liệu
> này là lỗi của code. Tài liệu thiếu thì sửa tài liệu trước, rồi mới sửa code.

## Cách đọc và cách sửa tài liệu này

- Mỗi luật có **mã** dạng `NHÓM-số` (ví dụ `VIS-03`). Code và test tham chiếu đúng mã
  đó. Mã đã dùng **không bao giờ đổi nghĩa**. Luật bỏ đi thì ghi "(đã bỏ, xem D-xx)".
- Mọi chữ trong luật phải quy được ra **một con số** (bảng NUM) hoặc **một hàm**
  (bảng DEF). Chữ như "gần", "an toàn", "phát hiện" phải định nghĩa trước khi dùng.
- Luật mới phải ghi rõ **thắng/thua với luật nào** khi xung đột (mục PRI).
- Kiểu Dota 2 nhưng đơn giản hóa cho 1v1 mobile. Chỗ khác Dota ghi "(Clashborn)".

---

## PRI — Thứ tự ưu tiên khi các luật xung đột

1. `PRI-01` Luật trạng thái (ST) thắng mọi luật hành vi. Ví dụ: STUNNED thì không
   đánh, dù bảng ưu tiên của bot bảo đánh.
2. `PRI-02` Luật hợp lệ mục tiêu (DEF `is_targetable`) thắng mọi bảng chọn mục tiêu.
3. `PRI-03` Luật khóa công trình (STR-02) thắng mọi thứ liên quan đến sát thương lên
   công trình.
4. `PRI-04` Trong cùng một đơn vị: bảng ưu tiên của controller, dòng trên thắng dòng dưới.
5. `PRI-05` Khi tính sát thương: INVULNERABLE → miễn theo loại (GHOST, MAGIC_IMMUNE) →
   khiên → máu. Nguồn có `pierces_magic_immunity` bỏ qua đúng bước MAGIC_IMMUNE.

---

## DEF — Định nghĩa dùng chung

| Mã | Thuật ngữ | Định nghĩa | Hàm duy nhất |
|---|---|---|---|
| DEF-01 | Khoảng cách | Mép–mép: `max(0, |A−B| − rA − rB)` | `Rules.distance` |
| DEF-02 | Trong tầm đánh | `distance ≤ attack_range` của kẻ đánh | `Rules.in_attack_range` |
| DEF-03 | Tick | 1/30 giây; mọi thời gian lưu bằng tick | `SimClock` |
| DEF-04 | Nhìn thấy | Theo VIS-01..05 | `Rules.is_visible(team, e)` |
| DEF-05 | Nhắm được | Còn sống, khác đội (hoặc filter cho phép), nhìn thấy, không bị luật ST/STR chặn | `Rules.is_targetable(by, e)` |
| DEF-06 | Công trình kế tiếp của lane | Trụ T1→T2→T3 còn sống đầu tiên của đối phương trên lane; hết thì T4 còn sống gần nhất; hết T4 thì nhà chính | `Objectives.next_for_lane` |
| DEF-07 | Mép trước của lane | Tiến độ route của công trình kế tiếp trừ tầm đánh của lính | `Rules.lane_limit` |
| DEF-08 | Origin leash | Vị trí đơn vị ở **lần đầu** vào state đuổi; sự kiện mới chỉ gia hạn thời gian | lưu trong controller |
| DEF-09 | Vùng nguy hiểm của trụ T với X | Trong `attack_range(T) + radius(X) + NUM tower_danger_margin` tính từ mép T | `Rules.tower_threat_at` |
| DEF-10 | Vị trí an toàn cho hero X | Ngoài vùng nguy hiểm mọi trụ địch, **hoặc** trụ đó đang bắn đơn vị khác và có ≥ `tower_tank_creeps` lính phe X trong tầm nó và máu X ≥ `dive_min_hp`. Trụ đang nhắm X thì không bao giờ an toàn | `Rules.is_safe_for_hero` |
| DEF-11 | Giao tranh hero | Hero A gây sát thương trực tiếp (đòn đánh hoặc kỹ năng nhắm đơn vị) lên hero B khác đội. Phản sát thương, sát thương lan không tính | sự kiện `hero_attacked_hero` |
| DEF-12 | Frontline | Lính lane còn sống có tiến độ route lớn nhất của đội trên lane | `Rules.frontline` |

---

## STAT — Chỉ số

`STAT-01` Danh sách chỉ số hợp lệ (thêm chỉ số = thay đổi luật):
`strength, agility, intelligence, max_hp, max_mana, hp_regen, mana_regen,
physical_damage, magic_damage, pure_damage, physical_armor, magic_armor,
attack_range, cast_range, base_attack_time, attack_speed, movement_speed,
vision_range, evasion, accuracy, critical_chance, critical_multiplier,
status_resistance, armor_reduction, physical_armor_penetration, lifesteal,
damage_taken_multiplier`.

`damage_taken_multiplier` (mặc định 1.0) nhân vào sát thương cuối cùng mà đơn vị
nhận, sau giáp (CMB-02).

`STAT-02` Chỉ số cuối = base (hero + tăng cấp) → cộng mọi ADD → nhân mọi MULTIPLY
→ OVERRIDE (nếu nhiều, lấy cái áp sau cùng theo id hiệu ứng) → giới hạn. Công thức
thuộc tính → máu/giáp/tốc đánh lấy từ v1 (`StatCalculator`).

`STAT-03` Không gì được đổi chỉ số ngoài Modifier (ARCHITECTURE 3.2).

---

## ST — Trạng thái

State được tính từ hiệu ứng đang có. Bảng tác động (✓ được, ✗ không):

| Mã | State | Di chuyển | Đánh thường | Dùng chiêu | Địch nhắm được | Nhận sát thương |
|---|---|---|---|---|---|---|
| ST-01 | STUNNED | ✗ | ✗ | ✗ | ✓ | ✓ |
| ST-02 | ROOTED | ✗ | ✓ | ✓ | ✓ | ✓ |
| ST-03 | SILENCED | ✓ | ✓ | ✗ | ✓ | ✓ |
| ST-04 | DISARMED | ✓ | ✗ | ✓ | ✓ | ✓ |
| ST-05 | INVISIBLE | ✓ | ✓ (VIS-04) | ✓ (VIS-04) | chỉ khi lộ (VIS-02) | ✓ |
| ST-06 | REVEALED | — | — | — | — | — |
| ST-07 | INVULNERABLE | ✓ | ✓ | ✓ | ✓ | ✗ |
| ST-08 | DEAD | ✗ | ✗ | ✗ | ✗ | ✗ |
| ST-11 | GHOST | ✓ | ✗ | ✓ | bằng chiêu ✓, bằng đánh thường ✗ | vật lý ✗; phép × (1 + `ghost_magic_amp`); pure ✓ |
| ST-12 | UNTARGETABLE | ✓ | ✓ | ✓ | ✗ (kỹ năng vùng vẫn trúng) | ✓ |
| ST-15 | MAGIC_IMMUNE | ✓ | ✓ | ✓ | đánh thường ✓; chiêu/đồ địch chỉ khi xuyên miễn phép | phép ✗ (trừ nguồn xuyên miễn phép); vật lý ✓; pure ✓ |
| ST-16 | HEXED | ✓ (tốc cố định `hex_move_speed`) | ✗ | ✗ (kể cả đồ) | ✓ | ✓ |

`ST-09` Kháng hiệu ứng (`status_resistance`) giảm thời lượng các hiệu ứng có tag
`debuff` (v1 chỉ giảm choáng).

`ST-10` State mới chỉ được thêm khi trả lời đủ **bảng tương tác bắt buộc**
(ARCHITECTURE mục 7) và có test cho từng dòng.


`ST-13` GHOST và đánh thường: đòn đánh vật lý đang bay tới mục tiêu vừa thành GHOST thì
  mất tác dụng khi chạm. Đơn vị GHOST bị STUNNED vẫn là GHOST.

`ST-14` UNTARGETABLE: lệnh đánh/chiêu đang nhắm đơn vị bị hủy như khi mất tầm nhìn (VIS-05).

`ST-15` MAGIC_IMMUNE (miễn phép, kiểu BKB):
  - Khi bắt đầu: thanh tẩy cơ bản các debuff trên mình (EFF-07).
  - Chặn mọi hiệu ứng có tag `debuff` mới từ phe địch, kể cả từ đòn đánh (Búa
    Choáng, Ngọc Băng Sương), trừ nguồn có cờ `pierces_magic_immunity`.
  - Chiêu/đồ nhắm đơn vị của địch không nhắm được nó; chiêu vùng của địch không gây
    sát thương phép và không áp debuff lên nó. Nguồn xuyên miễn phép thì tác dụng đủ
    (cả sát thương phép).
  - Không chặn: đánh thường, sát thương vật lý và pure, hiệu ứng của đồng minh.

`ST-16` HEXED (biến hình): đơn vị thành hình dạng con vật, tốc chạy bị **đặt** bằng
  `hex_move_speed` (bỏ qua mọi modifier tốc chạy), không đánh, không dùng chiêu, không
  dùng đồ; mọi hiệu ứng có tag `passive` của nó tạm tắt (trigger không chạy).
  Đang tung chiêu thì bị hủy.

`ST-17` Kết hợp state: mỗi state áp độc lập, không state nào "đè" state khác trừ khi
  ghi rõ. Ví dụ GHOST + MAGIC_IMMUNE → chỉ còn nhận sát thương pure. INVULNERABLE
  chặn mọi sát thương và mọi debuff mới từ phe địch; các state đi cùng trong **cùng
  một hiệu ứng** (ví dụ Gậy Lốc Xoáy: INVULNERABLE + UNTARGETABLE + STUNNED) vẫn có tác dụng.

---

## VIS — Tầm nhìn

- `VIS-01` Đội T thấy đơn vị E khi có ít nhất một đơn vị sống của T có khoảng cách
  tâm–tâm tới E ≤ `vision_range` của đơn vị đó. (Map hiện không có bụi.)
- `VIS-02` E đang INVISIBLE thì đội địch chỉ thấy khi E có REVEALED đối với đội đó
  (từ true sight hoặc hiệu ứng làm lộ).
- `VIS-03` Fountain có true sight bán kính `fountain_true_sight`. (Trụ không có, giống Dota.)
- `VIS-04` Hiệu ứng tàng hình mặc định bị xóa khi chủ nhân bắt đầu đánh hoặc dùng
  chiêu (khai báo `removed_by`). Có `fade_in`: trong thời gian này vẫn bị thấy.
- `VIS-05` Mất tầm nhìn tới mục tiêu: lệnh đánh/chiêu nhắm đơn vị bị hủy; đạn đã bay
  vẫn trúng.

---

## CMB — Chiến đấu

- `CMB-01` Đòn đánh xảy ra khi: đang có lệnh đánh, mục tiêu nhắm được, trong tầm,
  hết thời gian chờ (`base_attack_time / attack_speed`), không bị ST chặn.
- `CMB-02` Thứ tự tính sát thương (giữ công thức v1): trúng/né → chí mạng → giáp →
  hệ số công trình → khóa công trình (STR-02) kiểm tra **lúc trúng đòn**.
- `CMB-03` Ba loại sát thương: PHYSICAL (giáp vật lý), MAGIC (giáp phép), PURE (bỏ qua giáp).
- `CMB-04` Hero gây `hero_structure_damage` × sát thương lên công trình; lính gây
  `creep_structure_damage` ×; lính công thành `siege_structure_damage` ×.
- `CMB-05` Hút máu không áp lên công trình.
- `CMB-06` Nhịp đánh (kiểu Dota): mỗi đòn có **vung tay** (`attack_point`, giây, theo
  hero) và **thu tay**. Sát thương/đạn xuất hiện ở cuối vung tay. Di chuyển hoặc dừng
  trong lúc vung tay hủy đòn, không tính hồi đòn. Thu tay có thể hủy bằng di chuyển.
  Hoạt ảnh của view **theo** mốc thời gian này, không bao giờ ngược lại.
- `CMB-07` Chí mạng là **thay đổi đòn đánh**, không phải sát thương thêm: tung xúc xắc
  khi bắt đầu vung tay (để hoạt ảnh biết trước); nếu nhiều nguồn cùng trúng, lấy hệ
  số cao nhất; chỉ nhân sát thương vật lý của chính đòn đánh, không nhân sát thương
  thêm từ trigger (bash, phục kích…). Không chí mạng lên công trình.
- `CMB-08` Bash (đòn choáng ngẫu nhiên): trigger `attack_landed` có xác suất → choáng +
  sát thương thêm. Không tác dụng lên công trình. Nhiều nguồn bash: chỉ một nguồn
  được tung (nguồn có hệ số cao nhất), có thời gian chờ chung `bash_cooldown`.
- `CMB-09` Sát thương phản hồi (phản đòn, trả đòn, phân tán) được đánh dấu `reflected`:
  không kích hoạt bất kỳ trigger phản hồi nào khác (tránh hai bên phản qua phản lại vô
  hạn), không hút máu, không chí mạng, không tính là giao tranh hero (DEF-11), có tính
  để ghi công hạ gục.
- `CMB-10` Đốt mana: trừ mana của mục tiêu tối đa bằng số mana nó đang có; sự kiện
  mang lượng thực tế bị đốt (`event.burned_mana`) để hành động sau dùng.
- `CMB-11` Né (evasion): đòn đánh có thể trượt theo chỉ số `evasion` của mục tiêu và
  `accuracy` của kẻ đánh (công thức v1, PRD theo RNG-01). Đòn trượt không kích hoạt
  `attack_landed`, chỉ `attack_missed`.

## ABL — Kỹ năng

- `ABL-01` Mỗi hero có 3 ô nâng bằng điểm: **Q**, **W** (tối đa cấp 5) và **R** —
  ultimate (tối đa cấp 3); cộng một ô **nội tại** (innate) không tốn điểm (ABL-11).
- `ABL-11` Nội tại là kỹ năng bị động có sẵn từ cấp 1, **tự lên cấp** theo cấp hero:
  bậc 1–6 ở hero cấp 1 / 4 / 8 / 12 / 16 / 20. Mảng giá trị của nội tại có 6 phần tử.
- `ABL-12` Q hoặc W cũng có thể là bị động (`targeting: PASSIVE`), nâng bằng điểm như
  skill thường. Bị động không tốn mana, không hồi chiêu trừ khi khai báo (ví dụ bash
  có thời gian chờ).
- `ABL-02` Dùng chiêu: đủ mana, hết hồi chiêu, không SILENCED/STUNNED, mục tiêu hợp lệ
  theo `target_filter`, trong `cast_range`. Trừ mana và bắt đầu hồi chiêu **khi bắt
  đầu tung**, không phải khi kết thúc.
- `ABL-03` Đang tung chiêu (`cast_time` > 0) mà bị STUNNED/SILENCED: hủy, không hoàn mana.
- `ABL-04` Lên cấp hero nhận 1 điểm. Điểm dùng để: nâng Q/W lên cấp n khi hero
  đạt cấp `2n − 1`; nâng R lên cấp 1/2/3 khi hero đạt cấp 6/11/16; hoặc đổi lấy
  `attribute_bonus` mọi thuộc tính (tối đa `attribute_bonus_max` lần). Điểm chưa
  dùng được giữ lại.
- `ABL-05` Đạn định hướng (skillshot): bay thẳng theo hướng chọn tới tầm tối đa,
  trúng kẻ địch **đầu tiên** chạm phải (theo khoảng cách dọc đường bay; hòa thì id
  nhỏ hơn), không trúng công trình, trừ khi kỹ năng khai báo `pierce`. Đạn định
  hướng bị chặn bởi vách đá và rừng.
- `ABL-06` Vùng có độ trễ: chọn điểm lúc tung; hiện cho **cả hai đội** thấy; sau
  `delay` mới xét ai đang đứng trong vùng (né được).
- `ABL-07` Kỹ năng vùng trúng mọi đơn vị theo `target_filter` trong vùng **tại thời
  điểm tác dụng**, kể cả INVISIBLE và UNTARGETABLE; không trúng công trình trừ khi
  khai báo `hits_structures`.
- `ABL-08` Lướt (dash): di chuyển theo đường thẳng với tốc độ riêng, dừng ở mép
  mục tiêu hoặc vật cản đầu tiên; trong lúc lướt đơn vị UNTARGETABLE; bị STUNNED
  khi đang lướt thì dừng tại chỗ. Mục tiêu biến mất giữa chừng: dừng, không gây
  sát thương, không hoàn mana.
- `ABL-09` Mọi giá trị theo cấp skill là **giá trị có tên** (`damage`, `duration`…)
  khai báo trong skill; hành động đọc theo tên. Đây là chỗ talent can thiệp (TAL-02).
- `ABL-10` Đẩy lùi (knockback): đơn vị bị dời theo hướng định sẵn một khoảng trong thời
  gian định sẵn; trong lúc bị dời nó STUNNED; dừng sớm khi chạm vách đá, rừng hoặc thân
  trụ; không bao giờ đi xuyên vật cản. Hủy lệnh và chiêu đang tung của nó. Bị chặn
  bởi MAGIC_IMMUNE trừ khi nguồn xuyên miễn phép.

## RNG — Ngẫu nhiên

- `RNG-01` Mọi xác suất của bị động (chí mạng, bash, né…) dùng **giả ngẫu nhiên
  (PRD)** như Dota: mỗi lần không trúng, xác suất lần sau tăng dần; trúng thì về lại
  mức đầu. Trung bình vẫn đúng con số khai báo nhưng tránh chuỗi trúng/trượt liên
  tục — quan trọng cho 1v1. Bộ đếm PRD riêng cho mỗi (đơn vị, nguồn).
- `RNG-02` Mọi số ngẫu nhiên lấy từ `world.rng` có seed (INV-08).

## ITM — Trang bị

- `ITM-01` 6 ô đồ. Chỉ số của đồ là Modifier (STAT-03).
- `ITM-02` Kỹ năng chủ động/bị động của đồ dùng `AbilityDef`/`EffectDef` như skill
  hero, không có cấp, có thể có số lần dùng (`charges`).
- `ITM-03` Dùng đồ chủ động: bị chặn bởi STUNNED, HEXED; **không** bị chặn bởi
  SILENCED (giống Dota). Không tốn mana trừ khi khai báo.
- `ITM-04` Hai món cùng loại dùng chung hồi chiêu. Bị động "đòn đánh" cùng loại không
  cộng dồn (chỉ tính một lần, tag `unique`).
- `ITM-05` Giá trị khác nhau cho cận chiến/đánh xa khai báo bằng hai giá trị có tên
  (`chance_melee`, `chance_ranged`), không bằng code.
- `ITM-06` Mua, bán, ghép đồ: ECO-06.

## TAL — Talent

- `TAL-01` Khi hero đạt cấp `talent_level` (20): chọn đúng 1 trong 3 talent, mỗi
  talent nâng một skill lên tầng II. Chọn xong không đổi được trong trận. Bot chọn
  theo thứ tự ưu tiên khai báo trong dữ liệu hero.
- `TAL-02` Talent chỉ được: (a) cộng / nhân / thay giá trị có tên của skill,
  (b) thêm hành động vào cuối chuỗi hành động của skill, (c) thêm trigger hoặc hiệu
  ứng vào skill.
- `TAL-03` Talent **không được** đổi luật của một state (ví dụ cho GHOST đánh thường
  được). Muốn khác luật thì tạo state/cơ chế mới theo quy trình cơ chế mới.
- `TAL-04` Talent áp ngay lúc chọn, kể cả lên hiệu ứng của skill đang còn tác dụng
  ở lần dùng sau.

## EFF — Hiệu ứng

- `EFF-01` Cách cộng dồn: REFRESH (làm mới thời gian), STACK (thêm stack tới
  `max_stacks`, làm mới thời gian), INDEPENDENT (mỗi lần áp một bản riêng).
- `EFF-02` Hai hiệu ứng cùng id từ hai nguồn khác nhau là hai bản riêng, trừ khi id
  có tag `unique` (chỉ giữ bản mạnh nhất).
- `EFF-03` Làm chậm: chỉ lấy mức mạnh nhất (giống v1). Giảm giáp: cộng dồn.
- `EFF-04` Trigger lồng nhau tối đa 4 tầng.
- `EFF-05` `removed_by` chỉ tính sự kiện xảy ra **sau** khi hiệu ứng được áp (dùng chiêu
  tàng hình không tự làm mất tàng hình).
- `EFF-06` Khiên (`absorb`): hiệu ứng có lượng khiên hút sát thương mọi loại trước khi
  trừ máu, sau giáp và sau `damage_taken_multiplier`. Nhiều khiên: trừ khiên áp sớm
  nhất trước. Khiên về 0 → hiệu ứng bị xóa với lý do `depleted`.
- `EFF-07` Thanh tẩy: mỗi hiệu ứng khai báo `dispel`: BASIC, STRONG hoặc NONE — mức
  thanh tẩy thấp nhất gỡ được nó. Thanh tẩy cơ bản gỡ BASIC; thanh tẩy mạnh gỡ BASIC
  và STRONG; NONE không gỡ được. Mặc định: debuff khống chế cứng (STUNNED, HEXED) là
  STRONG; debuff khác (chậm, câm lặng, trói, cấm đánh, lộ diện) là BASIC; buff từ
  skill thường là BASIC; buff từ ultimate là NONE. Thanh tẩy **mình** gỡ debuff;
  **tước** (purge) lên địch gỡ buff.
- `EFF-08` Trigger khai báo **vai** của chủ hiệu ứng trong sự kiện: `as: SOURCE` (mình
  gây ra, ví dụ mình đánh trúng) hoặc `as: TARGET` (mình bị, ví dụ mình bị đánh trúng).
  Cùng sự kiện `attack_landed` có thể kích hoạt nội tại của kẻ đánh và kẻ bị đánh.
- `EFF-09` Giá trị trong hành động có thể là **biểu thức** gồm: số, giá trị có tên của
  skill, chỉ số của chủ hiệu ứng / mục tiêu (`self.strength`, `target.max_hp`…), dữ
  liệu của sự kiện (`event.damage`, `event.burned_mana`). Chỉ cộng, trừ, nhân, chia,
  min, max. Không có điều kiện if trong biểu thức; điều kiện nằm ở `condition` của trigger.

## EVT — Sự kiện

`attack_started, attack_landed, attack_missed, damage_taken, hero_attacked_hero,
ability_cast, ability_finished, effect_applied, effect_removed, unit_died,
kill_credited, structure_destroyed, unit_spawned, gold_changed, level_up,
skill_leveled, talent_chosen, dash_finished, projectile_hit, item_used,
knockback_finished, dispelled, attack_target_changed, innate_ranked, mana_burned,
lethal_damage, reincarnated`.
`effect_removed` mang lý do: `expired`, `depleted`, `removed_by_event`, `dispelled`, `owner_died`.
Thêm sự kiện = thay đổi luật.

---

## CRP — Lính đường

Bảng ưu tiên (dòng trên thắng):

| Mã | State | Vào khi | Làm gì | Thoát khi |
|---|---|---|---|---|
| CRP-01 | HERO_AGGRO | Có `hero_attacked_hero` mà nạn nhân là hero phe mình và lính trong `creep_hero_aggro_range` của nạn nhân | Đánh hero gây sự | Hết `creep_hero_aggro_time` (gia hạn nếu đánh tiếp), mục tiêu không nhắm được, vượt `creep_chase_leash` từ origin |
| CRP-02 | LANE_COMBAT | Lính địch nhắm được trong `creep_acquire_range` | Đánh lính địch gần nhất | Mục tiêu mất, vượt leash |
| CRP-03 | SIEGE | Công trình kế tiếp trong `creep_acquire_range` | Đánh nó | Công trình chết; có lính địch |
| CRP-04 | HERO_NEARBY | Hero địch nhắm được trong `creep_acquire_range` | Đánh hero đó | Ra khỏi tầm, vượt leash |
| CRP-05 | ADVANCE | Mặc định | Đi theo route, không vượt mép trước của lane (DEF-07) | — |

- `CRP-06` Giữ mục tiêu hiện tại khi còn hợp lệ; không đổi chỉ vì có mục tiêu gần hơn.
- `CRP-07` Hết đuổi → về điểm gần nhất trên route rồi đi tiếp, không cắt qua rừng.
- `CRP-08` Đợt lính mỗi `wave_interval`; mỗi lane `wave_melee` cận chiến + `wave_ranged`
  đánh xa; lính công thành mỗi `siege_every_waves` đợt. Sinh ở cửa lane sau T3.

## STR — Công trình

- `STR-01` Trụ chọn mục tiêu (dòng trên thắng): (1) hero địch vừa gây giao tranh hero
  lên hero phe trụ, cả hai trong tầm, trong `tower_aggro_time`; (2) giữ mục tiêu hiện
  tại nếu còn trong tầm và nhắm được; (3) lính địch gần nhất; (4) hero địch gần nhất.
- `STR-02` Khóa: T1 luôn mở; T2 mở khi T1 cùng lane chết; T3 mở khi T2 cùng lane
  chết; hai T4 mở khi **bất kỳ** T3 chết; nhà chính mở khi **cả hai** T4 chết. Công
  trình khóa không nhận sát thương và không nhắm được.
- `STR-03` (Clashborn, mốc sau) Chống backdoor: công trình nhận `backdoor_multiplier`
  sát thương khi không có lính phe tấn công trong `backdoor_radius`.
- `STR-04` Fountain hồi `fountain_regen` máu/mana mỗi giây cho phe mình trong
  `fountain_radius`, bắn hero địch trong vùng.
- `STR-05` Nhà chính bị phá → đội đó thua.

## JGL — Quái rừng

| Mã | State | Vào khi | Làm gì | Thoát khi |
|---|---|---|---|---|
| JGL-01 | AGGRO | Bị gây sát thương | Cả trại đánh kẻ gây sát thương | Mục tiêu chết/không nhắm được; mục tiêu hoặc quái ra ngoài `jungle_leash` từ tâm trại; `jungle_aggro_time` không bị đánh |
| JGL-02 | RETURN_HOME | Thoát AGGRO | Về tâm trại, không nhận mục tiêu, hồi đầy máu khi tới | Tới nơi |
| JGL-03 | IDLE | Ở trại | Đứng yên | Bị đánh |

- `JGL-04` Không chủ động đánh ai; không đánh lính đường.
- `JGL-05` Trại hồi mỗi `jungle_respawn_check` giây nếu đã trống và không có đơn vị
  nào trong `camp_spawn_box` quanh tâm trại. Lần đầu ở `jungle_first_spawn`.
- `JGL-06` Loại trại (small/medium/large/boss) lấy từ dữ liệu map.

## DTH — Chết và hồi sinh tại chỗ

- `DTH-01` Khi máu về 0, trước khi chết thật hệ thống phát sự kiện `lethal_damage`.
  Hiệu ứng có `prevent_death` (ví dụ tái sinh kiểu Wraith King) có thể chặn chết nếu
  còn đủ điều kiện (hết hồi chiêu, đủ mana nếu có khai báo).
- `DTH-02` Bị chặn chết thì: máu giữ ở 1, đơn vị nằm xuống tại chỗ, INVULNERABLE +
  UNTARGETABLE + không hành động trong `reincarnate_delay`, rồi đứng dậy đầy máu và mana
  tại chỗ; mọi debuff bị gỡ.
- `DTH-03` (Clashborn) Tái sinh vẫn tính là một lần bị hạ: kẻ hạ nhận vàng và XP, chuỗi
  thắng/thua tính bình thường; nhưng không có thời gian chờ hồi sinh và không mất vàng.

## ECO — Kinh tế và hero

- `ECO-01` Vàng từ lính/quái chỉ cho đòn kết liễu (last hit). Vàng thụ động
  `passive_gold` mỗi giây.
- `ECO-02` Chặn (deny): đánh lính phe mình dưới `deny_hp_fraction` máu; kẻ địch chỉ
  nhận `deny_xp_fraction` XP.
- `ECO-03` XP chia cho hero trong `xp_share_range` khi đơn vị địch chết.
- `ECO-04` Hồi sinh sau `respawn_base + respawn_per_level × cấp` giây, tại fountain.
- `ECO-05` Chết mất `death_gold_per_level × cấp` vàng.
- `ECO-06` 6 ô trang bị; ghép đồ trừ giá thành phần đang có (như v1).

## CTL — Người chơi điều khiển

- `CTL-01` Joystick/WASD: di chuyển tay, hủy lệnh đánh.
- `CTL-02` Nút đánh: tự chọn mục tiêu theo thứ tự (quái/lính gần nhất trong
  `command_radius` → công trình mở khóa gần nhất) ; nút đánh hero: hero gần nhất.
- `CTL-03` Chạm/click vào địch: khóa mục tiêu đến khi nó chết, mất nhắm được, hoặc ra lệnh khác.
- `CTL-04` Người chơi không bao giờ tự về nhà.

## BOT — Bot hero

Bot gửi Command giống người chơi, chỉ dùng `Rules.is_safe_for_hero` để đánh giá an toàn.

| Mã | State | Vào khi | Làm gì | Thoát khi |
|---|---|---|---|---|
| BOT-01 | ESCAPE_TOWER | Trụ/fountain địch đang nhắm bot | Tới điểm an toàn gần nhất phía nhà | Không bị nhắm và đang ở vị trí an toàn |
| BOT-02 | RETREAT | Máu < `bot_retreat_hp` | Về fountain | Tới fountain |
| BOT-03 | RECOVER | Ở fountain, máu < `bot_recover_hp` | Đứng hồi | Đủ máu |
| BOT-04 | TRADE | Bị người chơi gây giao tranh hero trong `bot_trade_window` và vị trí người chơi an toàn | Đánh trả | Hết cửa sổ, không an toàn, vượt `bot_chase_leash` |
| BOT-05 | KILL | Máu người chơi < `bot_kill_hp`, trong `bot_kill_range`, an toàn | Săn | Chết, không an toàn, vượt leash |
| BOT-06 | DEFEND_BASE | Lính địch trong base bot | Đánh lính đó | Hết lính |
| BOT-07 | FARM | Có lính địch an toàn để đánh trên lane | Ưu tiên last hit | Hết |
| BOT-08 | PUSH | Công trình kế tiếp mở, vị trí đánh an toàn | Đánh công trình | Hết điều kiện |
| BOT-09 | RALLY | Mặc định | Đứng sau frontline `bot_lane_offset`; không có thì ngay ngoài vùng nguy hiểm trụ địch | — |

- `BOT-10` Mọi điểm bot đi tới hoặc đứng đánh đều qua `is_safe_for_hero`, không ngoại lệ.
- `BOT-11` Không đứng yên ngoài RECOVER và DEAD.
- `BOT-12` Bot thấy đúng những gì đội nó thấy (VIS). Không "nhìn xuyên" tàng hình.
- `BOT-13` Bot dùng skill và đồ chủ động theo **loại** khai báo trong dữ liệu (`bot_usage`: DISABLE,
  POKE, FINISH, ENGAGE, ESCAPE, SELF_DEFENSE, TEAMFIGHT) cộng điều kiện dữ liệu của
  skill. Logic bot viết cho từng loại, **không viết cho từng skill**.
- `BOT-14` Bot nâng skill và chọn talent theo thứ tự khai báo trong dữ liệu hero.
- `BOT-15` Skill ENGAGE chỉ dùng khi điểm đến an toàn (DEF-10); ESCAPE được dùng bất
  kể an toàn.

## MAP — Bản đồ

- `MAP-01` Hình vẽ, va chạm, tìm đường dùng chung polygon từ `tools/map_build`.
- `MAP-02` Map 8448 × 8448; Blue dưới–trái, Red trên–phải; 3 lane; sông; vách đá chỉ
  qua ở dốc; 11 trụ mỗi đội; 13 trại thường + 1 boss pit.

## INV — Bất biến (test soak kiểm tra mỗi tick)

1. `INV-01` Không đơn vị nào chồng lên vật cản.
2. `INV-02` Không đơn vị nào nhắm công trình đang khóa.
3. `INV-03` Không lính đường nào vượt mép trước của lane quá 200.
4. `INV-04` Không đơn vị nào ở xa origin leash quá leash + 100.
5. `INV-05` Không đơn vị nào (trừ state cho phép) đứng yên > 2 s khi không có mục tiêu.
6. `INV-06` Bot không ở vị trí không an toàn > 1 s (trừ ESCAPE_TOWER, RETREAT).
7. `INV-07` Không đơn vị nào nhắm một đơn vị mà đội nó không thấy.
8. `INV-08` Cùng seed + cùng Command → cùng kết quả.

---

## NUM — Tham số (giá trị nằm trong `content/balance/match_rules.tres`)

| Tham số | Khởi đầu | | Tham số | Khởi đầu |
|---|---:|---|---|---:|
| wave_interval | 30 s | | tower_attack_range | 550 |
| wave_melee / wave_ranged | 3 / 1 | | tower_aggro_time | 4 s |
| siege_every_waves | 5 | | tower_danger_margin | 100 |
| creep_acquire_range | 500 | | backdoor_multiplier / radius | 0.5 / 900 |
| creep_chase_leash | 800 | | fountain_radius | 250 |
| creep_hero_aggro_range | 500 | | fountain_true_sight | 900 |
| creep_hero_aggro_time | 2.5 s | | jungle_first_spawn | 30 s |
| hero_structure_damage | 0.5 | | jungle_respawn_check | 60 s |
| creep_structure_damage | 0.65 | | jungle_leash | 600 |
| siege_structure_damage | 1.25 | | jungle_aggro_time | 5 s |
| passive_gold | 1 / 2 s | | camp_spawn_box | 300 |
| deny_hp_fraction | 0.5 | | bot_retreat_hp / recover_hp | 0.30 / 0.80 |
| deny_xp_fraction | 0.5 | | bot_kill_hp / kill_range | 0.35 / 900 |
| xp_share_range | 1200 | | bot_chase_leash | 1200 |
| respawn_base / per_level | 5 / 2 s | | bot_trade_window | 3 s |
| death_gold_per_level | 25 | | bot_lane_offset | 350 |
| command_radius | 650 | | tower_tank_creeps / dive_min_hp | 2 / 0.6 |
| ghost_magic_amp | 0.4 | | talent_level | 20 |
| attribute_bonus | +2 mọi thuộc tính | | attribute_bonus_max | 7 lần |
| hex_move_speed | 140 | | bash_cooldown | 1.5 s |
| reincarnate_delay | 3 s | | match_target_minutes | 15–20 (D-29) |

Mục tiêu đo được: trung vị thời lượng trận bot đấu bot nằm trong `match_target_minutes`,
hero đạt cấp 20 trong khoảng phút 14–17. Lệch thì chỉnh số trong bảng này, không sửa luật.
