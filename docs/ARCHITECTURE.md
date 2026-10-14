# Kiến trúc Clashborn v2

> Trạng thái: **ĐÃ CHỐT** (D-07, D-31). Đổi kiến trúc phải có quyết định mới trong `DECISIONS.md`.

Mục tiêu của kiến trúc này chỉ có một: **thêm một hero, một kỹ năng, một món đồ
hay một cơ chế mới mà không phải sửa lan ra nhiều chỗ, và không làm hỏng thứ cũ.**

Mọi quy định bên dưới phục vụ mục tiêu đó.

---

## 1. Ba tầng, phụ thuộc một chiều

```
┌──────────────────────────────────────────────────────────────┐
│  APP          scene, luồng game: menu → chọn hero → trận     │
├──────────────────────────────────────────────────────────────┤
│  VIEW         vẽ trạng thái mô phỏng, UI, nhận input         │
│               chỉ ĐỌC sim; muốn thay đổi gì phải gửi Command │
├──────────────────────────────────────────────────────────────┤
│  SIM          mô phỏng trận đấu thuần logic, 30 tick/giây    │
│               không Node, không vẽ, không input, không giờ   │
│               hệ thống, có seed → chạy lại ra đúng kết quả   │
├──────────────────────────────────────────────────────────────┤
│  CONTENT      dữ liệu .tres: hero, kỹ năng, hiệu ứng, đồ,    │
│               lính, trụ, map, số cân bằng                    │
└──────────────────────────────────────────────────────────────┘
```

- Tầng trên được dùng tầng dưới, **không bao giờ ngược lại**. SIM không biết VIEW
  tồn tại.
- Người chơi và bot đi **cùng một đường**: cả hai tạo `Command` (đi tới, đánh, dùng
  kỹ năng, mua đồ) → SIM kiểm tra hợp lệ → thực hiện. Bot không có "quyền đặc biệt",
  và sau này làm online chỉ cần gửi Command qua mạng.
- Vì SIM là logic thuần, test chạy một trận 10 phút trong vài giây, không cần mở scene.

## 2. Thư mục

```
clashborn_v2/
  AGENTS.md                quy tắc cho AI agent (đọc đầu tiên)
  docs/
    GAME_RULES.md          luật chơi — nguồn sự thật duy nhất về hành vi
    ARCHITECTURE.md        tài liệu này
    ROADMAP.md             các mốc, việc, tiêu chí xong
    DECISIONS.md           nhật ký quyết định (chỉ thêm, không sửa)
    CONTENT.md             thiết kế hero và trang bị (bản thiết kế của content/)
    ART.md                 phong cách, hợp đồng hình ảnh, lộ trình đồ họa
  content/                 dữ liệu (.tres), không có logic
    heroes/  abilities/  effects/  items/  units/  balance/
  data/maps/               map đã build (từ tools/map_build)
  sim/                     tầng SIM
    core/                  công thức (mang từ v1): stat, sát thương, trúng/né
    rules.gd               Rules: khoảng cách mép–mép, trong tầm, nhắm được (DEF, ST)
    world/                 World (pha tick, events, damage_requests, projectiles, state_hash), Entity,
                           GameEvent, DamageRequest, Projectile, UnitFactory, MatchSetup, Objectives (STR-02),
                           SpatialGrid (tra đơn vị gần), StatBlock, StatModifier, StatId,
                           UnitState; EffectContainer ở M3
    systems/               mỗi file một hệ thống, chạy theo thứ tự cố định
    defs/                  khuôn dữ liệu: HeroDef, AbilityDef, EffectDef, TalentDef, ItemDef, UnitDef…
    content/               ContentLibrary (nạp content/), ContentValidator, RuleCatalog, ExprRules
    actions/               hành động dùng chung cho kỹ năng/hiệu ứng (mỗi loại một khuôn)
    controllers/           AI: lính (LaneCreepController), trụ (StructureController), quái rừng, bot — chỉ sinh Command
    commands/              Command, Order, CommandReplay (phát lại nhật ký); kiểm tra ở CommandSystem
    map/                   MapLayout, MapNavigation, MapValidator, MapShape (mang từ v1), LaneRoute (tiến độ lane)
  view/                    vẽ đơn vị, map, hiệu ứng, HUD, điều khiển cảm ứng;
                           ArtLibrary: tra hình theo id, thiếu thì hình tạm (ART.md)
    map/                   MapView, MapPainter (vẽ tạm bằng hình phẳng)
    units/                 UnitsView: vẽ đơn vị, nội suy giữa hai tick, y-sort
    art/                   ArtLibrary: res://assets/art/<art_id>.png, thiếu → hình tạm
    hud/                   TouchJoystick (joystick ảo; tên VirtualJoystick trùng lớp có sẵn của Godot 4.7)
  app/                     scene chính, luồng màn hình, màn xem map, màn trận;
                           SimRunner: chạy World 30 tick/giây theo thời gian thật;
                           MatchInput: joystick/WASD/chạm → Command (CTL-01)
  tests/                   test (framework nhỏ tự viết, xem mục 9)
  tools/                   script ngoài Godot (build map...)
```

## 3. Mô hình dữ liệu trong SIM

### 3.1 Entity — mọi thứ trên sân

Một class có kiểu, **không dùng Dictionary cho trạng thái**:

```
Entity
  id: int                 # tăng dần, quyết định thứ tự xử lý
  team: int               # 0 Blue, 1 Red, 2 Trung lập
  kind: Kind              # HERO, LANE_CREEP, NEUTRAL, TOWER, CORE, PROJECTILE...
  tags: TagSet            # "ranged", "siege", "structure", "boss"...
  position, radius
  stats: StatBlock        # chỉ số cuối cùng, tính từ base + modifier
  health, mana
  states: StateSet        # STUNNED, INVISIBLE... (mục 4.3) — tính ra, không gán tay
  effects: EffectContainer
  abilities: Array[AbilityInstance]
  controller_id           # ai ra quyết định: PLAYER, BOT, LANE, TOWER, JUNGLE
  order: Order            # lệnh hiện tại (đi, đánh, dùng kỹ năng)
```

### 3.2 StatBlock và Modifier — cách DUY NHẤT để đổi chỉ số

Không đoạn code nào được viết thẳng vào chỉ số kiểu `stats.attack_speed *= 1.2`.
Mọi thay đổi là một **Modifier**:

```
Modifier { stat: StringName, op: ADD | MULTIPLY | OVERRIDE, value: float, source: id }
```

Nguồn modifier: tăng cấp, trang bị, hiệu ứng, kỹ năng bị động. Công thức gộp đặt
ở **một hàm** (`StatBlock.recompute`), thứ tự: base → ADD → MULTIPLY → OVERRIDE →
giới hạn (cap). Công thức thuộc tính → chỉ số dẫn xuất lấy nguyên từ
`StatCalculator` của v1.

Danh sách tên chỉ số hợp lệ nằm trong `GAME_RULES.md` mục STAT. Thêm chỉ số mới là
một **thay đổi luật**, không phải chuyện tùy ý.

### 3.3 Hiệu ứng (Effect) — mọi buff, debuff, trạng thái

`EffectDef` là dữ liệu (.tres):

```
EffectDef
  id, display_name, icon
  duration: float                 # 0 = vĩnh viễn (vd bị động)
  stacking: REFRESH | STACK | INDEPENDENT ;  max_stacks
  tags: ["debuff", "dispellable", ...]
  modifiers: Array[ModifierDef]   # mỗi stack nhân lên nếu stacking = STACK
  states: Array[State]            # vd [STUNNED], [INVISIBLE]
  periodic: interval + Array[ActionDef]   # vd đốt máu mỗi giây
  triggers: Array[TriggerDef]     # phản ứng với sự kiện (mục 3.5)
  removed_by: Array[EventName]    # vd tàng hình mất khi "attack_started" (EFF-05)
  fade_in: float                  # state chỉ có hiệu lực sau khoảng này (tàng hình)
  absorb: value name              # khiên (EFF-06)
```

Mọi con số trong EffectDef có thể là số hoặc **tên giá trị** của skill đã áp nó
(ví dụ `duration "duration"`), để cấp skill và talent điều khiển được.

### 3.4 Kỹ năng (Ability) và Talent

`AbilityDef` là dữ liệu:

```
AbilityDef
  id, display_name, icon
  slot: INNATE | Q | W | R        # R = ultimate 3 cấp; INNATE tự lên 6 bậc (ABL-11)
  max_rank: 6 | 5 | 3
  targeting: PASSIVE | NO_TARGET | UNIT | POINT | DIRECTION
  target_filter: ENEMY | ALLY | SELF ... + loại đơn vị được nhắm
  values: { cooldown: [..], mana: [..], cast_range: [..], damage: [..], duration: [..], ... }
  cast_time
  on_cast: Array[ActionDef]       # chuỗi hành động; tham số đọc theo tên trong values
  talent: TalentDef               # tầng II của skill này (TAL)
  bot_usage, bot_conditions       # BOT-13
```

**Giá trị có tên** là chìa khóa: action ghi `Damage(amount = "damage")`, không ghi
số. Cấp skill chọn phần tử trong mảng; talent sửa giá trị theo tên.

```
TalentDef
  id, display_name, description
  value_changes: [ {name: "damage", op: ADD, value: 100}, {name: "cooldown", op: ADD, value: -2} ]
  extra_actions: Array[ActionDef]     # nối vào cuối on_cast
  extra_effects / extra_triggers      # gắn thêm vào hiệu ứng của skill
```

HeroDef có đúng 1 nội tại + 3 skill (Q, W, R), 3 talent (mỗi skill Q/W/R một),
thứ tự nâng skill và chọn talent cho bot.

Bị động (nội tại, hoặc Q/W khai báo PASSIVE) dùng `on_learn: ApplyEffect(self,
hiệu ứng vĩnh viễn)`; hiệu ứng đó mang modifier và trigger. Chí mạng là thuộc tính
`attack_modifier` của hiệu ứng mà AttackSystem đọc khi bắt đầu vung tay (CMB-07).
Xác suất dùng bộ đếm PRD trong World (RNG-01).

### 3.5 Sự kiện, Trigger, Action — cách kỹ năng "làm gì đó"

SIM phát **sự kiện có kiểu** trong mỗi tick: `attack_started`, `attack_landed`,
`damage_taken`, `unit_died`, `ability_cast`, `effect_applied`, `kill_credited`...
(danh sách đầy đủ trong `GAME_RULES.md` mục EVT).

Hiệu ứng khai báo **trigger** trong dữ liệu:

```
TriggerDef { on: "attack_landed", as: SOURCE, chance: 0.2, condition: "target_not_structure",
             actions: [ApplyEffect(target, "stun", 1.5), Damage(target, PHYSICAL, 40)] }
```

`as` chọn vai của chủ hiệu ứng trong sự kiện (EFF-08): SOURCE = mình gây ra,
TARGET = mình bị. Tham số của action là **biểu thức** (EFF-09), ví dụ trả đòn kiểu
Centaur:

```
TriggerDef { on: "attack_landed", as: TARGET,
             actions: [Damage(event.source, PHYSICAL, "20 + 0.3 * self.strength", reflected)] }
```

**Action** là thư viện nhỏ dùng chung, mỗi loại một file trong `sim/actions/`.
Bốn hero và các món đồ đầu tiên cần đúng các action sau (CONTENT.md):

| Action | Dùng ở |
|---|---|
| `Damage(target, type, amount)` | mọi skill gây sát thương |
| `Heal(target, amount)` / hồi theo thời gian qua `periodic` | Brakk R, Noctis W II |
| `ApplyEffect(target, effect, duration)` / `RemoveEffect` | hầu hết skill |
| `AreaAt(center, radius, delay, actions)` | Brakk Q, Myra W, Myra R |
| `SpawnProjectile(direction, range, width, speed, pierce, on_hit)` | Myra Q |
| `Dash(to_target, speed, on_arrive)` | Noctis Q |
| `SpawnZone(center, radius, duration, periodic actions)` | Myra R II |
| `ModifyCooldown(slot, amount)` | Noctis Q II |
| `Push(target, direction, distance, duration)` | Vexa W |
| `Dispel(target, level)` / `Purge(target, level, on_each)` | Vexa R, Giáp Bất Khuất, Bùa Thanh Tẩy |
| `ManaBurn(target, amount)` | Thư viện bị động (Anti-Mage) |
| `AreaAt` có tham số `falloff` (giảm dần theo khoảng cách) | Thư viện bị động (Spectre) |

Móc chặn chết (`prevent_death`, DTH-01) nằm trong DeathSystem, không phải action.

Kỹ năng **kết hợp** action, không tự viết logic riêng. Action mới = cơ chế mới.

### 3.6 Bốn hero và trang bị đầu tiên phủ toàn bộ cơ chế

Bản đầu v2 có 4 hero đầy đủ (Brakk, Myra, Noctis, Vexa) và 9 món đồ có kỹ năng —
xem bảng phủ hiệu ứng trong `CONTENT.md`. Đồ dùng chung hệ AbilityDef/EffectDef với
skill (ITM-02), nên Lưỡi Ẩn Thân dùng lại đúng hiệu ứng tàng hình của Noctis W.

12 bị động của v1 vẫn biểu diễn được bằng mô hình này mà không cần code riêng, nên
có thể dùng lại làm skill/talent cho hero sau. Ví dụ: Cuồng Tốc = trigger
`attack_landed` → hiệu ứng STACK tối đa 10 cộng `attack_speed`; Bash = trigger
`attack_landed`, chance 0.2 → choáng + sát thương; Săn Linh Hồn = trigger
`kill_credited` → hiệu ứng STACK vĩnh viễn cộng `physical_damage`.

## 4. Thứ tự một tick (cố định, không ai được chen ngang)

```
 1. CommandSystem      nhận Command (người chơi, bot, controller) → kiểm tra hợp lệ → Order
 2. EffectSystem       hết hạn hiệu ứng, chạy periodic
 3. StateSystem        tính lại StateSet + StatBlock của đơn vị có thay đổi
 4. VisionSystem       ai thấy ai (dùng StateSet: INVISIBLE, REVEALED)
 5. ControllerSystem   lính, trụ, quái, bot đọc snapshot → sinh Command cho tick sau
 6. MovementSystem     di chuyển theo Order, va chạm, tìm đường
 7. AbilitySystem      tiến trình tung chiêu, chạy on_cast; đạn kỹ năng, vùng trễ,
                       vùng cháy, lướt (ABL-05..08)
 8. AttackSystem       đòn đánh thường, đạn bay, tạo DamageRequest
 9. DamageSystem       giáp, né, chí mạng → trừ máu (công thức v1), phát sự kiện
10. TriggerSystem      xử lý trigger theo thứ tự sự kiện (có giới hạn độ sâu)
11. DeathSystem        chết, thưởng vàng/XP, hồi sinh, phá công trình
12. Spawn/Match        đợt lính, trại rừng, điều kiện thắng
```

Thứ tự này là `World.Phase` trong code; hệ thống đăng ký vào một pha, World tự chạy
đúng thứ tự (test kiểm tra danh sách pha khớp bảng trên).

Quy tắc:
- **Mỗi hệ thống chỉ ghi phần dữ liệu của mình.** Ví dụ chỉ DamageSystem trừ máu,
  chỉ MovementSystem đổi vị trí. Hệ khác muốn thay đổi thì tạo request/sự kiện.
- Duyệt đơn vị theo `id` tăng dần. RNG chỉ lấy từ `World.rng` có seed.
- Trigger gây ra trigger khác: tối đa 4 tầng, tránh vòng lặp vô hạn.

## 5. Trạng thái (State) — nơi các cơ chế gặp nhau

State là cờ được **tính ra** từ các hiệu ứng đang có, không bao giờ gán tay. Danh
sách state và bảng tác động nằm **duy nhất** ở `GAME_RULES.md` mục ST (không chép
sang đây để tránh hai bản lệch nhau).

Các hệ thống hỏi state qua **một nhóm hàm** trong `sim/rules.gd`:
`Rules.can_move(e)`, `Rules.can_attack(e)`, `Rules.can_cast(e)`,
`Rules.is_targetable(by, target, by_attack: bool)`, `Rules.is_visible(to_team, e)`,
`Rules.damage_multiplier(target, damage_type)`.
Không hệ thống nào tự kiểm tra `if e.has_effect("stun")`.

Nhờ vậy, khi thêm GHOST chỉ cần sửa `Rules.is_targetable` (đánh thường không nhắm
được) và `Rules.damage_multiplier` (miễn vật lý, tăng phép). AttackSystem, bot,
trụ, lính tự đúng theo.

## 6. Ví dụ đầy đủ: thêm hero có kỹ năng tàng hình

### Trường hợp A — cơ chế tàng hình ĐÃ CÓ trong luật (đích của kiến trúc này)

Chỉ thêm dữ liệu, **không sửa code**. Đây là W của Noctis (CONTENT.md):

```
content/effects/shadow_veil.tres      EffectDef
  duration "duration" ; states [INVISIBLE] ; fade_in 0.6
  modifiers [ movement_speed MULTIPLY "speed_bonus" ]
  removed_by [ attack_started, ability_cast ]

content/effects/ambush_ready.tres     EffectDef
  duration "duration" ; removed_by [ ability_cast ]
  triggers [ on attack_landed: Damage(target, PHYSICAL, "ambush_damage"),
                               ApplyEffect(target, disarm, "disarm_duration"),
                               RemoveEffect(self, ambush_ready) ]

content/abilities/noctis_w.tres       AbilityDef
  slot W ; targeting NO_TARGET
  values { duration [6,7,8,9,10], speed_bonus [...], ambush_damage [...], ... }
  on_cast [ ApplyEffect(self, shadow_veil), ApplyEffect(self, ambush_ready) ]
```

Kèm test kịch bản: Noctis tàng hình → trụ và bot địch không nhắm được → Noctis đánh
→ hiện hình, mục tiêu bị cấm đánh → trụ nhắm lại.

### Trường hợp B — tàng hình CHƯA CÓ (lần đầu xuất hiện cơ chế)

Theo quy trình "cơ chế mới" (AGENTS.md):

1. **Viết luật trước.** Thêm vào `GAME_RULES.md`:
   - State INVISIBLE, REVEALED vào bảng ST, kèm **bảng tương tác bắt buộc**
     (mục 7): trụ, lính, bot, đạn đang bay, minimap, kỹ năng vùng, UI phe mình/phe địch.
   - Luật tầm nhìn VIS: "đơn vị INVISIBLE chỉ hiện với đội có REVEALED lên nó".
   - Cách bị lộ: đứng trong tầm *true sight* (fountain), hiệu ứng REVEALED.
2. Ghi một dòng vào `DECISIONS.md`.
3. Code **đúng một chỗ**: `VisionSystem` + `Rules.is_visible`. Vì mọi controller,
   AttackSystem, AbilitySystem đều đã hỏi `Rules.is_targetable`, chúng tự đúng mà
   không cần sửa.
4. Thêm hành vi "mất khi tấn công": cơ chế `removed_by` của EffectSystem (dùng chung
   cho mọi hiệu ứng sau này, không riêng tàng hình).
5. Test: một test cho mỗi dòng trong bảng tương tác.
6. Sau đó mới làm trường hợp A.

**Kết quả:** hero tàng hình thứ hai, thứ ba về sau đều chỉ là dữ liệu.

## 7. Bảng tương tác bắt buộc cho mọi cơ chế mới

Cơ chế mới (state, action, loại đơn vị) phải trả lời đủ các câu này trong
`GAME_RULES.md` **trước khi code**:

| Hỏi | Ví dụ với INVISIBLE |
|---|---|
| Đơn vị có state này di chuyển / đánh / dùng chiêu được không? | Được; đánh hoặc dùng chiêu làm mất state |
| Địch nhắm được không? Đồng minh? | Địch: chỉ khi bị lộ. Đồng minh: có |
| Lệnh/đạn đang nhắm nó thì sao? | Lệnh đánh của địch bị hủy; đạn đã bay vẫn trúng |
| Trụ, lính, quái rừng, bot phản ứng ra sao? | Không thấy → không chọn; bot chuyển mục tiêu |
| Kỹ năng vùng có trúng không? | Có |
| Hiển thị phía mình / phía địch / minimap? | Mình: mờ 50%. Địch: không thấy. Minimap: ẩn với địch |
| Tương tác với state khác? | REVEALED khử INVISIBLE; STUNNED không làm lộ |
| Bị xóa bởi gì? | Hết giờ, tấn công, dùng chiêu, chết |

## 8. Những gì mang từ v1 sang

| Mang sang | Cách |
|---|---|
| Công thức: `StatCalculator`, `DamageCalculator`, `HitCalculator`, `BalanceSettings`, `SimulationClock` | Mang công thức và con số, viết lại thành hàm thuần có kiểu (`sim/core/*_formulas.gd`, D-32), kèm test công thức của v1 |
| Đạn bay (`CombatProjectile`) | Chép, gắn vào AttackSystem |
| Chỉ số và tăng trưởng hero (`*_growth.tres`) | Brakk, Myra, Noctis lấy từ hero v1 cùng tên, **bỏ** `physical_damage` mỗi cấp (D-35); 9 hero còn lại giữ làm mẫu chỉ số cho hero sau |
| Trang bị (14 + 23 món) | `modifiers` của v1 chuyển thẳng thành Modifier |
| Map: `tools/map_build`, `data/maps`, `MapLayout`, `MapNavigation`, `MapPainter` | Công cụ build và dữ liệu chép nguyên (build lại ra đúng từng byte). Code gõ kiểu lại; bỏ va chạm vật lý Godot và nút trụ trong scene của v1 (MAP-01); bán kính thân trụ thành tham số. Test dữ liệu và tìm đường của `test_map` mang sang |
| Âm thanh, icon | Chép |
| **Không mang:** `CombatEngine.step`, `moba_match.gd`, AI, sandbox, UI cũ | Viết mới theo kiến trúc này |

`CombatEngine` v1 trộn sandbox, AI và bị động hero trong một hàm `step`. V2 giữ
công thức của nó nhưng chia phần xử lý thành các hệ thống ở mục 4.

## 9. Test

- Framework nhỏ tự viết (`tests/framework/`): mỗi file `test_*.gd` `extends TestCase`
  có các hàm `test_*`; `tests/run_all.gd` chạy hết, báo xanh/đỏ, trả mã lỗi. Lỗi
  script trong test bị bắt (qua `Logger`) và tính là đỏ.
- **Test kịch bản SIM**: dựng World bằng code (`WorldBuilder`), đặt đơn vị, chạy N
  tick, kiểm tra. Không cần scene, chạy nhanh.
- **Test phát lại (replay)**: chạy trận hai lần với cùng seed và cùng nhật ký Command,
  so hash trạng thái World mỗi tick; lệch một tick là đỏ (D-30). Nhật ký Command của
  trận lỗi được lưu để tái hiện lỗi.
- **Test bất biến (soak)**: bot đấu bot 10 phút với 3 seed, kiểm tra các bất biến
  trong `GAME_RULES.md` mục INV mỗi tick.
- **Test nội dung**: mọi file trong `content/` đều nạp được, id không trùng, tham
  chiếu tới effect/ability tồn tại, số theo rank đủ 5 phần tử.
- Tên test chứa mã luật: `test_VIS_03_invisible_not_targeted_by_tower`.
- **Nội dung chỉ dùng cho test** (`tests/content/`): hero thử nghiệm mang bị động trong
  thư viện (CONTENT.md) để kiểm thử viên gạch trước khi có hero thật dùng nó. Dựng
  bằng code (`fixture_content.gd`), test lưu ra `.tres` tạm để kiểm tra lưu/nạp. Game
  không nạp thư mục này.
- **Quy ước trong các Def**: trường `String` là biểu thức (EFF-09), tên/id là
  `StringName`; validator duyệt mọi trường theo quy ước này nên khuôn mới tự được kiểm tra.
