extends TestCase
## M1.5: CTL-01 — hướng joystick/WASD → MOVE_DIR / STOP; chạm map → MOVE_TO.
## M2.4: CTL-02..04 — nút đánh (J/K/L), giữ để đánh liên tục, khóa mục tiêu.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


func _setup() -> Array:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = Entity.new()
	e.stats = StatBlock.new(w.balance)
	w.add_entity(e)
	var input: MatchInput = MatchInput.new()
	input.world = w
	input.hero = e
	return [w, e, input]


func _sent(w: World) -> Array[Command]:
	return w.take_pending_commands()


func test_CTL_01_direction_sends_move_dir_once() -> void:
	var s: Array = _setup()
	var input: MatchInput = s[2]
	input.set_direction(Vector2(1, 0))
	input.flush()
	input.flush()
	var sent: Array[Command] = _sent(s[0])
	assert_eq(sent.size(), 1, "cùng hướng không gửi lại")
	assert_eq(sent[0].type, Command.Type.MOVE_DIR)


func test_CTL_01_small_angle_change_ignored_big_change_sent() -> void:
	var s: Array = _setup()
	var input: MatchInput = s[2]
	input.set_direction(Vector2.RIGHT)
	input.flush()
	input.set_direction(Vector2.from_angle(deg_to_rad(2)))
	input.flush()
	input.set_direction(Vector2.from_angle(deg_to_rad(10)))
	input.flush()
	assert_eq(_sent(s[0]).size(), 2)


func test_CTL_01_release_sends_stop() -> void:
	var s: Array = _setup()
	var input: MatchInput = s[2]
	input.set_direction(Vector2.UP)
	input.flush()
	input.set_direction(Vector2.ZERO)
	input.flush()
	input.flush()
	var sent: Array[Command] = _sent(s[0])
	assert_eq(sent.size(), 2)
	assert_eq(sent[1].type, Command.Type.STOP)


func test_CTL_01_pc_click_on_ground_sends_move_to_and_joystick_overrides() -> void:
	var s: Array = _setup()
	var input: MatchInput = s[2]
	input.click_world_point(Vector2(500, 600), true)
	input.flush()
	var sent: Array[Command] = _sent(s[0])
	assert_eq(sent.size(), 1)
	assert_eq(sent[0].type, Command.Type.MOVE_TO)
	assert_eq(sent[0].point, Vector2(500, 600))
	input.set_direction(Vector2.LEFT)
	input.flush()
	assert_eq(_sent(s[0])[0].type, Command.Type.MOVE_DIR)


func test_idle_without_input_sends_nothing() -> void:
	var s: Array = _setup()
	(s[2] as MatchInput).flush()
	assert_true(_sent(s[0]).is_empty())


func test_touch_joystick_direction_and_dead_zone() -> void:
	var stick: TouchJoystick = TouchJoystick.new()
	stick.radius = 100.0
	assert_eq(stick.direction_for(Vector2(5, 0)), Vector2.ZERO, "vùng chết")
	assert_eq(stick.direction_for(Vector2(50, 0)), Vector2.RIGHT)
	assert_near(stick.direction_for(Vector2(300, 300)).length(), 1.0, 0.0001)
	stick.free()


func test_CTL_01_mobile_tap_on_ground_does_nothing() -> void:
	var s: Array = _setup()
	var input: MatchInput = s[2]
	input.click_world_point(Vector2(500, 600), false)
	input.flush()
	assert_true(_sent(s[0]).is_empty(), "điện thoại không có chạm map để đi (D-45)")


func test_CTL_04_click_on_enemy_locks_and_attacks() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var input: MatchInput = s[2]
	var enemy: Entity = Entity.new()
	enemy.team = 1
	enemy.radius = 24.0
	enemy.position = Vector2(500, 600)
	enemy.stats = StatBlock.new(w.balance)
	w.add_entity(enemy)
	for allow_move: bool in [false, true]:
		input.click_world_point(Vector2(510, 590), allow_move)
		input.flush()
		var sent: Array[Command] = _sent(w)
		assert_eq(sent.size(), 1)
		assert_eq(sent[0].type, Command.Type.ATTACK)
		assert_eq(sent[0].target_id, enemy.id)
		assert_true(sent[0].lock, "chạm địch là khóa (CTL-04)")


func test_CTL_02_press_attack_sends_attack_auto_once_while_attacking() -> void:
	var s: Array = _setup()
	var e: Entity = s[1]
	var input: MatchInput = s[2]
	input.set_attack_held(Rules.AttackMode.ALL, true)
	input.flush()
	var sent: Array[Command] = _sent(s[0])
	assert_eq(sent.size(), 1)
	assert_eq(sent[0].type, Command.Type.ATTACK_AUTO)
	assert_eq(sent[0].mode, Rules.AttackMode.ALL)
	e.order = Order.attack(99)
	input.flush()
	assert_true(_sent(s[0]).is_empty(), "đang đánh thì giữ nút không gửi lại")
	e.order.finished = true
	input.flush()
	assert_eq(_sent(s[0]).size(), 1, "mục tiêu chết mà vẫn giữ → chọn tiếp")
	e.order = Order.swing()
	input.set_attack_held(Rules.AttackMode.ALL, false)
	e.order.finished = true
	input.flush()
	assert_true(_sent(s[0]).is_empty(), "thả nút thì thôi")


func test_CTL_02_joystick_cancels_attack_then_holding_resumes() -> void:
	var s: Array = _setup()
	var input: MatchInput = s[2]
	input.set_attack_held(Rules.AttackMode.ALL, true)
	input.set_direction(Vector2.LEFT)
	input.flush()
	assert_eq(_sent(s[0])[0].type, Command.Type.MOVE_DIR, "joystick thắng")
	input.set_direction(Vector2.ZERO)
	input.flush()
	assert_eq(_sent(s[0])[0].type, Command.Type.STOP)
	input.flush()
	assert_eq(_sent(s[0])[0].type, Command.Type.ATTACK_AUTO, "thả joystick mà vẫn giữ nút → đánh tiếp")


func test_CTL_03_last_pressed_button_wins() -> void:
	var s: Array = _setup()
	var e: Entity = s[1]
	var input: MatchInput = s[2]
	input.set_attack_held(Rules.AttackMode.ALL, true)
	input.flush()
	_sent(s[0])
	e.order = Order.attack(99)
	input.set_attack_held(Rules.AttackMode.CREEP, true)
	input.flush()
	var sent: Array[Command] = _sent(s[0])
	assert_eq(sent.size(), 1, "nhấn nút mới thì gửi ngay")
	assert_eq(sent[0].mode, Rules.AttackMode.CREEP)
	input.set_attack_held(Rules.AttackMode.CREEP, false)
	e.order.finished = true
	input.flush()
	assert_eq(_sent(s[0])[0].mode, Rules.AttackMode.ALL, "thả nút lính, còn giữ ĐÁNH")


func test_ECO_04_dead_hero_sends_nothing() -> void:
	var s: Array = _setup()
	var e: Entity = s[1]
	var input: MatchInput = s[2]
	e.alive = false
	input.set_direction(Vector2.LEFT)
	input.set_attack_held(Rules.AttackMode.ALL, true)
	input.flush()
	assert_true(_sent(s[0]).is_empty())
	e.alive = true
	input.flush()
	assert_eq(_sent(s[0])[0].type, Command.Type.MOVE_DIR, "sống lại mà vẫn giữ joystick thì đi tiếp")


func test_CTL_02_attack_buttons_hit_test() -> void:
	var b: AttackButtons = AttackButtons.new()
	b.size = Vector2(640, 640)
	assert_eq(b.button_at(b.button_center(Rules.AttackMode.ALL)), Rules.AttackMode.ALL)
	assert_eq(b.button_at(b.button_center(Rules.AttackMode.CREEP) + Vector2(5, 5)), Rules.AttackMode.CREEP)
	assert_eq(b.button_at(b.button_center(Rules.AttackMode.STRUCTURE)), Rules.AttackMode.STRUCTURE)
	assert_eq(b.button_at(Vector2(2, 2)), -1)
	b.press_at(0, b.button_center(Rules.AttackMode.CREEP))
	assert_true(b.is_held(Rules.AttackMode.CREEP))
	b.release(0)
	assert_false(b.is_held(Rules.AttackMode.CREEP))
	b.free()


func test_ABL_04_auto_skill_follows_suggested_order() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	var def: HeroDef = lib.heroes[&"brakk"]
	var hero: Entity = UnitFactory.hero(w, def, 0, Vector2(500, 500))
	var picks: Array[int] = []
	for level: int in range(1, 21):
		if level > 1:
			Progression.add_xp(w, hero, Progression.xp_to_next(w, level - 1))
		var slot: int = AutoSkill.pick(w, hero, def.bot_skill_order)
		picks.append(slot)
		Progression.spend_point(w, hero, slot)
	assert_eq(picks[0], AbilityDef.Slot.Q)
	assert_eq(picks[5], AbilityDef.Slot.R, "cấp 6 lên R")
	assert_eq(Abilities.of(hero, AbilityDef.Slot.Q).rank, 5)
	assert_eq(Abilities.of(hero, AbilityDef.Slot.R).rank, 3)
	assert_eq(hero.skill_points, 0)


func test_M38_skill_button_and_key_quick_cast() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	var hero: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(500, 500))
	var input: MatchInput = MatchInput.new()
	input.world = w
	input.hero = hero
	input.set_direction(Vector2.LEFT)
	input.flush()
	w.take_pending_commands()
	input.press_skill(AbilityDef.Slot.Q)
	input.flush()
	var sent: Array[Command] = w.take_pending_commands()
	assert_eq(sent.size(), 1)
	assert_eq(sent[0].type, Command.Type.CAST, "chiêu thắng joystick")
	assert_eq(sent[0].slot, AbilityDef.Slot.Q)
	input.flush()
	assert_eq(w.take_pending_commands()[0].type, Command.Type.MOVE_DIR, "sau đó joystick gửi lại hướng")


func test_M38_quick_cast_aims_at_enemy_hero_first() -> void:
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	var me: Entity = _unit_at(w, 0, Vector2(500, 500), Entity.Kind.HERO)
	var creep: Entity = _unit_at(w, 1, Vector2(560, 500), Entity.Kind.LANE_CREEP)
	var foe: Entity = _unit_at(w, 1, Vector2(800, 500), Entity.Kind.HERO)
	var d: AbilityDef = AbilityDef.new()
	d.slot = AbilityDef.Slot.Q
	d.targeting = AbilityDef.Targeting.UNIT
	d.values = {&"cast_range": PackedFloat32Array([400, 400, 400, 400, 400])}
	var a: AbilityInstance = AbilityInstance.new()
	a.def = d
	a.slot = AbilityDef.Slot.Q
	a.rank = 1
	me.abilities.append(a)
	assert_eq(QuickCast.command(w, me, AbilityDef.Slot.Q).target_id, foe.id)
	foe.position = Vector2(2000, 500)
	assert_eq(QuickCast.command(w, me, AbilityDef.Slot.Q).target_id, creep.id, "không có hero thì lính gần nhất")


func _unit_at(w: World, team: int, at: Vector2, kind: Entity.Kind) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.stats = StatBlock.new(w.balance)
	return w.add_entity(e)


func test_M38_skill_buttons_tap_drag_cancel_and_plus() -> void:
	var b: SkillButtons = SkillButtons.new()
	b.size = Vector2(640, 640)
	var taps: Array[int] = []
	var aims: Array = []
	var levels: Array[int] = []
	b.skill_tapped.connect(func(i: int) -> void: taps.append(i))
	b.skill_aimed.connect(func(i: int, aim: Vector2) -> void: aims.append([i, aim]))
	b.level_pressed.connect(func(i: int) -> void: levels.append(i))
	var c: Vector2 = b.skill_center(1)
	b.press_at(0, c + Vector2(5, 0))
	b.release_at(0, c + Vector2(8, 0))
	assert_eq(taps, [1], "chạm tại chỗ = tung nhanh")
	b.press_at(0, c)
	b.drag_to(0, c + Vector2(80, 0))
	assert_true(b.is_aiming())
	b.release_at(0, c + Vector2(80, 0))
	assert_eq(aims.size(), 1)
	assert_near(aims[0][1].x, 0.5, 0.001, "kéo 80/160 = nửa tầm")
	b.press_at(0, c)
	b.drag_to(0, c + Vector2(400, 400))
	b.release_at(0, b.cancel_center())
	assert_eq(aims.size(), 1, "thả vào Hủy thì không tung")
	assert_eq(taps.size(), 1)
	b.press_at(0, b.plus_center(0))
	assert_true(levels.is_empty(), "không nâng được thì không có nút +")
	b.skill_view[0] = [1, 0.0, true, true]
	b.attributes_can_level = true
	b.press_at(0, b.plus_center(0))
	b.press_at(1, b.plus_center(SkillButtons.ATTRIBUTES))
	assert_eq(levels, [0, SkillButtons.ATTRIBUTES])
	b.free()


func test_M38_aimed_and_cursor_casts() -> void:
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	var me: Entity = _unit_at(w, 0, Vector2(500, 500), Entity.Kind.HERO)
	var near: Entity = _unit_at(w, 1, Vector2(700, 520), Entity.Kind.HERO)
	var other: Entity = _unit_at(w, 1, Vector2(500, 750), Entity.Kind.HERO)
	var a: AbilityInstance = AbilityInstance.new()
	a.def = AbilityDef.new()
	a.def.slot = AbilityDef.Slot.Q
	a.def.targeting = AbilityDef.Targeting.POINT
	a.def.values = {&"cast_range": PackedFloat32Array([600, 600, 600, 600, 600])}
	a.slot = AbilityDef.Slot.Q
	a.rank = 1
	me.abilities.append(a)
	var c: Command = QuickCast.aimed(w, me, AbilityDef.Slot.Q, Vector2(0.5, 0))
	assert_eq(c.point, Vector2(800, 500), "nửa tầm theo hướng kéo")
	a.def.targeting = AbilityDef.Targeting.DIRECTION
	assert_eq(QuickCast.aimed(w, me, AbilityDef.Slot.Q, Vector2(0, -1)).direction.normalized(), Vector2(0, -1))
	a.def.targeting = AbilityDef.Targeting.UNIT
	assert_eq(QuickCast.at_point(w, me, AbilityDef.Slot.Q, Vector2(500, 760)).target_id, other.id, "đơn vị gần con trỏ nhất")
	assert_eq(QuickCast.at_point(w, me, AbilityDef.Slot.Q, Vector2(710, 520)).target_id, near.id)
