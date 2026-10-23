class_name DamageRequest
extends RefCounted
## Yêu cầu gây sát thương; chỉ DamageSystem trừ máu (ARCHITECTURE mục 4).

var source_id: int
var target_id: int
var raw: float
var damage_type: DamageFormulas.DamageType = DamageFormulas.DamageType.PHYSICAL
var is_attack: bool = false
## CMB-07: đòn đánh chí mạng (đã nhân vào raw).
var crit: bool = false
## CMB-09: sát thương phản hồi.
var reflected: bool = false
## ST-15: nguồn xuyên miễn phép (bỏ qua đúng bước MAGIC_IMMUNE, PRI-05).
var pierces_magic_immunity: bool = false
## DUL-04b: kẻ gây hồi máu bằng phần này của sát thương gây ra (sau giáp, trước khiên).
var heal_source: float = 0.0


static func attack(source: Entity, target_id: int) -> DamageRequest:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source.id
	r.target_id = target_id
	r.raw = source.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE)
	r.is_attack = true
	return r
