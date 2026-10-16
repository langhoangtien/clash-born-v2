extends SceneTree
## M7.5 / M7.6: chạy bot đấu bot không giao diện.
## godot --headless -s tools/bot_matches.gd -- [--minutes=10] [--seeds=1,2,3] [--pairs=brakk:myra,...] [--full]
## --full: chạy tới khi có đội thắng (tối đa 40 phút), in thời lượng và phút đạt cấp 20.
## Mỗi trận kiểm INV-06 / BOT-11 (tests/sim/bots/test_bot_invariants.gd) và INV-07.

const HEROES: Array[StringName] = [&"brakk", &"myra", &"noctis", &"vexa"]
const Inv = preload("res://tests/sim/bots/test_bot_invariants.gd")


func _initialize() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var minutes: float = float(args.get("minutes", "10"))
	var full: bool = args.has("full")
	var seeds: Array = Array(String(args.get("seeds", "1,2,3")).split(",")).map(func(x: String) -> int: return int(x))
	var pairs: Array = []
	if args.has("pairs"):
		for p: String in String(args["pairs"]).split(","):
			pairs.append(Array(p.split(":")).map(func(x: String) -> StringName: return StringName(x)))
	else:
		for a: StringName in HEROES:
			for b: StringName in HEROES:
				pairs.append([a, b])
	var bad: int = 0
	for pair: Array in pairs:
		for seed: int in seeds:
			bad += 0 if _one(pair[0], pair[1], seed, 40.0 if full else minutes, full) else 1
	print("== %s: %d lỗi ==" % ["XONG" if bad == 0 else "LỖI", bad])
	quit(1 if bad > 0 else 0)


func _one(a: StringName, b: StringName, seed: int, minutes: float, full: bool) -> bool:
	var inv: Object = Inv.new()
	var w: World = inv._world(seed, a, b)
	var start: int = Time.get_ticks_msec()
	var level20: Array[int] = [-1, -1]
	var problem: String = ""
	var chunk: float = 0.5
	var elapsed: float = 0.0
	while elapsed < minutes and w.winner < 0 and problem == "":
		problem = Inv.run_checks(w, chunk)
		if problem == "":
			problem = _inv07(w)
		elapsed += chunk
		for e: Entity in w.entities:
			if e.kind == Entity.Kind.HERO and level20[e.team] < 0 and e.stats.level() >= 20:
				level20[e.team] = w.tick
	var heroes: Array[Entity] = []
	for e: Entity in w.entities:
		if e.kind == Entity.Kind.HERO:
			heroes.append(e)
	var line: String = "%s vs %s seed %d: %s, %s" % [a, b, seed, MatchHud.clock_text(w.tick),
		("đội %d thắng" % w.winner) if w.winner >= 0 else "chưa xong"]
	for h: Entity in heroes:
		line += " | %s cấp %d K/D %d/%d LH %d vàng+đồ %d mode %s" % [h.hero_def.id, h.stats.level(), h.kills, h.deaths, h.last_hits,
			h.gold + _item_worth(h), BotState.Mode.keys()[h.bot.mode]]
	if full:
		line += " | cấp 20: %s / %s" % [MatchHud.clock_text(level20[0]) if level20[0] >= 0 else "-", MatchHud.clock_text(level20[1]) if level20[1] >= 0 else "-"]
	line += " | trụ đổ %d %s | %.0f s" % [w.destroyed_structures.size(), str(w.destroyed_structures.keys()), (Time.get_ticks_msec() - start) / 1000.0]
	print(line)
	if problem != "":
		print("   LỖI: " + problem)
	return problem == ""


func _item_worth(h: Entity) -> int:
	var n: int = 0
	for it: ItemInstance in Items.slots(h):
		if it != null:
			n += it.def.cost
	return n


## INV-07: không đơn vị nào nhắm (lệnh đánh) một đơn vị mà đội nó không thấy.
func _inv07(w: World) -> String:
	for e: Entity in w.entities:
		if e.alive and e.order.type == Order.Type.ATTACK and not e.order.finished:
			var t: Entity = w.find_entity(e.order.target_id)
			if t != null and t.alive and not Rules.is_visible(e.team, t):
				return "INV-07: %d nhắm %d không thấy" % [e.id, t.id]
	return ""
