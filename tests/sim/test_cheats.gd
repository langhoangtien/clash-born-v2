extends TestCase
## CMD-06 (D-138): lệnh thử nghiệm — cộng vàng, lên cấp, cho cả hero bot; phát lại được.


func _setup() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	var me: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(1000, 1000))
	var bot: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 1, Vector2(3000, 3000))
	return [w, me, bot]


func test_CMD_06_cheat_gold_adds_gold() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var me: Entity = s[1]
	var bot: Entity = s[2]
	var gold: Array[int] = [me.gold, bot.gold]
	w.submit(Command.cheat_gold(me.id, 10000))
	w.submit(Command.cheat_gold(bot.id, 10000))
	w.step()
	assert_eq(me.gold - gold[0], 10000)
	assert_eq(bot.gold - gold[1], 10000, "bot cũng được")


func test_CMD_06_cheat_level_gives_levels_and_points() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var me: Entity = s[1]
	w.submit(Command.cheat_level(me.id, 1))
	w.step()
	assert_eq(me.stats.level(), 2)
	assert_eq(me.skill_points, 2, "cấp 2: 2 điểm")
	w.submit(Command.cheat_level(me.id, 99))
	w.step()
	assert_eq(me.stats.level(), w.balance.hero_max_level, "không quá cấp tối đa")
	w.submit(Command.cheat_level(me.id, 1))
	w.step()
	assert_eq(w.rejected_commands[0].reject_reason, Command.Reject.CANNOT_LEVEL, "đã tối đa")


func test_CMD_06_cheat_works_while_dead_and_keeps_order() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var me: Entity = s[1]
	w.submit(Command.move_to(me.id, Vector2(1500, 1000)))
	w.step()
	w.submit(Command.cheat_gold(me.id, 500))
	w.step()
	assert_eq(me.order.type, Order.Type.MOVE, "không đổi lệnh đang làm")
	me.alive = false
	w.submit(Command.cheat_level(me.id, 1))
	w.step()
	assert_eq(me.stats.level(), 2, "chờ hồi sinh vẫn lên cấp được")
