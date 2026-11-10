extends TestCase
## D-263: HUD chỉ vẽ lại khi nội dung hiện ra đổi (đo D-261: vẽ HUD mỗi khung tốn ~11 ms trên máy tính bảng).


func test_D_263_gate_reports_only_changes() -> void:
	var g: RedrawGate = RedrawGate.new()
	assert_true(g.changed([1, "a"]), "lần đầu luôn vẽ")
	assert_true(not g.changed([1, "a"]), "giống hệt thì không vẽ lại")
	assert_true(g.changed([2, "a"]))
	var key: Array = [[1, 2.0]]
	g.changed(key)
	key[0][1] = 3.0
	assert_true(g.changed(key), "sửa tại chỗ mảng lồng vẫn nhận ra (giữ bản sao sâu)")


func test_D_263_skill_cooldown_redraws_once_per_shown_second() -> void:
	var b: SkillButtons = SkillButtons.new()
	var art: Array[StringName] = [&"", &"", &""]
	assert_true(b.show_view([[1, 2.3, false, false, 5], [0, 0.0, false, false, 5], [0, 0.0, false, false, 3]], art, false))
	assert_true(not b.show_view([[1, 2.1, false, false, 5], [0, 0.0, false, false, 5], [0, 0.0, false, false, 3]], art, false),
		"2,3 s và 2,1 s cùng hiện \"3\" → không vẽ lại")
	assert_true(b.show_view([[1, 1.9, false, false, 5], [0, 0.0, false, false, 5], [0, 0.0, false, false, 3]], art, false), "hiện \"2\"")
	assert_true(b.show_view([[1, 1.9, false, false, 5], [0, 0.0, false, false, 5], [0, 0.0, false, false, 3]], art, true), "nút +TT hiện")
	assert_eq(b.skill_view[0][1], 2.0, "lưu số giây làm tròn lên (đúng số đang hiện)")
	b.free()


func test_D_263_item_buttons_redraw_on_change_only() -> void:
	var b: ItemButtons = ItemButtons.new()
	assert_true(b.show_view([[2, "GH", 4.5, -1, false, &""]], -1.0))
	assert_true(not b.show_view([[2, "GH", 4.2, -1, false, &""]], -1.0), "cùng hiện \"5\"")
	assert_true(b.show_view([[2, "GH", 4.2, -1, false, &""]], 0.25), "đang về thành: vòng tiến độ đổi")
	assert_true(not b.show_view([[2, "GH", 4.2, -1, false, &""]], 0.25))
	b.free()


func _hud() -> MatchHud:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	var h: MatchHud = MatchHud.new()
	h.world = w
	h.hero = UnitFactory.hero(w, lib.heroes[&"myra"], 0, Vector2(1000, 1000))
	h.show_fps = false
	return h


func test_D_263_top_bar_key_changes_with_shown_content() -> void:
	var h: MatchHud = _hud()
	var before: Array = h.text_key()
	assert_eq(h.text_key(), before, "không có gì đổi")
	h.world.tick += 10
	assert_eq(h.text_key(), before, "đồng hồ hiện theo giây: 10 tick chưa đổi")
	h.world.tick += 30
	assert_ne(h.text_key(), before, "qua giây mới")
	var t: Array = h.panel_key()
	h.hero.gold += 1
	assert_ne(h.panel_key(), t, "vàng đổi")
	t = h.bars_key()
	h.hero.health -= 0.2
	assert_eq(h.bars_key(), t, "máu hiện số nguyên: lệch 0,2 chưa đổi")
	h.hero.health -= 1.0
	assert_ne(h.bars_key(), t)
	h.free()


## D-290: máu / mana đổi ~8 lần / giây — chỉ lớp thanh máu vẽ lại, không kéo theo băng rôn tỷ số (nửa chi phí
## vẽ, ~1,7 ms mỗi lần trên máy tính bảng) hay bảng tướng; đồng hồ đổi không vẽ lại băng rôn.
func test_D_290_health_change_redraws_only_bars_layer() -> void:
	var h: MatchHud = _hud()
	var keys: Array = [h.banner_key(), h.text_key(), h.panel_key(), h.bars_key()]
	h.hero.health -= 5.0
	h.hero.mana -= 5.0
	assert_eq(h.banner_key(), keys[0])
	assert_eq(h.text_key(), keys[1])
	assert_eq(h.panel_key(), keys[2], "bảng tướng (chân dung, vàng, K/D/A) không vẽ lại khi máu đổi")
	assert_ne(h.bars_key(), keys[3])
	h.world.tick += 60
	assert_eq(h.banner_key(), keys[0], "đồng hồ đổi: băng rôn giữ nguyên")
	assert_ne(h.text_key(), keys[1])
	h.free()


func test_D_290_hud_layers_draw_in_tree() -> void:
	var h: MatchHud = _hud()
	(Engine.get_main_loop() as SceneTree).root.add_child(h)
	var names: Array[String] = []
	for c: Node in h.get_children():
		names.append(c.name)
	assert_eq(names, ["Banner", "Panel", "Bars", "TopText", "KillFeed"] as Array[String], "thứ tự vẽ: chữ đè lên băng rôn; D-339 thông báo hạ gục trên cùng")
	h.queue_free()


func test_D_261_hud_draw_time_counted_in_total_and_part() -> void:
	var p: FrameProfile = FrameProfile.new()
	p.next_frame(0)
	p.hud(&"hud_top", 0, 3000)
	p.hud(&"hud_skills", 0, 1000)
	p.add(&"draw2d", 0, 10_000)
	p.next_frame(FrameProfile.WINDOW_USEC)
	assert_near(p.avg_ms[&"hud"], 4.0, 0.0001, "tổng HUD")
	assert_near(p.avg_ms[&"hud_top"], 3.0, 0.0001)
	var got: Dictionary = {}
	for r: Array in ProfilePainter.rows(p):
		got[r[0]] = r[1]
	assert_near(got[ProfilePainter.LABELS[&"draw2d_other"]], 6.0, 0.0001, "cuối khung 10 − HUD 4 = xương / biến đổi")
