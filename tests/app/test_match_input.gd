extends TestCase
## M1.5: CTL-01 — hướng joystick/WASD → MOVE_DIR / STOP; chạm map → MOVE_TO.

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


func test_CTL_01_tap_sends_move_to_and_joystick_overrides() -> void:
	var s: Array = _setup()
	var input: MatchInput = s[2]
	input.tap_world_point(Vector2(500, 600))
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
