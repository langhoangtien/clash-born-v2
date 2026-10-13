extends Node2D
## Màn xem map (M0.4). Kéo để di chuyển, cuộn chuột / chụm 2 ngón để phóng to,
## phím 1–5 bật/tắt lớp đánh dấu, Esc quay lại.

const MAIN_SCENE: String = "res://app/main.tscn"
const MIN_ZOOM: float = 0.06
const MAX_ZOOM: float = 1.5
const ZOOM_STEP: float = 1.15

@onready var view: MapView = $MapView
@onready var camera: Camera2D = $Camera2D

var _dragging: bool = false
var _touches: Dictionary[int, Vector2] = {}


func _ready() -> void:
	_fit()


func _fit() -> void:
	var size: Vector2 = view.layout.world_size()
	camera.position = size * 0.5
	var screen: Vector2 = get_viewport_rect().size
	var zoom: float = clampf(minf(screen.x / size.x, screen.y / size.y), MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2.ONE * zoom


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event as InputEventKey)
	elif event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _dragging:
		camera.position -= (event as InputEventMouseMotion).relative / camera.zoom
	elif event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_touch_drag(event as InputEventScreenDrag)


func _on_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(MAIN_SCENE)
	elif event.keycode == KEY_0:
		_fit()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
		view.toggle_overlay(MapView.OVERLAYS[event.keycode - KEY_1])


func _on_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_by(ZOOM_STEP)
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_by(1.0 / ZOOM_STEP)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)


func _on_touch_drag(event: InputEventScreenDrag) -> void:
	if _touches.size() >= 2 and _touches.has(event.index):
		var other: Vector2 = _touches[_touches.keys().filter(func(k: int) -> bool: return k != event.index)[0]]
		var before: float = _touches[event.index].distance_to(other)
		var after: float = event.position.distance_to(other)
		if before > 1.0:
			_zoom_by(after / before)
	elif _touches.size() == 1:
		camera.position -= event.relative / camera.zoom
	_touches[event.index] = event.position


func _zoom_by(factor: float) -> void:
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
