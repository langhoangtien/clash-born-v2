class_name ZoneView3D
extends Node3D
## D-297: vùng kỹ năng trên đất vẽ 3D (thay ZonePainter phẳng — người chơi: vòng tròn viền rõ, không giống game):
## vùng tồn tại (World.zones, ABL-17) là vũng mép loang không đều, gợn + bọt chạy suốt thời gian vùng; vùng có độ trễ
## (World.pending_areas, ABL-06) là vùng nạp, lõi sáng lớn dần tới lúc nổ. Màu theo mảnh `zone` / `pending` trong công
## thức vfx.json của kỹ năng sinh ra vùng (không có thì màu phe). Cả hai đội đều thấy. Chỉ đọc World.
## D-298: mảnh `meteors` (count) — sao băng rơi xiên xuống vùng có độ trễ, mỗi viên lệch thời gian, chạm đất lúc nổ.

## Sao băng: độ cao bắt đầu (m), hướng rơi, phần thời gian một viên rơi — hằng số hiển thị.
const METEOR_HEIGHT: float = 5.0  # cao quá thì phần lớn đường rơi ra ngoài mép trên màn hình (camera nghiêng)
const METEOR_DIR: Vector3 = Vector3(0.35, -1.0, 0.0)
const METEOR_FALL: float = 0.45

var _items: Dictionary = {}  # ActiveZone | PendingArea → Node3D [vũng, sao băng…]


func sync(world: World) -> void:
	var seen: Dictionary = {}
	for z: ActiveZone in world.zones:
		seen[z] = true
		var span: float = maxf(1.0, z.end_tick - z.start_tick)
		_show(world, z, "zone", z.action, z.source_id, z.team, z.center, z.radius, clampf((world.tick - z.start_tick) / span, 0.0, 1.0))
	for p: PendingArea in world.pending_areas:
		if p.radius <= 0.0:
			continue
		seen[p] = true
		var span: float = maxf(1.0, p.due_tick - p.start_tick)
		_show(world, p, "pending", p.action, p.source_id, p.team, p.center, p.radius, clampf((world.tick - p.start_tick) / span, 0.0, 1.0))
	for k: Variant in _items.keys():
		if not seen.has(k):
			(_items[k] as Node3D).queue_free()
			_items.erase(k)


func count() -> int:
	return _items.size()


func _show(world: World, key: Variant, kind: String, action: ActionDef, source_id: int, team: int, center: Vector2,
		radius: float, t: float) -> void:
	if not _items.has(key):
		var root: Node3D = Node3D.new()
		root.position = Vector3(center.x * MatchView3D.S, VfxParts.GROUND_LIFT, center.y * MatchView3D.S)
		root.add_child(VfxParts.make(part_for(world, kind, action, source_id, team), radius * MatchView3D.S))
		var rain: Dictionary = part_for(world, "meteors", action, source_id, team) if kind == "pending" else {}
		if rain.has("count"):
			_add_meteors(root, rain, radius * MatchView3D.S)
		add_child(root)
		_items[key] = root
	var node: Node3D = _items[key]
	VfxParts.animate(node.get_child(0) as MeshInstance3D, t)
	for i: int in range(1, node.get_child_count()):
		_fall(node.get_child(i) as Node3D, t)


## Sao băng: vệt dọc hướng rơi (đầu ở +X) + đốm đầu; điểm chạm và thời điểm rơi rải theo số thứ tự (cố định).
static func _add_meteors(root: Node3D, part: Dictionary, radius: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var dir: Vector3 = METEOR_DIR.normalized()
	for i: int in int(part["count"]):
		var comet: Node3D = Node3D.new()
		var streak: Dictionary = part.duplicate()
		streak["type"] = "shot"
		var body: MeshInstance3D = VfxParts.make(streak, Vector2(2.2, float(part.get("size", 0.5))))
		body.rotation = Vector3(0, 0, atan2(dir.y, dir.x))  # mặt phẳng XY quay về camera nghiêng
		body.position = -dir * 1.1
		comet.add_child(body)
		var head: Dictionary = part.duplicate()
		head["type"] = "glow"
		comet.add_child(VfxParts.make(head, float(part.get("size", 0.5)) * 1.6))
		var at: Vector2 = Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * radius * 0.75
		comet.set_meta("land", Vector3(at.x, 0, at.y))
		comet.set_meta("start", rng.randf() * (1.0 - METEOR_FALL))
		comet.visible = false
		root.add_child(comet)


static func _fall(comet: Node3D, t: float) -> void:
	var k: float = (t - float(comet.get_meta("start"))) / METEOR_FALL
	comet.visible = k > 0.0 and k < 1.0
	comet.position = comet.get_meta("land") - METEOR_DIR.normalized() * METEOR_HEIGHT * (1.0 - clampf(k, 0.0, 1.0))


## Mảnh `kind` của kỹ năng (của chủ vùng) có chứa hành động sinh ra vùng; không có thì màu phe.
static func part_for(world: World, kind: String, action: ActionDef, source_id: int, team: int) -> Dictionary:
	var e: Entity = world.find_entity(source_id)
	if e != null:
		for a: AbilityInstance in e.abilities:
			if not _contains(a.def.on_cast, action):
				continue
			for part: Dictionary in SkillVfx3D.recipes().get(String(a.def.art_id), {}).get("parts", []):
				if part["type"] == kind:
					return part
	var col: Color = (UnitsView.BLUE if team == 0 else UnitsView.RED).lightened(0.3)
	return {"type": kind, "color": "#" + col.to_html(false), "alpha": 0.6}


## `action` có nằm trong cây hành động `list` (kể cả hành động con) không.
static func _contains(list: Array, action: ActionDef) -> bool:
	for a: Variant in list:
		if a == action:
			return true
		if a is Resource:
			for prop: Dictionary in (a as Resource).get_property_list():
				var v: Variant = (a as Resource).get(prop["name"])
				if v is Array and _contains(v, action):
					return true
				if v is ActionDef and _contains([v], action):
					return true
	return false
