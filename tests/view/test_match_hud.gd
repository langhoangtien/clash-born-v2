extends TestCase
## M2.5: HUD tối thiểu, màn kết quả (STR-05), phím tốc độ chơi thử (D-53).

const SCENE: String = "res://app/match_scene.tscn"


func test_clock_and_respawn_text() -> void:
	assert_eq(MatchHud.clock_text(0), "0:00")
	assert_eq(MatchHud.clock_text(30 * 75), "1:15")
	var w: World = World.new(1, BalanceSettings.new())
	var e: Entity = Entity.new()
	assert_eq(MatchHud.respawn_text(w, e), "")
	e.alive = false
	e.respawn_tick = 100
	assert_eq(MatchHud.respawn_text(w, e), "Hồi sinh sau 4 s")


func test_STR_05_result_title() -> void:
	assert_eq(ResultPanel.title_for(0, 0), "CHIẾN THẮNG")
	assert_eq(ResultPanel.title_for(1, 0), "THẤT BẠI")


func test_match_scene_speed_cycle_and_result_screen() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(scene)
	scene.set_process(false)
	var runner: SimRunner = scene.runner
	for expected: int in [2, 4, 8, 1]:
		scene.cycle_speed()
		assert_eq(runner.speed, expected)
	scene.tick_frame(0.0)
	assert_true(scene.result == null, "chưa xong trận thì không có màn kết quả")
	scene.world.winner = 0
	scene.tick_frame(0.5)
	assert_true(scene.result != null, "nhà chính đổ thì hiện màn kết quả")
	assert_eq(scene.world.tick, 0, "trận xong thì không chạy tiếp")
	assert_true(scene.find_child("ReplayButton", true, false) != null)
	assert_true(scene.find_child("MenuButton", true, false) != null)
	scene.free()


func test_M38_scene_manual_levels_and_talent_panel() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(scene)
	scene.set_process(false)
	var w: World = scene.world
	var hero: Entity = scene.hero
	scene.tick_frame(0.0)
	assert_true(scene.skill_buttons.skill_view[0][3], "cấp 1 có điểm: hiện + ở Q")
	scene.skills.level_up(AbilityDef.Slot.Q)
	w.step()
	assert_eq(Abilities.of(hero, AbilityDef.Slot.Q).rank, 1, "cộng điểm bằng tay, không còn tự cộng")
	Progression.add_xp(w, hero, 100000.0)
	for slot: int in [AbilityDef.Slot.W, AbilityDef.Slot.R]:
		Abilities.set_rank(w, hero, Abilities.of(hero, slot), 1)
	scene.tick_frame(0.0)
	assert_true(scene.talent_panel.visible, "cấp 20 hiện bảng talent")
	assert_true(scene.talent_panel.find_child("Talent%d" % AbilityDef.Slot.W, true, false) != null)
	scene.talent_panel.chosen.emit(AbilityDef.Slot.W)
	w.step()
	scene.tick_frame(0.0)
	assert_eq(hero.talent_slot, AbilityDef.Slot.W)
	assert_false(scene.talent_panel.visible)
	scene.free()


func test_M40_buff_bar_entries_and_layout() -> void:
	var w: World = World.new(1, BalanceSettings.new())
	var e: Entity = Entity.new()
	e.stats = StatBlock.new(w.balance)
	w.add_entity(e)
	var passive: EffectDef = EffectDef.new()
	passive.id = &"innate"
	passive.duration = "0"
	passive.tags = [&"passive"]
	var slow: EffectDef = EffectDef.new()
	slow.id = &"slow"
	slow.display_name = "Băng giá"
	slow.duration = "2"
	slow.tags = [&"debuff"]
	var shield: EffectDef = EffectDef.new()
	shield.id = &"shield"
	shield.display_name = "Giáp Sắt"
	shield.duration = "4"
	shield.tags = [&"buff"]
	Effects.apply(w, e, passive, e)
	Effects.apply(w, e, slow, null)
	Effects.apply(w, e, shield, e)
	var entries: Array = BuffBar.entries(w, e)
	assert_eq(entries.size(), 2, "nội tại (passive) không hiện")
	assert_eq(entries[0][0], shield, "buff trước, debuff sau")
	assert_true(entries[1][1], "debuff")
	assert_near(entries[0][2], 1.0, 0.01, "còn đủ thời gian")
	var bar: BuffBar = BuffBar.new()
	bar.size = Vector2(1280, 720)
	bar.right_limit = 900.0
	var row: Rect2 = bar.row_rect(3)
	assert_near(row.get_center().x, 640.0, 1.0, "căn giữa màn hình")
	bar.right_limit = 680.0
	assert_true(bar.row_rect(12).end.x <= 680.0, "nhiều icon thì dồn sang trái, không đè nút Q")
	bar.free()
