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
	assert_true(String(stats[3][1]).contains("giảm"), "giáp ghi % giảm sát thương")
	assert_true(String(stats[1][1]).contains("đòn/giây"), "D-124: tốc đánh kèm số đòn mỗi giây")
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
	assert_eq(rows[1][5], 2400, "giá trị đồ")
	assert_eq(rows[1][6][0], "BC", "ô đồ: tên tắt")
	assert_eq(rows[1][7][0], &"stun_hammer", "D-115: ô đồ có icon")
	assert_eq(rows[1][9], -1, "đang sống: không có số hồi sinh")
	p.free()


## D-339: bảng tỷ số hiện số giây hồi sinh của hero đang chết (mình và địch).
func test_D_339_score_rows_respawn_countdown() -> void:
	var p: InfoPanels = _setup()
	var foe: Entity = p.world.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.HERO and e != p.hero)[0]
	foe.alive = false
	foe.respawn_tick = p.world.tick + 12 * 30 + 1
	var rows: Array = InfoPanels.score_rows(p.world)
	var mine: Array = rows.filter(func(r: Array) -> bool: return r[0] == foe.team)
	assert_eq(mine[0][9], 13, "còn 12,03 s → hiện 13")
	p.free()


func test_D_124_damage_and_attributes_split_base_plus_items() -> void:
	var p: InfoPanels = _setup()
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var rows: Array = InfoPanels.stat_rows(p.hero)
	assert_eq(rows[0][2], "", "chưa có đồ: không có phần cộng thêm")
	Items.give(p.world, p.hero, lib.items[&"claymore"])
	Items.give(p.world, p.hero, lib.items[&"ogre_axe"])
	p.world.step()
	rows = InfoPanels.stat_rows(p.hero)
	assert_true(String(rows[0][2]).begins_with("+2"), "sát thương: gốc + phần từ đồ (Đại Kiếm 25 + Rìu Khổng Lồ)")
	var strength: Array = rows.filter(func(r: Array) -> bool: return String(r[0]).begins_with("Sức mạnh"))[0]
	assert_eq(strength[2], "+10", "Sức mạnh: gốc + 10 từ Rìu Khổng Lồ")
	assert_true(rows.any(func(r: Array) -> bool: return String(r[0]).begins_with("BAT")), "có dòng BAT")
	p.free()


## D-253 (người chơi: thua Quyết Đấu thấy "167 + -27" màu xanh, tưởng được cộng): phần trừ in "−27" (màu đỏ khi vẽ).
func test_D_253_negative_bonus_shows_minus() -> void:
	var p: InfoPanels = _setup()
	p.hero.stats.add_modifier(StatModifier.make(StatId.Id.PHYSICAL_DAMAGE, ModifierDef.Op.ADD, -27.0, 99))
	p.hero.stats.recompute()
	assert_eq(InfoPanels.stat_rows(p.hero)[0][2], "−27", "sát thương bị trừ: dấu trừ, không phải + -27")
	p.free()


## D-253: bảng thông số có 3 tab (Chỉ số / Kỹ năng / Talent); tab Kỹ năng có nút + nâng cấp chiêu, tab Talent chọn talent.
func test_D_253_tabs_level_up_and_talent_buttons() -> void:
	var p: InfoPanels = _setup()
	var leveled: Array[int] = []
	var picked: Array[int] = []
	p.level_pressed.connect(func(slot: int) -> void: leveled.append(slot))
	p.talent_pressed.connect(func(slot: int) -> void: picked.append(slot))
	p.press_at(MatchHud.PANEL.get_center())
	assert_eq(p.tab, InfoPanels.Tab.STATS, "mở: tab Chỉ số")
	p.press_at(p.tab_rect(InfoPanels.Tab.SKILLS).get_center())
	assert_eq(p.tab, InfoPanels.Tab.SKILLS)
	p.hero.skill_points = 1
	p.press_at(p.level_rect(AbilityDef.Slot.W).get_center())
	assert_eq(leveled, [AbilityDef.Slot.W], "nút + của W")
	p.hero.skill_points = 0
	p.press_at(p.level_rect(AbilityDef.Slot.W).get_center())
	assert_eq(leveled.size(), 1, "hết điểm: nút + không có")
	p.press_at(p.tab_rect(InfoPanels.Tab.TALENT).get_center())
	p.press_at(p.talent_rect(AbilityDef.Slot.Q).get_center())
	assert_eq(picked, [], "chưa cấp 20: chưa chọn được")
	Progression.cheat(p.world, p.hero, Command.cheat_level(p.hero.id, 20))
	p.press_at(p.talent_rect(AbilityDef.Slot.Q).get_center())
	assert_eq(picked, [AbilityDef.Slot.Q], "cấp 20: chọn talent Q")
	assert_eq(p.open, InfoPanels.Open.STATS, "bấm trong bảng không đóng bảng")
	p.free()


## D-253: số gần nguyên làm tròn (0,7 × 100 = 69,999… → "70", không cắt thành "69").
func test_D_253_num_rounds_float_noise() -> void:
	assert_eq(InfoPanels.num(0.7 * 100.0), "70")
	assert_eq(InfoPanels.num(0.35 * 100.0), "35")
	assert_eq(InfoPanels.num(1.25), "1.25")
