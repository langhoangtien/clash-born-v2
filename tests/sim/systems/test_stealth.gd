extends TestCase
## M5.2: tàng hình, lộ diện, true sight fountain, không thể bị nhắm (VIS-02..04, VIS-08,
## ST-12, ST-14, D-73) — mỗi dòng bảng tương tác một test.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const EPS: float = 0.01
const Slot := AbilityDef.Slot

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.add_vision(w)
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _dir() -> Vector2:
	return Vector2(1, -1).normalized()


func _unit(w: World, team: int, at: Vector2, sight: float = 1200.0, kind: Entity.Kind = Entity.Kind.HERO) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.attack_point = 0.3
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 100000)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 50)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 600)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	e.stats.set_base(StatId.Id.VISION_RANGE, sight)
	return w.add_entity(e)


func _veil(w: World, e: Entity, fade: float = 0.0) -> EffectInstance:
	return Effects.apply(w, e, _lib.effects[&"shadow_veil"], e, {&"fade_in": fade, &"move_bonus": 0.2}, "10")


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _reject(w: World, c: Command) -> Command.Reject:
	w.submit(c)
	w.step()
	return w.rejected_commands[0].reject_reason if not w.rejected_commands.is_empty() else Command.Reject.NONE


func test_VIS_02_invisible_hidden_in_range_same_bush_and_while_stunned() -> void:
	var w: World = _world()
	var sneak: Entity = _unit(w, 1, _center())
	var eye: Entity = _unit(w, 0, _center() + _dir() * 300.0)
	_veil(w, sneak)
	w.step()
	assert_false(Rules.is_visible(0, sneak), "tàng hình: trong tầm vẫn không thấy")
	assert_true(Rules.is_visible(1, eye))
	Effects.apply(w, sneak, _lib.effects[&"stun"], eye, {}, "1")
	var r: DamageRequest = DamageRequest.new()
	r.source_id = eye.id
	r.target_id = sneak.id
	r.raw = 50.0
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	_steps(w, 2)
	assert_false(Rules.is_visible(0, sneak), "bị choáng, bị trúng đòn không làm lộ")
	var bush: Vector2 = _map.bushes.polygons[0][0].lerp(_map.bushes.polygons[0][8], 0.5)
	sneak.position = bush
	eye.position = bush + Vector2(10, 0)
	_steps(w, 2)
	assert_false(Rules.is_visible(0, sneak), "tàng hình mạnh hơn bụi: cùng bụi vẫn không thấy")


func test_VIS_04_fade_in_keeps_visible_but_speed_applies() -> void:
	var w: World = _world()
	var sneak: Entity = _unit(w, 1, _center())
	_unit(w, 0, _center() + _dir() * 300.0)
	_veil(w, sneak, 0.6)
	w.step()
	assert_near(sneak.stats.get_stat(StatId.Id.MOVEMENT_SPEED), 360.0, 0.5, "modifier có ngay")
	_steps(w, 16)
	assert_true(Rules.is_visible(0, sneak), "đang hiện dần thì vẫn bị thấy")
	assert_false(Rules.has_state(sneak, UnitState.Id.INVISIBLE))
	_steps(w, 3)
	assert_true(Rules.has_state(sneak, UnitState.Id.INVISIBLE), "hết 0.6 s thì tàng hình")
	assert_false(Rules.is_visible(0, sneak))


func test_VIS_04_attacking_or_casting_breaks_invisibility() -> void:
	var w: World = _world()
	var sneak: Entity = _unit(w, 1, _center())
	var victim: Entity = _unit(w, 0, _center() + _dir() * 300.0)
	_veil(w, sneak)
	w.step()
	w.submit(Command.attack(sneak.id, victim.id))
	_steps(w, 3)
	assert_false(Rules.has_state(sneak, UnitState.Id.INVISIBLE), "bắt đầu đánh thì mất tàng hình")
	assert_true(Rules.is_visible(0, sneak))
	var caster: Entity = _unit(w, 1, _center() - _dir() * 300.0)
	var d: AbilityDef = AbilityDef.new()
	d.id = &"test_self"
	d.slot = Slot.Q
	d.targeting = AbilityDef.Targeting.NO_TARGET
	d.values = {&"mana": PackedFloat32Array([0, 0, 0, 0, 0])}
	var a: AbilityInstance = AbilityInstance.new()
	a.def = d
	a.slot = Slot.Q
	a.rank = 1
	caster.abilities.append(a)
	_veil(w, caster)
	w.step()
	assert_false(Rules.is_visible(0, caster))
	w.submit(Command.cast(caster.id, Slot.Q))
	_steps(w, 2)
	assert_true(Rules.is_visible(0, caster), "dùng chiêu thì mất tàng hình")


func test_VIS_02_towers_creeps_and_attack_button_ignore_invisible() -> void:
	var w: World = _world()
	var sneak: Entity = _unit(w, 1, _center())
	var tower: Entity = _unit(w, 0, _center() + _dir() * 400.0, 1200.0, Entity.Kind.TOWER)
	var me: Entity = _unit(w, 0, _center() + _dir() * 200.0)
	_veil(w, sneak)
	w.step()
	assert_false(Rules.is_targetable(tower, sneak), "trụ không nhắm được")
	assert_eq(Rules.pick_attack_target(w, me, Rules.AttackMode.ALL), -1, "nút đánh không chọn")
	assert_eq(_reject(w, Command.attack(me.id, sneak.id)), Command.Reject.BAD_TARGET)


func test_VIS_02_attack_order_cancelled_but_projectile_and_areas_hit() -> void:
	var w: World = _world()
	var sneak: Entity = _unit(w, 1, _center())
	var shooter: Entity = _unit(w, 0, _center() + _dir() * 550.0)
	shooter.projectile_speed = 250.0
	w.step()
	w.submit(Command.attack(shooter.id, sneak.id))
	for i: int in range(60):
		w.step()
		if not w.projectiles.is_empty():
			break
	assert_false(w.projectiles.is_empty())
	var hp: float = sneak.health
	_veil(w, sneak)
	_steps(w, 2)
	assert_true(shooter.order.finished, "lệnh đánh bị hủy")
	_steps(w, 90)
	assert_true(sneak.health < hp, "đạn đã bay vẫn trúng")
	var hit: DamageAction = DamageAction.new()
	hit.damage_type = DamageFormulas.DamageType.PURE
	hit.amount = "100"
	var area: AreaAction = AreaAction.new()
	area.target = ActionDef.Target.TARGET
	area.radius = "150"
	area.actions = [hit]
	var ctx: ExprContext = ExprContext.make(shooter, shooter, {})
	ctx.point = sneak.position
	var before: float = sneak.health
	ActionRunner.run(w, [area], ctx, shooter.id)
	DamageSystem.resolve(w)
	assert_near(sneak.health, before - 100.0, EPS, "vùng trúng kẻ tàng hình")


func test_VIS_08_revealed_seen_by_source_team_anywhere() -> void:
	var w: World = _world()
	var hunter: Entity = _unit(w, 0, _center(), 0.0)
	var prey: Entity = _unit(w, 1, _center() + _dir() * 4000.0)
	_veil(w, prey)
	var bush: Vector2 = _map.bushes.polygons[3][0].lerp(_map.bushes.polygons[3][8], 0.5)
	prey.position = bush
	w.step()
	assert_false(Rules.is_visible(0, prey))
	Effects.apply(w, prey, _lib.effects[&"revealed"], hunter, {}, "6")
	w.step()
	assert_true(Rules.is_visible(0, prey), "lộ diện: thấy ở mọi nơi, kể cả tàng hình trong bụi")
	assert_true(Rules.is_targetable(hunter, prey))
	_steps(w, 6 * 30)
	assert_false(Rules.is_visible(0, prey), "hết lộ diện")


func test_VIS_03_fountain_true_sight() -> void:
	var w: World = _world()
	var f: Vector2 = _map.fountain_point(0)
	var inside: Entity = _unit(w, 1, f + Vector2(880, 0).rotated(-0.7), 0.0)
	var outside: Entity = _unit(w, 1, f + Vector2(950, 0).rotated(-0.7), 0.0)
	_veil(w, inside)
	_veil(w, outside)
	w.step()
	assert_true(Rules.is_visible(0, inside), "trong 900 quanh fountain: luôn thấy, kể cả tàng hình")
	assert_false(Rules.is_visible(0, outside))
	var home: Entity = _unit(w, 0, f + Vector2(100, -100), 0.0)
	w.step()
	assert_false(Rules.is_visible(1, home), "fountain đội 0 không cho đội 1 true sight")


func test_ST_12_14_untargetable() -> void:
	var w: World = _world()
	var me: Entity = _unit(w, 0, _center())
	var foe: Entity = _unit(w, 1, _center() + _dir() * 300.0)
	var mate: Entity = _unit(w, 0, _center() - _dir() * 200.0)
	var lift: EffectDef = EffectDef.new()
	lift.id = &"test_lift"
	lift.states = [UnitState.Id.UNTARGETABLE]
	w.step()
	w.submit(Command.attack(me.id, foe.id))
	_steps(w, 2)
	Effects.apply(w, foe, lift, foe, {}, "3")
	Effects.apply(w, mate, lift, mate, {}, "3")
	_steps(w, 2)
	assert_true(me.order.finished, "lệnh đang nhắm bị hủy")
	assert_eq(_reject(w, Command.attack(me.id, foe.id)), Command.Reject.BAD_TARGET)
	assert_true(Rules.is_visible(0, foe), "vẫn được thấy")
	var ally_spell: AbilityDef = AbilityDef.new()
	ally_spell.target_team = AbilityDef.Team.ALLY
	assert_true(Abilities.accepts(me, ally_spell, mate), "đồng minh vẫn nhắm được")
	var enemy_spell: AbilityDef = AbilityDef.new()
	assert_false(Abilities.accepts(me, enemy_spell, foe))
	assert_true(Abilities.accepts(me, enemy_spell, foe, false), "vùng / đạn kỹ năng vẫn trúng")
