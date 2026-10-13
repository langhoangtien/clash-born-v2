class_name ValueChangeDef
extends Resource
## Talent sửa một giá trị có tên của kỹ năng (TAL-02a).

enum Op { ADD, MULTIPLY, SET }

@export var value_name: StringName
@export var op: Op = Op.ADD
@export var amount: float
