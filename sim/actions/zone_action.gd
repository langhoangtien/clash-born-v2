class_name ZoneAction
extends ActionDef
## Vùng tồn tại một lúc, chạy `actions` định kỳ lên đơn vị trong vùng.

@export var radius: String
@export var duration: String
@export var interval: String
@export var actions: Array[ActionDef] = []
