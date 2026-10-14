class_name ActiveZone
extends RefCounted
## Vùng tồn tại (ZoneAction, ABL-17): tâm và bán kính chốt lúc tung; từ `start_tick` mỗi
## `interval_ticks` chạy `actions` lên đơn vị hợp lệ trong vùng, tới trước `end_tick`.
## Có trong world.zones ngay từ lúc tung để hai đội cùng thấy.

var action: ZoneAction
var ctx: ExprContext
var source_id: int
var center: Vector2
var radius: float
var team: int
var start_tick: int
var end_tick: int
var interval_ticks: int
var next_tick: int
