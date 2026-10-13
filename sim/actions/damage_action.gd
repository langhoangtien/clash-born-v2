class_name DamageAction
extends ActionDef
## Gây sát thương (CMB-03). `reflected`: sát thương phản hồi (CMB-09).

@export var damage_type: DamageFormulas.DamageType = DamageFormulas.DamageType.PHYSICAL
@export var amount: String
@export var reflected: bool = false
