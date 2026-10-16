extends SceneTree
## Xuất ảnh map dev có ký hiệu (M5.6, D-77) ra docs/map_dev.png. Cần màn hình (Linux: xvfb-run):
##   godot --path . -s tools/map_dev_png.gd
## Chạy lại sau mỗi lần sửa map (tools/map_build/build_map.py).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const OUT: String = "res://docs/map_dev.png"
const SIDE: int = 3000

var _frames: int = 0
var _viewport: SubViewport


func _initialize() -> void:
	var layout: MapLayout = load(MAP_PATH) as MapLayout
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIDE, SIDE)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var view: MapView = MapView.new()
	view.layout = layout
	view.show_structures = true
	view.show_camps = true
	view.show_labels = true
	_viewport.add_child(view)
	var camera: Camera2D = Camera2D.new()
	camera.position = layout.world_size() * 0.5
	camera.zoom = Vector2.ONE * (SIDE / layout.world_size().x)
	_viewport.add_child(camera)
	camera.make_current()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4:
		_viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
		print("đã lưu ", OUT)
		return true
	return false
