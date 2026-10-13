class_name ExprRules
extends RefCounted
## Kiểm tra biểu thức trong dữ liệu (EFF-09): số, giá trị có tên của kỹ năng,
## `self.<chỉ số>`, `target.<chỉ số>`, `event.<trường>`, + − × ÷, min, max, ngoặc.
## Trong các Def: kiểu `String` là biểu thức; tên dùng `StringName`.

const ALLOWED_CHARS: String = "0123456789.+-*/(), \t_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

static var _identifier: RegEx = RegEx.create_from_string("(?<![0-9.])[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)*")


## Lỗi của biểu thức `expr` khi kỹ năng có các giá trị tên `names`. Rỗng = hợp lệ.
static func errors(expr: String, names: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if expr.strip_edges().is_empty():
		return out
	for c: String in expr:
		if not ALLOWED_CHARS.contains(c):
			out.append("ký tự không cho phép '%s' trong \"%s\"" % [c, expr])
			return out
	var parser: Expression = Expression.new()
	if parser.parse(expr, PackedStringArray(["self", "target", "event"]) + names) != OK:
		out.append("sai cú pháp \"%s\": %s" % [expr, parser.get_error_text()])
		return out
	for m: RegExMatch in _identifier.search_all(expr):
		var problem: String = _identifier_problem(m.get_string(), names)
		if not problem.is_empty():
			out.append("%s trong \"%s\"" % [problem, expr])
	return out


## Tên giá trị của kỹ năng mà biểu thức dùng (không gồm self./target./event./hàm).
static func named_values(expr: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for m: RegExMatch in _identifier.search_all(expr):
		var token: String = m.get_string()
		if not token.contains(".") and not RuleCatalog.FUNCTIONS.has(token):
			out.append(token)
	return out


static func _identifier_problem(token: String, names: PackedStringArray) -> String:
	var parts: PackedStringArray = token.split(".")
	if parts.size() == 1:
		if names.has(token) or RuleCatalog.FUNCTIONS.has(token):
			return ""
		return "giá trị có tên '%s' không có trong kỹ năng" % token
	if parts.size() != 2:
		return "tên '%s' quá nhiều dấu chấm" % token
	match parts[0]:
		"self", "target":
			return "" if RuleCatalog.unit_field_ok(parts[1]) else "chỉ số '%s' không có trong STAT-01" % parts[1]
		"event":
			return "" if RuleCatalog.EVENT_FIELDS.has(parts[1]) else "dữ liệu sự kiện '%s' không có" % parts[1]
	return "không rõ '%s'" % token
