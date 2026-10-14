class_name ResultPanel
extends Control
## Màn kết quả (STR-05): thắng/thua, thời gian trận, vàng, last hit; nút Chơi lại / Về menu.
## Chỉ báo bằng tín hiệu, tầng APP quyết định làm gì.

signal replay_pressed
signal menu_pressed


static func title_for(winner: int, my_team: int) -> String:
	return "CHIẾN THẮNG" if winner == my_team else "THẤT BẠI"


func show_result(world: World, hero: Entity) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 24)
	add_child(box)
	var won: bool = world.winner == hero.team
	_label(box, title_for(world.winner, hero.team), 72, Color(1, 0.85, 0.3) if won else Color(1, 0.4, 0.4))
	_label(box, "Thời gian %s · Vàng %d · Last hit %d" % [MatchHud.clock_text(world.tick), hero.gold, hero.last_hits], 32, Color.WHITE)
	_button(box, "ReplayButton", "Chơi lại", replay_pressed)
	_button(box, "MenuButton", "Về menu", menu_pressed)


func _label(box: Container, text: String, font_size: int, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	box.add_child(label)


func _button(box: Container, node_name: String, text: String, pressed: Signal) -> void:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.add_theme_font_size_override("font_size", 36)
	button.pressed.connect(func() -> void: pressed.emit())
	box.add_child(button)
