class_name CampState
extends RefCounted
## Trạng thái chung của một trại rừng (JGL-01..05). JungleController / JungleSpawner ghi.

## Chỉ số trại trong MapLayout.camp_* và loại trại (CampDef.kind).
var index: int
var kind: StringName
var center: Vector2
var def: CampDef
## Quái của trại (id); đơn vị đã chết được bỏ dần.
var unit_ids: Array[int] = []
## JGL-01: mục tiêu chung, tick hết AGGRO nếu không bị đánh thêm; -1 = không có.
var target_id: int = -1
var aggro_until_tick: int = -1
## JGL-02: đang về.
var returning: bool = false
