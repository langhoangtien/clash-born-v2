class_name CombatStatsDef
extends Resource
## Chỉ số gốc dùng chung cho hero và đơn vị (STAT-01). Hero cộng thêm phần từ thuộc
## tính (STAT-04).

@export var base_hp: float
@export var base_mana: float
@export var base_hp_regen: float
@export var base_mana_regen: float
@export var base_damage: float
@export var physical_armor: float
@export var magic_armor: float
@export var base_attack_time: float
## Thời điểm ra đòn trong nhịp đánh, giây (CMB-06).
@export var attack_point: float
@export var attack_range: float
## 0 = cận chiến (đòn đánh trúng ngay).
@export var projectile_speed: float
@export var movement_speed: float
@export var vision_range: float
@export var collision_radius: float
