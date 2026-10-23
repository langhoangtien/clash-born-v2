class_name DamageAction
extends ActionDef
## Gây sát thương (CMB-03). `reflected`: sát thương phản hồi (CMB-09).

@export var damage_type: DamageFormulas.DamageType = DamageFormulas.DamageType.PHYSICAL
@export var amount: String
@export var reflected: bool = false
## CMB-13: false = không nhân khuếch đại phép của nguồn (vd sát thương thêm của đòn đánh, D-132).
@export var amplified: bool = true
