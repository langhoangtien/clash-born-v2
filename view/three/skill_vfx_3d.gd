class_name SkillVfx3D
extends Node3D
## D-247: hiệu ứng chiêu 3D theo công thức dữ liệu (assets/vfx/vfx.json, khóa = art_id kỹ năng). Chỉ đọc World:
## `ability_finished` (chiêu ra, đúng lúc gây tác dụng) sinh các mảnh của công thức; `damage_taken` do chủ chiêu gây
## trong HIT_TICKS tick sau đó sinh tia lóe trên mục tiêu. Mảnh tự gỡ khi hết `life`. Code không biết tên chiêu.

const RECIPES: String = "res://assets/vfx/vfx.json"
const TEXTURES: String = "res://assets/vfx/%s.png"
const SWEEP_SHADER: Shader = preload("res://view/three/skill_sweep.gdshader")
const HIT_TICKS: int = 4  ## hằng số hiển thị: sát thương của chủ chiêu trong 4 tick sau khi chiêu ra coi là trúng chiêu
const SWEEP_SEGMENTS: int = 28  ## hằng số kỹ thuật: số đoạn của dải lưỡi liềm
const SWEEP_TAIL: float = 0.55  ## độ dài đuôi vệt quét (phần góc quạt), khớp `tail` của shader

static var _recipes: Dictionary = {}

var _items: Array[Array] = []  # [Node3D, loại, tuổi (giây), part]
var _armed: Dictionary[int, Array] = {}  # id chủ chiêu → [tick chiêu ra, part hit]


static func recipes() -> Dictionary:
	if _recipes.is_empty():
		_recipes = JSON.parse_string(FileAccess.get_file_as_string(RECIPES))
	return _recipes


func on_event(w: World, ev: GameEvent) -> void:
	match ev.type:
		&"ability_finished":
			_cast(w, ev)
		&"damage_taken":
			_hit(w, ev)


## Loại mảnh đang chạy (cho test / chẩn đoán).
func kinds() -> Array:
	return _items.map(func(it: Array) -> String: return it[1])


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	for it: Array in _items:
		it[2] += delta
		_animate(it)
	for it: Array in _items.filter(func(x: Array) -> bool: return x[2] >= float(x[3].get("life", 0.3))):
		(it[0] as Node3D).queue_free()
		_items.erase(it)


func _cast(w: World, ev: GameEvent) -> void:
	var e: Entity = w.find_entity(ev.source_id)
	var a: AbilityInstance = Abilities.of(e, int(ev.amount)) if e != null else null
	if a == null:
		return
	for part: Dictionary in recipes().get(String(a.def.art_id), {}).get("parts", []):
		match part["type"]:
			"sweep":
				_add(_sweep_node(e, a, part), "sweep", part, _ground(e.position, part))
			"burst":
				var at: Vector2 = e.position + e.facing * float(part.get("forward", 0.0)) / MatchView3D.S
				_add(_quad(part["tex"], part, false), "burst", part, _ground(at, part))
			"hit":
				_armed[e.id] = [w.tick, part]


func _hit(w: World, ev: GameEvent) -> void:
	var arm: Array = _armed.get(ev.source_id, [])
	var target: Entity = w.find_entity(ev.target_id)
	if arm.is_empty() or w.tick - int(arm[0]) > HIT_TICKS or ev.amount <= 0.0 or target == null:
		return
	var part: Dictionary = arm[1]
	var node: Node3D = _quad(part["tex"], part, true)
	if part.has("glow"):
		node.add_child(_quad(part["glow"], part, true))
	_add(node, "hit", part, _ground(target.position, part))


func _add(node: Node3D, kind: String, part: Dictionary, at: Vector3) -> void:
	node.position = at
	add_child(node)
	var it: Array = [node, kind, 0.0, part]
	_items.append(it)
	_animate(it)


static func _ground(p: Vector2, part: Dictionary) -> Vector3:
	return Vector3(p.x * MatchView3D.S, float(part.get("height", 0.0)), p.y * MatchView3D.S)


## Giá trị mảnh: số, hoặc tên giá trị của kỹ năng (theo cấp hiện tại).
static func _value(e: Entity, a: AbilityInstance, v: Variant) -> float:
	return Abilities.value(e, a, StringName(v)) if v is String else float(v)


func _sweep_node(e: Entity, a: AbilityInstance, part: Dictionary) -> MeshInstance3D:
	var radius: float = _value(e, a, part.get("radius", 300.0)) * MatchView3D.S
	var half: float = deg_to_rad(_value(e, a, part.get("angle", 120.0))) * 0.5
	var facing: float = e.facing.angle() if e.facing != Vector2.ZERO else 0.0
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in SWEEP_SEGMENTS + 1:
		var t: float = float(i) / SWEEP_SEGMENTS
		var d: Vector2 = Vector2.from_angle(facing + half - 2.0 * half * t)  # quét từ một mép quạt sang mép kia
		for v: float in [0.0, 1.0]:
			st.set_uv(Vector2(t, v))
			var r: float = radius * lerpf(float(part.get("inner", 0.3)), 1.0, v)
			st.add_vertex(Vector3(d.x * r, 0.0, d.y * r))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SWEEP_SHADER
	mat.set_shader_parameter("color", Color(part.get("color", "#4080ff")))
	mat.set_shader_parameter("edge", Color(part.get("edge", "#ffffff")))
	mat.set_shader_parameter("tail", SWEEP_TAIL)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Mặt phẳng luôn quay về camera, ảnh `tex` (bảng khung `frames` × `frames` nếu có), cộng sáng hoặc trong suốt.
static func _quad(tex: String, part: Dictionary, additive: bool) -> MeshInstance3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = load(TEXTURES % tex)
	mat.albedo_color = Color(part.get("color", "#ffffff"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.no_depth_test = additive
	var frames: int = int(part.get("frames", 1))
	mat.uv1_scale = Vector3(1.0 / frames, 1.0 / frames, 1.0)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE * float(part.get("size", 1.0))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _animate(it: Array) -> void:
	var part: Dictionary = it[3]
	var t: float = clampf(it[2] / float(part.get("life", 0.3)), 0.0, 1.0)
	match it[1]:
		"sweep":
			var mat: ShaderMaterial = (it[0] as MeshInstance3D).material_override
			mat.set_shader_parameter("progress", clampf(it[2] / float(part.get("sweep", 0.2)), 0.0, 1.0) * (1.0 + SWEEP_TAIL))
			mat.set_shader_parameter("fade", 1.0 - t * t)
		"burst":
			var frames: int = int(part.get("frames", 1))
			var k: int = mini(int(t * frames * frames), frames * frames - 1)
			var mat: StandardMaterial3D = (it[0] as MeshInstance3D).material_override
			mat.uv1_offset = Vector3(float(k % frames) / frames, float(k / frames) / frames, 0.0)
		"hit":
			(it[0] as Node3D).scale = Vector3.ONE * (0.4 + 1.2 * sin(PI * minf(t * 1.4, 1.0)))
			var mat: StandardMaterial3D = (it[0] as MeshInstance3D).material_override
			mat.albedo_color.a = 1.0 - t
