class_name ExprContext
extends RefCounted
## Ngữ cảnh tính biểu thức (EFF-09): chủ (`self.`), mục tiêu (`target.`), giá trị có tên của
## kỹ năng (đã chụp lúc áp), dữ liệu sự kiện (`event.`).

var owner: Entity
var target: Entity
var values: Dictionary = {}
var event_damage: float = 0.0
var event_burned_mana: float = 0.0
var event_heal: float = 0.0


static func make(p_owner: Entity, p_target: Entity = null, p_values: Dictionary = {}) -> ExprContext:
	var c: ExprContext = ExprContext.new()
	c.owner = p_owner
	c.target = p_target if p_target != null else p_owner
	c.values = p_values
	return c
