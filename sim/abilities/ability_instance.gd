class_name AbilityInstance
extends RefCounted
## Kỹ năng đang có trên đơn vị (ABL). `rank` 0 = chưa học.

var def: AbilityDef
var slot: AbilityDef.Slot
var rank: int = 0
## Tick hết hồi chiêu (ABL-02).
var ready_tick: int = 0
## Hiệu ứng do `on_learn` áp (bị động); gỡ và áp lại khi lên cấp.
var learned_effects: Array[EffectInstance] = []
