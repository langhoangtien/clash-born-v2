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
| DEF-07 | Mép trước của lane | Điểm route đầu tiên (đi về phía trước) mà từ đó công trình kế tiếp nằm trong tầm đánh của lính | `LaneRoute.limit` |
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
damage_taken_multiplier, spell_amplification`.

`damage_taken_multiplier` (mặc định 1.0) nhân vào sát thương cuối cùng mà đơn vị
nhận, sau giáp (CMB-02).

`STAT-02` Chỉ số cuối = base (hero + tăng cấp) → cộng mọi ADD → nhân với hệ số
MULTIPLY → OVERRIDE (nếu nhiều, lấy cái áp sau cùng theo id hiệu ứng) → giới hạn.
Các MULTIPLY **cộng phần trăm với nhau** rồi mới nhân (kiểu Dota): hệ số = 1 + Σ(mᵢ − 1),
không dưới 0. Ví dụ tăng tốc +20% (1.2) và chậm 30% (0.7) → ×0.9 (D-40). Công thức
thuộc tính → máu/giáp/tốc đánh lấy từ v1 (`StatCalculator`).

`STAT-03` Không gì được đổi chỉ số ngoài Modifier (ARCHITECTURE 3.2).

`STAT-04` Lên cấp hero **chỉ** cộng Sức mạnh / Nhanh nhẹn / Trí tuệ theo tăng
trưởng của hero (số lẻ được), cộng `attribute_bonus` khi đổi điểm thừa (ABL-04).
Lên cấp **không** cộng thẳng sát thương, máu, giáp hay tốc đánh; các chỉ số đó tăng
nhờ thuộc tính (D-35):

| Thuộc tính | Cho mỗi điểm |
|---|---|
| Sức mạnh (STR) | `hp_per_strength` máu, `hp_regen_per_strength` hồi máu |
| Nhanh nhẹn (AGI) | `armor_per_agility` giáp, `attack_speed_per_agility` tốc đánh |
| Trí tuệ (INT) | `mana_per_intelligence` mana, `mana_regen_per_intelligence` hồi mana, `magic_armor_per_intelligence` giáp phép (cùng hệ số và cùng công thức giảm sát thương với giáp vật lý), `spell_amp_per_intelligence` khuếch đại phép (CMB-13) |
| Thuộc tính chính | `primary_damage_coefficient` sát thương đòn đánh |

Sát thương đòn đánh = sát thương gốc của hero + thuộc tính chính ×
`primary_damage_coefficient` + modifier. Hệ số nằm ở
`content/balance/balance_settings.tres`.

`STAT-05` **Nhóm duy nhất** (`unique_group`): modifier và bị động có thể khai báo một
nhóm. Trên một đơn vị, trong cùng nhóm chỉ **một nguồn** có tác dụng; nguồn khác bị bỏ
qua hoàn toàn (không cộng chỉ số, không tung xúc xắc). Chọn nguồn (D-55, không so mạnh
yếu): **đồ thắng skill/nội tại**; hai món đồ thì **món ở ô sau** thắng (giày ô 2 thắng
giày ô 1); còn hòa thì nguồn có id nhỏ hơn. Không khai báo nhóm thì cộng dồn bình
thường (D-34).

| Nhóm | Thành viên bản đầu | Ví dụ |
|---|---|---|
| `bash` | Brakk nội tại, bị động Búa Choáng | Brakk mua Búa Choáng: chỉ bash của Búa Choáng được tung; 2 Búa Choáng không tăng tỉ lệ (CMB-08) |
| `move_speed_boots` | tốc chạy của mọi món giày (chưa có ở bản đầu) | 2 đôi giày chỉ tính đôi ở ô sau |
| `item:<id>` (tự động) | bị động của chính một món đồ | 2 món giống nhau: bị động chỉ tính một lần (ITM-04) |

Kỹ năng và trang bị **khác nhóm** vẫn kết hợp bình thường (vd Ngọc Băng Sương làm chậm
cùng chiêu làm chậm theo EFF-03). Riêng chí mạng không cần nhóm vì CMB-07 không bao
giờ nhân hệ số với nhau.

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

`ST-14` UNTARGETABLE: địch không ra được lệnh đánh / chiêu nhắm đơn vị lên nó (BAD_TARGET);
lệnh đang nhắm nó bị hủy như khi mất tầm nhìn (VIS-05), đạn đã bay vẫn trúng. Vùng và
đạn kỹ năng định hướng vẫn trúng (ABL-05/07). Đồng minh vẫn nhắm được. Vẫn được thấy.

Bảng tương tác (ARCHITECTURE mục 7) của INVISIBLE / REVEALED / UNTARGETABLE (D-73):

| Hỏi | INVISIBLE | REVEALED | UNTARGETABLE |
|---|---|---|---|
| Đi / đánh / chiêu | Được; đánh hoặc chiêu làm mất (VIS-04) | Không ảnh hưởng | Được |
| Địch nhắm được | Không (trừ khi lộ / true sight) | Có, ở mọi nơi | Không |
| Lệnh / đạn đang nhắm | Lệnh hủy, đạn đã bay vẫn trúng | — | Lệnh hủy, đạn đã bay vẫn trúng |
| Trụ, lính, nút đánh | Không thấy → không chọn; trong tầm bắn trụ thì trụ thấy và bắn (VIS-03) | Chọn được nếu trong tầm đánh | Không chọn |
| Vùng / đạn kỹ năng | Trúng | Trúng | Trúng |
| Hiển thị | Phe mình mờ 50%; địch và minimap không hiện | Như thường | Như thường |
| Với state khác | REVEALED, true sight khử; STUNNED không làm lộ; mạnh hơn bụi | Khử INVISIBLE và bụi | — |
| Mất khi | Hết giờ, đánh, dùng chiêu, chết | Hết giờ, chết | Hết giờ, chết |

`ST-15` MAGIC_IMMUNE (miễn phép, kiểu BKB):
  - Khi bắt đầu: thanh tẩy cơ bản các debuff trên mình (EFF-07).
  - Chặn mọi hiệu ứng có tag `debuff` mới từ phe địch, kể cả từ đòn đánh (Búa
    Choáng, Ngọc Băng Sương), trừ nguồn có cờ `pierces_magic_immunity`.
  - Chiêu/đồ nhắm đơn vị của địch (kể cả loại nhắm được cả ta lẫn địch như Gậy Lốc Xoáy, D-90)
    không nhắm được nó; chiêu vùng của địch không gây
    sát thương phép và không áp debuff lên nó. Nguồn xuyên miễn phép thì tác dụng đủ
    (cả sát thương phép).
  - Không chặn: đánh thường, sát thương vật lý và pure, hiệu ứng của đồng minh.
  - (D-78, giữ đúng BKB) Vùng/đạn kỹ năng vẫn **chạm** đơn vị miễn phép (đẩy, sát thương
    vật lý/pure của vùng vẫn có), nhưng phần sát thương phép và mọi debuff trong cùng chiêu
    bị chặn hết; chỉ chiêu/đồ nhắm đơn vị mới không chọn được nó làm mục tiêu.

`ST-16` HEXED (biến hình): đơn vị thành hình dạng con vật, tốc chạy bị **đặt** bằng
  `hex_move_speed` (bỏ qua mọi modifier tốc chạy), không đánh, không dùng chiêu, không
  dùng đồ; mọi hiệu ứng có tag `passive` của nó tạm tắt (trigger không chạy).
  Đang tung chiêu thì bị hủy. Tốc chạy cố định áp như modifier OVERRIDE (nguồn riêng của
  trạng thái) nên mọi nơi đọc `movement_speed` đều thấy đúng (D-78).

`ST-17` Kết hợp state: mỗi state áp độc lập, không state nào "đè" state khác trừ khi
  ghi rõ. Ví dụ GHOST + MAGIC_IMMUNE → chỉ còn nhận sát thương pure. INVULNERABLE
  chặn mọi sát thương và mọi debuff mới từ phe địch; các state đi cùng trong **cùng
  một hiệu ứng** (ví dụ Gậy Lốc Xoáy: INVULNERABLE + UNTARGETABLE + STUNNED) vẫn có tác dụng.

`ST-18` (M3.2) State tính từ hiệu ứng đang có, không gán tay; hệ thống chỉ hỏi
  `Rules.has_state / can_move / can_attack / can_cast / is_attackable / damage_factor`.
  Bị chặn hành động thì **lệnh vẫn giữ**: hết choáng/trói đơn vị làm tiếp lệnh cũ. Đòn
  đang vung bị hủy khi mất quyền đánh, không tốn hồi đòn (như CMB-06). Hệ số sát thương
  theo state nhân sau giáp, trước khiên.

---

## VIS — Tầm nhìn

- `VIS-01` Đội T thấy đơn vị E khi có ít nhất một đơn vị sống của T có khoảng cách
  tâm–tâm tới E ≤ `vision_range` của đơn vị đó. Mọi đơn vị (hero, lính, trụ, nhà chính)
  cho tầm nhìn theo dữ liệu; luôn thấy đồng đội; rừng và vách không che. Tính mỗi tick ở
  pha VISION (D-71).
- `VIS-02` E đang INVISIBLE thì đội địch không thấy E, kể cả trong tầm nhìn, cùng bụi
  (tàng hình mạnh hơn bụi). Chỉ thấy khi E bị lộ (VIS-08) hoặc ở trong true sight
  (VIS-03). Bị choáng, bị trúng đòn không làm lộ (D-73).
- `VIS-03` True sight (D-80):
  - Fountain: bán kính `fountain_true_sight` quanh tâm fountain — đội chủ luôn thấy mọi kẻ
    địch trong vùng, kể cả tàng hình, núp bụi, ngoài tầm các đơn vị.
  - Trụ: kẻ địch tàng hình mà mép thân trong **tầm bắn** của trụ thì đội chủ trụ thấy (trụ
    bắn được), ra ngoài thì ẩn lại — như tàng hình thường trong Dota (Riki, Bounty Hunter).
    Trong tầm bắn, trụ cũng thấy kẻ địch núp bụi (D-83), để map đổi chỗ bụi không phải sửa luật.
  - Loại tàng hình không bị true sight lộ (kiểu Shadow Dance của Slark) chưa có; khi có hero
    dùng thì thêm cờ riêng cho hiệu ứng.
- `VIS-04` Hiệu ứng tàng hình bị xóa khi chủ nhân bắt đầu đánh hoặc dùng chiêu (khai báo
  `removed_by`, EFF-05). `fade_in`: trong thời gian này hiệu ứng đã có (modifier có tác
  dụng) nhưng **state** của nó chưa bật — với tàng hình là vẫn bị thấy.
- `VIS-08` REVEALED (kiểu Track của Bounty Hunter, Haze của Slardar, D-73): đội của kẻ áp
  hiệu ứng thấy E ở **mọi nơi trên map**, kể cả tàng hình, trong bụi, ngoài tầm nhìn.
  Không có kẻ áp (vd fountain) thì mọi đội địch của E đều thấy.
- `VIS-06` Bụi cỏ (D-72, kiểu Liên Quân): đơn vị E có tâm nằm trong bụi B thì đội T khác
  đội E chỉ thấy E khi (a) T có đơn vị sống cũng đứng trong B (thấy cả bụi, không cần
  tầm), hoặc (b) E đang lộ (VIS-07) và VIS-01 thỏa. Áp cho mọi đội; riêng trụ thấy vào bụi trong tầm bắn của nó (VIS-03, D-83). Bụi không chặn đi lại, đạn hay vùng kỹ năng. Đứng ngoài bụi thì như VIS-01.
- `VIS-07` Ra tay thì lộ: bắt đầu vung đòn đánh (`attack_started`) hoặc tung chiêu
  (`ability_cast`) → lộ `bush_reveal_time` giây, tính từ tick sau sự kiện. Đang lộ thì
  bụi không che (vẫn cần trong tầm nhìn VIS-01).
- `VIS-05` Mất tầm nhìn tới mục tiêu: lệnh đánh/chiêu nhắm đơn vị bị hủy; đạn đã bay
  vẫn trúng. Không ra lệnh đánh / chiêu nhắm đơn vị lên kẻ không thấy (BAD_TARGET); nút
  đánh, lính, trụ chỉ chọn kẻ đang thấy. Vùng và đạn kỹ năng vẫn trúng kẻ không thấy (ABL-07).

---

## CMB — Chiến đấu

- `CMB-01` Đòn đánh xảy ra khi: đang có lệnh đánh, mục tiêu nhắm được, trong tầm,
  hết thời gian chờ (`base_attack_time / attack_speed`), không bị ST chặn.
- `CMB-02` Thứ tự tính sát thương (giữ công thức v1): trúng/né → chí mạng → giáp →
  hệ số công trình → khóa công trình (STR-02) kiểm tra **lúc trúng đòn**.
- `CMB-03` Ba loại sát thương: PHYSICAL (giáp vật lý), MAGIC (giáp phép), PURE (bỏ qua giáp).
- `CMB-04` Hero gây `hero_structure_damage` × sát thương lên công trình; lính gây
  `creep_structure_damage` ×; lính công thành `siege_structure_damage` ×.
- `CMB-04b` (D-125) Trụ gây `tower_creep_damage` × sát thương lên lính đường (0.6); lên hero,
  quái rừng và ward giữ nguyên.
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
  được tung (nhóm `bash`, chọn nguồn theo STAT-05). Thời gian chờ **do từng nguồn khai
  báo** (`cooldown` của trigger): có bash có chờ, có bash không (D-63).
- `CMB-09` Sát thương phản hồi (phản đòn, trả đòn, phân tán) được đánh dấu `reflected`
  (`damage_taken` mang lý do `reflected`; trigger nào có hành động sát thương `reflected` là
  trigger phản hồi và bỏ qua sự kiện đó):
  không kích hoạt bất kỳ trigger phản hồi nào khác (tránh hai bên phản qua phản lại vô
  hạn), không hút máu, không chí mạng, không tính là giao tranh hero (DEF-11), có tính
  để ghi công hạ gục.
- `CMB-10` Đốt mana: trừ mana của mục tiêu tối đa bằng số mana nó đang có; sự kiện
  mang lượng thực tế bị đốt (`event.burned_mana`) để hành động sau dùng.
- `CMB-13` (D-125) Khuếch đại phép: sát thương do hành động `Damage` của chiêu / đồ / hiệu ứng
  (không phải đòn đánh thường, không phải sát thương phản hồi) nhân `1 + spell_amplification`
  của kẻ gây, trước giáp. `spell_amplification` = Trí tuệ × `spell_amp_per_intelligence` (0.003)
  + modifier (đồ phép).
- `CMB-12` Đổi mục tiêu đánh (D-69): khi bắt đầu vung đòn vào mục tiêu **khác** mục tiêu
  của đòn vung trước (đánh gió không tính), phát `attack_target_changed` (kẻ gây = người
  đánh, đối tượng = mục tiêu mới). Đòn đầu tiên không phát. Đạn của đòn cũ đang bay vẫn
  trúng và vẫn tính như đòn trúng bình thường.
- `CMB-11` Né và chính xác (D-33):
  - Né từ nhiều nguồn **nhân dồn**: `evasion = 1 − Π(1 − né_i)`. Hai món né 50% →
    trúng 0.5 × 0.5 = 25% → né 75%.
  - Chính xác từ nhiều nguồn cũng **nhân dồn**: `accuracy = 1 − Π(1 − chính_xác_i)`.
    Hai món chính xác 80% → 1 − 0.2 × 0.2 = 96%.
  - Xác suất trượt = `evasion × (1 − accuracy)`. Mục tiêu né 100% (kiểu Windrun), kẻ
    đánh có 80% chính xác → 100 đòn trúng 80; có hai món 80% → trượt 4%, trúng 96%.
  - Né tối đa `evasion_cap` (1.0 = không giới hạn, như Dota).
  - Tung trượt/trúng bằng PRD (RNG-01) lúc đòn chạm (cả đạn bay). Đòn trượt không kích
    hoạt `attack_landed`, chỉ `attack_missed`; công trình không né.

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
  dùng được giữ lại. Cấp 1 có sẵn 1 điểm; cộng điểm được cả khi chờ hồi sinh (lệnh
  `LEVEL_UP`, không đổi lệnh đang làm). Lên cấp / cộng thuộc tính: máu và mana hiện tại
  cộng đúng phần tối đa tăng thêm.
- `ABL-05` Đạn định hướng (skillshot): bay thẳng theo hướng chọn tới tầm tối đa,
  trúng kẻ địch **đầu tiên** chạm phải (theo khoảng cách dọc đường bay; hòa thì id
  nhỏ hơn), không trúng công trình, trừ khi kỹ năng khai báo `pierce`. Đạn định
  hướng bị chặn bởi vách đá và rừng (không bị thân trụ chặn). Trúng khi thân đơn vị chạm
  dải đạn quét qua trong tick (bề rộng `width`); `pierce` khác 0 thì xuyên, mỗi đơn vị trúng
  một lần; trúng thì chạy `on_hit` lên đơn vị đó, sự kiện `projectile_hit` (D-67).
- `ABL-06` Vùng có độ trễ: chọn điểm lúc tung; hiện cho **cả hai đội** thấy ngay từ lúc
  tung (vòng báo trước, lõi lớn dần tới lúc nổ); sau `delay` mới xét ai đang đứng trong
  vùng (né được; bước vào đúng lúc nổ thì trúng). Tâm và bán kính chốt lúc tung. `delay`
  là giá trị có tên nên talent đổi được (D-68).
- `ABL-07` Kỹ năng vùng trúng mọi đơn vị theo `target_filter` trong vùng **tại thời
  điểm tác dụng**, kể cả INVISIBLE và UNTARGETABLE; không trúng công trình trừ khi
  khai báo `hits_structures`.
- `ABL-08` Lướt (dash, D-74): bắt đầu ở tick sau khi tung, mỗi tick đi thẳng `speed` × tick
  về phía vị trí **hiện tại** của mục tiêu (bám theo nếu nó chạy), xuyên qua mọi đơn vị
  (không đẩy tách); tới khi thân chạm mép mục tiêu thì chạy `on_arrive` lên mục tiêu
  (sự kiện `dash_arrived`). Trong lúc lướt: UNTARGETABLE, không đi/đánh/dùng chiêu theo
  lệnh; lệnh mới chờ tới khi lướt xong (như D-59). Dừng sớm, **không** chạy `on_arrive`,
  không hoàn mana/hồi chiêu khi: gặp vách đá, rừng hoặc thân trụ (đứng ở chỗ còn đi
  được cuối cùng); bị STUNNED (dừng tại chỗ); mục tiêu chết, biến mất, hoặc không còn
  nhắm được (tàng hình, UNTARGETABLE…). Chết thì hết lướt.
- `ABL-18` Chỉnh hồi chiêu (ModifyCooldownAction): cộng `amount` giây vào thời gian hồi
  còn lại của ô `slot` trên đơn vị nhận; âm thì giảm, không xuống dưới 0 (sẵn sàng ngay).
- `ABL-09` Mọi giá trị theo cấp skill là **giá trị có tên** (`damage`, `duration`…)
  khai báo trong skill; hành động đọc theo tên. Đây là chỗ talent can thiệp (TAL-02).
- `ABL-10` Đẩy lùi (knockback): đơn vị bị dời theo hướng định sẵn một khoảng trong thời
  gian định sẵn; trong lúc bị dời nó STUNNED; dừng sớm khi chạm vách đá, rừng hoặc thân
  trụ; không bao giờ đi xuyên vật cản. Hủy lệnh và chiêu đang tung của nó. Bị chặn
  bởi MAGIC_IMMUNE trừ khi nguồn xuyên miễn phép.
  (D-82) Hướng: từ chủ kỹ năng ra đơn vị bị đẩy; dời đều `distance / duration` mỗi tick
  bắt đầu từ tick sau, xuyên qua đơn vị khác; bị đẩy lại thì cú mới thay cú cũ; đang lướt
  thì hết lướt. Xong phát `knockback_finished`; lệnh cũ không tiếp tục (đứng yên).
- `ABL-13` Vùng có hai hình (D-37): **tròn** (tâm + `radius`) hoặc **chữ nhật theo
  hướng** — bắt đầu từ chủ kỹ năng, dài `length`, rộng `width`, theo hướng đã chọn
  lúc tung. Luật trúng của ABL-06/07 áp như nhau cho cả hai hình.
- `ABL-15` (D-59, kiểu Liên Quân) Chiêu nhắm đơn vị ngoài tầm: đi tới mép `cast_range` rồi
  tung. Chiêu nhắm điểm xa quá tầm: điểm kéo về mép tầm, tung ngay. Đang tung chiêu
  (`cast_time`) thì lệnh mới không hủy chiêu mà chờ, tung xong (hoặc bị hủy) mới áp. Vùng
  của kỹ năng lọc đối tượng theo `target_team` và các cờ `hits_*` (ABL-07). Nội tại học
  sẵn cấp 1; bị động lên cấp thì gỡ hiệu ứng cũ, áp lại với giá trị cấp mới.
- `ABL-16` Hồi máu / mana: mỗi tick cộng `hp_regen` / `mana_regen` (mỗi giây) × thời gian
  tick, không quá tối đa; đơn vị chết không hồi.
- `ABL-17` Vùng tồn tại (ZoneAction, D-68): tâm, bán kính chốt lúc tung; bắt đầu sau
  `delay`, tồn tại `duration`; từ lúc bắt đầu cứ mỗi `interval` chạy `actions` lên mọi
  đơn vị hợp lệ có thân chạm vùng lúc đó (lọc như ABL-07). Lần đầu ngay lúc bắt đầu, lần
  cuối trước khi hết: đứng trong vùng 4 s, mỗi 1 s một lần → đúng 4 lần. Hai đội đều
  thấy, kể cả trước lúc bắt đầu. Chủ vùng chết thì vùng vẫn còn.
- `ABL-14` Cờ bật/tắt của hành động (vd đạn `pierce`) là giá trị có tên (0 = tắt,
  khác 0 = bật) để talent đổi được (TAL-02a).

## RNG — Ngẫu nhiên

- `RNG-01` Mọi xác suất của bị động (chí mạng, bash, né…) dùng **giả ngẫu nhiên
  (PRD)** như Dota: mỗi lần không trúng, xác suất lần sau tăng dần; trúng thì về lại
  mức đầu. Trung bình vẫn đúng con số khai báo nhưng tránh chuỗi trúng/trượt liên
  tục — quan trọng cho 1v1. Bộ đếm PRD riêng cho mỗi (đơn vị, nguồn). Lần thử thứ n kể
  từ lần trúng trước có xác suất min(1, C × n), C chọn sao cho tỉ lệ trung bình đúng p
  (vd 25% → C ≈ 0.085). Chí mạng tung lúc bắt đầu vung (theo kẻ đánh và nguồn); né tung
  lúc đòn chạm (theo mục tiêu); trigger có `chance` theo (chủ hiệu ứng, nguồn). Bộ đếm
  thuộc trạng thái trận (D-30).
- `RNG-02` Mọi số ngẫu nhiên lấy từ `world.rng` có seed (INV-08).

## ITM — Trang bị

- `ITM-01` 6 ô đồ. Chỉ số của đồ là Modifier (STAT-03).
- `ITM-02` Kỹ năng chủ động/bị động của đồ dùng `AbilityDef`/`EffectDef` như skill
  hero, không có cấp, có thể có số lần dùng (`charges`).
- `ITM-03` Dùng đồ chủ động: bị chặn bởi STUNNED, HEXED; **không** bị chặn bởi
  SILENCED (giống Dota). Không tốn mana trừ khi khai báo.
- `ITM-04` Hai món cùng loại dùng chung hồi chiêu. Chỉ số thường của đồ (sát thương,
  thuộc tính…) cộng dồn; **bị động** của hai món cùng loại chỉ tính một lần (nhóm
  `item:<id>`, STAT-05). Né và chính xác vẫn nhân dồn theo CMB-11.
- `ITM-05` Giá trị khác nhau cho cận chiến/đánh xa khai báo bằng hai giá trị có tên
  (`chance_melee`, `chance_ranged`), không bằng code. Biểu thức ghi tên gốc (`chance`);
  hệ thống chọn bản `_melee` hay `_ranged` theo kiểu đánh của chủ kỹ năng.
- `ITM-06` Mua, bán, ghép đồ: ECO-06.
- `ITM-07` (M6.5, D-85) Ô đồ đánh số 1–6; chỉ số và hiệu ứng của món ở ô k mang `item_slot` = k
  (D-55: đồ ô sau thắng). Lệnh dùng đồ là CAST với ô kỹ năng `10 + (k − 1)`. Dùng xong: mọi
  món cùng loại trên người vào hồi chiêu (ITM-04); món có `charges` > 0 mất một lần dùng, hết
  thì món biến mất khỏi ô. Bị động của nhiều món cùng loại: chỉ món ở ô cao nhất áp hiệu ứng
  bị động; bỏ món đó thì món cùng loại còn lại nhận.
- `ITM-08` Dùng đồ được khi còn sống, không lướt, không STUNNED, không HEXED (ITM-03); câm lặng
  không chặn. Tầm, mana, cách nhắm như chiêu (ABL-02).

## SHOP — Mua bán (D-81, M6.5b)

- `SHOP-01` Lệnh BUY(món) / SELL(ô). Không cần đứng ở shop với đồ thường (`shop: BASE`), mua
  được cả khi đang chờ hồi sinh. Món vào ô trống đầu tiên. Từ chối: thiếu vàng
  (NOT_ENOUGH_GOLD), hết ô (INVENTORY_FULL), món không có trong cửa hàng (BAD_ITEM).
- `SHOP-02` Đồ shop ẩn (`shop: SECRET`): chỉ mua được khi hero còn sống và tâm hero cách tâm
  một shop ẩn (S1 hoặc S1') không quá `shop_radius`; không thì NOT_IN_SHOP. Cả hai đội dùng
  chung cả hai shop.
- `SHOP-03` Đồ mở theo giờ (`unlock_time` giây > 0): trước thời điểm đó từ chối NOT_YET.
- `SHOP-04` Đồ độc nhất (`unique`): trong trận chỉ một món tồn tại; đang có ai giữ thì từ
  chối SOLD_OUT. Bán lại thì món về cửa hàng; chết không rơi đồ.
- `SHOP-05` Bán: nhận `sell_ratio` × giá (làm tròn xuống); bán trong `sell_full_refund_time`
  giây sau khi mua thì hoàn đủ. Bán được ở mọi nơi, cả khi đang chờ hồi sinh.
- `SHOP-06` Thứ tự kiểm tra khi mua: món có trong cửa hàng → giờ mở → độc nhất → kho đội
  (SHOP-08) → shop ẩn → vàng → ô trống (món gộp được thì còn chỗ gộp cũng được, WRD-01).
- `SHOP-07` Mỗi món thuộc một danh mục (`category`): Tấn công, Phép, Phòng thủ, Tiện ích. Cửa
  hàng có thêm hai bộ lọc: Tất cả và Shop ẩn. Danh mục chỉ để hiển thị, không đổi luật mua bán.
- `SHOP-09` (ECO-06, D-106) Ghép đồ: món có `components` ghép từ các món đó (lặp được). Mua món
  ghép khi đang có thành phần (một cấp, mỗi ô dùng một lần, theo thứ tự thành phần): trả
  `cost` − tổng giá thành phần đang có, thành phần biến mất, món mới vào ô trống đầu tiên. Đầy ô
  nhưng có ít nhất một thành phần thì vẫn mua được. Bán món ghép: theo giá món (SHOP-05).
- `SHOP-10` (D-117) Thứ tự lên đồ (`BuildPlan`): món kế tiếp = món đầu tiên trong danh sách chưa
  có (đã ghép vào món lớn hơn cũng tính là có). Mua lúc này: món đó nếu mua được, không thì thành
  phần còn thiếu đầu tiên mua được (đi sâu vào thành phần con). Bot dùng thứ tự `bot_item_build`;
  người chơi có nút mua nhanh bên trái (trên joystick) hiện món mua được theo cùng thứ tự gợi ý
  của hero, chạm là mua; không mua được gì thì ẩn.
- `SHOP-08` Kho mỗi đội (`stock_initial`, `stock_max`, `stock_restock`; stock_max 0 = không giới
  hạn): mua trừ 1 của kho đội mình, hết thì từ chối OUT_OF_STOCK. Kho chưa đầy thì cứ
  `stock_restock` giây thêm 1 (đồng hồ chạy từ lúc kho rời mức đầy); bán không trả lại kho.

## WRD — Ward (D-92, M6.8)

- `WRD-01` Mắt vàng (`observer_ward`) / mắt xanh (`sentry_ward`): đồ chủ động nhắm điểm, tầm
  500 (xa hơn thì cắm ở mép tầm), cắm ward của phe mình ở đất đi được gần điểm nhắm nhất, tốn
  1 lần dùng; hết lần dùng thì món mất. Mua thêm cộng vào món cùng loại đang có tới
  `max_stack` (4 / 6) lần cắm, không tốn ô mới.
- `WRD-02` Ward là đơn vị loại WARD: không di chuyển, không đánh, không chắn ai, luôn
  INVISIBLE; phe mình luôn thấy. Hết `lifetime` (mắt vàng 4 phút, mắt xanh 5 phút) thì biến
  mất, không ai được thưởng.
- `WRD-03` Mắt vàng có tầm nhìn 1400 như một đơn vị (đứng trong bụi thì soi cả bụi đó, VIS-06).
  Mắt xanh không có tầm nhìn, không soi bụi; trong `true_sight_range` 900 quanh nó, kẻ tàng
  hình (hero, ward) được xét như không tàng hình — vẫn cần đội có tầm nhìn tới đó theo VIS-01 /
  VIS-06. Ward địch còn bị thấy nhờ true sight fountain, tầm bắn trụ (D-80) và REVEALED.
- `WRD-04` Máu ward = 6 đòn: mỗi đòn đánh của hero trừ `ward_hero_hit` (3), của lính / trụ /
  đơn vị khác trừ `ward_other_hit` (1), bỏ qua sát thương thật. Sát thương không phải đòn
  đánh (chiêu, vùng, phản đòn…) không tác dụng; chiêu không nhắm và không trúng ward.
- `WRD-05` Hero phá ward địch nhận `bounty_gold` của ward (mắt vàng 150, mắt xanh 25), không
  tính last hit, không XP. Lính / trụ phá thì không ai được.
- `WRD-06` Ưu tiên chọn mục tiêu: nút Lính — ward trước lính; nút Đánh — hero → lính → công
  trình → ward. Lính đường: sau mọi mục tiêu khác. Trụ: lính → hero → ward. Quái rừng không
  đánh ward.

## RCL — Về thành (D-104, kiểu Liên Quân)

- `RCL-01` Lệnh RECALL: hero còn sống, không bị choáng / biến hình (như dùng đồ được) thì đứng
  lại kênh `recall_time` giây (8 s), xong thì dịch chuyển về fountain đội mình. Không có hồi chiêu.
- `RCL-02` Bị hủy khi: có lệnh mới bất kỳ (đi, đánh, dùng chiêu…), trúng sát thương (> 0), bị
  choáng / biến hình, chết. Sự kiện `recall_started`, `recall_cancelled`, `recall_finished`.

## TAL — Talent

- `TAL-01` Khi hero đạt cấp `talent_level` (20): chọn đúng 1 trong 3 talent, mỗi
  talent nâng một skill lên tầng II. Chọn xong không đổi được trong trận. Bot chọn
  theo thứ tự ưu tiên khai báo trong dữ liệu hero.
- `TAL-02` Talent chỉ được: (a) cộng / nhân / thay giá trị có tên của skill,
  (b) thêm hành động vào cuối chuỗi hành động của skill, (c) thêm trigger hoặc hiệu
  ứng vào skill.
- `TAL-03` Talent **không được** đổi luật của một state (ví dụ cho GHOST đánh thường
  được). Muốn khác luật thì tạo state/cơ chế mới theo quy trình cơ chế mới.
- `TAL-04` Talent áp ngay lúc chọn: bị động áp lại ngay với giá trị mới; chiêu chủ động
  mạnh lên từ lần dùng sau; hiệu ứng đang chạy giữ nguyên bản cũ (D-62). Chọn bằng lệnh
  `CHOOSE_TALENT(ô)`, cần cấp `talent_level`, kỹ năng đã học; được chọn cả khi chờ hồi
  sinh; sai thì từ chối `CANNOT_CHOOSE_TALENT`. Vá hiệu ứng (TAL-02c) áp cho hiệu ứng do
  chính hero đó áp; sự kiện `talent_chosen`.

## EFF — Hiệu ứng

- `EFF-01` Cách cộng dồn: REFRESH (làm mới thời gian), STACK (thêm stack tới
  `max_stacks`, làm mới thời gian), INDEPENDENT (mỗi lần áp một bản riêng).
- `EFF-02` Hai hiệu ứng cùng id từ hai nguồn khác nhau là hai bản riêng (không cộng dồn
  tầng, hết hạn riêng); thứ không được tác dụng hai lần dùng nhóm STAT-05 (D-55). Tag có
  nghĩa trong luật: `debuff`, `buff`, `passive`, `dispellable`; thêm tag = thay đổi luật.
- `EFF-03` Làm chậm từ **các nguồn khác nhau cộng dồn** theo kiểu cộng (STAT-02): chậm
  30% và chậm 50% → chậm 80%; tổng từ 100% trở lên thì đứng yên. Hai món đồ giống nhau
  chỉ tính một lần (ITM-04); cùng một hiệu ứng áp lại thì làm mới (EFF-01). Giảm giáp:
  cộng dồn (D-39, D-40).
- `EFF-04` Trigger lồng nhau tối đa 4 tầng.
- `EFF-05` `removed_by` chỉ tính sự kiện xảy ra **sau** khi hiệu ứng được áp (dùng chiêu
  tàng hình không tự làm mất tàng hình), và chỉ sự kiện mà **chủ hiệu ứng là kẻ gây
  ra** (Noctis đánh thì mất tàng hình; Noctis bị đánh thì không). Cùng một sự kiện vừa
  kích hoạt trigger vừa xóa hiệu ứng: trigger chạy trước, xóa sau (đòn phục kích gây
  sát thương rồi mới tự mất) (D-37).
- `EFF-06` Khiên (`absorb`): hiệu ứng có lượng khiên hút sát thương mọi loại trước khi
  trừ máu, sau giáp và sau `damage_taken_multiplier`. Nhiều khiên: trừ khiên áp sớm
  nhất trước. Khiên về 0 → hiệu ứng bị xóa với lý do `depleted`.
- `EFF-07` Thanh tẩy: mỗi hiệu ứng khai báo `dispel`: BASIC, STRONG hoặc NONE — mức
  thanh tẩy thấp nhất gỡ được nó. Thanh tẩy cơ bản gỡ BASIC; thanh tẩy mạnh gỡ BASIC
  và STRONG; NONE không gỡ được. Mặc định: debuff khống chế cứng (STUNNED, HEXED) là
  STRONG; debuff khác (chậm, câm lặng, trói, cấm đánh, lộ diện) là BASIC; buff từ
  skill thường là BASIC; buff từ ultimate là NONE. Thanh tẩy **mình** gỡ debuff;
  **tước** (purge) lên địch gỡ buff.
  Tước buff (purge) của địch đang MAGIC_IMMUNE không có tác dụng, trừ nguồn xuyên miễn phép
  (như Dota, D-79). Thanh tẩy debuff trên chính mình / đồng minh không bị chặn.
- `EFF-08` Trigger khai báo **vai** của chủ hiệu ứng trong sự kiện: `as: SOURCE` (mình
  gây ra, ví dụ mình đánh trúng) hoặc `as: TARGET` (mình bị, ví dụ mình bị đánh trúng).
  Cùng sự kiện `attack_landed` có thể kích hoạt nội tại của kẻ đánh và kẻ bị đánh.
  Điều kiện (`condition`) cho phép: `target_not_structure`, `target_is_hero`,
  `this_effect_depleted` (sự kiện `effect_removed` của chính hiệu ứng này, lý do
  `depleted`), `this_effect_ended` (`effect_removed` của chính hiệu ứng này, lý do bất kỳ
  trừ `owner_died`); thêm điều kiện = thay đổi luật.
- `EFF-09` Giá trị trong hành động có thể là **biểu thức** gồm: số, giá trị có tên của
  skill, chỉ số của chủ hiệu ứng / mục tiêu (`self.strength`, `target.max_hp`…), dữ
  liệu của sự kiện (`event.damage`, `event.burned_mana`). Chỉ cộng, trừ, nhân, chia,
  min, max. Không có điều kiện if trong biểu thức; điều kiện nằm ở `condition` của trigger.
  `self.` / `target.` đọc chỉ số STAT-01 và `current_hp`, `current_mana`, `level`;
  `event.` đọc `damage`, `burned_mana`, `heal`. Danh sách nằm trong `RuleCatalog`, test
  nội dung từ chối mọi tên khác. Giá trị có tên được **chụp lúc áp** hiệu ứng: nâng cấp
  skill sau đó không đổi bản đang chạy.
- `EFF-10` Thời hạn (D-56): `duration` d giây → hiệu ứng có tác dụng đúng d giây (gỡ ở pha
  EFFECT của tick áp + d, lý do `expired`); `"0"` = vĩnh viễn; rỗng = thời lượng do hành
  động áp truyền vào.
- `EFF-11` Hiệu ứng chu kỳ: hành động chạy lần đầu sau một chu kỳ, lần cuối đúng lúc hết
  hạn (3 s, chu kỳ 1 s → 3 lần). Sát thương chu kỳ tính cho kẻ áp hiệu ứng.
- `EFF-12` STACK: modifier nhân theo số tầng (ADD × tầng; MULTIPLY: phần trăm × tầng, vd
  +10% × 3 tầng = +30%).
- `EFF-14` (M3.3) Xử lý trigger (pha TRIGGER, sau DAMAGE): sự kiện theo thứ tự phát, kể cả
  sự kiện do trigger sinh ra. Mỗi sự kiện: trigger vai SOURCE trên kẻ gây, rồi vai TARGET
  trên đối tượng; sát thương do trigger gây ra tính ngay (có thể kích hoạt tiếp tới tầng 4,
  EFF-04); rồi mới gỡ hiệu ứng `removed_by` (EFF-05). Sự kiện phát sau pha TRIGGER (chết,
  hồi sinh…) xử lý ở tick sau. Chủ hiệu ứng phải còn sống. Xác suất tạm dùng ngẫu nhiên có
  seed; PRD ở M3.6b (RNG-01). Hành động trong trigger tính kẻ gây là chủ hiệu ứng.
- `EFF-15` Kỹ năng vùng (AreaAction) trúng đơn vị theo bộ lọc của kỹ năng (ABL-07); vùng
  không thuộc kỹ năng (hiệu ứng, đồ) trúng **phe địch, không phải công trình**, nhắm được (DEF-05), mép thân trong vùng; tâm/hướng chốt lúc tung, có `delay` thì nổ sau đó;
  đơn vị trúng xử lý theo id. `falloff` f: sát thương nhân 1 − f × (khoảng cách tâm–tâm /
  bán kính), tối thiểu ở mép (f = 1 → mép nhận 0).
- `EFF-13` Chủ hiệu ứng chết → mọi hiệu ứng bị gỡ (lý do `owner_died`), trừ hiệu ứng có tag
  `passive` (D-56).

## EVT — Sự kiện

`attack_started, attack_landed, attack_missed, damage_taken, hero_attacked_hero,
ability_cast, ability_finished, effect_applied, effect_removed, unit_died,
kill_credited, structure_destroyed, unit_spawned, gold_changed, level_up,
skill_leveled, talent_chosen, dash_finished, projectile_hit, item_used,
knockback_finished, dispelled, attack_target_changed, innate_ranked, mana_burned,
lethal_damage, reincarnated, recall_started, recall_cancelled, recall_finished`.
`effect_removed` mang lý do: `expired`, `depleted`, `removed_by_event`, `removed` (hành động RemoveEffect), `dispelled`, `owner_died`.
Thêm sự kiện = thay đổi luật.

---

## CRP — Lính đường

Bảng ưu tiên (dòng trên thắng):

| Mã | State | Vào khi | Làm gì | Thoát khi |
|---|---|---|---|---|
| CRP-01 | HERO_AGGRO | Có `hero_attacked_hero` mà nạn nhân là hero phe mình và lính trong `creep_hero_aggro_range` của nạn nhân | Đánh hero gây sự | Hết `creep_hero_aggro_time` (gia hạn nếu đánh tiếp), mục tiêu không nhắm được, vượt `creep_chase_leash` từ origin |
| CRP-02 | LANE_COMBAT | Lính địch hoặc quái rừng nhắm được trong `creep_acquire_range` | Đánh lính địch / quái gần nhất (D-76) | Mục tiêu mất, vượt leash |
| CRP-03 | SIEGE | Công trình kế tiếp trong `creep_acquire_range` hoặc trong tầm đánh của lính (lính công thành tầm 690 > 500) | Đánh nó | Công trình chết; có lính địch |
| CRP-03b | SIEGE lệch route (D-118) | Lính đã tới mép trước của lane (DEF-07) mà công trình kế tiếp vẫn ngoài tầm (trụ 4 / nhà chính nằm lệch khỏi route) | Rời route, đi thẳng tới đánh nó; đánh công trình thì không bị leash / mép trước kéo về (CRP-07) | Công trình chết; có lính địch |
| CRP-04 | HERO_NEARBY | Hero địch nhắm được trong `creep_acquire_range` | Đánh hero đó | Ra khỏi tầm, vượt leash |
| CRP-05 | ADVANCE | Mặc định | Đi theo route, không vượt mép trước của lane (DEF-07) | — |

- `CRP-06` Giữ mục tiêu hiện tại khi còn hợp lệ; không đổi chỉ vì có mục tiêu gần hơn.
- `CRP-07` Hết đuổi → về điểm gần nhất trên route rồi đi tiếp, không cắt qua rừng.
- `CRP-08` Đợt lính đầu ở giây `first_wave_time`, sau đó mỗi `wave_interval`; mỗi lane
  `wave_melee` cận chiến + `wave_ranged` đánh xa; đợt thứ `siege_every_waves`, 2×… có thêm
  1 lính công thành. Sinh ở cửa lane sau T3.
- `CRP-09` Thứ tự ưu tiên: dòng trên thắng dòng dưới; trong cùng một dòng giữ mục tiêu
  hiện tại (CRP-06). Một mục tiêu bị bỏ khi: không nhắm được, lính cách origin quá
  `creep_chase_leash`, hoặc lính vượt mép trước của lane quá `creep_front_margin` (INV-03).
  Bỏ vì leash/mép trước → về điểm gần nhất trên route (CRP-07), trong lúc về không nhận
  mục tiêu mới. ADVANCE đi lần lượt qua các điểm của route (không đi tắt qua rừng), dừng ở
  mép trước của lane (DEF-07).
- `CRP-10` Lính công thành gây `siege_structure_damage` lên công trình (CMB-04).
- `CRP-11` (D-98) Lính mạnh dần: lính đường sinh ra sau k × `creep_upgrade_interval` giây (tính từ
  tick 0) có máu tối đa và sát thương × (1 + k × `creep_upgrade_step`). Vàng, XP không đổi.
- `CRP-12` (D-98) Lính siêu cấp: trụ 3 của địch trên lane L đã đổ → lính của đội phá sinh trên L
  có thêm máu × `super_creep_hp`, sát thương × `super_creep_damage`. Cả 3 trụ 3 của địch đã đổ →
  siêu lính ở mọi lane: máu × `mega_creep_hp`, sát thương × `mega_creep_damage` (thay cho hệ số
  siêu cấp), thêm `mega_extra_melee` lính cận chiến mỗi đợt, vàng × `mega_creep_bounty`.
  Nhân với hệ số CRP-11.

## STR — Công trình

- `STR-01` Trụ chọn mục tiêu (dòng trên thắng): (1) hero địch vừa gây giao tranh hero
  lên hero phe trụ, cả hai trong tầm, trong `tower_aggro_time`; (2) giữ mục tiêu hiện
  tại nếu còn trong tầm và nhắm được; (3) lính địch gần nhất; (4) hero địch gần nhất.
- `STR-02` Khóa: T1 luôn mở; T2 mở khi T1 cùng lane chết; T3 mở khi T2 cùng lane
  chết; hai T4 mở khi **bất kỳ** T3 chết; nhà chính mở khi **cả hai** T4 chết. Công
  trình khóa không nhận sát thương và không nhắm được.
- `STR-03` (Clashborn, mốc sau) Chống backdoor: công trình nhận `backdoor_multiplier`
  sát thương khi không có lính phe tấn công trong `backdoor_radius`.
- `STR-04` Fountain (không phải đơn vị, không nhắm được): mỗi tick hồi
  `fountain_regen` × máu/mana tối đa mỗi giây cho đơn vị phe mình (trừ công trình) trong
  `fountain_radius` quanh điểm fountain; cứ `fountain_attack_interval` giây gây
  `fountain_damage` sát thương thuần lên **mỗi** hero địch còn sống trong `fountain_attack_radius`
  (D-101, D-103: 600; nhà chính đặt ngoài tầm này nên đánh được từ mọi phía; sự kiện
  `fountain_shot`).
- `STR-05` Nhà chính bị phá → đội đó thua: trận ghi đội thắng, phát `match_ended`; từ đó
  `World.step()` không chạy nữa (tick đứng yên).

## JGL — Quái rừng

Quái rừng thuộc đội trung lập (đội 2), là **kẻ địch của mọi phe**: hero, lính đường, trụ
đánh được như đánh lính địch (D-76). Mỗi trại có trạng thái chung cho cả trại.

| Mã | State | Vào khi | Làm gì | Thoát khi |
|---|---|---|---|---|
| JGL-01 | AGGRO | Quái trong trại bị gây sát thương | Cả trại đánh kẻ gây sát thương **gần đây nhất** (đổi sang kẻ mới nếu kẻ khác đánh) | Mục tiêu chết/không nhắm được; mục tiêu hoặc một con quái ra ngoài `jungle_leash` từ tâm trại; `jungle_aggro_time` giây không bị đánh |
| JGL-02 | RETURN_HOME | Thoát AGGRO | Mỗi con về chỗ đứng của nó, không nhận mục tiêu (bị đánh cũng bỏ qua), tới nơi thì hồi đầy máu | Cả trại tới nơi |
| JGL-03 | IDLE | Ở trại | Đứng yên | Bị đánh |

- `JGL-04` Không chủ động đánh ai. Ai gây sát thương (hero, lính đường, trụ) thì bị đánh
  lại theo JGL-01 — đây là cơ chế kéo quái (pull) kiểu Dota (D-76).
- `JGL-05` Mọi trại xuất hiện ở `jungle_first_spawn`. Sau đó cứ mỗi `jungle_respawn_check`
  giây tính từ lần đầu, trại đã trống hồi lại nếu không có đơn vị sống nào trong bán kính
  `camp_spawn_box` quanh tâm trại.
- `JGL-06` Loại trại (small/medium/large/boss) lấy từ dữ liệu map; quái của từng loại lấy
  từ `content/camps` (CampDef). Loại không có CampDef (boss) thì chưa xuất hiện.
- `JGL-07` Thưởng (D-76): hero kết liễu → vàng + last hit (ECO-01); XP chia cho hero **cùng
  phe kẻ hạ** trong `xp_share_range` (ECO-03). Lính / trụ hạ → không ai được vàng, XP chia
  cho hero phe kẻ hạ ở gần.

## DTH — Chết và hồi sinh tại chỗ

- `DTH-01` Khi máu về 0, trước khi chết thật hệ thống phát sự kiện `lethal_damage`.
  Hiệu ứng có `prevent_death` (ví dụ tái sinh kiểu Wraith King) có thể chặn chết nếu
  còn đủ điều kiện (hết hồi chiêu, đủ mana nếu có khai báo). Hiệu ứng gắn với kỹ năng bị động
  (on_learn) thì dùng hồi chiêu và mana của kỹ năng đó; không gắn kỹ năng nào thì dùng một lần
  rồi mất (kiểu Aegis). Chặn được thì không phát `unit_died` (D-91).
- `DTH-02` Bị chặn chết thì: máu giữ ở 1, đơn vị nằm xuống tại chỗ, INVULNERABLE +
  UNTARGETABLE + không hành động trong `reincarnate_delay`, rồi đứng dậy đầy máu và mana
  tại chỗ; mọi debuff bị gỡ, buff giữ nguyên, phát `reincarnated`. Lệnh và chiêu đang vung bị
  hủy. Mọi sát thương tới (kể cả đòn khác trong cùng tick) bỏ qua đơn vị đang nằm.
- `DTH-03` (Clashborn) Tái sinh vẫn tính là một lần bị hạ: kẻ hạ nhận vàng và XP, chuỗi
  thắng/thua tính bình thường; nhưng không có thời gian chờ hồi sinh và không mất vàng.

## ECO — Kinh tế và hero

- `ECO-01` Vàng từ lính/quái chỉ cho đòn kết liễu (last hit): hero gây đòn chết nhận
  `bounty_gold` của đơn vị đó và +1 last hit; lính/trụ/fountain kết liễu thì không ai được.
  Vàng khởi đầu: mỗi hero có `starting_gold` (400, D-106) lúc vào trận.
  Vàng thụ động: cứ `passive_gold_interval` giây (tính từ tick 0) mỗi hero được
  `passive_gold` vàng, kể cả khi đang chờ hồi sinh.
- `ECO-07` Trụ đổ (ai phá cũng vậy): mọi hero đội kia nhận `bounty_gold` của trụ.
- `ECO-02` ~~Chặn (deny)~~ — bỏ (D-60): không đánh được lính phe mình.
- `ECO-03` Đơn vị chết → `bounty_xp` (hero: `hero_kill_xp_base + hero_kill_xp_per_level ×
  cấp nạn nhân`) chia đều cho hero **phe kia, còn sống**, trong `xp_share_range` quanh nơi
  chết (quái rừng: hero cùng phe kẻ hạ, JGL-07); hero hạ được luôn được tính. XP lên cấp kế: `xp_base + xp_per_level × (cấp − 1)`;
  tối đa `hero_max_level` (20), tới cấp tối đa không giữ XP.
- `ECO-08` Hạ hero: kẻ hạ (hero) nhận `hero_kill_gold_base + hero_kill_gold_per_level × cấp
  nạn nhân` vàng, sự kiện `kill_credited`; trụ/lính/fountain hạ thì vàng chia đều cho hero
  phe kia nhận XP (ECO-03).
- `ECO-04` Hero chết không bị gỡ khỏi trận: nằm chờ (không nhắm được, không đi, không
  chiếm chỗ, mọi lệnh bị từ chối `UNIT_DEAD`), hết khóa mục tiêu. Sau
  `respawn_base + respawn_per_level × cấp` giây hồi sinh tại fountain phe mình, đầy máu và
  mana, lệnh IDLE (sự kiện `hero_died`, `hero_respawned`).
- `ECO-05` Chết mất `death_gold_per_level × cấp` vàng.
- `ECO-09` KDA (M4.0): hero hạ (ECO-08) +1 hạ; nạn nhân +1 chết; mỗi hero phe kia đã gây
  sát thương lên nạn nhân trong `assist_window` (15 s) trước khi chết, trừ kẻ hạ, +1 hỗ trợ.
  Tỷ số đội = tổng số lần hero đội kia chết (kể cả bị trụ/lính hạ).
- `ECO-06` 6 ô trang bị; ghép đồ trừ giá thành phần đang có (như v1).

## CTL — Người chơi điều khiển

Điều khiển kiểu Liên Quân (D-45). Chọn mục tiêu là một hàm luật dùng chung cho người
chơi và bot (`Rules.pick_attack_target`), nút trên màn hình chỉ gọi hàm đó rồi gửi lệnh.

- `CTL-01` Joystick/WASD: di chuyển tay (`MOVE_DIR`), hủy lệnh đánh và đòn đang vung;
  thả ra → `STOP`. Chỉ gửi lệnh mới khi hướng đổi quá `input_angle_step` (3°), tối đa một
  lệnh mỗi tick. PC: chuột phải chỗ trống → `MOVE_TO`. **Điện thoại không có chạm map để đi.**
- `CTL-02` Nút ĐÁNH: giữ là đánh liên tục. Mỗi lần cần mục tiêu mới, chọn trong tầm tìm
  `attack_range + attack_search_bonus` theo thứ tự: (1) mục tiêu đang khóa nếu còn nhắm
  được; (2) hero địch — **máu thấp nhất** (cài đặt đổi được: gần nhất, % máu thấp nhất);
  (3) lính/quái gần nhất; (4) công trình đã mở khóa gần nhất. Hòa thì gần hơn, rồi id
  nhỏ hơn. Không có ai → **đánh gió**
  (D-46): vung đòn tại chỗ theo hướng đang nhìn, không gây sát thương, vẫn tốn một nhịp
  đánh; joystick hủy như đòn thường. Mục tiêu ngoài tầm đánh nhưng trong tầm tìm → tự
  tiến lại đánh. PC: phím **J** = ĐÁNH, **K** = đánh lính, **L** = đánh trụ (giả lập 3 nút).
- `CTL-03` Hai nút nhỏ cạnh nút đánh: **đánh lính** (lính/quái máu thấp nhất trong tầm tìm,
  để kết liễu lấy tiền) và **đánh trụ** (công trình mở khóa gần nhất). Hai nút này bỏ qua
  mục tiêu khóa; không có ai thì cũng đánh gió.
- Giữ nút: khi hero không còn đòn/lệnh đánh dang dở (mục tiêu chết, đánh gió xong) thì
  gửi lại lệnh của nút đó; mục tiêu đang đánh còn hợp lệ thì giữ, không đổi giữa chừng.
- `CTL-04` Chạm vào đơn vị địch (điện thoại) / chuột phải vào địch (PC): khóa mục tiêu và
  đánh; khóa giữ đến khi nó chết, mất nhắm được, hoặc ra khỏi `lock_break_range`.
- `CTL-05` Người chơi không bao giờ tự về nhà.
- `CAM-01` (D-118) Hero người chơi chết: camera tự do từ chỗ chết — joystick / WASD đẩy camera,
  kéo một ngón trên map kéo camera, không ra khỏi map; giữ bản đồ nhỏ vẫn xem nhanh như cũ.
  Hồi sinh: camera về theo hero.
- `CAM-01b` (D-126) Lúc chết, chạm / kéo trên bản đồ nhỏ: camera tự do nhảy tới chỗ đó và ở lại
  khi thả tay (không bật về chỗ cũ); sau đó vẫn đẩy / kéo tiếp được.
- `CTL-06` (M3.8, D-65) Ô chiêu Q/W/R: chạm thả tại chỗ = tung nhanh, tự nhắm (mục tiêu đang
  khóa hoặc đang đánh nếu kỹ năng nhận nó và trong tầm + tầm tìm (D-75), rồi hero địch gần
  nhất trong tầm + tầm tìm, rồi đơn vị địch gần nhất, rồi hướng đang nhìn); kéo ra quá vùng
  chết = nhắm (khoảng kéo tỉ lệ với tầm, không quá tầm), thả = tung; thả vào ô "Hủy" = không
  tung. Có điểm chưa dùng thì hiện "+" trên ô nâng được và "+TT" (thuộc tính); cấp 20 hiện
  bảng chọn talent. PC: phím 1/2/3 nhắm vào con trỏ chuột, Ctrl + 1/2/3/4 cộng điểm.

## MOV — Di chuyển

- `MOV-01` Đơn vị có lệnh MOVE đi theo đường ngắn nhất né rừng, vách và thân trụ
  (MapNavigation, MAP-01), mỗi giây đi `movement_speed` đơn vị.
- `MOV-02` Điểm đến không đứng được → đi tới điểm đứng được gần nhất (tìm trong 1600);
  không có điểm nào → lệnh xong ngay, đứng yên.
- `MOV-03` Tới điểm đến → lệnh xong, đứng yên. Đổi lệnh → tìm đường lại.
- `MOV-04` Đẩy nhau (D-41): hai đơn vị chồng lên nhau (khoảng cách tâm < tổng bán kính)
  bị đẩy tách theo đường nối tâm, mỗi bên một nửa phần chồng, mỗi tick tối đa
  `separation_speed` × thời gian tick. Bên nào bị vật cản chặn thì bên kia nhận hết.
  Đơn vị đứng yên cũng bị đẩy (hero len qua được đám lính). Xét từng cặp theo id tăng
  dần. Công trình không bao giờ bị đẩy. Bị đẩy lệch khỏi đường mà không còn đi thẳng
  tới điểm kế tiếp được thì tìm đường lại.
- `MOV-05` Không bao giờ đi hoặc bị đẩy vào vật cản (INV-01).
- `MOV-06` Đi theo hướng (lệnh `MOVE_DIR`, D-42): đi thẳng theo hướng, không tìm đường.
  Bước thẳng bị chặn thì **trượt dọc mép**: thử lệch ±15°, ±30°, ±45°, ±60°, ±75° (góc
  nhỏ trước, cùng góc thì + trước −), đi quãng = bước × cos(góc). Không góc nào đi được
  thì đứng yên tick đó. Lệnh không tự xong; dừng khi có lệnh khác (`STOP`).

## CMD — Lệnh (Command)

Người chơi, bot và controller (lính, trụ, quái) đều điều khiển đơn vị bằng lệnh.
- `CMD-01` Lệnh gửi trong tick N được áp ở pha COMMAND của tick N+1, theo đúng thứ tự gửi.
- `CMD-02` Lệnh không hợp lệ bị bỏ, kèm lý do đọc được: `UNKNOWN_UNIT` (đơn vị không tồn
  tại), `POINT_OUTSIDE_MAP` (điểm ngoài map hoặc không phải số hữu hạn), `BAD_DIRECTION`
  (hướng dài 0 hoặc không hữu hạn), `BAD_TARGET` (mục tiêu không nhắm được: không tồn
  tại, đã chết, cùng đội), `UNIT_DEAD` (đơn vị ra lệnh đang chờ hồi sinh), `NOT_LEARNED`, `ON_COOLDOWN`, `NO_MANA`,
  `CANNOT_CAST` (bị động, hoặc đang STUNNED/SILENCED). Thêm lý do khi
  thêm loại lệnh.
- `CMD-03` Lệnh hợp lệ thay lệnh hiện tại (Order) của đơn vị. `STOP` → đứng yên.
- `CMD-04` Mọi lệnh đã áp được ghi vào nhật ký kèm tick; phát lại nhật ký trên World cùng
  seed cho ra đúng trận đó (D-30).
- `CMD-05` Loại lệnh hiện có: `MOVE_TO(điểm)`, `MOVE_DIR(hướng)`, `STOP`, `ATTACK(mục tiêu)`
  (ngoài tầm thì đi tới, vào tầm thì đứng đánh; mục tiêu chết/không nhắm được → lệnh xong;
  cờ `lock` = khóa mục tiêu CTL-04), `ATTACK_AUTO(chế độ ALL / CREEP / STRUCTURE)` — chọn
  mục tiêu bằng `Rules.pick_attack_target` **lúc áp lệnh** (CTL-02/03); không có ai →
  lệnh SWING (đánh gió, D-46: vung một đòn tại chỗ, không sát thương, tốn nhịp đánh như
  đòn thường, xong thì lệnh xong), `CAST(ô, mục tiêu | điểm | hướng)` — dùng kỹ năng (ABL-02,
  ABL-15). Đánh, dùng chiêu, mua đồ thêm ở
  mốc của chúng.

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

- `BOT-10` Mọi điểm bot đi tới hoặc đứng đánh đều qua `is_safe_for_hero`, không ngoại lệ. Đường thẳng
  tới chỗ đứng đánh cũng phải an toàn; lỡ đứng chỗ không an toàn thì vào ESCAPE_TOWER.
- `BOT-16` (D-94) JUNGLE: không có việc ở lane (không TRADE / KILL / DEFEND_BASE / FARM / PUSH),
  máu ≥ 50% → đánh quái trại rừng phe mình gần nhất (trong 2500) còn quái, chỗ đứng an toàn.
  Không kéo lính.
- `BOT-11` Không đứng yên ngoài RECOVER, DEAD và lúc kênh về thành. (D-96) Có lệnh đi mà 1 s không nhích quá 20 →
  bước sang ngang 160 rồi đi tiếp; không đánh được (biến hình, tước vũ khí) mà đang có mục tiêu
  → lùi ra xa mục tiêu 300 (điểm an toàn).
- `BOT-18` (D-99) Đang hơn: hơn hero địch ≥ `bot_ahead_kills` mạng hoặc ≥ `bot_ahead_levels` cấp, hoặc
  mọi hero địch đang chết; và máu ≥ `bot_siege_min_hp`. Khi đó: PUSH xếp trước FARM, DEF-10 nới
  còn `bot_siege_tanks` lính đỡ và máu ≥ `bot_siege_min_hp`, đứng sau lính chỉ nửa
  `bot_lane_offset`, không đi shop ẩn / cắm mắt / rừng. INV-06 dùng ngưỡng nới này cho bot đang hơn.
- `BOT-21` (D-104) RETREAT: cách fountain > 2500, không thấy hero địch trong 1500 và 2 s chưa bị trúng
  sát thương → về thành (RCL) thay vì đi bộ; đang kênh thì không ra lệnh khác.
- `BOT-20` (D-101) PUSH tính cả công trình chưa thấy (công trình đứng yên, biết chỗ): đi tới chỗ đứng
  đánh, thấy rồi mới ra lệnh đánh (INV-07).
- `BOT-19` (D-99) JUNGLE chỉ khi trên lane của bot không còn lính phe mình. Tướng đánh xa canh last
  hit thêm ×1.35 (bù thời gian đạn bay).
- `BOT-17` (D-96) Chủ động cấu: hero địch trong tầm đánh + 250, máu bot ≥ 50% và hơn máu địch
  (theo phần trăm) `AHEAD` (Dễ 0.30 / Thường 0.15 / Khó 0.05) → mở cửa sổ TRADE như bị đánh.
  KILL thêm điều kiện: máu địch thấp hơn máu bot 2 × AHEAD. Thứ tự: TRADE do bị đánh → KILL →
  chủ động cấu. JUNGLE chỉ đi trại trong 1600 (điều kiện lane: BOT-19); PUSH không giới hạn khoảng cách.
- `BOT-12` Bot thấy đúng những gì đội nó thấy (VIS). Không "nhìn xuyên" tàng hình.
- `BOT-13` Bot dùng skill và đồ chủ động theo **loại** khai báo trong dữ liệu (`bot_usage`: DISABLE,
  POKE, FINISH, ENGAGE, ESCAPE, SELF_DEFENSE, TEAMFIGHT) cộng điều kiện dữ liệu của
  skill. Logic bot viết cho từng loại, **không viết cho từng skill**. Nhiều loại thì điều kiện thứ
  i đi với loại thứ i; một loại thì mọi điều kiện phải đúng (`predict_position`,
  `prefer_engaging_enemy`, `prefer_same_target` chỉ là gợi ý). Tên điều kiện: RuleCatalog
  .BOT_CONDITIONS. SELF_DEFENSE luôn cần vừa bị trúng sát thương trong 2 s; POKE giữ ≥ 40% mana.
- `BOT-14` Bot nâng skill và chọn talent theo thứ tự khai báo trong dữ liệu hero.
- `BOT-15` Skill ENGAGE chỉ dùng khi điểm đến an toàn (DEF-10); ESCAPE được dùng bất
  kể an toàn.

## MAP — Bản đồ

- `MAP-01` Hình vẽ, va chạm, tìm đường dùng chung polygon từ `tools/map_build`. Va chạm
  và tìm đường đọc trường khoảng trống (clearance) dựng từ chính các polygon đó; không
  dùng vật lý Godot. Thân trụ chặn đứng/đi với bán kính `tower_body_radius`. Ô lưới tìm
  đường chỉ đi được khi mọi pixel khoảng trống trong ô đủ rộng; kiểm tra đường thẳng duyệt
  từng pixel mà đoạn đi qua (không lấy mẫu), nên đường đi không bao giờ cắt góc vật cản.
- `MAP-03` Map phải đọc được (D-43): chỗ trống hẹp hơn `gap_min_world` (112) giữa rừng/vách
  bị lấp thành rừng khi build; vùng trống kín không vào được cũng lấp. Kiểm tra: mọi điểm
  trống rộng ≥ 12 phải cách chỗ hero đứng được không quá 48 — tức không có khe nào
  trông như lối đi mà hero không lọt.
- `MAP-02` Map 8448 × 8448; Blue dưới–trái, Red trên–phải; 3 lane; sông; vách đá chỉ
  qua ở dốc; 11 trụ mỗi đội; 6 trại mỗi phe + 1 boss pit trên trục sông.
- `MAP-04` Cân bằng (D-49): map **đối xứng xoay 180°** quanh tâm (công cụ build giữ nửa
  Blue, sinh nửa Red). Lane an toàn của Blue là BOT, của Red là TOP: ở lane an toàn đợt
  lính đầu gặp nhau ngay ngoài tầm trụ 1 của phe mình (`tower_layout` BOT 760), lane khó
  xa trụ 1 (TOP 2000), mid gặp ở giữa sông, trụ 1 mid cách đều (1200). Đợt đầu luôn
  gặp ngoài tầm mọi trụ 1; tâm trụ cách rừng/vách ≥ 160.
- `MAP-05` Chỗ mid cắt sông (D-50): trong bán kính 460 quanh tâm map không có vách hay bậc
  dốc (khu giao tranh mid để trống); sông, bờ kè và các dốc xa hơn giữ nguyên.

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

## NUM — Tham số (giá trị nằm trong `content/balance/balance_settings.tres`)

| Tham số | Khởi đầu | | Tham số | Khởi đầu |
|---|---:|---|---|---:|
| wave_interval | 30 s | | tower_attack_range | 550 |
| wave_melee / wave_ranged | 3 / 1 | | tower_aggro_time | 4 s |
| siege_every_waves | 5 | | tower_danger_margin | 100 |
| creep_acquire_range | 500 | | backdoor_multiplier / radius | 0.5 / 900 |
| creep_chase_leash | 800 | | fountain_radius | 600 |
| creep_hero_aggro_range | 500 | | fountain_true_sight | 900 |
| creep_hero_aggro_time | 2.5 s | | jungle_first_spawn | 30 s |
| hero_structure_damage | 0.5 | | jungle_respawn_check | 60 s |
| tower_creep_damage (D-125) | 0.6 | | | |
| creep_structure_damage | 0.65 | | jungle_leash | 600 |
| siege_structure_damage | 1.25 | | jungle_aggro_time | 5 s |
| hero_kill_gold base / per_level | 200 / 10 (D-125) | | hero_max_level | 20 |
| passive_gold / interval | 1 / 0.75 s (D-125) | | camp_spawn_box | 300 |
| xp_base / xp_per_level | 120 / 30 | | bot_retreat_hp / recover_hp | 0.30 / 0.80 |
| hero_kill_xp base / per_level | 60 / 30 | | bot_kill_hp / kill_range | 0.35 / 900 |
| xp_share_range | 1200 | | bot_chase_leash | 1200 |
| respawn_base / per_level | 5 / 2 s | | bot_trade_window | 3 s |
| death_gold_per_level | 25 | | bot_lane_offset | 350 |
| attack_search_bonus / lock_break_range | 100 / 1400 | | tower_tank_creeps / dive_min_hp | 2 / 0.6 |
| ghost_magic_amp | 0.4 | | talent_level | 20 |
| attribute_bonus | +2 mọi thuộc tính | | attribute_bonus_max | 7 lần |
| hex_move_speed | 140 | | bush_reveal_time | 1 s |
| shop_radius | 600 | | sell_ratio / sell_full_refund_time | 0.5 / 10 s |
| reincarnate_delay | 3 s | | match_target_minutes | 20–30 (D-97) |
| recall_time | 8 s | | | |
| ward_hero_hit / ward_other_hit | 3 / 1 (máu ward 6) | | creep_upgrade_interval / step | 300 s / 0.08 |
| super_creep_hp / damage | 1.5 / 1.5 | | mega_creep_hp / damage | 2.2 / 2.0 |
| mega_extra_melee / mega_creep_bounty | 1 / 0.5 | | | |
| first_wave_time | 15 s | | creep_front_margin | 200 |
| fountain_regen | 0.05 / s | | fountain_damage / attack_interval | 300 / 1 s |
| evasion_cap | 1.0 (không giới hạn) | | tower_body_radius | 52 |
| minimum_movement_speed | 0 (bị chậm hết thì đứng yên) | | separation_speed | 400 / s |

Mục tiêu đo được: trung vị thời lượng trận bot đấu bot nằm trong `match_target_minutes`,
hero đạt cấp 20 trong khoảng phút 14–17. Lệch thì chỉnh số trong bảng này, không sửa luật.
