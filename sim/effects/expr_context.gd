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
## Hai bên của sự kiện (trigger): ActionDef.Target.EVENT_SOURCE / EVENT_TARGET.
var event_source: Entity
var event_target: Entity
## Điểm và hướng lúc tung (kỹ năng POINT/DIRECTION; vùng RECT). INF = không có điểm.
var point: Vector2 = Vector2.INF
var direction: Vector2 = Vector2.ZERO
## Kỹ năng đang chạy (lọc đối tượng của vùng, ABL-07); null = hiệu ứng/đồ không có kỹ năng.
var ability: AbilityDef


static func make(p_owner: Entity, p_target: Entity = null, p_values: Dictionary = {}) -> ExprContext:
	var c: ExprContext = ExprContext.new()
	c.owner = p_owner
	c.target = p_target if p_target != null else p_owner
	c.values = p_values
	return c


## Bản sao nông với mục tiêu khác (từng đơn vị trúng vùng / bị tước).
func with_target(t: Entity) -> ExprContext:
	var c: ExprContext = ExprContext.new()
	c.owner = owner
	c.target = t
	c.values = values
	c.event_damage = event_damage
	c.event_burned_mana = event_burned_mana
	c.event_heal = event_heal
	c.event_source = event_source
	c.event_target = event_target
	c.point = point
	c.direction = direction
	c.ability = ability
	return c
