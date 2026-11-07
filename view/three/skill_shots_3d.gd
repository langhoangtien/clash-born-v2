class_name SkillShots3D
extends Node3D
## D-296: đạn kỹ năng định hướng (World.skill_shots, ABL-05) vẽ 3D: vệt sáng dịu bay ngang mặt đất + đốm sáng ở đầu,
## màu theo mảnh `shot` trong công thức vfx.json của kỹ năng có đạn của chủ (không có thì màu sáng của phe). Đạn địch
## ngoài tầm nhìn không vẽ. Thay đường kẻ 2D trên mặt đất cũ (UnitsView). Chỉ đọc World.

## Độ cao (m) đạn bay và độ dài vệt (px) — hằng số hiển thị.
const HEIGHT: float = 0.7
const TRAIL_PX: float = 220.0

var viewer_team: int = -1
var _items: Dictionary = {}  # SkillShot → Node3D


func sync(world: World) -> void:
	var seen: Dictionary = {}
	for s: SkillShot in world.skill_shots:
		if viewer_team >= 0 and s.team != viewer_team and not FogView.lit(world, viewer_team, s.position):
			continue
		seen[s] = true
		if not _items.has(s):
			_items[s] = _make(world, s)
		_place(_items[s], s)
	for s: SkillShot in _items.keys():
		if not seen.has(s):
			(_items[s] as Node3D).queue_free()
			_items.erase(s)


func count() -> int:
	return _items.size()


## Mảnh `shot` của chủ đạn (kỹ năng đầu tiên có mảnh này trong vfx.json).
static func shot_part(world: World, s: SkillShot) -> Dictionary:
	var e: Entity = world.find_entity(s.source_id)
	if e != null:
		for a: AbilityInstance in e.abilities:
			for part: Dictionary in SkillVfx3D.recipes().get(String(a.def.art_id), {}).get("parts", []):
				if part["type"] == "shot":
					return part
	var col: Color = (UnitsView.BLUE if s.team == 0 else UnitsView.RED).lightened(0.4)
	return {"type": "shot", "color": "#" + col.to_html(false), "alpha": 0.7}


func _make(world: World, s: SkillShot) -> Node3D:
	var part: Dictionary = shot_part(world, s)
	var root: Node3D = Node3D.new()
	var w: float = maxf(s.half_width * 2.0, 70.0) * MatchView3D.S
	var streak: MeshInstance3D = VfxParts.make(part, Vector2(TRAIL_PX * MatchView3D.S, w))
	streak.position.x = -TRAIL_PX * 0.5 * MatchView3D.S  # đầu vệt ở gốc nút (vị trí đạn)
	root.add_child(streak)
	var head: Dictionary = part.duplicate()
	head["type"] = "glow"
	root.add_child(VfxParts.make(head, float(part.get("size", 0.9))))
	add_child(root)
	return root


static func _place(node: Node3D, s: SkillShot) -> void:
	node.position = Vector3(s.position.x * MatchView3D.S, HEIGHT, s.position.y * MatchView3D.S)
	node.rotation.y = atan2(-s.direction.y, s.direction.x)
