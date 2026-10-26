extends TestCase
## D-158: cảnh 3D dựng từ dữ liệu map — cây nằm trong vùng rừng (trừ lỗ), đổ nát xuất hiện chỗ trụ đã đổ.

const MAP_PATH: String = "res://data/maps/clashborn.tres"


func test_D_158_trees_fill_forest_but_not_holes() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var total: int = 0
	for shape: MapShape in layout.forest_shapes:
		for p: Vector2 in Scenery3D._fill(shape, 95.0, 24.0, rng):
			total += 1
			assert_true(Geometry2D.is_point_in_polygon(p, shape.outer), "cây trong vùng rừng")
			assert_false(Scenery3D._inside(shape.holes, p), "không mọc trong lỗ")
	assert_true(total > 100, "rừng có cây")


func test_D_158_rubble_appears_where_tower_fell() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var w: World = World.new(1, BalanceSettings.new())
	w.map = layout
	var s: Scenery3D = Scenery3D.new()
	s._layout = layout
	var before: int = s.get_child_count()
	w.destroyed_structures[StringName(layout.tower_ids[0])] = true
	s.update(w)
	s.update(w)
	assert_eq(s.get_child_count(), before + 1, "một đống đổ nát, không thêm lại mỗi khung")
	s.free()


func test_D_170_river_bank_ribbon_slopes_down_to_water() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var bank: MeshInstance3D = RiverBank3D.build(layout)
	assert_true(bank != null, "có dải bờ")
	var lines: int = 0
	for i: int in layout.rock_lines.size():
		if layout.rock_line_kinds[i] != "bank":
			continue
		lines += 1
		var line: PackedVector2Array = layout.rock_lines[i]
		var side: float = RiverBank3D._water_side(layout, line, layout.rock_line_widths[i])
		var closer: int = 0
		for k: int in line.size() - 1:
			var mid: Vector2 = (line[k] + line[k + 1]) * 0.5
			var n: Vector2 = RiverBank3D._normal(line, k) * side * layout.rock_line_widths[i]
			closer += 1 if RiverBank3D._to_water(layout, mid + n) < RiverBank3D._to_water(layout, mid - n) else 0
		assert_true(closer * 2 > line.size() - 1, "đoạn bờ %d: phía thấp nhìn ra nước" % i)
	assert_true(lines > 10)
	bank.free()
