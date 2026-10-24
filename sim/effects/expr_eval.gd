class_name ExprEval
extends RefCounted
## Tính biểu thức dữ liệu (EFF-09) bằng Expression của Godot. `self.`/`target.`/`event.` đổi
## tên thành biến riêng trước khi phân tích (Expression dành `self` cho đối tượng gốc).
## Biểu thức đã phân tích được nhớ theo (chuỗi, danh sách tên). Dữ liệu đã qua
## ContentValidator nên ở đây gặp lỗi là lỗi lập trình: báo lỗi và trả 0.

const PREFIXES: Array[String] = ["self.", "target.", "event."]
const INPUTS: PackedStringArray = ["self_", "target_", "event_"]

static var _cache: Dictionary[String, Expression] = {}
static var _rename: RegEx = RegEx.create_from_string("(?<![A-Za-z0-9_.])(self|target|event)\\.")


static func evaluate(expr: String, ctx: ExprContext) -> float:
	var text: String = expr.strip_edges()
	if text.is_empty():
		return 0.0
	if text.is_valid_float():
		return text.to_float()
	var names: Array = ctx.values.keys()
	names.sort()
	var key: String = text + "|" + ",".join(names.map(func(n: Variant) -> String: return str(n)))
	var parsed: Expression = _cache.get(key)
	if parsed == null:
		parsed = Expression.new()
		var input_names: PackedStringArray = INPUTS.duplicate()
		for n: Variant in names:
			input_names.append(str(n))
		if parsed.parse(_rename.sub(text, "$1_.", true), input_names) != OK:
			push_error("EFF-09: không phân tích được \"%s\": %s" % [text, parsed.get_error_text()])
			return 0.0
		_cache[key] = parsed
	var inputs: Array = [_unit(ctx.owner), _unit(ctx.target), _event(ctx)]
	for n: Variant in names:
		inputs.append(ctx.values[n])
	var result: Variant = parsed.execute(inputs, null, false)
	if parsed.has_execute_failed() or not (result is float or result is int):
		push_error("EFF-09: không tính được \"%s\"" % text)
		return 0.0
	return float(result)


static func _unit(e: Entity) -> ExprUnit:
	var u: ExprUnit = ExprUnit.new()
	u.unit = e
	return u


static func _event(ctx: ExprContext) -> ExprEvent:
	var ev: ExprEvent = ExprEvent.new()
	ev.damage = ctx.event_damage
	ev.burned_mana = ctx.event_burned_mana
	ev.heal = ctx.event_heal
	ev.raw_damage = ctx.event_raw_damage
	return ev
