class_name HeroDef
extends GameDef
## Một hero: chỉ số, tăng trưởng thuộc tính (STAT-04, không có sát thương mỗi cấp),
## nội tại + Q/W/R, thứ tự nâng skill và chọn talent cho bot (BOT-14).

enum Upgrade { Q, W, R, ATTRIBUTES }

@export var primary_attribute: StatFormulas.Attribute = StatFormulas.Attribute.STRENGTH
@export var base_strength: float
@export var base_agility: float
@export var base_intelligence: float
@export var strength_growth: float
@export var agility_growth: float
@export var intelligence_growth: float
@export var stats: CombatStatsDef
@export var innate: AbilityDef
@export var q: AbilityDef
@export var w: AbilityDef
@export var r: AbilityDef
## Lựa chọn ở mỗi lần lên cấp; ATTRIBUTES = đổi điểm lấy thuộc tính (ABL-04).
@export var bot_skill_order: Array[Upgrade] = []
@export var bot_talent_priority: Array[AbilityDef.Slot] = []


func abilities() -> Array[AbilityDef]:
	return [innate, q, w, r]
