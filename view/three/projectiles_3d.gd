class_name Projectiles3D
extends Node3D
## D-219: đạn đánh thường (World.projectiles) vẽ 3D trên không, hình theo đơn vị bắn: `projectile` trong cấu hình
## units_3d.json của đơn vị / công trình (shape: orb | bolt | arrow, hoặc `model` = mô hình GLB; color: mã màu hoặc
## "team"; size; arc = độ cao vòng cung / quãng bay). Không có thì dùng `projectiles.default`.
## Chỉ là hình: sim vẫn bay theo mục tiêu (CMB-06), vòng cung chỉ nâng độ cao hiển thị.

const LAUNCH: float = 1.0  ## độ cao lúc bắn (đơn vị 3D) — hằng số hiển thị
const LAND: float = 0.6  ## độ cao lúc trúng

var _items: Dictionary = {}  # Projectile → [Node3D, Vector2 điểm bắn, cfg, Vector2 điểm đích gần nhất, Vector3 trước]


func sync(world: World) -> void:
	var seen: Dictionary = {}
	for p: Projectile in world.projectiles:
		seen[p] = true
		if not _items.has(p):
			_items[p] = _make(world, p)
		_place(world, p)
	for p: Projectile in _items.keys():
		if not seen.has(p):
			(_items[p][0] as Node3D).queue_free()
			_items.erase(p)


func count() -> int:
	return _items.size()


func shape_of(p: Projectile) -> String:
	return (_items[p][2] as Dictionary).get("shape", "orb")


func node_of(p: Projectile) -> Node3D:
	return _items[p][0]


static func config_of(world: World, p: Projectile) -> Dictionary:
	var e: Entity = world.find_entity(p.source_id)
	var cfg: Dictionary = {}
	if e != null:
		cfg = ModelLibrary.unit(e.art_id)
		if cfg.is_empty():
			cfg = ModelLibrary.structure(e)
	return cfg.get("projectile", ModelLibrary.config().get("projectiles", {}).get("default", {}))


func _make(world: World, p: Projectile) -> Array:
	var cfg: Dictionary = config_of(world, p)
	var e: Entity = world.find_entity(p.source_id)
	var team: int = e.team if e != null else -1
	var node: Node3D
	if cfg.has("model"):
		node = ModelLibrary.static_scene(cfg["model"], team).instantiate() as Node3D
		ModelLibrary.apply_team_texture(node, cfg["model"], team)
	else:
		node = _primitive(cfg.get("shape", "orb"), _color(cfg.get("color", "#ffffff"), team))
	add_child(node)
	return [node, p.position, cfg, p.position, Vector3.INF]


func _color(spec: String, team: int) -> Color:
	if spec == "team":
		var colors: Array = ModelLibrary.config().get("projectiles", {}).get("team_colors", ["#ffffff", "#ffffff"])
		return Color(colors[team] if team >= 0 and team < colors.size() else "#ffffff")
	return Color(spec)


## Hình cơ bản, trục dài theo −Z (hướng bay sau Basis.looking_at).
func _primitive(shape: String, color: Color) -> Node3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	if shape == "orb":
		var s: SphereMesh = SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 8
		s.rings = 4
		mi.mesh = s
	else:  # bolt: mảnh tinh thể nhọn; arrow: que mảnh dài
		var c: CylinderMesh = CylinderMesh.new()
		c.top_radius = 0.0 if shape == "bolt" else 0.05
		c.bottom_radius = 0.3 if shape == "bolt" else 0.05
		c.height = 1.6 if shape == "bolt" else 1.4
		c.radial_segments = 5
		mi.mesh = c
		mi.rotation.x = -PI / 2
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mi.material_override = m
	var holder: Node3D = Node3D.new()
	holder.add_child(mi)
	return holder


func _place(world: World, p: Projectile) -> void:
	var item: Array = _items[p]
	var cfg: Dictionary = item[2]
	var target: Entity = world.find_entity(p.target_id)
	if target != null:
		item[3] = target.position
	var start: Vector2 = item[1]
	var done: float = start.distance_to(p.position)
	var left: float = p.position.distance_to(item[3])
	var s: float = done / maxf(done + left, 0.001)
	var arc: float = float(cfg.get("arc", 0.0)) * (done + left) * MatchView3D.S
	var at: Vector3 = Vector3(p.position.x * MatchView3D.S, lerpf(LAUNCH, LAND, s) + arc * 4.0 * s * (1.0 - s),
			p.position.y * MatchView3D.S)
	var node: Node3D = item[0]
	var dir: Vector3 = at - item[4] if item[4] != Vector3.INF else Vector3(item[3].x - start.x, 0, item[3].y - start.y)
	var basis: Basis = node.basis.orthonormalized()
	if dir.length() > 0.0001 and absf(dir.normalized().y) < 0.999:
		basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	node.transform = Transform3D(basis.scaled(Vector3.ONE * float(cfg.get("size", 0.15))), at)
	item[4] = at
