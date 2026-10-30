class_name MatchView3D
extends Node3D
## Bản 3D (D-145): mặt đất Terrain3D (sương tính trong shader), hình phẳng trên đất (vòng đội, vùng chiêu,
## hiệu ứng, mũi nhắm, viền bụi…) vẽ bằng GroundCanvas (D-180, thay lớp 2D vẽ vào SubViewport); đơn vị là
## mô hình 3D có hoạt ảnh. Camera nghiêng kiểu Liên Quân. Chỉ đọc World (qua UnitsView để lấy vị trí nội
## suy, ai thấy được).

## 1 px thế giới = 0,01 đơn vị 3D.
const S: float = 0.01
## D-151: vùng camera thấy (tính từ khung nhìn) để lọc đơn vị / mắt sương; xa quá FAR_PX phía trước bị
## sương che; nới GROUND_MARGIN mỗi phía.
const FAR_PX: float = 1500.0
const GROUND_MARGIN: float = 96.0
## Camera: lệch khỏi điểm nhìn (đơn vị 3D), góc nhìn.
const CAM_OFFSET: Vector3 = Vector3(0, 11.5, 11.0)
const CAM_FOV: float = 40.0
## Số mắt sương tối đa gửi shader mặt đất (khớp mảng eyes trong ground.gdshader).
const FOG_EYES: int = 64
## Độ đậm sương (như FogView của minimap).
const FOG_ALPHA: float = 0.6
## D-159: rung camera (đơn vị 3D) khi tướng mình đánh trúng / chí mạng / mất hơn SHAKE_HURT_FRACTION máu
## một lần; giảm SHAKE_DECAY mỗi giây.
const SHAKE_HIT: float = 0.03
const SHAKE_CRIT: float = 0.07
const SHAKE_HURT: float = 0.09
const SHAKE_HURT_FRACTION: float = 0.08
const SHAKE_DECAY: float = 0.6

var world: World
var units: UnitsView
var aim: AimIndicator
## D-180: hình phẳng trên đất — `overlay` vẽ lại mỗi khung, `marks` (bụi, shop, trụ, trại) dựng một lần.
var overlay: GroundCanvas
var marks: GroundCanvas
## Phe nhìn (sương); -1 = không sương.
var fog_team: int = -1
var fog_alpha: float = FOG_ALPHA
var camera: Camera3D
var scenery: Scenery3D
## D-159: tướng của người chơi (rung camera khi đánh trúng / bị đánh mạnh).
var hero_id: int = -1
var _event_tick: int = -1
var _shake: float = 0.0
var _ground: MeshInstance3D
var _ground_mat: ShaderMaterial
## Vùng đất camera thấy so với điểm nhìn (px thế giới).
var _ground_rect: Rect2 = Rect2()
var _actors: Dictionary[int, Actor3D] = {}
## D-179: bảng chẩn đoán — mặt nước, vật liệu mặt đất có ảnh nền, có vẽ nhân vật không.
var _water: MeshInstance3D
var _show_actors: bool = true


## Dựng bản 3D dưới `parent`, thanh máu vào lớp HUD `hud` (dưới mọi nút).
static func create(parent: Node, hud: CanvasLayer, w: World, units_view: UnitsView, aim_indicator: AimIndicator) -> MatchView3D:
	var v: MatchView3D = MatchView3D.new()
	v.name = "View3D"
	parent.add_child(v)
	v.setup(w, units_view, aim_indicator)
	var bars: Bars3D = Bars3D.new()
	bars.name = "Bars3D"
	bars.view = v
	hud.add_child(bars)
	hud.move_child(bars, 0)
	bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return v


## Dựng cảnh 3D: mặt đất tĩnh phủ cả vùng mặt nạ map, nước, cảnh vật, hình phẳng trên đất.
func setup(w: World, units_view: UnitsView, aim_indicator: AimIndicator) -> void:
	world = w
	units = units_view
	aim = aim_indicator
	_ground = MeshInstance3D.new()
	_ground.mesh = PlaneMesh.new()
	_ground_mat = Terrain3D.ground_material()  # D-178
	_ground.material_override = _ground_mat
	var r: Rect2 = Terrain3D.mask_rect()
	(_ground.mesh as PlaneMesh).size = r.size * S
	_ground.position = to_3d(r.get_center())
	add_child(_ground)
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.current = true
	add_child(camera)
	_fit_view()
	get_viewport().size_changed.connect(_fit_view)
	Look3D.add_lights(self)  # D-150
	scenery = Scenery3D.new()  # D-158, D-178: cây, đá, rào, tường thành, cửa hàng, đổ nát dựng từ dữ liệu map
	add_child(scenery)
	marks = GroundCanvas.new()
	overlay = GroundCanvas.new()
	if world.map != null:
		scenery.build(world.map)
		_water = Terrain3D.water(world.map)  # D-178
		add_child(_water)
		GroundMarks.paint(marks, world.map, world.balance.shop_radius)
	add_child(marks)
	add_child(overlay)


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
	_shake = move_toward(_shake, 0.0, get_process_delta_time() * SHAKE_DECAY)
	camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
	scenery.update(world)
	_paint_ground(focus)
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
		a.sync(world, e, to_3d(units.display_position(e)), units.is_moving(e), world.tick - units.hit_tick(e), units.faded(e))
		a.visible = _show_actors
	_dispatch_events()
	for id: int in _actors.keys():
		if not keep.has(id):
			_actors[id].queue_free()
			_actors.erase(id)


## D-179: bật / tắt một phần vẽ (bảng chẩn đoán FPS): cảnh vật, nền ảnh (tắt = màu phẳng), lớp phủ (hình
## phẳng trên đất, D-180), sương, nhân vật, nước.
func set_part(key: StringName, on: bool) -> void:
	match key:
		&"scenery":
			scenery.visible = on
		&"ground":
			_ground.material_override = _ground_mat if on else _flat_ground()
		&"layer":
			overlay.visible = on
			marks.visible = on
		&"actors":
			_show_actors = on
		&"fog":
			fog_alpha = FOG_ALPHA if on else 0.0
		&"water":
			if _water != null:
				_water.visible = on


static func _flat_ground() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.42, 0.6, 0.3)  # chỉ để đo, không phải màu trận
	return m


## Vùng mặt đất đang vẽ (px thế giới) khi nhìn vào `focus` — cho sương và lọc đơn vị.
func ground_world_rect(focus: Vector2) -> Rect2:
	return Rect2(focus + _ground_rect.position, _ground_rect.size)


## D-180: hình phẳng trên đất mỗi khung (đơn vị, vùng chiêu, hiệu ứng, mũi nhắm) + mắt sương cho shader đất.
func _paint_ground(focus: Vector2) -> void:
	overlay.begin()
	units.paint(overlay)
	if aim != null:
		aim.paint(overlay)
	overlay.commit()
	var eyes: Array[Vector4] = []
	if fog_team < 0:
		eyes.append(Vector4(0, 0, 1e6, 0))  # không sương: một mắt phủ hết
	else:
		var area: Rect2 = ground_world_rect(focus)
		for v: Vector4 in FogView.eyes(world, fog_team, units.display_position):
			if eyes.size() < FOG_EYES and area.grow(v.z).has_point(Vector2(v.x, v.y)):
				eyes.append(Vector4(v.x * S, v.y * S, v.z * S, 0.0))
	_ground_mat.set_shader_parameter("eye_count", eyes.size())
	eyes.resize(FOG_EYES)
	_ground_mat.set_shader_parameter("eyes", eyes)
	_ground_mat.set_shader_parameter("fog_color", Color(0.02, 0.03, 0.07, fog_alpha))


## D-151: đo vùng đất camera thấy (chiếu 4 góc màn hình xuống đất, phía xa cắt ở FAR_PX).
func _fit_view() -> void:
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


## D-159: sự kiện của tick mới → hoạt ảnh chiêu, khựng khung / lóe khi trúng, rung camera.
func _dispatch_events() -> void:
	if world.tick == _event_tick:
		return
	_event_tick = world.tick
	for ev: GameEvent in world.events:
		var src: Actor3D = _actors.get(ev.source_id)
		var dst: Actor3D = _actors.get(ev.target_id)
		match ev.type:
			&"ability_cast":
				if src != null:
					src.on_cast(int(ev.amount))
			&"attack_landed":
				var e: Entity = world.find_entity(ev.source_id)
				var melee: bool = e != null and e.projectile_speed <= 0.0
				if src != null and melee:
					src.on_hit_given()
				if dst != null:
					dst.on_hit_taken(melee)
				if ev.source_id == hero_id:
					_shake = maxf(_shake, SHAKE_CRIT if ev.reason == &"crit" else SHAKE_HIT)
			&"damage_taken":
				if dst != null and ev.amount > 0.0:
					dst.on_hit_taken(false)  # D-160: lóe dịu, giãn cách — chiêu / đòn xa cũng có phản hồi
				var me: Entity = world.find_entity(hero_id) if ev.target_id == hero_id else null
				if me != null and ev.amount > me.stats.get_stat(StatId.Id.MAX_HP) * SHAKE_HURT_FRACTION:
					_shake = maxf(_shake, SHAKE_HURT)


## D-180: vị trí màn hình của điểm `p` (px thế giới) cao `height` m; null nếu sau camera.
func ground_screen(p: Vector2, height: float = 0.0) -> Variant:
	var at: Vector3 = to_3d(p) + Vector3(0, height, 0)
	if camera.is_position_behind(at):
		return null
	return camera.unproject_position(at)


## Vị trí màn hình của chân đơn vị (cho dấu trạng thái); null nếu chưa có hình hoặc sau camera.
func foot_screen(e: Entity) -> Variant:
	var a: Actor3D = _actors.get(e.id)
	if a == null or camera.is_position_behind(a.position):
		return null
	return camera.unproject_position(a.position)


## Vị trí màn hình của đỉnh đầu đơn vị (cho thanh máu); null nếu sau camera.
func head_screen(e: Entity) -> Variant:
	var a: Actor3D = _actors.get(e.id)
	if a == null:
		return null
	var top: Vector3 = a.position + Vector3(0, a.height + 0.25, 0)
	if camera.is_position_behind(top):
		return null
	return camera.unproject_position(top)
