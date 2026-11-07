class_name EffectVfx3D
extends Node3D
## D-298: hiệu ứng 3D cho hiệu ứng đang có trên đơn vị (lốc xoáy của Gậy Lốc Xoáy, trói của Rìu Xiềng Xích, đóng băng
## của Myra…) theo mục "_effects" của vfx.json (khóa = id hiệu ứng): các mảnh đi theo đơn vị suốt thời gian hiệu ứng
## (t = phần thời gian đã qua). Đơn vị phe kia không thấy thì không vẽ. Thay các vòng tròn 2D tương ứng (StateMarks).
## Chỉ đọc World.

## Vị trí 3D đang vẽ của đơn vị (MatchView3D đặt = vị trí nội suy).
var position_of: Callable = func(e: Entity) -> Vector3: return Vector3(e.position.x, 0, e.position.y) * MatchView3D.S
var _items: Dictionary = {}  # EffectInstance → Node3D


static func parts_of(id: StringName) -> Array:
	return SkillVfx3D.recipes().get("_effects", {}).get(String(id), {}).get("parts", [])


## Trạng thái `state` của đơn vị đến từ hiệu ứng được vẽ 3D (StateMarks bỏ dấu 2D trùng).
static func covers(e: Entity, state: int) -> bool:
	for inst: EffectInstance in e.effects:
		if inst.def.states.has(state) and not parts_of(inst.def.id).is_empty():
			return true
	return false


func sync(world: World, seen: Callable) -> void:
	var live: Dictionary = {}
	for e: Entity in world.entities:
		if not e.alive or not seen.call(e):
			continue
		for inst: EffectInstance in e.effects:
			var parts: Array = parts_of(inst.def.id)
			if parts.is_empty():
				continue
			live[inst] = true
			if not _items.has(inst):
				_items[inst] = _make(e, parts)
			var node: Node3D = _items[inst]
			node.position = position_of.call(e)
			var span: float = float(inst.end_tick - inst.start_tick)
			var t: float = clampf((world.tick - inst.start_tick) / span, 0.0, 1.0) if span > 0.0 else 0.5
			for child: Node in node.get_children():
				VfxParts.animate(child as MeshInstance3D, t)
	for inst: Variant in _items.keys():
		if not live.has(inst):
			(_items[inst] as Node3D).queue_free()
			_items.erase(inst)


func count() -> int:
	return _items.size()


func _make(e: Entity, parts: Array) -> Node3D:
	var root: Node3D = Node3D.new()
	for part: Dictionary in parts:
		var px: float = float(part.get("radius", e.radius * 1.6))
		var mi: MeshInstance3D = VfxParts.make(part, px * MatchView3D.S)
		mi.position.y += float(part.get("height", VfxParts.GROUND_LIFT))
		root.add_child(mi)
	add_child(root)
	return root
