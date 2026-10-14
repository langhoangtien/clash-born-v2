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
## STAT-05 (D-55): cùng nhóm trên một đơn vị chỉ một nguồn tung (đồ thắng skill, ô sau thắng ô trước).
@export var unique_group: StringName
@export var actions: Array[ActionDef] = []
