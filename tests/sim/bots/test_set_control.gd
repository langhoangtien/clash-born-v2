extends TestCase
## M9.7 (D-390): lệnh SET_CONTROL — máy chủ phòng giao hero cho bot khi người rớt (NET-17) và trả lại khi vào lại (NET-18).
## Một dòng bảng tương tác của giao kèo CB-3 một test.

const Inv = preload("res://tests/sim/bots/test_bot_invariants.gd")


## Trận 1v1 cả hai ô là người (không có bot nào lúc dựng trận).
func _world(seed_value: int = 5) -> World:
	return Inv.new().team_world(MatchConfig.make(1, [&"brakk", &"noctis"] as Array[StringName], [0, 1], BotState.Difficulty.EASY, seed_value))


func _hero(w: World, team: int) -> Entity:
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.HERO and e.team == team:
			return e
	return null


func _steps(w: World, n: int) -> void:
	for i: int in range(n):
		w.step()


func _control(w: World, e: Entity, bot: bool) -> void:
	w.enqueue(Command.set_control(e.id, bot))


func test_NET_17_bot_takes_over_with_slot_lane_and_normal_difficulty() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0)
	assert_true(h.bot == null and not w.has_system(BotController), "trận dựng không có bot")
	_control(w, h, true)
	w.step()
	assert_true(w.rejected_commands.is_empty(), "lệnh được áp")
	assert_true(h.bot != null, "hero nhận bot")
	assert_true(w.has_system(BotController), "World có BotController")
	assert_eq(h.bot.difficulty, BotState.Difficulty.NORMAL, "R1: bot Thường")
	assert_eq(h.bot.lane, w.balance.bot_lane_order[0], "đường theo ô của hero như lúc dựng trận")
	var start: Vector2 = h.position
	_steps(w, 90)
	assert_true(h.position.distance_to(start) > 100.0, "bot điều khiển hero")


func test_NET_17_dead_hero_gets_bot_and_plays_after_respawn() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0)
	h.health = 0.0
	h.alive = false
	w.step()
	_control(w, h, true)
	w.step()
	assert_true(w.rejected_commands.is_empty(), "không bị từ chối UNIT_DEAD")
	assert_true(h.bot != null)
	var guard: int = 0
	while not h.alive and guard < 30 * 120:
		w.step()
		guard += 1
	assert_true(h.alive, "đã hồi sinh")
	var start: Vector2 = h.position
	_steps(w, 90)
	assert_true(h.position.distance_to(start) > 100.0, "hồi sinh xong bot đánh tiếp")


func test_NET_17_recall_channel_continues() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0)
	w.enqueue(Command.recall(h.id))
	w.step()
	var until: int = h.recall_until_tick
	assert_true(until >= 0, "đang kênh về thành")
	_control(w, h, true)
	w.step()
	assert_true(h.bot != null)
	assert_eq(h.recall_until_tick, until, "đổi quyền không hủy kênh về thành")


func test_NET_17_duel_rules_still_apply() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0)
	var foe: Entity = _hero(w, 1)
	var duel: EffectDef = load("res://content/effects/duel.tres") as EffectDef
	assert_true(Duels.start(w, foe, h, {&"duration": 4.0} as Dictionary[StringName, float], duel))
	_control(w, h, true)
	w.step()
	assert_true(h.bot != null, "không bị từ chối IN_DUEL")
	_steps(w, 30)
	assert_true(h.duel != null, "Quyết Đấu vẫn tiếp tục")
	assert_eq(h.order.type, Order.Type.ATTACK, "ST-19: vẫn bị ép đánh đối thủ")
	assert_eq(h.order.target_id, foe.id)


func test_NET_17_stunned_hero_gets_bot_and_acts_after_stun() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0)
	var stun: EffectDef = load("res://content/effects/stun.tres") as EffectDef
	Effects.apply(w, h, stun, _hero(w, 1), {}, "1.0")
	_control(w, h, true)
	w.step()
	assert_true(w.rejected_commands.is_empty() and h.bot != null, "nhận bot khi đang choáng")
	var start: Vector2 = h.position
	_steps(w, 20)
	assert_eq(h.position, start, "đang choáng không đi")
	_steps(w, 100)
	assert_true(h.position.distance_to(start) > 100.0, "hết choáng bot hành động")


func test_NET_17_held_move_dir_is_cancelled() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0)
	w.enqueue(Command.move_dir(h.id, Vector2.RIGHT))
	w.step()
	assert_eq(h.order.type, Order.Type.DIRECT)
	_control(w, h, true)
	w.step()
	assert_ne(h.order.type, Order.Type.DIRECT, "lệnh giữ của người bị hủy")


func test_NET_17_two_heroes_same_tick_both_applied() -> void:
	var w: World = _world()
	_control(w, _hero(w, 0), true)
	_control(w, _hero(w, 1), true)
	w.step()
	assert_true(_hero(w, 0).bot != null and _hero(w, 1).bot != null)
	assert_eq(_hero(w, 1).bot.lane, w.balance.bot_lane_order[0], "ô 0 của đội 1")


func test_NET_18_bot_then_human_same_tick_ends_human() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0)
	_control(w, h, true)
	_control(w, h, false)
	w.step()
	assert_true(w.rejected_commands.is_empty())
	assert_true(h.bot == null, "áp theo thứ tự: cuối cùng là người")


func test_NET_18_return_to_human_removes_bot_and_stops() -> void:
	var w: World = _world()
	var h: Entity = _hero(w, 0)
	_control(w, h, true)
	_steps(w, 60)
	assert_ne(h.order.type, Order.Type.IDLE, "bot đang ra lệnh")
	_control(w, h, false)
	w.step()
	assert_true(h.bot == null, "gỡ bot")
	assert_eq(h.order.type, Order.Type.IDLE, "hero dừng chờ lệnh người")
	assert_true(w.has_system(BotController), "BotController ở lại World")
	var at: Vector2 = h.position
	_steps(w, 30)
	assert_true(h.position.distance_to(at) < 5.0, "không ai ra lệnh thì đứng yên")


func test_NET_17_non_hero_or_missing_unit_rejected() -> void:
	var w: World = _world()
	var tower: Entity = null
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.TOWER:
			tower = e
			break
	w.enqueue(Command.set_control(tower.id, true))
	w.enqueue(Command.set_control(999999, true))
	w.step()
	assert_eq(w.rejected_commands.size(), 2)
	assert_eq(w.rejected_commands[0].reject_reason, Command.Reject.BAD_TARGET, "không phải hero")
	assert_eq(w.rejected_commands[1].reject_reason, Command.Reject.UNKNOWN_UNIT)
	assert_true(tower.bot == null)


func test_NET_17_repeating_current_mode_changes_nothing() -> void:
	var a: World = _world()
	var b: World = _world()
	_control(a, _hero(a, 1), true)
	_control(b, _hero(b, 1), true)
	_steps(a, 45)
	_steps(b, 45)
	_control(a, _hero(a, 0), false)  # đã là người
	_control(a, _hero(a, 1), true)  # đã là bot
	a.step()
	b.step()
	assert_eq(a.state_hash(), b.state_hash(), "lặp mode hiện tại không đổi gì")


func test_D_30_set_control_mid_match_is_deterministic() -> void:
	var worlds: Array[World] = [_world(9), _world(9)]
	for w: World in worlds:
		_steps(w, 300)
		_control(w, _hero(w, 0), true)
		_steps(w, 600)
		_control(w, _hero(w, 1), true)
		_steps(w, 600)
		_control(w, _hero(w, 0), false)
		_steps(w, 300)
	assert_eq(worlds[0].tick, 1800, "60 s")
	assert_eq(worlds[0].state_hash(), worlds[1].state_hash(), "cùng chuỗi lệnh → cùng mã băm")
