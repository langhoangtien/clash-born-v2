class_name PurgeAction
extends ActionDef
## Tước (EFF-07): gỡ buff của địch ở mức `level`; `on_each` chạy cho mỗi buff gỡ được.

@export var level: EffectDef.Dispel = EffectDef.Dispel.BASIC
@export var on_each: Array[ActionDef] = []
