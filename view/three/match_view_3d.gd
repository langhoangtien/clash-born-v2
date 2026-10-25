class_name MatchView3D
extends Node3D
## Bản thử 3D (D-145): mặt đất là lớp 2D (map, sương, vùng, mũi nhắm…) vẽ vào SubViewport quanh
## camera rồi dán lên mặt phẳng; tướng là mô hình 3D có hoạt ảnh, đơn vị khác là ảnh đứng (billboard).
## Camera nghiêng kiểu Liên Quân. Chỉ đọc World (qua UnitsView để lấy vị trí nội suy, ai thấy được).

## 1 px thế giới = 0,01 đơn vị 3D.
const S: float = 0.01
## D-151: lớp mặt đất chỉ phủ vùng camera thấy (tính từ khung nhìn), ảnh LAYER_SCALE điểm ảnh mỗi px
## thế giới (khớp MapBaker). Xa quá FAR_PX phía trước bị sương che, không vẽ; nới GROUND_MARGIN mỗi phía.
const LAYER_SCALE: float = 0.5
const FAR_PX: float = 1500.0
const GROUND_MARGIN: float = 96.0
## Camera: lệch khỏi điểm nhìn (đơn vị 3D), góc nhìn.
const CAM_OFFSET: Vector3 = Vector3(0, 11.5, 11.0)
const CAM_FOV: float = 40.0

var world: World
var units: UnitsView
var layer: SubViewport
var camera: Camera3D
var _layer_cam: Camera2D
var _ground: MeshInstance3D
## Vùng lớp đất so với điểm nhìn (px thế giới).
var _ground_rect: Rect2 = Rect2()
var _actors: Dictionary[int, Actor3D] = {}


## Dựng bản 3D dưới `parent`, thanh máu vào lớp HUD `hud` (dưới mọi nút).
static func create(parent: Node, hud: CanvasLayer, w: World, units_view: UnitsView, ground_nodes: Array[Node]) -> MatchView3D:
	var v: MatchView3D = MatchView3D.new()
	v.name = "View3D"
	parent.add_child(v)
	v.setup(w, units_view, ground_nodes)
	var bars: Bars3D = Bars3D.new()
	bars.name = "Bars3D"
	bars.view = v
	hud.add_child(bars)
	hud.move_child(bars, 0)
	bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return v


## Đưa các lớp 2D nằm trên mặt đất vào SubViewport và dựng cảnh 3D.
func setup(w: World, units_view: UnitsView, ground_nodes: Array[Node]) -> void:
	world = w
	units = units_view
	units.ground_only = true
	layer = SubViewport.new()
	layer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(layer)
	for n: Node in ground_nodes:
		n.reparent(layer, false)
	_layer_cam = Camera2D.new()
	_layer_cam.zoom = Vector2.ONE * LAYER_SCALE
	layer.add_child(_layer_cam)
	_ground = MeshInstance3D.new()
	_ground.mesh = PlaneMesh.new()
	_ground.material_override = Look3D.ground_material(layer.get_texture())  # D-150
	add_child(_ground)
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.current = true
	add_child(camera)
	_fit_ground()
	get_viewport().size_changed.connect(_fit_ground)
	Look3D.add_lights(self)  # D-150


func to_3d(p: Vector2) -> Vector3:
	return Vector3(p.x * S, 0.0, p.y * S)


## Điểm trên mặt đất (px thế giới) dưới điểm màn hình.
func screen_to_world(screen: Vector2) -> Vector2:
	var from: Vector3 = camera.project_ray_origin(screen)
	var dir: Vector3 = camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector2(from.x, from.z) / S
	var hit: Vector3 = from + dir * (-from.y / dir.y)
	return Vector2(hit.x, hit.z) / S


## Mỗi khung: camera theo `focus` (px thế giới), lớp đất theo camera, đồng bộ hình đơn vị.
func update(focus: Vector2) -> void:
	var target: Vector3 = to_3d(focus)
	camera.position = target + CAM_OFFSET
	camera.look_at(target, Vector3.UP)
	_layer_cam.position = focus + _ground_rect.get_center()
	_ground.position = to_3d(focus + _ground_rect.get_center())
	var keep: Dictionary[int, bool] = {}
	for e: Entity in world.entities:
		if not e.alive or not units.seen(e) or e.kind == Entity.Kind.WARD:
			continue
		if units.view_rect.has_area() and not units.view_rect.grow(UnitsView.CULL_MARGIN).has_point(e.position):
			continue  # D-149: ngoài vùng mặt đất đang vẽ — gỡ hình, khỏi chạy hoạt ảnh
		keep[e.id] = true
		var a: Actor3D = _actors.get(e.id)
		if a == null:
			a = Actor3D.make(e)
			add_child(a)
			_actors[e.id] = a
		a.sync(world, e, to_3d(units.display_position(e)), units.is_moving(e), world.tick - units.hit_tick(e))
	for id: int in _actors.keys():
		if not keep.has(id):
			_actors[id].queue_free()
			_actors.erase(id)


## Vùng mặt đất đang vẽ (px thế giới) khi nhìn vào `focus` — cho sương và lọc đơn vị.
func ground_world_rect(focus: Vector2) -> Rect2:
	return Rect2(focus + _ground_rect.position, _ground_rect.size)


## D-151: đo vùng đất camera thấy (chiếu 4 góc màn hình xuống đất, phía xa cắt ở FAR_PX), cỡ lớp đất theo đó.
func _fit_ground() -> void:
	camera.position = CAM_OFFSET
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var box: Rect2 = Rect2()
	for i: int in 4:
		var corner: Vector2 = Vector2(screen.x * (i % 2), screen.y * (i / 2))
		var hit: Vector2 = screen_to_world(corner) if camera.project_ray_normal(corner).y < -0.05 else Vector2(0, -FAR_PX)
		hit.y = maxf(hit.y, -FAR_PX)
		box = Rect2(hit, Vector2.ZERO) if i == 0 else box.expand(hit)
	_ground_rect = box.grow(GROUND_MARGIN)
	layer.size = Vector2i(ceili(_ground_rect.size.x * LAYER_SCALE), ceili(_ground_rect.size.y * LAYER_SCALE))
	(_ground.mesh as PlaneMesh).size = _ground_rect.size * S


## Vị trí màn hình của đỉnh đầu đơn vị (cho thanh máu); null nếu sau camera.
func head_screen(e: Entity) -> Variant:
	var a: Actor3D = _actors.get(e.id)
	if a == null:
		return null
	var top: Vector3 = a.position + Vector3(0, a.height + 0.25, 0)
	if camera.is_position_behind(top):
		return null
	return camera.unproject_position(top)
