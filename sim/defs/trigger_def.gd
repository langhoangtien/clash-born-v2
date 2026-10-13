class_name TriggerDef
extends Resource
## Phản ứng với sự kiện (ARCHITECTURE 3.5, EFF-08). `role`: vai của chủ hiệu ứng.

enum Role { SOURCE, TARGET }

@export var event: StringName
@export var role: Role = Role.SOURCE
## Xác suất 0..1 (PRD, RNG-01). Rỗng = luôn kích hoạt.
@export var chance: String
@export var condition: StringName
## Thời gian chờ giữa hai lần kích hoạt (giây). Rỗng = không chờ.
@export var cooldown: String
@export var unique_group: StringName
@export var unique_priority: String
@export var actions: Array[ActionDef] = []
