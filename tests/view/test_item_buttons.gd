extends TestCase
## D-87: nút đồ chủ động ở chỗ phép bổ trợ (bên trái ô Q), tối đa 3 nút, đồ bị động không có nút.


func test_D_87_active_item_buttons_left_of_q() -> void:
	var b: ItemButtons = ItemButtons.new()
	b.size = Vector2(1920, 1080)
	var got: Array[int] = []
	b.item_tapped.connect(func(i: int) -> void: got.append(i))
	b.item_view = [[2, "GH", 0.0, -1, true], [4, "BL", 5.0, 1, false]]
	var q: Vector2 = b.size - ItemButtons.MAIN_OFFSET + Vector2.from_angle(deg_to_rad(ItemButtons.Q_ANGLE)) * ItemButtons.Q_DISTANCE
	assert_true(b.button_center(0).x < q.x and b.button_center(1).x < b.button_center(0).x, "xếp sang trái ô Q")
	for k: int in range(2):
		var ev: InputEventScreenTouch = InputEventScreenTouch.new()
		ev.pressed = true
		ev.position = b.button_center(k)
		b._gui_input(ev)
	assert_eq(got, [2], "nút báo chỉ số ô đồ; nút đang hồi không báo")
	assert_eq(b.slot_for_button(1), 4)
	assert_eq(b.slot_for_button(2), -1)
	assert_near(b.left_edge(), b.button_center(1).x - ItemButtons.RADIUS, 0.01)
	var zone: Rect2 = b.zone_rect()
	assert_true(zone.end.x < q.x - 62.0, "chỗ nút đồ không đè ô Q")
	assert_true(ItemButtons.RADIUS < 62.0, "nút đồ nhỏ hơn nút chiêu")
	b.item_view = []
	assert_eq(b.left_edge(), INF)
	assert_eq(ItemButtons.short_name("Gậy Hồn Ma"), "GH")
	b.free()
