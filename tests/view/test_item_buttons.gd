extends TestCase
## M6.5a: hàng ô đồ trên HUD (ITM-01, ITM-07).


func test_ITM_07_item_buttons_tap_only_active_ready_slots() -> void:
	var b: ItemButtons = ItemButtons.new()
	b.size = Vector2(1920, 1080)
	var got: Array[int] = []
	b.item_tapped.connect(func(i: int) -> void: got.append(i))
	b.item_view = [["GH", 0.0, -1, true, true], ["BC", 0.0, -1, false, false], [], [], [], []]
	for i: int in range(3):
		var ev: InputEventScreenTouch = InputEventScreenTouch.new()
		ev.pressed = true
		ev.position = b.slot_rect(i).get_center()
		b._gui_input(ev)
	assert_eq(got, [0], "chỉ ô có món chủ động dùng được mới báo")
	assert_eq(b.slot_at(b.slot_rect(5).get_center()), 5)
	assert_eq(b.slot_at(Vector2(10, 10)), -1)
	assert_eq(ItemButtons.short_name("Gậy Hồn Ma"), "GH")
	b.free()
