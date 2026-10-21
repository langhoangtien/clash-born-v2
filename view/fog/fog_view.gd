class_name FogView
extends Node2D
## Sương mù (M5.1, VIS-01): phủ tối cả map trừ vòng tầm nhìn của các đơn vị phe `team`.
## Tính trên GPU (fog.gdshader); vòng theo vị trí hiển thị để khớp với hình đơn vị.
## Tầng VIEW: chỉ đọc World.

const SHADER: Shader = preload("res://view/fog/fog.gdshader")
## Giới hạn mảng trong shader.
const MAX_EYES: int = 128

var world: World
var team: int = 0
## Vị trí hiển thị của đơn vị (UnitsView.display_position); null thì dùng vị trí SIM.
var place: Callable
var fog_alpha: float = 0.6
## Vùng camera đang nhìn (tọa độ map); chỉ gửi mắt có vòng nhìn chạm vùng này lên shader
## (D-108: nhẹ GPU điện thoại). Rỗng = gửi hết.
var view_rect: Rect2 = Rect2()


func _ready() -> void:
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SHADER
	(material as ShaderMaterial).set_shader_parameter("fog_color", Color(0.02, 0.03, 0.07, fog_alpha))


## Các mắt của phe `team`: (x, y, tầm nhìn, 0).
static func eyes(world: World, team: int, place: Callable = Callable()) -> Array[Vector4]:
	var out: Array[Vector4] = []
	for e: Entity in world.entities:
		if e.team != team or not e.alive or e.stats == null:
			continue
		var sight: float = e.stats.get_stat(StatId.Id.VISION_RANGE)
		if sight > 0.0 and out.size() < MAX_EYES:
			var at: Vector2 = place.call(e) if place.is_valid() else e.position
			out.append(Vector4(at.x, at.y, sight, 0.0))
	return out


## Điểm `point` có nằm trong tầm nhìn phe `team` không (để ẩn đạn, chữ nổi của địch).
static func lit(world: World, team: int, point: Vector2) -> bool:
	for e: Entity in world.entities:
		if e.team == team and e.alive and e.stats != null:
			var sight: float = e.stats.get_stat(StatId.Id.VISION_RANGE)
			if point.distance_squared_to(e.position) <= sight * sight:
				return true
	return false


func _process(_delta: float) -> void:
	if world == null:
		return
	var list: Array[Vector4] = eyes(world, team, place)
	if view_rect.has_area():
		list = list.filter(func(v: Vector4) -> bool: return view_rect.grow(v.z).has_point(Vector2(v.x, v.y)))
	var count: int = list.size()
	list.resize(MAX_EYES)
	(material as ShaderMaterial).set_shader_parameter("eyes", list)
	(material as ShaderMaterial).set_shader_parameter("count", count)
	queue_redraw()


func _draw() -> void:
	if world != null and world.map != null:
		var area: Rect2 = Rect2(Vector2.ZERO, world.map.world_size())
		draw_rect(area.intersection(view_rect.grow(64.0)) if view_rect.has_area() else area, Color.WHITE)
