extends TestCase
## M3.2: trạng thái tính từ hiệu ứng (ST-01..04, 07, 08, 11), kháng hiệu ứng (ST-09).

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const MAP_PATH: String = "res://data/maps/clashborn.tres"
const EPS: float = 0.01
const S := UnitState.Id

static var _map: MapLayout


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var bal: BalanceSettings = Fixture.make()
	bal.minimum_movement_speed = 0.0
	bal.ghost_magic_amp = 0.4
	var w: World = World.new(1, bal)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


func _origin() -> Vector2:
	return _map.fountain_point(0) + Vector2(300, -300)


func _fighter(w: World, team: int, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.attack_point = 0.3
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 50)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 150)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	return w.add_entity(e)


func _state(w: World, e: Entity, state: UnitState.Id, seconds: String = "2", tags: Array[StringName] = [&"debuff"]) -> EffectInstance:
	var d: EffectDef = EffectDef.new()
	d.id = StringName("st_%d" % state)
	d.duration = seconds
	d.tags = tags
	d.states = [state]
	return Effects.apply(w, e, d, null)


func _hit(w: World, target: Entity, amount: float, type: DamageFormulas.DamageType) -> float:
	var hp: float = target.health
	var r: DamageRequest = DamageRequest.new()
	r.source_id = -1
	r.target_id = target.id
	r.raw = amount
	r.damage_type = type
	w.damage_requests.append(r)
	w.step()
	return hp - target.health


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


## Bảng ST: [state, đi, đánh, dùng chiêu, bị đánh thường].
func test_ST_table_rules() -> void:
	var rows: Array = [
		[S.STUNNED, false, false, false, true],
		[S.ROOTED, false, true, true, true],
		[S.SILENCED, true, true, false, true],
		[S.DISARMED, true, false, true, true],
		[S.INVULNERABLE, true, true, true, true],
		[S.GHOST, true, false, true, false],
	]
	for row: Array in rows:
		var w: World = _world()
		var e: Entity = _fighter(w, 0, _origin())
		var foe: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
		_state(w, e, row[0])
		var name: String = UnitState.Id.keys()[row[0]]
		assert_true(Rules.has_state(e, row[0]), name)
		assert_eq(Rules.can_move(e), row[1], name + " đi")
		assert_eq(Rules.can_attack(e), row[2], name + " đánh")
		assert_eq(Rules.can_cast(e), row[3], name + " chiêu")
		assert_eq(Rules.is_attackable(foe, e), row[4], name + " bị đánh thường")
		assert_true(Rules.is_targetable(foe, e), name + " vẫn nhắm được bằng chiêu")


func test_ST_08_dead_can_do_nothing() -> void:
	var w: World = _world()
	var e: Entity = _fighter(w, 0, _origin())
	var foe: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	e.alive = false
	assert_true(Rules.has_state(e, S.DEAD))
	assert_false(Rules.can_move(e) or Rules.can_attack(e) or Rules.can_cast(e) or Rules.is_targetable(foe, e))


func test_ST_states_come_and_go_with_effects() -> void:
	var w: World = _world()
	var e: Entity = _fighter(w, 0, _origin())
	_state(w, e, S.STUNNED, "1")
	_state(w, e, S.STUNNED, "2", [&"debuff", &"x"])
	assert_true(Rules.has_state(e, S.STUNNED))
	_steps(w, 30)
	assert_true(Rules.has_state(e, S.STUNNED), "còn một nguồn choáng")
	_steps(w, 30)
	assert_false(Rules.has_state(e, S.STUNNED))


func test_ST_01_stun_freezes_movement_then_order_resumes() -> void:
	var w: World = _world()
	var e: Entity = _fighter(w, 0, _origin())
	w.submit(Command.move_dir(e.id, Vector2.RIGHT))
	w.step()
	_state(w, e, S.STUNNED, "1")
	var spot: Vector2 = e.position
	_steps(w, 29)
	assert_eq(e.position, spot, "choáng đứng im")
	_steps(w, 2)
	assert_true(e.position.x > spot.x, "hết choáng đi tiếp lệnh cũ")


func test_ST_01_stun_cancels_windup_without_cooldown() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	var b: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	w.submit(Command.attack(a.id, b.id))
	_steps(w, 5)
	assert_eq(a.attack_phase, Entity.AttackPhase.WINDUP)
	_state(w, a, S.STUNNED, "0.5")
	w.step()
	assert_eq(a.attack_phase, Entity.AttackPhase.NONE, "choáng hủy vung tay")
	assert_eq(b.health, 1000.0)
	_steps(w, 14)
	assert_eq(a.attack_phase, Entity.AttackPhase.WINDUP, "hết choáng vung lại ngay, không chờ hồi đòn")


func test_ST_02_rooted_attacks_but_does_not_walk() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	var near: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	var far: Entity = _fighter(w, 1, _origin() + Vector2(0, -600))
	_state(w, a, S.ROOTED, "5")
	w.submit(Command.attack(a.id, far.id))
	_steps(w, 20)
	assert_eq(a.position, _origin(), "trói không đi tới mục tiêu xa")
	w.submit(Command.attack(a.id, near.id))
	_steps(w, 20)
	assert_true(near.health < 1000.0, "trói vẫn đánh mục tiêu trong tầm")


func test_ST_04_disarmed_walks_but_never_hits() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	var b: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	_state(w, a, S.DISARMED, "3")
	w.submit(Command.attack(a.id, b.id))
	_steps(w, 60)
	assert_eq(b.health, 1000.0)
	w.submit(Command.move_dir(a.id, Vector2.LEFT))
	_steps(w, 5)
	assert_true(a.position.x < _origin().x)


func test_ST_07_invulnerable_takes_no_damage() -> void:
	var w: World = _world()
	var e: Entity = _fighter(w, 0, _origin())
	_state(w, e, S.INVULNERABLE, "1", [&"buff"])
	for type: DamageFormulas.DamageType in [DamageFormulas.DamageType.PHYSICAL, DamageFormulas.DamageType.MAGIC, DamageFormulas.DamageType.PURE]:
		assert_near(_hit(w, e, 100.0, type), 0.0, EPS)


func test_ST_11_ghost_damage_types() -> void:
	var w: World = _world()
	var e: Entity = _fighter(w, 0, _origin())
	_state(w, e, S.GHOST, "3", [&"buff"])
	assert_near(_hit(w, e, 100.0, DamageFormulas.DamageType.PHYSICAL), 0.0, EPS, "miễn vật lý")
	assert_near(_hit(w, e, 100.0, DamageFormulas.DamageType.MAGIC), 140.0, EPS, "phép × 1.4")
	assert_near(_hit(w, e, 100.0, DamageFormulas.DamageType.PURE), 100.0, EPS, "thuần bình thường")


func test_ST_11_ghost_cannot_be_picked_or_ordered_as_attack_target() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	var ghost: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	_state(w, ghost, S.GHOST, "3", [&"buff"])
	assert_eq(Rules.pick_attack_target(w, a, Rules.AttackMode.ALL), -1)
	w.submit(Command.attack(a.id, ghost.id))
	w.step()
	assert_eq(w.rejected_commands.size(), 1)
	assert_eq(w.rejected_commands[0].reject_reason, Command.Reject.BAD_TARGET)


func test_ST_11_ghost_mid_fight_ends_attack() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	var b: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	w.submit(Command.attack(a.id, b.id))
	_steps(w, 5)
	_state(w, b, S.GHOST, "3", [&"buff"])
	_steps(w, 30)
	assert_eq(b.health, 1000.0)
	assert_true(a.order.finished, "mục tiêu hóa ma → lệnh đánh xong")


func test_ST_01_stunned_creep_stands_still() -> void:
	var w: World = _world()
	var c: Entity = _fighter(w, 0, _origin(), Entity.Kind.LANE_CREEP)
	_state(w, c, S.STUNNED, "1")
	w.submit(Command.move_to(c.id, _origin() + Vector2(300, 0)))
	_steps(w, 20)
	assert_eq(c.position, _origin())


func test_ST_09_status_resistance_shortens_debuffs_only() -> void:
	var w: World = _world()
	var e: Entity = _fighter(w, 0, _origin())
	e.stats.set_base(StatId.Id.STATUS_RESISTANCE, 0.25)
	e.stats.recompute()
	var stun: EffectInstance = _state(w, e, S.STUNNED, "2")
	var buff: EffectInstance = _state(w, e, S.INVULNERABLE, "2", [&"buff"])
	assert_eq(stun.end_tick - stun.start_tick, 45, "2 s × (1 − 0.25) = 1.5 s")
	assert_eq(buff.end_tick - buff.start_tick, 60, "buff không bị giảm")


func test_ST_17_invulnerable_blocks_new_enemy_debuffs_only() -> void:
	var w: World = _world()
	var e: Entity = _fighter(w, 0, _origin())
	var foe: Entity = _fighter(w, 1, _origin() + Vector2(100, 0))
	var ally: Entity = _fighter(w, 0, _origin() + Vector2(-100, 0))
	_state(w, e, UnitState.Id.INVULNERABLE, "3", [&"buff"])
	var stun: EffectDef = EffectDef.new()
	stun.id = &"stun"
	stun.duration = "1"
	stun.tags = [&"debuff"]
	stun.states = [UnitState.Id.STUNNED]
	assert_eq(Effects.apply(w, e, stun, foe), null, "địch không áp được debuff")
	assert_true(Effects.apply(w, e, stun, ally) != null, "đồng minh vẫn áp được")


func test_ST_13_physical_projectile_on_new_ghost_does_nothing() -> void:
	var w: World = _world()
	var a: Entity = _fighter(w, 0, _origin())
	a.projectile_speed = 300.0
	a.stats.set_base(StatId.Id.ATTACK_RANGE, 600)
	a.stats.recompute()
	var b: Entity = _fighter(w, 1, _origin() + Vector2(500, 0))
	w.submit(Command.attack(a.id, b.id))
	_steps(w, 12)
	assert_eq(w.projectiles.size(), 1, "đạn đang bay")
	_state(w, b, UnitState.Id.GHOST, "5", [&"buff"])
	_steps(w, 60)
	assert_eq(b.health, 1000.0)
