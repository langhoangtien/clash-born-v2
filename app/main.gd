extends Control
## Menu (D-413, thay màn chọn tướng gộp của D-123). Tầng APP: dựng MenuShell + các trang, nối tài khoản / online / cài đặt,
## mở trận khi người chơi bấm. Tầng APP: được dùng VIEW và SIM, không ngược lại (ARCHITECTURE mục 1).

const VERSION_TEXT: String = "Clashborn v2"
const MAP_VIEWER: String = "res://app/map_viewer.tscn"
const MATCH_SCENE: String = "res://app/match_scene.tscn"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
## Tướng chơi được, theo thứ tự hiện trên menu.
const PLAYABLE: Array[StringName] = [&"brakk", &"myra", &"noctis", &"vexa", &"gorran", &"duy_anh", &"huyet_cu_nhan",
	&"phong_tien", &"tho_san", &"thach_giap"]  # D-347: đợt 1 tướng mới

var shell: MenuShell
var home: HomePage
var play: PlayPage
var heroes: HeroesPage
var items: ItemsPage
var settings: SettingsPage
var account: MenuAccount
var audio: AudioView
## Mở màn `path` (test thay để ghi lại thay vì đổi màn thật).
var change_scene: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)


func _ready() -> void:
	var library: ContentLibrary = ContentLibrary.load_dir()
	var previews: Array[HeroPreview] = []
	for id: StringName in PLAYABLE:
		previews.append(HeroPreview.of(library.heroes[id], load(BALANCE_PATH) as BalanceSettings))
	shell = MenuShell.new()
	shell.name = "MenuShell"
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_pages(previews, library)
	audio = AudioView.new()  # D-114: nhạc menu (Safari phát sau lần chạm đầu tiên)
	audio.name = "Audio"
	add_child(audio)
	audio.play_music(&"music_menu")
	account = MenuAccount.attach(self, shell, home)  # D-333 / D-413
	settings.account_pressed.connect(account.open)
	account.client.changed.connect(func() -> void:
		settings.account_name = shell.account_name
		settings.queue_redraw())
	_setup_online()
	var updater: Updater = Updater.new()  # D-148: tự kiểm tra bản mới (Android)
	updater.name = "Updater"
	add_child(updater)
	updater.attach(shell)
	home.update_pressed.connect(func() -> void:  # thẻ Bản cập nhật: có bản mới thì tải như nút Cập nhật (D-148)
		if updater.button.visible:
			updater.button.pressed.emit())
	updater.checked.connect(func(latest: Dictionary) -> void:
		home.notes_text = "Mới nhất %s: %s" % [latest.get("name", ""), latest.get("notes", "")]
		home.queue_redraw())
	shell.open(&"home")
	print(VERSION_TEXT + " ready")


func _setup_pages(previews: Array[HeroPreview], library: ContentLibrary) -> void:
	home = HomePage.new()
	home.version_text = "Phiên bản " + (Updater.current_name() if Updater.current_name() != "" else "chạy từ editor")
	home.notes_text = "Chạm để xem cập nhật" if Updater.enabled() else ""
	shell.add_page(&"home", home)
	home.play_pressed.connect(func() -> void: shell.open(&"play"))
	play = PlayPage.new()
	play.setup(previews)
	shell.add_page(&"play", play)
	play.back_pressed.connect(shell.back)
	play.start_pressed.connect(_start)
	play.map_pressed.connect(func() -> void: change_scene.call(MAP_VIEWER))
	heroes = HeroesPage.new()
	heroes.setup(previews)
	shell.add_page(&"heroes", heroes)
	heroes.try_pressed.connect(func(id: StringName) -> void:  # Thử tướng: trận thử 1v1 với bot (MATCH-06)
		_start(id, PLAYABLE[1] if id == PLAYABLE[0] else PLAYABLE[0], BotState.Difficulty.NORMAL, 1, true))
	items = ItemsPage.new()
	items.setup(library)
	shell.add_page(&"items", items)
	settings = SettingsPage.new()
	settings.version_text = Updater.current_name()  # D-267
	shell.add_page(&"settings", settings)
	settings.sync_pressed.connect(func() -> void: SyncSession.open(self))  # D-336: M9.3 tất định điện thoại ↔ máy chủ
	settings.bench_pressed.connect(func() -> void:  # D-272: Benchmark A/B — cảnh cố định, hai tướng do bot
		BenchSession.requested = true
		var bench: MatchConfig = MatchConfig.duel(BenchSession.HERO, BenchSession.FOE)  # seed cố định: so sánh được
		bench.practice = true  # MATCH-06: đo hiệu năng — không tính thống kê
		_open(bench))


## M9.6 (D-344): Chơi online — bảng phòng (OnlinePanel) + phiên mạng (OnlineMenu); máy chủ chào vào trận → màn trận online.
func _setup_online() -> void:
	var panel: OnlinePanel = OnlinePanel.new()
	panel.name = "OnlinePanel"
	panel.visible = false
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu: OnlineMenu = OnlineMenu.new()
	menu.name = "Online"
	add_child(menu)
	menu.attach(panel)
	play.online_pressed.connect(func(size: int) -> void:  # D-356: Phòng bạn bè (5v5) / Đấu bạn (1v1)
		panel.preferred_size = size
		menu.open())
	menu.match_ready.connect(func(s: OnlineSession) -> void:
		var scene: GDScript = preload("res://app/match_scene.gd")
		scene.online = s
		change_scene.call(MATCH_SCENE))


## MATCH (D-328): 1v1 — đối thủ bot người chơi chọn; 3v3 — đồng đội và đối thủ là bot, tướng ngẫu nhiên không trùng
## (MATCH-02). Seed ngẫu nhiên mỗi trận (MATCH-05). MATCH-06: trận thử khi chọn "Trận thử" hoặc đang bật ghi log hiệu năng.
func _start(id: StringName, bot_id: StringName, difficulty: int, team_size: int, practice: bool) -> void:
	var seed_value: int = randi()
	var cfg: MatchConfig
	if team_size <= 1:
		cfg = MatchConfig.duel(id, bot_id, difficulty as BotState.Difficulty, seed_value)
	else:
		cfg = MatchConfig.make(team_size, _team_picks(id, team_size), [0], difficulty as BotState.Difficulty, seed_value)
	cfg.practice = practice or PerfSettings.enabled()
	_open(cfg)


## Người chơi cầm `id`; các ô còn lại tướng ngẫu nhiên không trùng (MATCH-02).
func _team_picks(id: StringName, team_size: int) -> Array[StringName]:
	var others: Array[StringName] = PLAYABLE.filter(func(h: StringName) -> bool: return h != id)
	others.shuffle()
	var heroes: Array[StringName] = [id]
	heroes.append_array(others.slice(0, 2 * team_size - 1))
	return heroes


func _open(config: MatchConfig) -> void:
	var problem: String = config.validate(ContentLibrary.load_dir())
	if problem != "":
		push_error("MATCH: cấu hình trận không hợp lệ: " + problem)
		return
	var scene: GDScript = preload("res://app/match_scene.gd")
	scene.config = config
	change_scene.call(MATCH_SCENE)
