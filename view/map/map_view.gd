class_name MapView
extends Node2D
## Vẽ một MapLayout: lớp nền, lớp vật cản, lớp đánh dấu (trụ, lane, trại, ô đi được).
## Tầng VIEW: chỉ đọc dữ liệu map, không đổi gì.

const MapPainter = preload("res://view/map/map_painter.gd")
const OVERLAYS: PackedStringArray = ["structures", "lanes", "camps", "spawns", "walkability"]
## Hằng số hiển thị (chỉ để vẽ, không phải số gameplay).
const TOWER_MARK_RADIUS: float = 52.0
const BLUE: Color = Color(0.45, 0.75, 1.0)
const RED: Color = Color(1.0, 0.5, 0.5)
const GOLD: Color = Color(1.0, 0.85, 0.25)

@export var layout: MapLayout

@export var show_structures: bool = true
var show_lanes: bool = false
var show_camps: bool = true
var show_spawns: bool = false
var show_walkability: bool = false

var _overlay: _Layer
var _walkability_texture: ImageTexture


class _Layer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


func _ready() -> void:
	if layout == null:
		return
	var errors: PackedStringArray = layout.validation_errors()
	if not errors.is_empty():
		push_error("Dữ liệu map lỗi: " + "; ".join(errors))
		return
	_add_layer("Ground", func(ci: CanvasItem) -> void: MapPainter.paint_ground(ci, layout, true))
	_add_layer("Obstacles", func(ci: CanvasItem) -> void: MapPainter.paint_obstacles(ci, layout, true))
	_add_layer("Bushes", func(ci: CanvasItem) -> void: MapPainter.paint_bushes(ci, layout, true))
	_overlay = _add_layer("Overlay", _paint_overlay)


func toggle_overlay(overlay_name: StringName) -> void:
	var key: String = "show_" + overlay_name
	set(key, not get(key))
	if _overlay != null:
		_overlay.queue_redraw()


func _add_layer(layer_name: String, painter: Callable) -> _Layer:
	var layer: _Layer = _Layer.new()
	layer.name = layer_name
	layer.painter = painter
	add_child(layer)
	return layer


func _paint_overlay(ci: CanvasItem) -> void:
	if show_walkability:
		ci.draw_texture_rect(_walkability(), Rect2(Vector2.ZERO, Vector2(layout.clearance_size) * layout.clearance_pixel), false)
	if show_lanes:
		for lane: String in MapLayout.LANES:
			ci.draw_polyline(layout.route(lane, 0), Color(GOLD, 0.8), 8, true)
	if show_spawns:
		for team: int in range(2):
			ci.draw_arc(layout.fountain_point(team), 60, 0, TAU, 32, _team_color(team), 6, true)
			for lane: String in MapLayout.LANES:
				ci.draw_arc(layout.lane_spawn_point(team, lane), 40, 0, TAU, 24, _team_color(team), 5, true)
	if show_structures:
		for i: int in range(layout.tower_points.size()):
			var color: Color = _team_color(layout.tower_teams[i])
			ci.draw_circle(layout.tower_points[i], TOWER_MARK_RADIUS, Color(0.05, 0.06, 0.08))
			ci.draw_arc(layout.tower_points[i], TOWER_MARK_RADIUS, 0, TAU, 32, color, 6, true)
		for team: int in range(2):
			ci.draw_arc(layout.core_point(team), 120, 0, TAU, 48, _team_color(team), 10, true)
	if show_camps:
		for point: Vector2 in layout.camp_points:
			ci.draw_arc(point, 48, 0, TAU, 28, GOLD, 6, true)


func _team_color(team: int) -> Color:
	return BLUE if team == 0 else RED


func _walkability() -> ImageTexture:
	if _walkability_texture != null:
		return _walkability_texture
	var size: Vector2i = layout.clearance_size
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y: int in range(size.y):
		for x: int in range(size.x):
			var clearance: float = float(layout.clearance_bytes[y * size.x + x]) * layout.clearance_unit
			if clearance < 32.0:
				image.set_pixel(x, y, Color(1, 0.15, 0.15, 0.45))
			elif clearance < 64.0:
				image.set_pixel(x, y, Color(1, 0.75, 0.1, 0.25))
	_walkability_texture = ImageTexture.create_from_image(image)
	return _walkability_texture
