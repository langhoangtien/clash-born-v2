extends TestCase
## D-158, D-178: cảnh 3D dựng từ dữ liệu map (decor.py) — mô hình có thật, cây chỉ trên bục rừng, mặt nạ nền
## phủ cả map; đổ nát xuất hiện chỗ trụ đã đổ.

const MAP_PATH: String = "res://data/maps/clashborn.tres"


func test_D_178_decor_models_exist() -> void:
	var seen: Dictionary = {}
	for it: Array in Terrain3D.items():
		seen[it[0]] = true
	assert_true(seen.size() >= 10, "đủ loại cảnh vật (%d)" % seen.size())
	for model: String in seen:
		assert_true(ResourceLoader.exists(ModelLibrary.MODELS + Terrain3D.MODEL_DIR + model + ".glb"), "có mô hình %s" % model)


func test_D_178_trees_only_on_plateaus() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	var trees: int = 0
	for it: Array in Terrain3D.items():
		if not String(it[0]).begins_with("pine") and not String(it[0]).begins_with("tree"):
			continue
		trees += 1
		var p: Vector2 = Vector2(float(it[1]), float(it[2]))
		var inside: bool = false
		for shape: MapShape in layout.forest_shapes:
			inside = inside or Geometry2D.is_point_in_polygon(p, shape.outer)
		assert_true(inside, "cây tại %s nằm trong bục rừng" % p)
	assert_true(trees > 100, "rừng có cây (%d)" % trees)


func test_D_178_ground_masks_cover_map() -> void:
	var rect: Rect2 = Terrain3D.mask_rect()
	var size: Vector2 = (load(MAP_PATH) as MapLayout).world_size()
	assert_true(rect.encloses(Rect2(Vector2.ZERO, size)), "mặt nạ phủ cả map")
	assert_eq(Terrain3D.mask_image().get_size(), Terrain3D.shadow_image().get_size())


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


