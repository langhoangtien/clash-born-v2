class_name ZoneView3D
extends Node3D
## D-297: vùng kỹ năng trên đất vẽ 3D (thay ZonePainter phẳng — người chơi: vòng tròn viền rõ, không giống game):
## vùng tồn tại (World.zones, ABL-17) là vũng mép loang không đều, gợn + bọt chạy suốt thời gian vùng; vùng có độ trễ
## (World.pending_areas, ABL-06) là vùng nạp, lõi sáng lớn dần tới lúc nổ. Màu theo mảnh `zone` / `pending` trong công
## thức vfx.json của kỹ năng sinh ra vùng (không có thì màu phe). Cả hai đội đều thấy. Chỉ đọc World.

var _items: Dictionary = {}  # ActiveZone | PendingArea → MeshInstance3D


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
		var mi: MeshInstance3D = VfxParts.make(part_for(world, kind, action, source_id, team), radius * MatchView3D.S)
		mi.position = Vector3(center.x * MatchView3D.S, VfxParts.GROUND_LIFT, center.y * MatchView3D.S)
		add_child(mi)
		_items[key] = mi
	VfxParts.animate(_items[key], t)


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
