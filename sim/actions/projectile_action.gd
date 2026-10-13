class_name ProjectileAction
extends ActionDef
## Đạn định hướng (ABL-05).

@export var travel_range: String
@export var width: String
@export var speed: String
## Cờ (ABL-14): 0 = dừng ở kẻ địch đầu tiên, khác 0 = xuyên.
@export var pierce: String
@export var on_hit: Array[ActionDef] = []
