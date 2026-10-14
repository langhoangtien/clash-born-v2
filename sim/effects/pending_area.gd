class_name PendingArea
extends RefCounted
## Vùng có độ trễ đã chốt tâm/hướng lúc tung, chờ tới `due_tick` (AreaAction.delay).
## Hai đội đều thấy từ `start_tick` (ABL-06): VIEW vẽ vòng báo trước theo `radius`, `team`.

var due_tick: int
var start_tick: int
var action: AreaAction
var ctx: ExprContext
var source_id: int
var center: Vector2
var radius: float
var team: int
