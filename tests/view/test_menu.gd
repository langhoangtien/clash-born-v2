extends TestCase
## D-413: menu mới — khung điều hướng (Trang chủ · Tướng · Trang bị · Cài đặt), nút CHƠI → Chọn chế độ → BẮT ĐẦU cho
## từng chế độ (đấu bot 1v1 / 3v3, trận thử 1v1 / 3v3, Online mở bảng phòng), Quay lại; Trang chủ: Bản cập nhật, Trận
## gần đây. Dùng màn menu thật (app/main.tscn), việc đổi màn được ghi lại thay vì đổi thật.

const MAIN: String = "res://app/main.tscn"


func _main() -> Node:
	var m: Node = (load(MAIN) as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	m.size = Vector2(1920, 1080)
	var opened: Array[String] = []
	m.set_meta("opened", opened)
	m.change_scene = func(path: String) -> void: opened.append(path)
	return m


func _config() -> MatchConfig:
	return (load("res://app/match_scene.gd") as GDScript).get("config")


func test_D_413_top_bar_switches_pages() -> void:
	var m: Node = _main()
	var shell: MenuShell = m.shell
	assert_eq(shell.current, &"home", "mở menu → Trang chủ")
	for key: StringName in shell.pages:
		shell.open(key)
		for other: StringName in shell.pages:
			assert_eq(shell.pages[other].visible, other == key, "%s mở → chỉ trang %s hiện" % [key, key])
	for i: int in MenuShell.TABS.size():
		shell.press_at(shell.tab_rect(i).get_center())
		assert_eq(shell.current, MenuShell.TABS[i])
	shell.press_at(shell.gear_rect().get_center())
	assert_eq(shell.current, &"settings", "⚙ → Cài đặt")
	m.free()


func test_D_413_play_button_back_and_account() -> void:
	var m: Node = _main()
	var shell: MenuShell = m.shell
	var home: HomePage = m.home
	home.press_at(home.play_rect().get_center())
	assert_eq(shell.current, &"play", "CHƠI → Chọn chế độ")
	var play: PlayPage = m.play
	play.press_at(play.back_rect().get_center())
	assert_eq(shell.current, &"home", "Quay lại → Trang chủ")
	shell.press_at(shell.account_rect().get_center())
	assert_true((m.get_node("AccountPanel") as Control).visible, "nút tài khoản → bảng Tài khoản")
	m.free()


## Mỗi chế độ: chọn tướng, đối thủ (1v1), độ khó → BẮT ĐẦU → mở màn trận với đúng cấu hình (MATCH-01..06).
func test_D_413_play_flow_starts_match_for_each_mode() -> void:
	var scene: GDScript = load("res://app/match_scene.gd")
	var keep: MatchConfig = scene.get("config")  # biến tĩnh của màn trận — trả lại sau test (test khác dựng màn trận)
	var m: Node = _main()
	var play: PlayPage = m.play
	var cases: Array = [[PlayPage.Mode.BOT_1V1, 1, false, 0], [PlayPage.Mode.BOT_3V3, 3, false, 0],
		[PlayPage.Mode.PRACTICE, 1, true, 0], [PlayPage.Mode.PRACTICE, 3, true, 1]]
	for c: Array in cases:
		m.shell.open(&"play")
		play.press_at(play.mode_rect(c[0]).get_center())
		if c[0] == PlayPage.Mode.PRACTICE:
			play.press_at(play.size_rect(c[3]).get_center())
		play.press_at(play.hero_rect(4).get_center())
		if play.picks_bot():
			play.press_at(play.bot_rect(1).get_center())
		play.press_at(play.diff_rect(2).get_center())
		play.press_at(play.start_rect().get_center())
		var cfg: MatchConfig = _config()
		assert_eq((m.get_meta("opened") as Array).back(), m.MATCH_SCENE, "BẮT ĐẦU → màn trận")
		assert_eq(cfg.team_size, c[1], "chế độ %d: số người mỗi đội" % c[0])
		var human: Array = cfg.slots.filter(func(x: MatchSlot) -> bool: return not x.is_bot)
		var bots: Array = cfg.slots.filter(func(x: MatchSlot) -> bool: return x.is_bot)
		assert_eq(human.size(), 1, "một người chơi")
		assert_eq(human[0].hero_id, m.PLAYABLE[4], "tướng người chơi")
		assert_eq(cfg.practice, c[2] or PerfSettings.enabled(), "trận thử (MATCH-06)")
		if c[1] == 1:
			assert_eq(bots[0].hero_id, m.PLAYABLE[1], "đối thủ bot đã chọn")
		assert_true(bots.all(func(x: MatchSlot) -> bool: return x.difficulty == BotState.Difficulty.HARD), "độ khó Khó")
	m.free()
	scene.set("config", keep)


func test_D_413_online_and_map_from_play() -> void:
	var m: Node = _main()
	var play: PlayPage = m.play
	m.shell.open(&"play")
	play.press_at(play.mode_rect(PlayPage.Mode.ONLINE).get_center())
	assert_true((m.get_node("OnlinePanel") as Control).visible, "Online → bảng phòng Online")
	assert_ne(play.mode, PlayPage.Mode.ONLINE, "Online không phải chế độ đấu bot")
	play.press_at(play.map_rect().get_center())
	assert_eq((m.get_meta("opened") as Array).back(), m.MAP_VIEWER, "Xem map")
	m.free()


## MATCH-02: bot 1v1 không bao giờ trùng tướng người chơi; 3v3 không chọn đối thủ.
func test_MATCH_02_bot_never_same_hero_and_hidden_in_3v3() -> void:
	var m: Node = _main()
	var play: PlayPage = m.play
	play.press_at(play.bot_rect(2).get_center())
	play.press_at(play.hero_rect(2).get_center())
	assert_ne(play.bot, play.selected, "chọn đúng tướng của bot → bot đổi sang tướng khác")
	play.press_at(play.mode_rect(PlayPage.Mode.BOT_3V3).get_center())
	assert_false(play.picks_bot(), "3v3: đồng đội và đối thủ ngẫu nhiên")
	m.free()


func test_D_413_home_cards() -> void:
	var lines: Array[String] = MenuAccount.recent_lines([{"won": true, "hero": "myra", "kills": 3, "deaths": 1, "assists": 2,
		"mode": "1v1", "duration_s": 754}])
	assert_true(lines[0].begins_with("Thắng") and lines[0].contains("12:34"), "trận mới nhất: kết quả + thời gian")
	assert_eq(MenuAccount.recent_lines([]), [] as Array[String], "chưa có trận → ẩn thẻ")
	var home: HomePage = HomePage.new()
	home.size = Vector2(1920, 984)
	assert_eq(home.recent_rect(), Rect2(), "không có trận gần đây → không có thẻ")
	home.recent = ["Thắng", ""]
	assert_true(home.recent_rect().has_area())
	home.free()


func test_D_123_preview_stats_skills_talents() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var p: HeroPreview = HeroPreview.of(lib.heroes[&"gorran"], load("res://content/balance/balance_settings.tres") as BalanceSettings)
	assert_eq(p.lv20.stats.level(), 20)
	var table: Array = p.stat_table()
	assert_true(table.any(func(r: Array) -> bool: return String(r[0]).begins_with("BAT") and r[1] == "1.70 s"), "có dòng BAT")
	assert_true(table.size() >= 11)
	assert_true(table.all(func(r: Array) -> bool: return r[3] is Color), "mỗi dòng có màu riêng")
	assert_eq(p.skill_rows().size(), 4, "nội tại + Q W R")
	assert_eq(p.talents().size(), 3)
	assert_true(p.growth_text().contains("3.51"), "chỉ số mỗi cấp")


## Trang Tướng: lọc theo thuộc tính, thẻ Chiêu / Chỉ số / Talent, Thử tướng → trận thử 1v1 với tướng đó.
func test_D_413_heroes_page_filter_tabs_and_try() -> void:
	var scene: GDScript = load("res://app/match_scene.gd")
	var keep: MatchConfig = scene.get("config")
	var m: Node = _main()
	m.shell.open(&"heroes")
	var page: HeroesPage = m.heroes
	page.press_at(page.filter_rect(3).get_center())
	assert_true(page.shown().all(func(i: int) -> bool: return page.previews[i].def.primary_attribute == 3), "lọc Trí tuệ")
	assert_true(page.shown().has(page.selected), "tướng đang chọn nằm trong danh sách lọc")
	page.press_at(page.filter_rect(0).get_center())
	assert_eq(page.shown().size(), page.previews.size(), "Tất cả")
	page.press_at(page.cell_rect(4).get_center())
	assert_eq(page.model_view.hero_id, page.previews[4].def.id, "khung 3D theo tướng đang chọn")
	page.press_at(page.tab_rect(2).get_center())
	assert_eq(page.tab, HeroDetail.Tab.TALENTS)
	page.press_at(page.try_rect().get_center())
	var cfg: MatchConfig = scene.get("config")
	assert_eq((m.get_meta("opened") as Array).back(), m.MATCH_SCENE)
	assert_true(cfg.practice, "Thử tướng = trận thử")
	assert_eq(cfg.slots.filter(func(x: MatchSlot) -> bool: return not x.is_bot)[0].hero_id, page.previews[4].def.id)
	m.shell.open(&"home")
	assert_eq(page.model_view.stage.actor, null, "rời trang Tướng → gỡ mô hình")
	m.free()
	scene.set("config", keep)


## Trang Trang bị: danh mục đúng như cửa hàng, ô tìm, chọn món → chi tiết; cuộn lưới.
func test_D_413_items_page_categories_search_select() -> void:
	var m: Node = _main()
	m.shell.open(&"items")
	var page: ItemsPage = m.items
	var lib: ContentLibrary = ContentLibrary.load_dir()
	assert_eq(page.shown().size(), lib.items.size(), "Tất cả = mọi món trong content/items")
	page.press_at(page.tab_rect(ShopPanel.Tab.ATTACK).get_center())
	assert_true(page.shown().all(func(d: ItemDef) -> bool: return d.category == ItemDef.Category.ATTACK), "Tấn công")
	page.press_at(page.tab_rect(ShopPanel.Tab.SECRET).get_center())
	assert_true(page.shown().all(func(d: ItemDef) -> bool: return d.shop == ItemDef.ShopKind.SECRET), "Shop ẩn")
	page.press_at(page.tab_rect(ShopPanel.Tab.ALL).get_center())
	var some: ItemDef = lib.items.values().filter(func(d: ItemDef) -> bool: return not d.components.is_empty())[0]
	page.search.text = some.display_name.substr(0, 6)
	page.search.text_changed.emit(page.search.text)
	assert_true(page.shown().has(some), "tìm theo tên")
	assert_true(page.shown().size() < lib.items.size())
	page.press_at(page.cell_rect(page.shown().find(some)).get_center())
	assert_eq(page.selected, some, "chạm ô → chi tiết món")
	page.search.text_changed.emit("")
	page.scroll_by(100000.0)
	assert_eq(page.scroll, page.max_scroll(), "cuộn tới cuối lưới")
	assert_true(page.max_scroll() > 0.0, "95 món: lưới phải cuộn")
	m.free()
