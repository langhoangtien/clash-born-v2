class_name MatchView3D
extends Node3D
## Bản thử 3D (D-145): mặt đất là Ground3D (bản đồ nướng sẵn + sương + lớp 2D động, D-155); tướng là mô hình 3D có hoạt ảnh, đơn vị khác là ảnh đứng (billboard).
## Camera nghiêng kiểu Liên Quân. Chỉ đọc World (qua UnitsView để lấy vị trí nội suy, ai thấy được).

## 1 px thế giới = 0,01 đơn vị 3D.
const S: float = 0.01
## D-151: mặt đất chỉ phủ vùng camera thấy (tính từ khung nhìn). Xa quá FAR_PX phía trước bị sương
## che, không vẽ; nới GROUND_MARGIN mỗi phía.
const FAR_PX: float = 1500.0
const GROUND_MARGIN: float = 96.0
## Camera: lệch khỏi điểm nhìn (đơn vị 3D), góc nhìn.
const CAM_OFFSET: Vector3 = Vector3(0, 11.5, 11.0)
const CAM_FOV: float = 40.0
## D-155: số khung giữ nhân vật nạp sẵn dưới đất.
const WARM_FRAMES: int = 3

var world: World
var units: UnitsView
var ground: Ground3D
var camera: Camera3D
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
	ground = Ground3D.new()
	add_child(ground)
	var others: Array[Node] = ground_nodes.filter(func(n: Node) -> bool: return not n is FogView)
	var fog: FogView = ground_nodes.filter(func(n: Node) -> bool: return n is FogView)[0]
	ground.setup(ground_nodes.filter(func(n: Node) -> bool: return n is MapView)[0], fog, others)  # D-155
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.current = true
	add_child(camera)
	_fit_ground()
	get_viewport().size_changed.connect(_fit_ground)
	Look3D.add_lights(self)  # D-150
	_warm_up()


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
	ground.follow(focus)
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
	return Rect2(focus + ground.rect.position, ground.rect.size)


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
	ground.fit(box.grow(GROUND_MARGIN))


## D-155: nạp và vẽ thử mọi nhân vật 3D (cả hai đội, có hoạt ảnh) dưới mặt đất trong vài khung đầu,
## để lần đầu lính / tướng xuất hiện không bị giật vì nạp mô hình, ảnh, dịch shader.
func _warm_up() -> void:
	var holder: Node3D = Node3D.new()
	add_child(holder)
	for art_id: String in ModelLibrary.config()["units"]:
		for team: int in 2:
			var a: Actor3D = Actor3D.make_model(art_id, team)
			holder.add_child(a)
			a.warm_up()
	for i: int in WARM_FRAMES:
		holder.position = camera.position - CAM_OFFSET + Vector3(0, -3.0, 0)  # dưới mặt đất, giữa khung nhìn
		await get_tree().process_frame
	holder.queue_free()


## Vị trí màn hình của đỉnh đầu đơn vị (cho thanh máu); null nếu sau camera.
func head_screen(e: Entity) -> Variant:
	var a: Actor3D = _actors.get(e.id)
	if a == null:
		return null
	var top: Vector3 = a.position + Vector3(0, a.height + 0.25, 0)
	if camera.is_position_behind(top):
		return null
	return camera.unproject_position(top)
