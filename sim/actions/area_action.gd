class_name AreaAction
extends ActionDef
## Vùng tròn (ABL-06, ABL-07): sau `delay` chạy `actions` lên mọi đơn vị hợp lệ trong
## vùng. `target` = tâm vùng. `falloff`: hệ số giảm theo khoảng cách (vd Spectre).

@export var radius: String
@export var delay: String
@export var falloff: String
@export var actions: Array[ActionDef] = []
