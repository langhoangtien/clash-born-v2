extends Control
## Màn chọn tướng (D-123). Tầng APP: dựng HeroSelect, mở trận / xem map khi người chơi bấm.
## Tầng APP: được dùng VIEW và SIM, không ngược lại (ARCHITECTURE mục 1).

const VERSION_TEXT: String = "Clashborn v2"
const MAP_VIEWER: String = "res://app/map_viewer.tscn"
const MATCH_SCENE: String = "res://app/match_scene.tscn"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
## Tướng chơi được, theo thứ tự hiện trên màn chọn.
const PLAYABLE: Array[StringName] = [&"brakk", &"myra", &"noctis", &"vexa", &"gorran", &"duy_anh"]


func _ready() -> void:
	var library: ContentLibrary = ContentLibrary.load_dir()
	var heroes: Array[HeroDef] = []
	for id: StringName in PLAYABLE:
		heroes.append(library.heroes[id])
	var select: HeroSelect = HeroSelect.new()
	select.name = "HeroSelect"
	add_child(select)
	select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	select.setup(heroes, load(BALANCE_PATH) as BalanceSettings)
	select.start_pressed.connect(_start)
	select.map_pressed.connect(func() -> void: get_tree().change_scene_to_file(MAP_VIEWER))
	_setup_account(select)
	var audio: AudioView = AudioView.new()  # D-114: nhạc menu (Safari phát sau lần chạm đầu tiên)
	audio.name = "Audio"
	add_child(audio)
	audio.play_music(&"music_menu")
	var settings: SettingsControl = SettingsControl.attach(self, false, audio)  # D-183
	settings.start_bench = func() -> void:  # D-272: Benchmark A/B — cảnh cố định, hai tướng do bot
		BenchSession.requested = true
		var bench: MatchConfig = MatchConfig.duel(BenchSession.HERO, BenchSession.FOE)  # seed cố định: so sánh được
		bench.practice = true  # MATCH-06: đo hiệu năng — không tính thống kê
		_open(bench)
	select.settings_pressed.connect(func() -> void:
		settings.panel.open = true
		settings.panel.queue_redraw())
	var updater: Updater = Updater.new()  # D-148: tự kiểm tra bản mới (Android)
	updater.name = "Updater"
	add_child(updater)
	updater.attach(select)
	print(VERSION_TEXT + " ready")


## MATCH (D-328): 1v1 — đối thủ bot người chơi chọn; 3v3 — đồng đội và đối thủ là bot, tướng ngẫu nhiên không trùng
## (MATCH-02). Seed ngẫu nhiên mỗi trận (MATCH-05). MATCH-06: trận thử khi bấm "Trận thử" hoặc đang bật ghi log hiệu năng.
## D-333: tài khoản — AccountClient (mạng, lưu phiên) + AccountPanel (form) nối qua tín hiệu.
func _setup_account(select: HeroSelect) -> void:
	var client: AccountClient = AccountClient.new()
	client.name = "Account"
	add_child(client)
	var panel: AccountPanel = AccountPanel.new()
	panel.name = "AccountPanel"
	panel.visible = false
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var show_account: Callable = func() -> void:
		select.account_name = String(AccountClient.account.get("name", "")) if AccountClient.signed_in() else ""
		if AccountClient.signed_in() and select.account_name == "":
			select.account_name = "Đặt tên"
		select.queue_redraw()
		panel.set_account(AccountClient.account)
	client.changed.connect(show_account)
	client.replied.connect(func(action: String, ok: bool, code: String, message: String, data: Dictionary) -> void:
		panel.on_reply(action, ok, code, message, data))
	panel.request.connect(func(action: String, body: Dictionary) -> void:
		if action == "google/cancel":
			client.cancel_google()
		elif action == "open_web":  # D-334: trang người chơi trên clashborn.quest/stats/
			OS.shell_open(Updater.SITES[0] + "stats/player.html?name=" + String(AccountClient.account.get("name", "")).uri_encode())
		elif action == "google/start":
			client.google()
		else:
			client.send(action, body))
	panel.closed.connect(func() -> void: panel.visible = false)
	select.account_pressed.connect(func() -> void: panel.visible = true)
	show_account.call()


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
	get_tree().change_scene_to_file(MATCH_SCENE)
