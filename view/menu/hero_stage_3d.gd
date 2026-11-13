class_name HeroStage3D
extends Node3D
## D-412: sân khấu 3D của khung xem tướng ở màn chọn tướng — một mô hình tướng dựng bằng đúng đường của trận
## (`Actor3D.make`: mô hình + xương + hoạt ảnh, màu phe, dây cung D-349, bóng chân), đèn cố định, nền tối, đĩa dưới chân,
## camera nhìn ngang ngực. Chỉ giữ một mô hình; đổi tướng / gỡ thì giải phóng mô hình cũ ngay.

## Hằng số hiển thị.
const BG_COLOR: Color = Color(0.045, 0.06, 0.095)
const DISC_COLOR: Color = Color(0.13, 0.17, 0.25)
const DISC_RADIUS: float = 0.75     ## so với chiều cao mô hình
const LOOK_AT: float = 0.55         ## điểm nhìn: phần chiều cao mô hình
const DISTANCE: float = 2.5         ## khoảng cách camera mặc định: lần chiều cao mô hình
const ZOOM_MIN: float = 0.35        ## gần nhất (soi bàn tay, vũ khí): lần khoảng cách mặc định
const ZOOM_MAX: float = 1.6
const PITCH: float = 0.18           ## rad, nhìn chếch xuống
const DEFAULT_YAW: float = -0.45    ## rad, quay chéo ba phần tư

var actor: Actor3D
var anim: AnimationPlayer
var camera: Camera3D
var yaw: float = DEFAULT_YAW
## 1 = khoảng cách mặc định; nhỏ hơn = gần hơn.
var zoom: float = 1.0
var _pivot: Node3D
var _disc: MeshInstance3D


func _init() -> void:
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.current = true
	add_child(camera)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_color = Look3D.SUN_COLOR
	sun.light_energy = 1.15
	add_child(sun)
	var back: DirectionalLight3D = DirectionalLight3D.new()  # viền sáng sau lưng cho dễ nhìn dáng
	back.rotation_degrees = Vector3(-20, 160, 0)
	back.light_energy = 0.45
	add_child(back)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Look3D.environment()
	env.environment.background_color = BG_COLOR
	env.environment.fog_enabled = false
	add_child(env)
	_disc = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.04
	_disc.mesh = cyl
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = DISC_COLOR
	_disc.material_override = mat
	_disc.position.y = -0.02
	add_child(_disc)


## Dựng mô hình của `e` (hero xem trước — HeroPreview.lv1); gỡ mô hình cũ.
func show_unit(e: Entity) -> void:
	clear()
	actor = Actor3D.make(e)
	actor.name = "Actor"
	_pivot.add_child(actor)
	var players: Array[Node] = actor.find_children("*", "AnimationPlayer", true, false)
	anim = players[0] as AnimationPlayer if not players.is_empty() else null
	_disc.scale = Vector3(actor.height * DISC_RADIUS, 1.0, actor.height * DISC_RADIUS)
	reset_view()


func clear() -> void:
	if actor != null:
		_pivot.remove_child(actor)
		actor.free()
	actor = null
	anim = null


func reset_view() -> void:
	yaw = DEFAULT_YAW
	zoom = 1.0
	place_camera()


## Xoay mô hình theo `yaw`, đặt camera theo `zoom` (gần thì điểm nhìn dịch lên tay / vũ khí một chút).
func place_camera() -> void:
	zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	_pivot.rotation.y = yaw
	var h: float = actor.height if actor != null else 1.0
	var target: Vector3 = Vector3(0.0, h * lerpf(0.62, LOOK_AT, clampf(zoom, 0.0, 1.0)), 0.0)
	var back: Vector3 = Vector3(0.0, sin(PITCH), cos(PITCH)) * h * DISTANCE * zoom
	camera.look_at_from_position(target + back, target, Vector3.UP)  # chạy được cả khi chưa vào cây cảnh
