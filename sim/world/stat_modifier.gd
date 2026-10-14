class_name StatModifier
extends RefCounted
## Một modifier đang tác dụng lên đơn vị: đã tính xong giá trị số (biểu thức của
## ModifierDef được tính khi áp hiệu ứng, ở M3). `source_id` = nguồn (hiệu ứng, đồ…).

var stat: StatId.Id
var op: ModifierDef.Op
var value: float
var source_id: int
var unique_group: StringName
## STAT-05 (D-55): ô đồ của nguồn (1–6), 0 nếu không phải đồ (skill, nội tại, hiệu ứng).
var item_slot: int


static func make(p_stat: StatId.Id, p_op: ModifierDef.Op, p_value: float, p_source: int,
		p_group: StringName = &"", p_item_slot: int = 0) -> StatModifier:
	var m: StatModifier = StatModifier.new()
	m.stat = p_stat
	m.op = p_op
	m.value = p_value
	m.source_id = p_source
	m.unique_group = p_group
	m.item_slot = p_item_slot
	return m
