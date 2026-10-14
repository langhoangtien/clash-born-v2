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
