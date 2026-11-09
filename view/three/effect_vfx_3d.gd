class_name EffectVfx3D
extends Node3D
## D-298: hiệu ứng 3D cho hiệu ứng đang có trên đơn vị (lốc xoáy của Gậy Lốc Xoáy, trói của Rìu Xiềng Xích, đóng băng
## của Myra…) theo mục "_effects" của vfx.json (khóa = id hiệu ứng): các mảnh đi theo đơn vị suốt thời gian hiệu ứng
## (t = phần thời gian đã qua). Đơn vị phe kia không thấy thì không vẽ. Thay các vòng tròn 2D tương ứng (StateMarks).
## D-299: mục "_states" (khóa = tên trạng thái, vd STUNNED) — hình chung cho trạng thái khi không hiệu ứng nào của nó
## có hình riêng (sao choáng 3D trên đầu); hiệu ứng có `lift` / `spin` (lốc xoáy) nhấc hình đơn vị lên và xoay (`pose`).
## D-305: mục `_effects` có `tint` / `tint_alpha` — phủ màu (băng) lên mô hình đơn vị (Actor3D) thay vòng chậm 2D.
## Chỉ đọc World.

## Vị trí 3D đang vẽ của đơn vị (MatchView3D đặt = vị trí nội suy).
var position_of: Callable = func(e: Entity) -> Vector3: return Vector3(e.position.x, 0, e.position.y) * MatchView3D.S
var _items: Dictionary = {}  # EffectInstance → Node3D


static func parts_of(id: StringName) -> Array:
	return SkillVfx3D.recipes().get("_effects", {}).get(String(id), {}).get("parts", [])


## D-305: màu phủ của hiệu ứng `id` (alpha 0 = không phủ).
static func tint_of_id(id: StringName) -> Color:
	var r: Dictionary = SkillVfx3D.recipes().get("_effects", {}).get(String(id), {})
	return Color(r["tint"], float(r.get("tint_alpha", 0.5))) if r.has("tint") else Color(0, 0, 0, 0)


## D-305: màu phủ lên đơn vị — hiệu ứng có `tint` đậm nhất đang có.
static func tint_of(e: Entity) -> Color:
	var out: Color = Color(0, 0, 0, 0)
	for inst: EffectInstance in e.effects:
		var c: Color = tint_of_id(inst.def.id)
		if c.a > out.a:
			out = c
	return out


static func state_parts(state: int) -> Array:
	return SkillVfx3D.recipes().get("_states", {}).get(UnitState.Id.keys()[state], {}).get("parts", [])


## Trạng thái `state` của đơn vị do một hiệu ứng có hình riêng gây ra.
static func covered_by_effect(e: Entity, state: int) -> bool:
	for inst: EffectInstance in e.effects:
		if inst.def.states.has(state) and not parts_of(inst.def.id).is_empty():
			return true
	return false


## Trạng thái `state` của đơn vị đang được vẽ 3D (StateMarks bỏ dấu 2D trùng).
static func covers(e: Entity, state: int) -> bool:
	return covered_by_effect(e, state) or (Rules.has_state(e, state) and not state_parts(state).is_empty())


## D-299: hiệu ứng có `lift` (m) / `spin` (vòng / giây) — lốc xoáy nhấc hình đơn vị lên và xoay (sau Actor3D.sync).
static func pose(world: World, e: Entity, actor: Node3D) -> void:
	for inst: EffectInstance in e.effects:
		var r: Dictionary = SkillVfx3D.recipes().get("_effects", {}).get(String(inst.def.id), {})
		if not r.has("lift"):
			continue
		var age: float = (world.tick - inst.start_tick) * SimClock.TICK_SECONDS
		var left: float = (inst.end_tick - world.tick) * SimClock.TICK_SECONDS
		actor.position.y += float(r["lift"]) * smoothstep(0.0, 0.4, age) * smoothstep(0.0, 0.3, left)
		actor.rotation.y += float(r.get("spin", 0.0)) * TAU * age


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
		for state: int in UnitState.Id.values():
			if Rules.has_state(e, state) and not state_parts(state).is_empty() and not covered_by_effect(e, state):
				var key: String = "%d:%d" % [e.id, state]
				live[key] = true
				if not _items.has(key):
					_items[key] = _make(e, state_parts(state))
				(_items[key] as Node3D).position = position_of.call(e)
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
