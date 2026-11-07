class_name Minimap
extends Control
## Minimap góc trên trái kiểu Liên Quân (M5.1): địa hình thu nhỏ, sương mù của phe mình,
## chấm đơn vị phe mình, chấm địch đang thấy, công trình, khung camera. Giữ ngón/chuột trên
## minimap → `peeking` và `peek_point` (tọa độ map) để camera xem chỗ đó; thả tay thì thôi.
## Tầng VIEW: chỉ đọc World.

const MapPainter = preload("res://view/map/map_painter.gd")
const SIDE: float = 260.0
const CORNER: float = 12.0  ## D-222: bo góc khung minimap
const MARGIN: Vector2 = Vector2(16, 16)
const BLUE: Color = Color(0.35, 0.65, 1.0)
const RED: Color = Color(1.0, 0.35, 0.3)
const ME: Color = Color(1.0, 0.9, 0.3)
const NEUTRAL: Color = Color(0.95, 0.75, 0.35)
## Độ nét ảnh địa hình so với cỡ minimap (2 = gấp đôi, cho màn hình mật độ cao).
const TERRAIN_DENSITY: float = 2.0
## D-290: chấm đơn vị + sương của minimap vẽ lại tối đa mỗi chừng này ms (~15 lần / giây; hằng số kỹ thuật của
## phần hình — trước vẽ mỗi khung, tốn ~¾ phần "cuối khung" đo trên PC).
const REFRESH_MS: int = 66

var world: World
var hero: Entity
var team: int = 0
## Khung camera đang thấy (tọa độ map), match_scene đặt mỗi khung.
var camera_rect: Rect2
var peeking: bool = false
var peek_point: Vector2 = Vector2.ZERO

var _content: Node2D
var _terrain: Texture2D
var _fog: FogView
var _dots: _Layer
var _pointer: int = -100
var _last_refresh: int = -1_000_000


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
	_add_terrain()
	_content = Node2D.new()
	_content.scale = Vector2.ONE * map_scale()
	add_child(_content)
	_fog = FogView.new()
	_fog.world = world
	_fog.team = team
	_fog.fog_alpha = 0.7
	_fog.manual = true
	_content.add_child(_fog)
	_dots = _Layer.new()
	_dots.painter = _paint_dots
	_dots.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # chấm ảnh thu nhỏ mịn
	_content.add_child(_dots)
	var frame: _Layer = _Layer.new()
	frame.painter = _paint_frame
	add_child(frame)
	queue_redraw()  # D-290: nền + ảnh địa hình vẽ một lần (không vẽ lại mỗi khung)


## D-147: địa hình vẽ một lần vào SubViewport (UPDATE_ONCE) rồi hiện như một ảnh, thay vì vẽ lại
## hàng trăm đa giác mỗi khung.
func _add_terrain() -> void:
	var px: int = int(SIDE * TERRAIN_DENSITY)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var terrain: _Layer = _Layer.new()
	terrain.scale = Vector2.ONE * (px / world.map.world_size().x)
	terrain.painter = func(ci: CanvasItem) -> void:
		MapPainter.paint_ground(ci, world.map, false)
		MapPainter.paint_obstacles(ci, world.map, false)
		MapPainter.paint_bushes(ci, world.map, false)
		MapPainter.paint_shops(ci, world.map, world.balance.shop_radius, false)
	vp.add_child(terrain)
	_terrain = vp.get_texture()


func map_scale() -> float:
	return SIDE / world.map.world_size().x


func to_map(local: Vector2) -> Vector2:
	return (local / map_scale()).clamp(Vector2.ZERO, world.map.world_size())


func _process(_delta: float) -> void:
	if _dots != null and refresh_due(Time.get_ticks_msec()):
		_dots.queue_redraw()
		_fog.refresh()


## true nếu đã đủ REFRESH_MS từ lần vẽ trước (và ghi nhận lần này).
func refresh_due(now_ms: int) -> bool:
	if now_ms - _last_refresh < REFRESH_MS:
		return false
	_last_refresh = now_ms
	return true


func _draw() -> void:
	var t: int = FrameProfile.now()  # D-263: đo thời gian vẽ từng bảng HUD
	_paint()
	FrameProfile.shared.hud(&"hud_minimap", t)


func _paint() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	if _terrain != null:
		draw_texture_rect(_terrain, Rect2(Vector2.ZERO, Vector2(SIDE, SIDE)), false)


## D-222: viền vàng bo góc, lớp trên cùng (trên sương mù); viền dày che góc vuông của ảnh.
func _paint_frame(ci: CanvasItem) -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	ci.draw_style_box(UiStyle.box(Color(0, 0, 0, 0), Color(UiStyle.GOLD_DEEP, 0.98), 6, int(CORNER)), r.grow(3))
	ci.draw_style_box(UiStyle.box(Color(0, 0, 0, 0), Color(UiStyle.GOLD, 0.55), 1, int(CORNER) - 4), r.grow(-3))


## Vẽ ở tọa độ map (layer đã thu nhỏ): bán kính chấm tính theo px minimap. D-290: chấm / vòng là ảnh dùng chung
## (UiBake) vẽ theo từng loại liền nhau — các lệnh cùng ảnh gộp lại (trước: mỗi chấm, mỗi vòng một lệnh vẽ, ~140
## lệnh mỗi khung chỉ riêng minimap).
func _paint_dots(ci: CanvasItem) -> void:
	var t: int = FrameProfile.now()  # D-290: tính vào cột HUD (trước lẫn vào "xương")
	var px: float = 1.0 / map_scale()
	var ring: Texture2D = UiBake.ring_texture()
	var disc: Texture2D = UiBake.disc_texture()
	for c: CampState in world.camps:  # JGL: chỗ trại (vòng nhỏ), quái đang thấy là chấm bên dưới
		_dot(ci, ring, c.center, 4.5 * px, Color(NEUTRAL, 0.7))
	var units: Array[Entity] = []
	for e: Entity in world.entities:
		if not e.alive:
			continue
		var color: Color = _color(e)
		if Rules.is_structure(e):
			var r: float = (6.0 if e.kind == Entity.Kind.CORE else 4.0) * px
			ci.draw_rect(Rect2(e.position - Vector2(r + px, r + px), Vector2(r + px, r + px) * 2.0), Color.BLACK)  # viền đen
			ci.draw_rect(Rect2(e.position - Vector2(r, r), Vector2(r, r) * 2.0), color)
		elif e.kind == Entity.Kind.WARD:  # WRD: chấm vàng / xanh của phe mình, đỏ nếu là ward địch đang thấy
			if e.team == team or Rules.is_visible(team, e):
				var wc: Color = RED if e.team != team else (Color(0.35, 0.75, 1.0) if e.true_sight_range > 0.0 else Color(1.0, 0.82, 0.25))
				ci.draw_rect(Rect2(e.position - Vector2(3, 3) * px, Vector2(6, 6) * px), wc)
		elif e.team == team or Rules.is_visible(team, e):
			units.append(e)
	for e: Entity in units:
		var hero_dot: bool = e.kind == Entity.Kind.HERO
		_dot(ci, disc, e.position, (5.0 if hero_dot else 2.2) * px, ME if e == hero else _color(e))
	for e: Entity in units:
		if e.kind == Entity.Kind.HERO:
			_dot(ci, ring, e.position, 5.5 * px, Color.BLACK)
	ci.draw_rect(camera_rect, Color(1, 1, 1, 0.8), false, 1.5 * px)
	FrameProfile.shared.hud(&"hud_minimap", t)


func _color(e: Entity) -> Color:
	return BLUE if e.team == team else (NEUTRAL if e.team == 2 else RED)


static func _dot(ci: CanvasItem, tex: Texture2D, at: Vector2, r: float, color: Color) -> void:
	ci.draw_texture_rect(tex, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), false, color)


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
