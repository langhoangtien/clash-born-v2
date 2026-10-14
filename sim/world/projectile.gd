class_name Projectile
extends RefCounted
## Đạn đánh thường bay theo mục tiêu (CMB-06). Sát thương chốt lúc bắn.

var source_id: int
var target_id: int
var position: Vector2
var speed: float
var request: DamageRequest
