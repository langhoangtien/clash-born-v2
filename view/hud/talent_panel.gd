class_name TalentPanel
extends Control
## Chọn talent cấp 20 (TAL-01, M3.8): ba nút theo Q/W/R, mỗi nút tên + mô tả talent. Chỉ báo
## bằng tín hiệu; APP gửi lệnh CHOOSE_TALENT.

signal chosen(slot: int)


## `options`: mảng [ô, tên, mô tả].
func show_options(options: Array) -> void:
	for child: Node in get_children():
		child.queue_free()
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	var title: Label = Label.new()
	title.text = "Chọn talent cấp 20"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	for o: Array in options:
		var b: Button = Button.new()
		b.name = "Talent%d" % o[0]
		b.text = "%s\n%s" % [o[1], o[2]]
		b.custom_minimum_size = Vector2(300, 90)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 18)
		var slot: int = o[0]
		b.pressed.connect(func() -> void: chosen.emit(slot))
		box.add_child(b)
	visible = true
