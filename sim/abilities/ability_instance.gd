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
## TAL: talent của kỹ năng này đã chọn; bản hiệu ứng đã vá theo talent (TAL-02c), nhớ theo hiệu ứng gốc.
var talent_active: bool = false
var patched: Dictionary[EffectDef, EffectDef] = {}
## ITM-07: chỉ số ô đồ (0..5) nếu là kỹ năng của món đồ, -1 nếu là kỹ năng hero.
var item_index: int = -1
