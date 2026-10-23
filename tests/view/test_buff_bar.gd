extends TestCase
## D-134: thời gian còn lại của buff/debuff là vệt viền chạy quanh ô vuông.


func _len(pts: PackedVector2Array) -> float:
	var total: float = 0.0
	for i: int in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total


func test_D_134_border_trail_length_matches_time_left() -> void:
	var box: Rect2 = Rect2(Vector2(10, 20), Vector2(40, 40))
	assert_near(_len(BuffBar.border_trail(box, 1.0)), 160.0, 0.01, "còn đủ: cả chu vi")
	assert_near(_len(BuffBar.border_trail(box, 0.5)), 80.0, 0.01, "còn nửa: nửa chu vi")
	assert_near(_len(BuffBar.border_trail(box, 0.1)), 16.0, 0.01)
	assert_eq(BuffBar.border_trail(box, 0.0).size(), 0, "hết giờ: không vẽ")


func test_D_134_trail_starts_top_center_and_runs_clockwise() -> void:
	var box: Rect2 = Rect2(Vector2(0, 0), Vector2(40, 40))
	var pts: PackedVector2Array = BuffBar.border_trail(box, 1.0)
	assert_eq(pts[0], Vector2(20, 0), "bắt đầu giữa cạnh trên")
	assert_eq(pts[1], Vector2(40, 0), "chạy sang phải (chiều kim đồng hồ)")
	assert_eq(pts[pts.size() - 1], Vector2(20, 0), "khép kín")
	var quarter: PackedVector2Array = BuffBar.border_trail(box, 0.25)
	assert_eq(quarter[quarter.size() - 1], Vector2(40, 20), "còn 1/4: tới giữa cạnh phải")
