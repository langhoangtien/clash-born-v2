class_name ModifierDef
extends Resource
## Thay đổi một chỉ số (STAT-02, STAT-03). Cùng `unique_group` trên một đơn vị: chỉ
## một nguồn có tác dụng: đồ thắng skill, đồ ô sau thắng ô trước (STAT-05, D-55).

enum Op { ADD, MULTIPLY, OVERRIDE }

@export var stat: StringName
@export var op: Op = Op.ADD
@export var value: String
@export var unique_group: StringName
