class_name Minimap
extends Control
## Minimap góc trên trái kiểu Liên Quân (M5.1): địa hình thu nhỏ, sương mù của phe mình,
## chấm đơn vị phe mình, chấm địch đang thấy, công trình, khung camera. Giữ ngón/chuột trên
## minimap → `peeking` và `peek_point` (tọa độ map) để camera xem chỗ đó; thả tay thì thôi.
## Tầng VIEW: chỉ đọc World.

const MapPainter = preload("res://view/map/map_painter.gd")
const SIDE: float = 260.0
const MARGIN: Vector2 = Vector2(16, 16)
const BLUE: Color = Color(0.35, 0.65, 1.0)
const RED: Color = Color(1.0, 0.35, 0.3)
const ME: Color = Color(1.0, 0.9, 0.3)
const NEUTRAL: Color = Color(0.95, 0.75, 0.35)

var world: World
var hero: Entity
var team: int = 0
## Khung camera đang thấy (tọa độ map), match_scene đặt mỗi khung.
var camera_rect: Rect2
var peeking: bool = false
var peek_point: Vector2 = Vector2.ZERO

var _content: Node2D
var _fog: FogView
var _dots: _Layer
var _pointer: int = -100


class _Layer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


func setup(w: World, h: Entity) -> void:
	world = w
	hero = h
	team = h.team
	position = MARGIN
	size = Vector2(SIDE, SIDE)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_content = Node2D.new()
	_content.scale = Vector2.ONE * map_scale()
	add_child(_content)
	var terrain: _Layer = _Layer.new()
	terrain.painter = func(ci: CanvasItem) -> void:
		MapPainter.paint_ground(ci, world.map, false)
		MapPainter.paint_obstacles(ci, world.map, false)
		MapPainter.paint_bushes(ci, world.map, false)
		MapPainter.paint_shops(ci, world.map, world.balance.shop_radius, false)
	_content.add_child(terrain)
	_fog = FogView.new()
	_fog.world = world
	_fog.team = team
	_fog.fog_alpha = 0.7
	_content.add_child(_fog)
	_dots = _Layer.new()
	_dots.painter = _paint_dots
	_content.add_child(_dots)


func map_scale() -> float:
	return SIDE / world.map.world_size().x


func to_map(local: Vector2) -> Vector2:
	return (local / map_scale()).clamp(Vector2.ZERO, world.map.world_size())


func _process(_delta: float) -> void:
	if _dots != null:
		_dots.queue_redraw()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))


## Vẽ ở tọa độ map (layer đã thu nhỏ): bán kính chấm tính theo px minimap.
func _paint_dots(ci: CanvasItem) -> void:
	var px: float = 1.0 / map_scale()
	for c: CampState in world.camps:  # JGL: chỗ trại (vòng nhỏ), quái đang thấy là chấm bên dưới
		ci.draw_arc(c.center, 4.0 * px, 0, TAU, 12, Color(NEUTRAL, 0.7), px)
	for e: Entity in world.entities:
		if not e.alive:
			continue
		var color: Color = BLUE if e.team == team else (NEUTRAL if e.team == 2 else RED)
		if Rules.is_structure(e):
			var r: float = (6.0 if e.kind == Entity.Kind.CORE else 4.0) * px
			ci.draw_rect(Rect2(e.position - Vector2(r, r), Vector2(r, r) * 2.0), color)
			ci.draw_rect(Rect2(e.position - Vector2(r, r), Vector2(r, r) * 2.0), Color.BLACK, false, px)
		elif e.team == team or Rules.is_visible(team, e):
			var hero_dot: bool = e.kind == Entity.Kind.HERO
			ci.draw_circle(e.position, (5.0 if hero_dot else 2.2) * px, ME if e == hero else color)
			if hero_dot:
				ci.draw_arc(e.position, 5.0 * px, 0, TAU, 16, Color.BLACK, px)
	ci.draw_rect(camera_rect, Color(1, 1, 1, 0.8), false, 1.5 * px)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed and _pointer == -100:
			_pointer = t.index
			_peek(t.position)
		elif not t.pressed and t.index == _pointer:
			_end()
		accept_event()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _pointer:
		_peek((event as InputEventScreenDrag).position)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_pointer = -1
			_peek((event as InputEventMouseButton).position)
		else:
			_end()
		accept_event()
	elif event is InputEventMouseMotion and peeking and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		_peek((event as InputEventMouseMotion).position)
		accept_event()


func _peek(local: Vector2) -> void:
	peeking = true
	peek_point = to_map(local)


func _end() -> void:
	peeking = false
	_pointer = -100
