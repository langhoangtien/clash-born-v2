class_name SkillVfx3D
extends Node3D
## D-247: hiệu ứng chiêu 3D theo công thức dữ liệu (assets/vfx/vfx.json, khóa = art_id kỹ năng). Chỉ đọc World:
## `ability_finished` (chiêu ra, đúng lúc gây tác dụng) sinh các mảnh của công thức; `damage_taken` do chủ chiêu gây
## trong HIT_TICKS tick sau đó sinh tia lóe trên mục tiêu. Mảnh tự gỡ khi hết `life`. Code không biết tên chiêu.
## `trail` (D-250, D-256): vệt tốc độ bám theo đường chạy của chủ chiêu suốt `life` (SpeedTrail3D), chỉ hiện khi chạy.
## `arc` (D-252): ảnh quạt vẽ tay nằm phẳng trước mặt chủ chiêu, đỉnh quạt ở chân, cỡ theo bán kính / góc của kỹ năng.
## D-296: mảnh "dịu" dựng bằng shader (VfxParts: ring, disc, pillar, glow, aura, wave) đặt ở chủ chiêu / điểm chọn /
## mục tiêu; `aura` đi theo đơn vị suốt `life`. Tia lóe khi trúng (`hit`) là đốm dịu trộn alpha (trước: cộng sáng xuyên
## mọi vật → W Duy Anh chói mắt).

const RECIPES: String = "res://assets/vfx/vfx.json"
const TEXTURES: String = "res://assets/vfx/%s.png"
const TINT_SHADER: Shader = preload("res://view/three/skill_tint.gdshader")
const HIT_TICKS: int = 4  ## hằng số hiển thị: sát thương của chủ chiêu trong 4 tick sau khi chiêu ra coi là trúng chiêu

static var _recipes: Dictionary = {}
## D-270: ảnh hiệu ứng giữ suốt trận. Trước đây mỗi lần tung chiêu `load()` lại; hiệu ứng trước đã gỡ thì ảnh bị
## thả khỏi bộ nhớ → đọc đĩa lại mỗi lần (W Duy Anh: ảnh 2048² ~50–70 ms máy chủ, 100–375 ms máy tính bảng).
static var _textures: Dictionary[String, Texture2D] = {}
## Khóa trong mảnh công thức (vfx.json) trỏ tới ảnh.
const TEX_KEYS: Array[String] = ["tex", "glow", "sparks"]

var _items: Array[Array] = []  # [Node3D, loại, tuổi (giây), part, id chủ chiêu]
var _world: World
## Vị trí 3D đang vẽ của đơn vị (MatchView3D đặt = vị trí nội suy); mặc định theo vị trí sim.
var position_of: Callable = func(e: Entity) -> Vector3: return _ground(e.position, {})
var _armed: Dictionary[int, Array] = {}  # id chủ chiêu → [tick chiêu ra, part hit]


static func recipes() -> Dictionary:
	if _recipes.is_empty():
		_recipes = JSON.parse_string(FileAccess.get_file_as_string(RECIPES))
	return _recipes


## D-270: vào trận nạp một lần mọi ảnh trong công thức.
func _ready() -> void:
	load_textures()


static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		_textures[name] = load(TEXTURES % name) as Texture2D
	return _textures[name]


static func recipe_textures() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key: String in recipes():
		if recipes()[key] is Dictionary:
			for part: Dictionary in recipes()[key].get("parts", []):
				for k: String in TEX_KEYS:
					if part.has(k) and not out.has(part[k]):
						out.append(part[k])
	return out


static func load_textures() -> void:
	for name: String in recipe_textures():
		texture(name)


static func has_texture(name: String) -> bool:
	return _textures.has(name)


static func forget_textures_for_test() -> void:
	_textures.clear()


func on_event(w: World, ev: GameEvent) -> void:
	_world = w
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
		if it[1] == "trail":
			_follow(it, delta)
		elif it[1] == "aura":
			_stick(it)
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
			"arc":
				_add(_arc_node(e, a, part), "arc", part, _ground(e.position, part))
			"hit":
				_armed[e.id] = [w.tick, part]
			"trail":
				var live: Dictionary = part.duplicate()
				live["life"] = _value(e, a, part.get("life", 1.0))
				_add(SpeedTrail3D.make(live, _tint_material(live)), "trail", live, Vector3.ZERO, e.id)
			_ when VfxParts.is_soft(part["type"]) and part["type"] != "shot":  # shot: SkillShots3D
				_soft(w, e, a, ev, part)


## D-296: mảnh dịu ở chủ chiêu / điểm chọn / mục tiêu; `aura` bám theo đơn vị đó.
func _soft(w: World, e: Entity, a: AbilityInstance, ev: GameEvent, part: Dictionary) -> void:
	var live: Dictionary = part.duplicate()
	live["life"] = _value(e, a, part.get("life", 0.5))
	var anchor: Entity = e
	var at: Vector2 = e.position
	match String(part.get("at", "caster")):
		"point":
			at = ev.point if ev.point.is_finite() else at
		"target":
			anchor = w.find_entity(ev.target_id) if ev.target_id >= 0 else e
			if anchor == null:
				return
			at = anchor.position
	var px: float = _value(e, a, part.get("radius", anchor.radius * 1.6))
	var size: Variant = px * MatchView3D.S
	if part["type"] == "glow":
		size = float(part.get("size", 1.0))
	elif part["type"] == "wave":
		size = Vector2(_value(e, a, part.get("width", 200.0)), _value(e, a, part.get("length", 600.0))) * MatchView3D.S
	var node: Node3D = Node3D.new()
	node.add_child(VfxParts.make(part, size))
	var dir: Vector2 = ev.direction if ev.direction != Vector2.ZERO else e.facing
	if dir != Vector2.ZERO:
		node.rotation.y = atan2(-dir.x, -dir.y)
	var lift: float = float(part.get("height", VfxParts.GROUND_LIFT))
	_add(node, part["type"], live, _ground(at, {"height": lift}), anchor.id if part["type"] == "aura" else -1)


func _hit(w: World, ev: GameEvent) -> void:
	var arm: Array = _armed.get(ev.source_id, [])
	var target: Entity = w.find_entity(ev.target_id)
	if arm.is_empty() or w.tick - int(arm[0]) > HIT_TICKS or ev.amount <= 0.0 or target == null:
		return
	var part: Dictionary = arm[1]
	var node: Node3D = Node3D.new()
	node.add_child(VfxParts.make(soft_hit(part), float(part.get("size", 0.8))))  # D-296: đốm dịu, không cộng sáng
	_add(node, "hit", part, _ground(target.position, part))


## Mảnh `hit` trong công thức → đốm sáng dịu.
static func soft_hit(part: Dictionary) -> Dictionary:
	var p: Dictionary = part.duplicate()
	p["type"] = "glow"
	p["alpha"] = part.get("alpha", 0.55)
	return p


func _add(node: Node3D, kind: String, part: Dictionary, at: Vector3, owner_id: int = -1) -> void:
	node.position = at
	add_child(node)
	var it: Array = [node, kind, 0.0, part, owner_id]
	_items.append(it)
	_animate(it)


static func _ground(p: Vector2, part: Dictionary) -> Vector3:
	return Vector3(p.x * MatchView3D.S, float(part.get("height", 0.0)), p.y * MatchView3D.S)


## Giá trị mảnh: số, hoặc tên giá trị của kỹ năng (theo cấp hiện tại).
static func _value(e: Entity, a: AbilityInstance, v: Variant) -> float:
	return Abilities.value(e, a, StringName(v)) if v is String else float(v)


## Quạt vẽ tay: trong mỗi khung ảnh, đỉnh quạt ở (`apex_x`, `apex_y`) (phần cỡ khung, gốc trên trái), nửa bề ngang cung
## `half_w`, sâu `depth` (phần cỡ khung) → kéo giãn cho nửa bề ngang = R·sin(góc/2), độ sâu = R.
func _arc_node(e: Entity, a: AbilityInstance, part: Dictionary) -> Node3D:
	var radius: float = _value(e, a, part.get("radius", 300.0)) * MatchView3D.S
	var half: float = deg_to_rad(_value(e, a, part.get("angle", 150.0))) * 0.5
	var sx: float = radius * sin(minf(half, PI * 0.5)) / float(part.get("half_w", 0.4))
	var sy: float = radius / float(part.get("depth", 0.34))
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(sx, sy)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = _tint_material(part)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.x = -PI * 0.5  # nằm phẳng, phía trên ảnh hướng ra trước
	mi.position = Vector3((float(part.get("apex_x", 0.5)) - 0.5) * sx, 0.0, -(float(part.get("apex_y", 0.84)) - 0.5) * sy)
	var root: Node3D = Node3D.new()
	var f: Vector2 = e.facing if e.facing != Vector2.ZERO else Vector2.DOWN
	root.rotation.y = atan2(-f.x, -f.y)
	root.add_child(mi)
	return root


static func _tint_material(part: Dictionary) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = TINT_SHADER
	mat.set_shader_parameter("tex", texture(part["tex"]))
	mat.set_shader_parameter("tint", part.has("color"))
	mat.set_shader_parameter("color", Color(part.get("color", "#ffffff")))
	mat.set_shader_parameter("edge", Color(part.get("edge", "#ffffff")))
	mat.set_shader_parameter("frames", float(part.get("frames", 1)))
	var ur: Array = part.get("u_range", [0.0, 1.0])
	mat.set_shader_parameter("u_range", Vector2(ur[0], ur[1]))
	mat.set_shader_parameter("tail_fade", 1.0 if part["type"] == "trail" else 0.0)
	return mat


func _follow(it: Array, delta: float) -> void:
	var e: Entity = _world.find_entity(it[4]) if _world != null else null
	if e == null or not e.alive:
		it[2] = INF
		return
	var trail: SpeedTrail3D = it[0]
	var at: Vector3 = position_of.call(e)
	var moving: bool = it.size() < 6 or at.distance_to(it[5]) > 0.0005  # so với khung trước (khung đầu coi là đang chạy)
	it.resize(6)
	it[5] = at
	trail.update(at, moving, delta)


## D-296: hào quang đi theo đơn vị (chết / mất thì tắt).
func _stick(it: Array) -> void:
	var e: Entity = _world.find_entity(it[4]) if _world != null else null
	if e == null or not e.alive:
		it[2] = INF
		return
	var at: Vector3 = position_of.call(e)
	(it[0] as Node3D).position = Vector3(at.x, float(it[3].get("height", VfxParts.GROUND_LIFT)), at.z)


func _animate(it: Array) -> void:
	var part: Dictionary = it[3]
	var t: float = clampf(it[2] / float(part.get("life", 0.3)), 0.0, 1.0)
	if it[1] == "hit" or VfxParts.is_soft(it[1]):
		VfxParts.animate((it[0] as Node3D).get_child(0) as MeshInstance3D, t)
		return
	match it[1]:
		"arc":
			var mat: ShaderMaterial = ((it[0] as Node3D).get_child(0) as MeshInstance3D).material_override
			var frames: int = int(part.get("frames", 1))
			mat.set_shader_parameter("frame", float(mini(int(t * frames * frames), frames * frames - 1)))
			if frames == 1:  # ảnh đơn: hiện nhanh rồi tan
				mat.set_shader_parameter("fade", float(part.get("alpha", 1.0)) * minf(1.0, t * 6.0) * (1.0 - t * t))
			else:  # D-296: bảng khung cũng theo `alpha` của công thức
				mat.set_shader_parameter("fade", float(part.get("alpha", 1.0)))
		"trail":
			(it[0] as SpeedTrail3D).set_fade(1.0 - smoothstep(0.85, 1.0, t))
