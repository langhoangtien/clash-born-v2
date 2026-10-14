class_name CastState
extends RefCounted
## Đang tung chiêu (cast_time > 0): chờ tới `release_tick` rồi chạy on_cast (ABL-02, ABL-03).

var ability: AbilityInstance
var release_tick: int
var target_id: int = -1
var point: Vector2 = Vector2.INF
var direction: Vector2 = Vector2.ZERO
