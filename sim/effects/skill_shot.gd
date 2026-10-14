class_name SkillShot
extends RefCounted
## Đạn kỹ năng định hướng đang bay (ABL-05). SkillShotSystem di chuyển và xét trúng.

var source_id: int
var origin: Vector2
var position: Vector2
var direction: Vector2
var speed: float
var max_range: float
var travelled: float = 0.0
var half_width: float
var pierce: bool = false
var hit_ids: Dictionary[int, bool] = {}
var actions: Array[ActionDef] = []
var ctx: ExprContext
var team: int
