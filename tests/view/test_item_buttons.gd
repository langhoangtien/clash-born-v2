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
		b.press_at(0, b.button_center(k))
		b.release_at(0, b.button_center(k))
	assert_eq(got, [2], "nút báo chỉ số ô đồ; nút đang hồi không báo")
	assert_eq(b.slot_for_button(1), 4)
	assert_eq(b.slot_for_button(2), -1)
	var zone3: Rect2 = b.zone_rect()
	b.item_view = [[0, "A", 0.0, -1, true], [1, "B", 0.0, -1, true], [2, "C", 0.0, -1, true], [3, "D", 0.0, -1, true], [4, "E", 0.0, -1, true], [5, "F", 0.0, -1, true]]
	assert_eq(b.slot_for_button(5), 5, "D-89: tối đa 6 nút")
	assert_true(b.button_center(5).x - ItemButtons.RADIUS > 0.0)
	assert_true(b.zone_rect().position.x < zone3.position.x, "nhiều nút thì hàng buff lùi theo")
	b.item_view = [[2, "GH", 0.0, -1, true], [4, "BL", 5.0, 1, false]]
	assert_near(b.left_edge(), b.button_center(1).x - ItemButtons.RADIUS, 0.01)
	var zone: Rect2 = b.zone_rect()
	assert_true(zone.end.x < q.x - 62.0, "chỗ nút đồ không đè ô Q")
	assert_true(ItemButtons.RADIUS < 62.0, "nút đồ nhỏ hơn nút chiêu")
	b.item_view = []
	assert_eq(b.left_edge(), INF)
	assert_eq(ItemButtons.short_name("Gậy Hồn Ma"), "GH")
	b.free()


func test_D_92_drag_item_button_to_aim() -> void:
	var b: ItemButtons = ItemButtons.new()
	b.size = Vector2(1920, 1080)
	b.item_view = [[3, "MV", 0.0, 2, true]]
	var aimed: Array = []
	var shown: Array = []
	b.item_aimed.connect(func(i: int, aim: Vector2) -> void: aimed.append([i, aim]))
	b.aim_changed.connect(func(i: int, _aim: Vector2, active: bool) -> void: shown.append([i, active]))
	var c: Vector2 = b.button_center(0)
	b.press_at(0, c)
	b.drag_to(0, c + Vector2(0, -ItemButtons.AIM_RADIUS))
	assert_true(b.is_aiming())
	b.release_at(0, c + Vector2(0, -ItemButtons.AIM_RADIUS))
	assert_eq(aimed.size(), 1, "kéo rồi thả ngoài nút: dùng theo hướng kéo")
	assert_eq(aimed[0][0], 3, "báo chỉ số ô đồ")
	assert_near(aimed[0][1].y, -1.0, 0.01, "hết tầm")
	assert_eq(shown[-1], [3, false], "tắt chỉ báo khi thả")
	b.press_at(0, c)
	b.drag_to(0, c + Vector2(40, 0))
	b.release_at(0, c + Vector2(10, 0))
	assert_eq(aimed.size(), 1, "kéo rồi thả lại trong nút: hủy")
	b.free()
