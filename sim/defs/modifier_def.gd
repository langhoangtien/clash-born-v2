class_name ModifierDef
extends Resource
## Thay đổi một chỉ số (STAT-02, STAT-03). Cùng `unique_group` trên một đơn vị: chỉ
## nguồn có `unique_priority` cao nhất có tác dụng (STAT-05).

enum Op { ADD, MULTIPLY, OVERRIDE }

@export var stat: StringName
@export var op: Op = Op.ADD
@export var value: String
@export var unique_group: StringName
## Rỗng = dùng `value`.
@export var unique_priority: String
