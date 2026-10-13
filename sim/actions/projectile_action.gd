class_name ProjectileAction
extends ActionDef
## Đạn định hướng (ABL-05).

@export var travel_range: String
@export var width: String
@export var speed: String
@export var pierce: bool = false
@export var on_hit: Array[ActionDef] = []
