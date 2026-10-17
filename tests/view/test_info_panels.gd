extends TestCase
## D-100: bảng thông số hero và bảng tỷ số.


func _setup() -> InfoPanels:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	var me: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 0, Vector2(1000, 1000), 3)
	var foe: Entity = UnitFactory.hero(w, lib.heroes[&"brakk"], 1, Vector2(3000, 1000))
	Abilities.set_rank(w, me, Abilities.of(me, AbilityDef.Slot.Q), 3)
	Items.give(w, foe, lib.items[&"stun_hammer"])
	foe.kills = 2
	var p: InfoPanels = InfoPanels.new()
	p.size = Vector2(1920, 1080)
	p.world = w
	p.hero = me
	return p


func test_D_100_open_close_by_tapping_hp_box_and_score() -> void:
	var p: InfoPanels = _setup()
	p.press_at(MatchHud.PANEL.get_center())
	assert_eq(p.open, InfoPanels.Open.STATS, "chạm ô máu/mana: bảng thông số")
	p.press_at(p.close_rect().get_center())
	assert_eq(p.open, InfoPanels.Open.NONE)
	p.press_at(p.score_rect().get_center())
	assert_eq(p.open, InfoPanels.Open.SCORE, "chạm tỷ số: bảng tỷ số")
	p.press_at(Vector2(5, 1075))
	assert_eq(p.open, InfoPanels.Open.NONE, "chạm ra ngoài: đóng")
	p.free()


func test_D_100_stat_and_skill_rows() -> void:
	var p: InfoPanels = _setup()
	var stats: Array = InfoPanels.stat_rows(p.hero)
	assert_eq(stats[0][0], "Sát thương")
	assert_true(String(stats[1][1]).contains("giảm"), "giáp ghi % giảm sát thương")
	var skills: Array = InfoPanels.ability_rows(p.hero)
	assert_eq(skills.size(), 4, "nội tại + Q W R")
	var q: Array = skills[1]
	assert_true(String(q[0]).contains("cấp 3/5"))
	var dmg: String = ""
	for line: String in q[1]:
		if line.begins_with("Sát thương:"):
			dmg = line
	assert_eq(dmg, "Sát thương: 90 / 140 / [190] / 240 / 290", "cấp đang có đánh dấu")
	p.free()


func test_D_100_score_rows_items_and_kda() -> void:
	var p: InfoPanels = _setup()
	var rows: Array = InfoPanels.score_rows(p.world)
	assert_eq(rows.size(), 2)
	assert_eq(rows[1][3], "2/0/0")
	assert_eq(rows[1][5], 2600, "giá trị đồ")
	assert_eq(rows[1][6][0], "BC", "ô đồ: tên tắt")
	p.free()
