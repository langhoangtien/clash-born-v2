extends Control
## Màn hình khởi động tạm của M0. Sẽ được thay bằng luồng màn hình thật ở M8.
## Tầng APP: được dùng VIEW và SIM, không ngược lại (ARCHITECTURE mục 1).

const VERSION_TEXT: String = "Clashborn v2 — M0"
const MAP_VIEWER: String = "res://app/map_viewer.tscn"
const MATCH_SCENE: String = "res://app/match_scene.tscn"
## Tướng chơi thử được (tạm, tới khi có màn chọn tướng M8).
const PLAYABLE: Array[StringName] = [&"brakk", &"myra", &"noctis", &"vexa"]


func _ready() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 32)
	add_child(box)
	var label: Label = Label.new()
	label.text = VERSION_TEXT
	label.add_theme_font_size_override("font_size", 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var button: Button = Button.new()
	button.name = "MapButton"
	button.text = "Xem map"
	button.add_theme_font_size_override("font_size", 36)
	button.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAP_VIEWER))
	box.add_child(button)
	var library: ContentLibrary = ContentLibrary.load_dir()
	box.add_child(_option_row("Bot", "BotHero", PLAYABLE.map(func(id: StringName) -> String: return library.heroes[id].display_name), 1))
	box.add_child(_option_row("Độ khó bot", "BotDifficulty", ["Dễ", "Thường", "Khó"], BotState.Difficulty.NORMAL))
	for id: StringName in PLAYABLE:
		var match_button: Button = Button.new()
		match_button.name = "Match_" + String(id)
		match_button.text = "Vào trận: " + library.heroes[id].display_name
		match_button.add_theme_font_size_override("font_size", 36)
		match_button.pressed.connect(_start.bind(id))
		box.add_child(match_button)
	print(VERSION_TEXT + " ready")


## Hàng chọn: nhãn + danh sách thả xuống (D-94: chọn hero và độ khó của bot).
func _option_row(title: String, node_name: String, labels: Array, selected: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 32)
	row.add_child(label)
	var pick: OptionButton = OptionButton.new()
	pick.name = node_name
	pick.add_theme_font_size_override("font_size", 32)
	for text: String in labels:
		pick.add_item(text)
	pick.select(selected)
	row.add_child(pick)
	return row


func _start(id: StringName) -> void:
	var scene: GDScript = preload("res://app/match_scene.gd")
	scene.hero_id = id
	scene.bot_hero_id = PLAYABLE[(find_child("BotHero", true, false) as OptionButton).selected]
	scene.bot_difficulty = (find_child("BotDifficulty", true, false) as OptionButton).selected
	get_tree().change_scene_to_file(MATCH_SCENE)
