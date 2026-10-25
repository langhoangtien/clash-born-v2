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
	var audio: AudioView = AudioView.new()  # D-114: nhạc menu (Safari phát sau lần chạm đầu tiên)
	audio.name = "Audio"
	add_child(audio)
	audio.play_music(&"music_menu")
	var updater: Updater = Updater.new()  # D-148: tự kiểm tra bản mới (Android)
	updater.name = "Updater"
	add_child(updater)
	updater.attach(select)
	print(VERSION_TEXT + " ready")


func _start(id: StringName, bot_id: StringName, difficulty: int) -> void:
	var scene: GDScript = preload("res://app/match_scene.gd")
	scene.hero_id = id
	scene.bot_hero_id = bot_id
	scene.bot_difficulty = difficulty
	get_tree().change_scene_to_file(MATCH_SCENE)
