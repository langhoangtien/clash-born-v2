extends TestCase
## ST-20 (D-383): TAUNTED — một test cho mỗi dòng bảng tương tác.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.spawn_structures(w, _lib)
	return w


func _mid() -> Vector2:
	return _map.world_size() * 0.5


func _hero(w: World, team: int, at: Vector2, id: StringName = &"brakk") -> Entity:
	var e: Entity = UnitFactory.hero(w, _lib.heroes[id], team, w.navigation(32.0).nearest_clear(at), 6)
	e.stats.set_base(StatId.Id.MAX_HP, 20000.0)
	e.health = 20000.0
	return e


func _taunt_def() -> EffectDef:
	var d: EffectDef = EffectDef.new()
	d.id = &"test_taunt"
	d.tags = [&"debuff"] as Array[StringName]
	d.dispel = EffectDef.Dispel.STRONG
	d.states = [UnitState.Id.TAUNTED] as Array[UnitState.Id]
	return d


func _state_def(id: StringName, state: UnitState.Id) -> EffectDef:
	var d: EffectDef = EffectDef.new()
	d.id = id
	d.states = [state] as Array[UnitState.Id]
	return d


func _taunt(w: World, victim: Entity, taunter: Entity, seconds: float = 3.0) -> EffectInstance:
	return Effects.apply(w, victim, _taunt_def(), taunter, {}, str(seconds))


func _forced(e: Entity, t: Entity) -> bool:
	return e.order.type == Order.Type.ATTACK and e.order.target_id == t.id


## Một cặp: kẻ khiêu khích đội 0 ở giữa map, nạn nhân đội 1 cách `gap`.
func _pair(gap: float = 150.0) -> Array:
	var w: World = _world()
	var taunter: Entity = _hero(w, 0, _mid())
	var victim: Entity = _hero(w, 1, _mid() + Vector2(gap, 0.0))
	return [w, taunter, victim]


func test_ST_20_taunted_unit_attacks_taunter() -> void:
	var s: Array = _pair()
	_taunt(s[0], s[2], s[1])
	(s[0] as World).step()
	assert_true(Rules.has_state(s[2], UnitState.Id.TAUNTED))
	assert_true(_forced(s[2], s[1]), "bị ép đánh kẻ khiêu khích")


func test_ST_20_walks_to_taunter_out_of_range() -> void:
	var s: Array = _pair(600.0)
	var start: float = (s[2] as Entity).position.distance_to((s[1] as Entity).position)
	_taunt(s[0], s[2], s[1])
	for i: int in range(30):
		(s[0] as World).step()
	assert_true((s[2] as Entity).position.distance_to((s[1] as Entity).position) < start - 150.0, "ngoài tầm thì tự đi tới")


func test_ST_20_rejects_move_attack_cast_item_recall() -> void:
	var s: Array = _pair()
	var w: World = s[0]
	var victim: Entity = s[2]
	Abilities.set_rank(w, victim, Abilities.of(victim, AbilityDef.Slot.Q), 1)
	_taunt(w, victim, s[1])
	w.step()
	var other: Entity = _hero(w, 0, _mid() + Vector2(0.0, 300.0), &"myra")
	for c: Command in [Command.move_to(victim.id, _mid()), Command.move_dir(victim.id, Vector2.RIGHT), Command.stop(victim.id),
			Command.attack(victim.id, other.id), Command.attack_auto(victim.id, 0), Command.cast(victim.id, AbilityDef.Slot.Q),
			Command.recall(victim.id)]:
		w.submit(c)
	w.step()
	assert_eq(w.rejected_commands.size(), 7, "mọi lệnh hành động bị từ chối")
	for c: Command in w.rejected_commands:
		assert_eq(c.reject_reason, Command.Reject.TAUNTED, "lệnh %s" % Command.Type.keys()[c.type])
	assert_true(_forced(victim, s[1]))
	assert_false(Rules.can_cast(victim) or Rules.can_use_item(victim), "không chiêu, không đồ")


func test_ST_20_cancels_recall() -> void:
	var s: Array = _pair()
	var w: World = s[0]
	var victim: Entity = s[2]
	w.submit(Command.recall(victim.id))
	w.step()
	assert_true(victim.recall_until_tick >= 0, "đang về thành")
	_taunt(w, victim, s[1])
	w.step()
	assert_eq(victim.recall_until_tick, -1, "bị khiêu khích thì hủy về thành")


func test_ST_20_structure_and_boss_not_taunted() -> void:
	var w: World = _world()
	var tower: Entity = null
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.TOWER and e.team == 1:
			tower = e
			break
	var taunter: Entity = _hero(w, 0, _mid())
	_taunt(w, tower, taunter)
	var boss: Entity = _boss_unit(w)
	_taunt(w, boss, taunter)
	w.step()
	assert_false(_forced(tower, taunter), "công trình không bị ép")
	assert_false(_forced(boss, taunter), "boss không bị ép")


## Quái của một trại boss (JGL-10) dựng tay ở giữa map.
func _boss_unit(w: World) -> Entity:
	for i: int in range(_map.camp_kinds.size()):
		var kind: StringName = StringName(_map.camp_kinds[i])
		if _lib.camps.has(kind) and (_lib.camps[kind] as CampDef).is_boss():
			var c: CampState = CampState.new()
			c.index = i
			c.kind = kind
			c.def = _lib.camps[kind]
			w.camps.append(c)
			var u: Entity = UnitFactory.unit(w, c.def.units[0], Entity.Kind.NEUTRAL, 2, _mid() + Vector2(0.0, 250.0))
			u.camp_index = i
			return u
	fail("map không có trại boss")
	return null


func test_ST_20_creep_and_neutral_taunted() -> void:
	var w: World = _world()
	var taunter: Entity = _hero(w, 0, _mid())
	var creep: Entity = UnitFactory.unit(w, _lib.units[&"creep_melee"], Entity.Kind.LANE_CREEP, 1, _mid() + Vector2(120.0, 0.0))
	var neutral: Entity = UnitFactory.unit(w, _lib.units[&"rhino_small"], Entity.Kind.NEUTRAL, 2, _mid() + Vector2(-120.0, 0.0))
	_taunt(w, creep, taunter)
	_taunt(w, neutral, taunter)
	w.step()
	assert_true(_forced(creep, taunter), "lính bị ép")
	assert_true(_forced(neutral, taunter), "quái thường bị ép")


func test_ST_20_stun_still_applies() -> void:
	var s: Array = _pair(400.0)
	var w: World = s[0]
	var victim: Entity = s[2]
	_taunt(w, victim, s[1])
	Effects.apply(w, victim, _state_def(&"test_stun", UnitState.Id.STUNNED), s[1], {}, "2")
	var at: Vector2 = victim.position
	for i: int in range(20):
		w.step()
	assert_eq(victim.position, at, "ST-17: choáng vẫn tác dụng")


func test_ST_20_waits_when_taunter_unattackable() -> void:
	var s: Array = _pair(400.0)
	var w: World = s[0]
	var victim: Entity = s[2]
	_taunt(w, victim, s[1])
	Effects.apply(w, s[1], _state_def(&"test_untargetable", UnitState.Id.UNTARGETABLE), s[1], {}, "3")
	var other: Entity = _hero(w, 0, victim.position + Vector2(100.0, 0.0), &"myra")
	var at: Vector2 = victim.position
	for i: int in range(30):
		w.step()
	assert_true(victim.position.distance_to(at) < 5.0, "kẻ khiêu khích không nhắm được: đứng chờ")
	assert_false(victim.order.type == Order.Type.ATTACK and victim.order.target_id == other.id, "không tự đánh người khác")
	assert_true(Rules.has_state(victim, UnitState.Id.TAUNTED))


func test_ST_20_ends_when_taunter_dies() -> void:
	var s: Array = _pair()
	var w: World = s[0]
	var taunter: Entity = s[1]
	var victim: Entity = s[2]
	_taunt(w, victim, taunter)
	w.step()
	taunter.health = 0.0
	taunter.alive = false
	w.step()
	var reason: StringName = &""
	for ev: GameEvent in w.events:
		if ev.type == &"effect_removed" and ev.target_id == victim.id:
			reason = ev.reason
	assert_false(Rules.has_state(victim, UnitState.Id.TAUNTED), "kẻ khiêu khích chết thì hết")
	assert_eq(reason, &"source_died")


func test_ST_20_duel_takes_precedence() -> void:
	var s: Array = _pair()
	var w: World = s[0]
	var victim: Entity = s[2]
	var knight: Entity = _hero(w, 0, victim.position + Vector2(0.0, 120.0), &"duy_anh")
	assert_true(Duels.start(w, knight, victim, {&"duration": 4.0} as Dictionary[StringName, float], load("res://content/effects/duel.tres") as EffectDef))
	_taunt(w, victim, s[1])
	for i: int in range(5):
		w.step()
	assert_true(_forced(victim, knight), "Quyết Đấu thắng TAUNTED")


func test_ST_20_latest_taunt_wins() -> void:
	var s: Array = _pair()
	var w: World = s[0]
	var victim: Entity = s[2]
	var second: Entity = _hero(w, 0, victim.position + Vector2(0.0, 150.0), &"myra")
	_taunt(w, victim, s[1])
	w.step()
	_taunt(w, victim, second)
	w.step()
	assert_true(_forced(victim, second), "bản áp sau cùng thắng")


func test_ST_20_flying_projectile_still_hits_old_target() -> void:
	var w: World = _world()
	var taunter: Entity = _hero(w, 0, _mid())
	var victim: Entity = _hero(w, 1, _mid() + Vector2(500.0, 0.0), &"myra")
	var mark: Entity = UnitFactory.unit(w, _lib.units[&"creep_melee"], Entity.Kind.LANE_CREEP, 0, _mid() + Vector2(500.0, 450.0))
	w.submit(Command.attack(victim.id, mark.id))
	var guard: int = 0
	while w.projectiles.is_empty() and guard < 150:
		w.step()
		guard += 1
	assert_false(w.projectiles.is_empty(), "đạn đã bay")
	var hp: float = mark.health
	_taunt(w, victim, taunter)
	for i: int in range(30):
		w.step()
	assert_true(not mark.alive or mark.health < hp, "đạn đã bay vẫn trúng mục tiêu cũ")
	assert_true(_forced(victim, taunter))


func test_ST_20_pierces_magic_immunity_only_when_declared() -> void:
	var s: Array = _pair()
	var w: World = s[0]
	var victim: Entity = s[2]
	Effects.apply(w, victim, _state_def(&"test_bkb", UnitState.Id.MAGIC_IMMUNE), victim, {}, "5")
	Effects.apply(w, victim, _taunt_def(), s[1], {}, "3")
	assert_false(Rules.has_state(victim, UnitState.Id.TAUNTED), "miễn phép chặn debuff thường")
	Effects.apply(w, victim, _taunt_def(), s[1], {}, "3", 0, true)
	assert_true(Rules.has_state(victim, UnitState.Id.TAUNTED), "T2: chiêu khai báo xuyên miễn phép thì trúng")


func test_ST_20_bot_taunted_no_orders() -> void:
	var s: Array = _pair()
	var w: World = s[0]
	var victim: Entity = s[2]
	MatchSetup.add_bot(w, victim)
	_taunt(w, victim, s[1])
	var sent: int = 0
	for i: int in range(60):
		w.step()
		for c: Command in w.rejected_commands:
			sent += 1 if c.entity_id == victim.id else 0
	assert_eq(sent, 0, "bot không ra lệnh khi bị khiêu khích")
	assert_true(_forced(victim, s[1]))
