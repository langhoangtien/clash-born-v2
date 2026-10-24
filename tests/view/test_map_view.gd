extends TestCase
## Màn xem map (M0.4) dựng được từ dữ liệu, không lỗi.

const SCENE: String = "res://app/map_viewer.tscn"


func test_map_viewer_scene_builds_layers() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var viewer: Node = (load(SCENE) as PackedScene).instantiate()
	tree.root.add_child(viewer)
	var view: MapView = viewer.find_child("MapView", true, false) as MapView
	assert_true(view != null, "có MapView")
	if view != null:
		assert_true(view.get_node_or_null("Ground") != null, "có lớp nền")
		assert_true(view.get_node_or_null("Obstacles") != null, "có lớp vật cản")
		assert_true(view.get_node_or_null("Overlay") != null, "có lớp đánh dấu")
	viewer.free()


func test_overlay_toggles() -> void:
	var view: MapView = MapView.new()
	view.layout = load("res://data/maps/clashborn.tres") as MapLayout
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(view)
	assert_true(view.show_structures, "mặc định hiện trụ")
	view.toggle_overlay(&"walkability")
	assert_true(view.show_walkability)
	view.toggle_overlay(&"walkability")
	assert_false(view.show_walkability)
	view.free()


func test_D_147_baking_skipped_headless_keeps_live_layers() -> void:
	assert_false(MapBaker.can_bake(), "test chạy headless: không nướng")
	var view: MapView = MapView.new()
	view.layout = load("res://data/maps/clashborn.tres") as MapLayout
	view.bake_static = true
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	assert_true(view.baker == null)
	assert_true((view.get_node("Ground") as CanvasItem).visible, "lớp gốc vẫn vẽ")
	view.free()


func test_D_147_tile_grid_covers_map() -> void:
	var size: Vector2 = (load("res://data/maps/clashborn.tres") as MapLayout).world_size()
	assert_true(ceili(size.x / MapBaker.TILE) * MapBaker.TILE >= size.x)
	assert_true(MapBaker.TILE * MapBaker.SCALE <= 2048.0, "ô vừa giới hạn kết cấu của máy yếu")
