class_name World
extends RefCounted
## Toàn bộ trạng thái một trận và vòng tick (ARCHITECTURE mục 4). Xác định (D-30):
## cùng seed + cùng Command → cùng trạng thái từng tick.

## Thứ tự pha cố định của một tick.
enum Phase { COMMAND, EFFECT, STATE, VISION, CONTROLLER, MOVEMENT, ABILITY, ATTACK, DAMAGE, TRIGGER, DEATH, SPAWN }

var tick: int = 0
## Đội thắng (STR-05), -1 khi trận chưa xong. Đã có đội thắng thì step() không chạy nữa.
var winner: int = -1
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

var _next_id: int = 1
var _next_serial: int = 0
## Số thứ tự sự kiện cuối cùng và tầng trigger hiện tại (TriggerSystem đặt, EFF-04).
var event_seq: int = 0
var emit_depth: int = 0
## Vùng có độ trễ đang chờ (AreaAction), TriggerSystem chạy khi tới tick.
var pending_areas: Array[PendingArea] = []
## Chỉ để VIEW vẽ: vùng vừa nổ gần đây [tâm, bán kính, tick, đội]. Không thuộc trạng thái trận.
var recent_areas: Array = []
var _pending: Array[Command] = []
var _systems: Array[Array] = []  # [phase, thứ tự đăng ký, SimSystem]


func _init(seed_value: int, p_balance: BalanceSettings) -> void:
	rng.seed = seed_value
	balance = p_balance
	add_system(CommandSystem.new(), Phase.COMMAND)
	add_system(EffectSystem.new(), Phase.EFFECT)
	add_system(StateSystem.new(), Phase.STATE)
	add_system(RegenSystem.new(), Phase.STATE)
	add_system(StructureController.new(), Phase.CONTROLLER)
	add_system(AbilitySystem.new(), Phase.ABILITY)
	add_system(AttackSystem.new(), Phase.ATTACK)
	add_system(FountainSystem.new(), Phase.ATTACK)
	add_system(DamageSystem.new(), Phase.DAMAGE)
	add_system(TriggerSystem.new(), Phase.TRIGGER)
	add_system(DeathSystem.new(), Phase.DEATH)
	add_system(EconomySystem.new(), Phase.SPAWN)


func add_system(system: SimSystem, phase: Phase) -> void:
	_systems.append([phase, _systems.size(), system])
	_systems.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))


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
	var key: String = "%d:%s:%s" % [map.get_instance_id(), radius, balance.tower_body_radius]
	if not _nav_cache.has(key):
		_nav_cache[key] = MapNavigation.new(map, radius, balance.tower_body_radius)
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
func submit(command: Command) -> void:
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


## Số thứ tự toàn trận cho bản hiệu ứng (EffectInstance.serial), tăng dần.
func next_serial() -> int:
	_next_serial += 1
	return _next_serial


func step() -> void:
	if winner >= 0:
		return
	tick += 1
	previous_events = events
	events = []
	for entry: Array in _systems:
		(entry[2] as SimSystem).run(self)


## Băm toàn bộ trạng thái để so hai lần chạy (test phát lại, D-30).
func state_hash() -> PackedByteArray:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(PackedInt64Array([tick, rng.seed, rng.state, entities.size(), winner]).to_byte_array())
	for e: Entity in entities:
		ctx.update(PackedInt64Array([e.id, e.team, e.kind, e.order.type, int(e.order.finished), e.order.target_id,
			int(e.alive), int(e.locked), int(e.returning), int(e.has_origin), e.aggro_target_id, e.aggro_until_tick, e.attack_phase, e.attack_target_id, e.attack_start_tick, e.attack_release_tick, e.next_attack_tick,
			e.lock_target_id, e.respawn_tick, e.gold, e.last_hits, e.skill_points, e.attribute_bonus_count, e.talent_slot]).to_byte_array())
		ctx.update(PackedFloat64Array([e.position.x, e.position.y, e.radius, e.health, e.mana,
			e.order.point.x, e.order.point.y, e.order.direction.x, e.order.direction.y,
			e.chase_origin.x, e.chase_origin.y, e.xp]).to_byte_array())
		if e.stats != null:
			ctx.update(e.stats.values().to_byte_array())
		for a: AbilityInstance in e.abilities:
			ctx.update(PackedInt64Array([a.slot, a.rank, a.ready_tick]).to_byte_array())
		if e.cast != null:
			ctx.update(PackedInt64Array([e.cast.ability.slot, e.cast.release_tick, e.cast.target_id]).to_byte_array())
		for inst: EffectInstance in e.effects:
			ctx.update(PackedInt64Array([inst.serial, inst.def.id.hash(), inst.source_id, inst.stacks, inst.end_tick, inst.next_period_tick]).to_byte_array())
			ctx.update(PackedFloat64Array([inst.absorb_left]).to_byte_array())
	for p: Projectile in projectiles:
		ctx.update(PackedFloat64Array([p.source_id, p.target_id, p.position.x, p.position.y, p.request.raw]).to_byte_array())
	return ctx.finish()
