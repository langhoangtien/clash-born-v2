extends Control
## Màn hình khởi động tạm của M0. Sẽ được thay bằng luồng màn hình thật ở M8.
## Tầng APP: được dùng VIEW và SIM, không ngược lại (ARCHITECTURE mục 1).

const VERSION_TEXT: String = "Clashborn v2 — M0"


func _ready() -> void:
	var label: Label = Label.new()
	label.text = VERSION_TEXT
	label.add_theme_font_size_override("font_size", 48)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(label)
	print(VERSION_TEXT + " ready")
