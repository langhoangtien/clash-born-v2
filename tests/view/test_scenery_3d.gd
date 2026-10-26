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
