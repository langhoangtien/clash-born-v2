class_name CampDef
extends GameDef
## Quái của một loại trại rừng (JGL-06): `kind` khớp loại trại trong dữ liệu map.

@export var kind: StringName
@export var units: Array[UnitDef] = []
## JGL-10 (D-307): trại boss — xuất hiện lần đầu ở `first_spawn` giây, hồi lại `respawn` giây sau khi trống
## (-1 = trại thường, JGL-05).
@export var first_spawn: float = -1.0
@export var respawn: float = -1.0


func is_boss() -> bool:
	return first_spawn >= 0.0
