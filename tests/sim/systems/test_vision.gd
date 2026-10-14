extends TestCase
## M5.1: tầm nhìn (VIS-01, VIS-05), không nhắm thứ không thấy (INV-07).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01
const Slot := AbilityDef.Slot

static var _map: MapLayout


func _world(vision: bool = true) -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	if vision:
		MatchSetup.add_vision(w)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _dir() -> Vector2:
	return Vector2(1, -1).normalized()


func _unit(w: World, team: int, at: Vector2, sight: float = 0.0, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.attack_point = 0.3
	e.projectile_speed = 0.0
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.MAX_MANA, 500)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 50)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 600)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	e.stats.set_base(StatId.Id.VISION_RANGE, sight)
	return w.add_entity(e)


func _reject(w: World, c: Command) -> Command.Reject:
	w.submit(c)
	w.step()
	return w.rejected_commands[0].reject_reason if not w.rejected_commands.is_empty() else Command.Reject.NONE


func test_VIS_01_center_distance_within_vision_range() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center(), 1200.0)
	var near: Entity = _unit(w, 1, _center() + _dir() * 1199.0)
	var far: Entity = _unit(w, 1, _center() + _dir() * 1201.0)
	var mate: Entity = _unit(w, 0, _center() + _dir() * 3000.0)
	w.step()
	assert_true(Rules.is_visible(0, near), "tâm–tâm 1199 ≤ 1200")
	assert_false(Rules.is_visible(0, far), "1201 thì không thấy (không tính bán kính thân)")
	assert_true(Rules.is_visible(0, mate), "luôn thấy đồng đội")
	assert_true(Rules.is_visible(1, me) == false, "đội 1 không có tầm nhìn (tầm 0)")
	assert_true(Rules.is_visible(0, me))


func test_VIS_01_dead_units_give_no_vision_and_no_vision_system_sees_all() -> void:
	var w: World = _world()
	var eye: Entity = _unit(w, 0, _center(), 1200.0)
	var foe: Entity = _unit(w, 1, _center() + _dir() * 500.0)
	w.step()
	assert_true(Rules.is_visible(0, foe))
	eye.alive = false
	w.step()
	assert_false(Rules.is_visible(0, foe), "đơn vị chết không cho tầm nhìn")
	var plain: World = _world(false)
	var a: Entity = _unit(plain, 0, _center())
	var b: Entity = _unit(plain, 1, _center() + _dir() * 5000.0)
	plain.step()
	assert_true(Rules.is_visible(0, b) and Rules.is_visible(1, a), "World không có VisionSystem: thấy hết (test cơ chế)")


func test_INV_07_cannot_attack_or_pick_unseen() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center(), 300.0)
	var foe: Entity = _unit(w, 1, _center() + _dir() * 500.0)
	w.step()
	assert_eq(_reject(w, Command.attack(me.id, foe.id)), Command.Reject.BAD_TARGET, "trong tầm đánh 600 nhưng không thấy")
	assert_eq(Rules.pick_attack_target(w, me, Rules.AttackMode.ALL), -1, "nút đánh không chọn kẻ không thấy")
	me.stats.set_base(StatId.Id.VISION_RANGE, 800.0)
	me.stats.recompute()
	w.step()
	assert_eq(Rules.pick_attack_target(w, me, Rules.AttackMode.ALL), foe.id)


func test_VIS_05_target_leaving_vision_cancels_attack_but_projectile_hits() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center(), 700.0)
	var foe: Entity = _unit(w, 1, _center() + _dir() * 500.0)
	w.step()
	w.submit(Command.attack(me.id, foe.id))
	_steps_until(w, func() -> bool: return me.attack_phase == Entity.AttackPhase.WINDUP)
	foe.position = _center() + _dir() * 590.0  # còn trong tầm đánh, vẫn thấy
	w.step()
	foe.position = _center() + _dir() * 750.0
	w.step()
	w.step()
	assert_true(me.order.finished, "mất tầm nhìn thì lệnh đánh bị hủy")
	assert_eq(me.attack_phase, Entity.AttackPhase.NONE)
	var shooter: Entity = _unit(w, 0, _center() + _dir().orthogonal() * 300.0, 1000.0)
	shooter.projectile_speed = 300.0
	var mark: Entity = _unit(w, 1, shooter.position + _dir() * 550.0)
	w.step()
	w.submit(Command.attack(shooter.id, mark.id))
	_steps_until(w, func() -> bool: return not w.projectiles.is_empty())
	shooter.stats.set_base(StatId.Id.VISION_RANGE, 0.0)
	shooter.stats.recompute()
	me.alive = false
	var hp: float = mark.health
	for i: int in range(90):
		w.step()
	assert_true(mark.health < hp, "đạn đã bay vẫn trúng dù mất tầm nhìn")


func test_VIS_05_unit_target_skill_needs_sight_but_areas_hit_unseen() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center(), 200.0)
	var foe: Entity = _unit(w, 1, _center() + _dir() * 400.0)
	var hit: DamageAction = DamageAction.new()
	hit.damage_type = DamageFormulas.DamageType.PURE
	hit.amount = "100"
	var d: AbilityDef = AbilityDef.new()
	d.id = &"test_unit"
	d.slot = Slot.Q
	d.targeting = AbilityDef.Targeting.UNIT
	d.values = {&"mana": PackedFloat32Array([0, 0, 0, 0, 0]), &"cast_range": PackedFloat32Array([600, 600, 600, 600, 600])}
	d.on_cast = [hit]
	var a: AbilityInstance = AbilityInstance.new()
	a.def = d
	a.slot = Slot.Q
	a.rank = 1
	me.abilities.append(a)
	w.step()
	assert_eq(_reject(w, Command.cast(me.id, Slot.Q, foe.id)), Command.Reject.BAD_TARGET, "không nhắm được kẻ không thấy")
	var area: AreaAction = AreaAction.new()
	area.target = ActionDef.Target.TARGET
	area.radius = "150"
	area.actions = [hit]
	var ctx: ExprContext = ExprContext.make(me, me, {})
	ctx.point = foe.position
	ActionRunner.run(w, [area], ctx, me.id)
	DamageSystem.resolve(w)
	assert_near(foe.health, 900.0, EPS, "vùng trúng cả kẻ không thấy (ABL-07)")


func test_creeps_do_not_acquire_unseen_heroes() -> void:
	var w: World = _world()
	w.add_system(LaneCreepController.new(), World.Phase.CONTROLLER)
	var creep: Entity = _unit(w, 0, _center(), 0.0, Entity.Kind.LANE_CREEP)
	creep.lane = "mid"
	var foe: Entity = _unit(w, 1, _center() + _dir() * 400.0)
	for i: int in range(10):
		w.step()
	assert_true(creep.order.type != Order.Type.ATTACK or creep.order.target_id != foe.id, "lính không thấy thì không đánh")


func test_D_30_visibility_in_hash() -> void:
	var w: World = _world()
	_unit(w, 0, _center(), 1200.0)
	var foe: Entity = _unit(w, 1, _center() + _dir() * 500.0)
	w.step()
	var h: PackedByteArray = w.state_hash()
	foe.visible_mask = 0
	assert_true(w.state_hash() != h)


func _steps_until(w: World, done: Callable) -> void:
	for i: int in range(120):
		if done.call():
			return
		w.step()
