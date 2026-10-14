extends Control
## Màn hình khởi động tạm của M0. Sẽ được thay bằng luồng màn hình thật ở M8.
## Tầng APP: được dùng VIEW và SIM, không ngược lại (ARCHITECTURE mục 1).

const VERSION_TEXT: String = "Clashborn v2 — M0"
const MAP_VIEWER: String = "res://app/map_viewer.tscn"
const MATCH_SCENE: String = "res://app/match_scene.tscn"
## Tướng chơi thử được (tạm, tới khi có màn chọn tướng M8).
const PLAYABLE: Array[StringName] = [&"brakk", &"myra"]


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
	for id: StringName in PLAYABLE:
		var match_button: Button = Button.new()
		match_button.name = "Match_" + String(id)
		match_button.text = "Vào trận: " + library.heroes[id].display_name
		match_button.add_theme_font_size_override("font_size", 36)
		match_button.pressed.connect(_start.bind(id))
		box.add_child(match_button)
	print(VERSION_TEXT + " ready")


func _start(id: StringName) -> void:
	preload("res://app/match_scene.gd").hero_id = id
	get_tree().change_scene_to_file(MATCH_SCENE)
