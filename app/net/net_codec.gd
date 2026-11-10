class_name NetCodec
extends RefCounted
## D-337 (NET): Command / MatchConfig ↔ Dictionary cho dây mạng. Đọc lại kiểm kiểu từng trường (tin từ máy khác không
## tin được): sai → null, bỏ.


static func command_to(c: Command) -> Dictionary:
	return {"k": int(c.type), "e": c.entity_id, "p": [c.point.x, c.point.y], "d": [c.direction.x, c.direction.y],
		"t": c.target_id, "l": c.lock, "m": c.mode, "s": c.slot, "i": String(c.item_id)}


static func command_from(d: Variant) -> Command:
	if not d is Dictionary:
		return null
	var k: Variant = d.get("k")
	if not _int(k) or int(k) < 0 or int(k) >= Command.Type.size():
		return null
	if not (_int(d.get("e")) and _int(d.get("t")) and _int(d.get("m")) and _int(d.get("s")) and _pair(d.get("p"))
			and _pair(d.get("d")) and d.get("l") is bool and d.get("i") is String and String(d.get("i")).length() <= 64):
		return null
	var c: Command = Command.new()
	c.type = int(k) as Command.Type
	c.entity_id = int(d["e"])
	c.point = Vector2(float(d["p"][0]), float(d["p"][1]))
	c.direction = Vector2(float(d["d"][0]), float(d["d"][1]))
	c.target_id = int(d["t"])
	c.lock = d["l"]
	c.mode = int(d["m"])
	c.slot = int(d["s"])
	c.item_id = StringName(d["i"])
	return c


static func config_to(c: MatchConfig) -> Dictionary:
	return {"size": c.team_size, "seed": c.seed, "practice": c.practice,
		"slots": c.slots.map(func(s: MatchSlot) -> Array: return [s.team, s.index, String(s.hero_id), s.is_bot, int(s.difficulty)])}


static func config_from(d: Dictionary) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.team_size = int(d.get("size", 1))
	c.seed = int(d.get("seed", 1))
	c.practice = bool(d.get("practice", false))
	for a: Variant in d.get("slots", []):
		var s: MatchSlot = MatchSlot.new()
		s.team = int(a[0])
		s.index = int(a[1])
		s.hero_id = StringName(String(a[2]))
		s.is_bot = bool(a[3])
		s.difficulty = int(a[4]) as BotState.Difficulty
		c.slots.append(s)
	return c


static func _int(v: Variant) -> bool:
	return (v is int or v is float) and float(v) == floorf(float(v)) and absf(float(v)) < 1e9


static func _pair(v: Variant) -> bool:
	return v is Array and v.size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int) \
		and is_finite(float(v[0])) and is_finite(float(v[1]))
