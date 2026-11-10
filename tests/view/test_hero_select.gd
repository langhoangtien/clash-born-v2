extends TestCase
## D-123: màn chọn tướng — chọn tướng / bot / độ khó, thẻ chi tiết, BẮT ĐẦU.


func _select() -> HeroSelect:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var s: HeroSelect = HeroSelect.new()
	s.size = Vector2(1920, 1080)
	var heroes: Array[HeroDef] = [lib.heroes[&"brakk"], lib.heroes[&"myra"], lib.heroes[&"gorran"]]
	s.setup(heroes, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	return s


func test_D_123_pick_hero_bot_difficulty_then_start() -> void:
	var s: HeroSelect = _select()
	var got: Array = []
	s.start_pressed.connect(func(h: StringName, b: StringName, d: int, n: int) -> void: got.append([h, b, d, n]))
	s.press_at(s.card_rect(2).get_center())
	s.press_at(s.bot_rect(0).get_center())
	s.press_at(s.diff_rect(2).get_center())
	s.press_at(s.tab_rect(1).get_center())
	assert_eq(s.tab, HeroDetail.Tab.STATS)
	s.press_at(HeroSelect.START.get_center())
	assert_eq(got, [[&"gorran", &"brakk", 2, 1]], "mặc định 1 vs 1")
	s.free()


## MATCH (D-328): nút 3 vs 3 → báo số người mỗi đội 3; MATCH-02: bot 1v1 không bao giờ trùng tướng người chơi.
func test_MATCH_02_mode_3v3_and_bot_never_same_hero() -> void:
	var s: HeroSelect = _select()
	var got: Array = []
	s.start_pressed.connect(func(h: StringName, b: StringName, _d: int, n: int) -> void: got.append([h, b, n]))
	s.press_at(s.bot_rect(2).get_center())
	s.press_at(s.card_rect(2).get_center())
	assert_ne(s.bot, s.selected, "chọn đúng tướng của bot → bot đổi sang tướng khác")
	s.press_at(s.mode_rect(1).get_center())
	s.press_at(HeroSelect.START.get_center())
	assert_eq(got[0][2], 3, "3 vs 3")
	assert_ne(got[0][0], got[0][1])
	s.free()


func test_D_123_preview_stats_skills_talents() -> void:
	var s: HeroSelect = _select()
	var p: HeroPreview = s.previews[2]
	assert_eq(p.lv20.stats.level(), 20)
	var table: Array = p.stat_table()
	assert_true(table.any(func(r: Array) -> bool: return String(r[0]).begins_with("BAT") and r[1] == "1.70 s"), "có dòng BAT")
	assert_true(table.size() >= 11)
	assert_true(table.all(func(r: Array) -> bool: return r[3] is Color), "mỗi dòng có màu riêng")
	assert_eq(p.skill_rows().size(), 4, "nội tại + Q W R")
	assert_true(not (p.skill_rows()[1][0] as AbilityDef).description.is_empty(), "chiêu có mô tả")
	assert_eq(p.talents().size(), 3)
	assert_true(p.growth_text().contains("3.51"), "chỉ số mỗi cấp")
	s.free()
