class_name GroundShadows
extends RefCounted
## Bóng cây nướng sẵn xuống lớp đất (thử phối màu theo concept): cây cố định theo map nên vẽ một
## lần lúc vào trận, không tốn gì mỗi khung. Bóng lệch theo hướng nắng (Look3D), tâm đậm, mép mờ.

const COLOR: Color = Color(0.08, 0.13, 0.04)
## Số vòng chồng nhau cho mép mềm, độ đục mỗi vòng.
const RINGS: int = 10
const RING_ALPHA: float = 0.075
## Tán cây: bán kính bóng và độ lệch theo nắng, theo cỡ mô hình (đơn vị mô hình).
const SPREAD: float = 0.55
const REACH: float = 0.45

static func paint(ci: CanvasItem, layout: MapLayout) -> void:
	var cfg: Dictionary = ModelLibrary.scenery()
	if cfg.is_empty():
		return
	var sun: Vector2 = Look3D.sun_ground_direction()
	for it: Array in Scenery3D.tree_items(layout):
		_tree(ci, it, RockWalls3D.model_bounds(cfg["trees"][it[1]]), sun)
	for it: Array in GiantTrees3D.items(layout):  # D-170
		_tree(ci, it, RockWalls3D.model_bounds(cfg["giants"]["models"][it[1]]), sun)


## Bóng một cây: lệch theo nắng, cỡ theo tán (cây cao hơn thì bóng dài hơn).
static func _tree(ci: CanvasItem, it: Array, box: AABB, sun: Vector2) -> void:
	var height: float = box.size.y * it[2] / MatchView3D.S
	var crown: float = maxf(box.size.x, box.size.z) * it[2] / MatchView3D.S * 0.5
	_blob(ci, it[0] + sun * height * REACH, maxf(crown, height * SPREAD * 0.6), sun)


## Đĩa bóng mềm, kéo dài theo hướng nắng.
static func _blob(ci: CanvasItem, at: Vector2, radius: float, along: Vector2) -> void:
	ci.draw_set_transform(at, along.angle(), Vector2(1.25, 0.85))
	for k: int in RINGS:
		ci.draw_circle(Vector2.ZERO, radius * (1.0 - 0.055 * k), Color(COLOR, RING_ALPHA))
	ci.draw_set_transform(Vector2.ZERO)
