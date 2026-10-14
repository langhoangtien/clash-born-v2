class_name PendingArea
extends RefCounted
## Vùng có độ trễ đã chốt tâm/hướng lúc tung, chờ tới `due_tick` (AreaAction.delay).

var due_tick: int
var action: AreaAction
var ctx: ExprContext
var source_id: int
var center: Vector2
