class_name MatchView3D
extends Node3D
## Bản thử 3D (D-145): mặt đất là lớp 2D (map, sương, vùng, mũi nhắm…) vẽ vào SubViewport quanh
## camera rồi dán lên mặt phẳng; tướng là mô hình 3D có hoạt ảnh, đơn vị khác là ảnh đứng (billboard).
## Camera nghiêng kiểu Liên Quân. Chỉ đọc World (qua UnitsView để lấy vị trí nội suy, ai thấy được).

## 1 px thế giới = 0,01 đơn vị 3D.
const S: float = 0.01
## Lớp mặt đất phủ chừng này px thế giới quanh camera, ảnh LAYER_SIZE px.
const GROUND_PX: float = 4096.0
const LAYER_SIZE: int = 2048
## Camera: lệch khỏi điểm nhìn (đơn vị 3D), góc nhìn.
const CAM_OFFSET: Vector3 = Vector3(0, 11.5, 11.0)
const CAM_FOV: float = 40.0
const HERO_MODEL: String = "res://assets/models/robot.glb"
const HERO_HEIGHT: float = 2.4

var world: World
var units: UnitsView
var layer: SubViewport
var camera: Camera3D
var _layer_cam: Camera2D
var _ground: MeshInstance3D
var _actors: Dictionary[int, Actor3D] = {}
var _hero_scene: PackedScene


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
	layer.size = Vector2i(LAYER_SIZE, LAYER_SIZE)
	layer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(layer)
	for n: Node in ground_nodes:
		n.reparent(layer, false)
	_layer_cam = Camera2D.new()
	_layer_cam.zoom = Vector2.ONE * (LAYER_SIZE / GROUND_PX)
	layer.add_child(_layer_cam)
	_ground = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE * GROUND_PX * S
	_ground.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = layer.get_texture()
	_ground.material_override = mat
	add_child(_ground)
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.current = true
	add_child(camera)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	_hero_scene = load(HERO_MODEL) as PackedScene


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
	_layer_cam.position = focus
	_ground.position = to_3d(focus)
	var target: Vector3 = to_3d(focus)
	camera.position = target + CAM_OFFSET
	camera.look_at(target, Vector3.UP)
	var keep: Dictionary[int, bool] = {}
	for e: Entity in world.entities:
		if not e.alive or not units.seen(e) or e.kind == Entity.Kind.WARD:
			continue
		keep[e.id] = true
		var a: Actor3D = _actors.get(e.id)
		if a == null:
			a = Actor3D.make(e, _hero_scene, HERO_HEIGHT)
			add_child(a)
			_actors[e.id] = a
		a.sync(world, e, to_3d(units.display_position(e)), units.is_moving(e), world.tick - units.hit_tick(e))
	for id: int in _actors.keys():
		if not keep.has(id):
			_actors[id].queue_free()
			_actors.erase(id)


## Vị trí màn hình của đỉnh đầu đơn vị (cho thanh máu); null nếu sau camera.
func head_screen(e: Entity) -> Variant:
	var a: Actor3D = _actors.get(e.id)
	if a == null:
		return null
	var top: Vector3 = a.position + Vector3(0, a.height + 0.25, 0)
	if camera.is_position_behind(top):
		return null
	return camera.unproject_position(top)
