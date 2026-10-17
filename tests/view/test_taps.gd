extends TestCase
## D-102: click PC (chuột + chạm giả) chỉ bật / tắt bảng một lần.


func _both(c: Control, at: Vector2) -> void:
	var m: InputEventMouseButton = InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = true
	m.position = at
	c._gui_input(m)
	var t: InputEventScreenTouch = InputEventScreenTouch.new()
	t.pressed = true
	t.position = at
	c._gui_input(t)


func test_D_102_shop_and_info_toggle_once_per_click() -> void:
	assert_true(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false), "dự án giả chạm từ chuột")
	var s: ShopPanel = ShopPanel.new()
	s.size = Vector2(1920, 1080)
	_both(s, ShopPanel.BUTTON.get_center())
	assert_true(s.open, "một click mở shop")
	s.free()
	var p: InfoPanels = InfoPanels.new()
	p.size = Vector2(1920, 1080)
	_both(p, p.score_rect().get_center())
	assert_eq(p.open, InfoPanels.Open.SCORE, "một click mở bảng tỷ số")
	p.free()
