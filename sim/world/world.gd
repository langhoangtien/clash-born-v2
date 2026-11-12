class_name World
extends RefCounted
## Toàn bộ trạng thái một trận và vòng tick (ARCHITECTURE mục 4). Xác định (D-30):
## cùng seed + cùng Command → cùng trạng thái từng tick.

## Thứ tự pha cố định của một tick.
enum Phase { COMMAND, EFFECT, STATE, VISION, CONTROLLER, MOVEMENT, ABILITY, ATTACK, DAMAGE, TRIGGER, DEATH, SPAWN }

var tick: int = 0
## Đội thắng (STR-05), -1 khi trận chưa xong. Đã có đội thắng thì step() không chạy nữa.
var winner: int = -1
## MATCH-06 (D-332): trận thử — chỉ khi đó lệnh thử (CMD-06) được nhận.
var practice: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var balance: BalanceSettings
## Map của trận; null trong test không cần map.
var map: MapLayout
## Luôn sắp theo id tăng dần.
var entities: Array[Entity] = []

## Lệnh đã áp, theo thứ tự (CMD-04). Đủ để phát lại trận (D-30).
var command_log: Array[Command] = []
## Lệnh bị từ chối ở tick vừa chạy, kèm lý do (CMD-02).
var rejected_commands: Array[Command] = []

## Sự kiện của tick vừa chạy (EVT); xóa đầu mỗi tick. `previous_events`: của tick trước
## (controller chạy ở pha 5, trước khi tick này có sự kiện sát thương).
var events: Array[GameEvent] = []
var previous_events: Array[GameEvent] = []
var _fights_tick: int = -1
var _fights: Array[GameEvent] = []
## Tra cứu đơn vị theo vị trí; hệ thống gọi `spatial_near` (tự dựng lại theo tick + pha).
var spatial: SpatialGrid = SpatialGrid.new()
## Route lane đã dựng, theo "LANE:team" (LaneRoute.of).
var lane_routes: Dictionary[String, LaneRoute] = {}
## Công trình đã đổ, theo structure_id (STR-02).
var destroyed_structures: Dictionary[StringName, bool] = {}
## Sát thương chờ DamageSystem xử lý trong tick này.
var damage_requests: Array[DamageRequest] = []
## Đạn đánh thường đang bay (AttackSystem quản lý).
var projectiles: Array[Projectile] = []

## Lưới tìm đường dựng sẵn, dùng chung giữa các World cùng map (dựng mất ~1 s).
static var _nav_cache: Dictionary[String, MapNavigation] = {}
## Số lần đã dựng lưới tìm đường (để test việc dựng sẵn lúc vào trận).
static var nav_builds: int = 0

var _next_id: int = 1
var _next_serial: int = 0
## Số thứ tự sự kiện cuối cùng và tầng trigger hiện tại (TriggerSystem đặt, EFF-04).
var event_seq: int = 0
var emit_depth: int = 0
## Vùng có độ trễ đang chờ (AreaAction), TriggerSystem chạy khi tới tick.
var pending_areas: Array[PendingArea] = []
## Vùng tồn tại (ZoneAction, ABL-17), kể cả vùng chưa bắt đầu; TriggerSystem cho tác dụng.
var zones: Array[ActiveZone] = []
## Trại rừng (JGL), MatchSetup.add_jungle dựng.
var camps: Array[CampState] = []
## SHOP: cửa hàng của trận (MatchSetup.add_shop), id → món.
var item_catalog: Dictionary[StringName, ItemDef] = {}
## SHOP-08: kho mỗi đội (0, 1): id món → [còn bao nhiêu, tick thêm 1 (-1 = đang đầy)].
var shop_stock: Array[Dictionary] = []
## Đạn kỹ năng đang bay (ABL-05), SkillShotSystem cập nhật.
var skill_shots: Array[SkillShot] = []
## Chỉ để VIEW vẽ: vùng vừa nổ gần đây [tâm / đỉnh, bán kính, tick, đội, hình, hướng, góc, dài, nửa rộng].
## Không thuộc trạng thái trận.
var recent_areas: Array = []
## Chỉ để VIEW: chữ nổi gần đây [loại, vị trí, giá trị, tick] (miss, damage, crit, stun).
## Không thuộc trạng thái trận.
var recent_notes: Array = []
## RNG-01: bộ đếm PRD theo khóa (Prd.key).
var prd_counters: Dictionary[int, int] = {}
var _pending: Array[Command] = []
## D-273: đã chạy nửa đầu tick hiện tại, chưa chạy nửa sau (VIEW chưa đọc sự kiện của tick này).
var mid_tick: bool = false
## NET-02 (D-337): trận online — nơi nhận lệnh người chơi (bộ mạng); trống = trận offline. `_in_tick`: đang chạy hệ thống.
var remote_sink: Callable = Callable()
var _in_tick: bool = false
var _systems: Array[Array] = []  # [phase, thứ tự đăng ký, SimSystem]
var _systems_later: Array[Array] = []  # [phase, SimSystem] thêm trong lúc đang chạy tick


func _init(seed_value: int, p_balance: BalanceSettings) -> void:
	rng.seed = seed_value
	balance = p_balance
	add_system(CommandSystem.new(), Phase.COMMAND)
	add_system(EffectSystem.new(), Phase.EFFECT)
	add_system(StateSystem.new(), Phase.STATE)
	add_system(RegenSystem.new(), Phase.STATE)
	add_system(DuelSystem.new(), Phase.STATE)  # D-135
	add_system(TauntSystem.new(), Phase.STATE)  # D-383: sau Quyết Đấu
	add_system(StructureController.new(), Phase.CONTROLLER)
	add_system(DashSystem.new(), Phase.MOVEMENT)  # trước MovementSystem (thêm sau)
	add_system(KnockbackSystem.new(), Phase.MOVEMENT)
	add_system(AbilitySystem.new(), Phase.ABILITY)
	add_system(SkillShotSystem.new(), Phase.ABILITY)
	add_system(AttackSystem.new(), Phase.ATTACK)
	add_system(FountainSystem.new(), Phase.ATTACK)
	add_system(DamageSystem.new(), Phase.DAMAGE)
	add_system(Recall.new(), Phase.DAMAGE)  # sau DamageSystem: trúng sát thương tick này thì hủy
	add_system(TriggerSystem.new(), Phase.TRIGGER)
	add_system(DeathSystem.new(), Phase.DEATH)
	add_system(EconomySystem.new(), Phase.SPAWN)


func add_system(system: SimSystem, phase: Phase) -> void:
	if _in_tick:
		_systems_later.append([phase, system])  # D-390: không đổi danh sách đang duyệt; chạy từ tick sau
		return
	_systems.append([phase, _systems.size(), system])
	_systems.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))


## Đã có hệ thống thuộc lớp `script` chưa (tính cả hệ thống chờ thêm sau tick).
func has_system(script: Script) -> bool:
	for entry: Array in _systems + _systems_later:
		if (entry[-1] as Object).get_script() == script:
			return true
	return false


## Cấp id, tính chỉ số lần đầu, đầy máu/mana.
func add_entity(e: Entity) -> Entity:
	e.id = _next_id
	_next_id += 1
	if e.stats != null:
		e.stats.recompute()
		e.health = e.stats.get_stat(StatId.Id.MAX_HP)
		e.mana = e.stats.get_stat(StatId.Id.MAX_MANA)
	entities.append(e)
	return e


## Tìm đường cho đơn vị bán kính `radius` trên map của trận (MAP-01).
func navigation(radius: float) -> MapNavigation:
	var key: String = "%d:%s:%s:%s" % [map.get_instance_id(), radius, balance.tower_body_radius, balance.core_body_radius]
	if not _nav_cache.has(key):
		_nav_cache[key] = MapNavigation.new(map, radius, balance.tower_body_radius, balance.core_body_radius)
		nav_builds += 1
	return _nav_cache[key]


## Đơn vị gần `point` (lọc thô, sắp theo id). `phase` để dựng lại sau khi vị trí đổi.
func spatial_near(point: Vector2, radius: float, phase: int, sorted: bool = true) -> Array[Entity]:
	spatial.rebuild(entities, tick, phase)
	return spatial.near(point, radius, sorted)


## Sự kiện `hero_attacked_hero` của tick trước (DEF-11), lọc một lần mỗi tick cho controller.
func previous_hero_fights() -> Array[GameEvent]:
	if _fights_tick != tick:
		_fights_tick = tick
		_fights = previous_events.filter(func(ev: GameEvent) -> bool: return ev.type == &"hero_attacked_hero")
	return _fights


## Gửi lệnh; áp ở pha COMMAND của tick kế tiếp (CMD-01).
## NET-02 (D-337): trận online — lệnh gửi từ ngoài tick (giao diện người chơi) chuyển cho `remote_sink` (bộ mạng gửi lên
## máy chủ) thay vì vào hàng chờ; lệnh sinh trong tick (bot, controller) vẫn vào thẳng — mọi máy tự tính giống nhau.
func submit(command: Command) -> void:
	if remote_sink.is_valid() and not _in_tick:
		remote_sink.call(command)
		return
	_pending.append(command)


## NET-01: lệnh trong gói lệnh của máy chủ (đã có tick thực thi) — vào hàng chờ của tick kế tiếp, không qua remote_sink.
func enqueue(command: Command) -> void:
	_pending.append(command)


func take_pending_commands() -> Array[Command]:
	var out: Array[Command] = _pending
	_pending = []
	return out


## Tìm theo id (danh sách sắp theo id nên tìm nhị phân).
func find_entity(entity_id: int) -> Entity:
	var lo: int = 0
	var hi: int = entities.size() - 1
	while lo <= hi:
		var mid: int = (lo + hi) / 2
		var e: Entity = entities[mid]
		if e.id == entity_id:
			return e
		if e.id < entity_id:
			lo = mid + 1
		else:
			hi = mid - 1
	return null


func remove_entity(e: Entity) -> void:
	entities.erase(e)


func emit(type: StringName, source_id: int, target_id: int, amount: float = 0.0, reason: StringName = &"") -> GameEvent:
	var ev: GameEvent = GameEvent.make(type, tick, source_id, target_id, amount, reason)
	event_seq += 1
	ev.seq = event_seq
	ev.depth = emit_depth
	events.append(ev)
	return ev


## Ghi chữ nổi cho VIEW (không ảnh hưởng trận).
## `owner` (D-240): chỉ hero này thấy (vd "+vàng" khi last hit); -1 = ai cũng thấy.
func note(kind: StringName, at: Vector2, value: float = 0.0, owner: int = -1) -> void:
	if recent_notes.size() > 60:
		recent_notes = recent_notes.filter(func(n: Array) -> bool: return tick - n[3] < 30)
	recent_notes.append([kind, at, value, tick, owner])


## Số thứ tự toàn trận cho bản hiệu ứng (EffectInstance.serial), tăng dần.
func next_serial() -> int:
	_next_serial += 1
	return _next_serial


func step() -> void:
	if mid_tick:
		step_second_half()  # D-273: đang giữa tick thì làm nốt, không mở tick mới
		return
	step_first_half()
	step_second_half()


## D-273: nửa đầu một tick — mở tick mới và chạy các pha tới hết CONTROLLER. APP có thể chạy nửa sau ở khung kế
## để một khung không gánh cả tick; cùng thứ tự hệ thống nên kết quả y như step().
func step_first_half() -> void:
	if winner >= 0 or mid_tick:
		return
	tick += 1
	previous_events = events
	events = []
	_run_systems(true)
	mid_tick = true


## D-273: nửa sau — các pha từ MOVEMENT tới hết.
func step_second_half() -> void:
	if not mid_tick:
		return
	_run_systems(false)
	mid_tick = false


func _run_systems(first_half: bool) -> void:
	_in_tick = true
	for entry: Array in _systems:
		if (int(entry[0]) <= Phase.CONTROLLER) == first_half:
			(entry[2] as SimSystem).run(self)
	_in_tick = false
	var later: Array[Array] = _systems_later
	_systems_later = []
	for entry: Array in later:
		add_system(entry[1], entry[0])


## Băm toàn bộ trạng thái để so hai lần chạy (test phát lại, D-30) — WorldHash.
func state_hash() -> PackedByteArray:
	return WorldHash.of(self)


## M9.3 (D-336): mã băm riêng một đơn vị — WorldHash.
func entity_digest(e: Entity) -> PackedByteArray:
	return WorldHash.entity(e)
