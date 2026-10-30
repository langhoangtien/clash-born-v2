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
