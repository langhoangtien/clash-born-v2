extends SceneTree
## D-152: đo SIM không giao diện — thời gian mỗi tick, tách theo hệ thống, trận N bot mỗi đội.
## godot --headless -s tools/sim_profile.gd -- [--per_team=5] [--minutes=12] [--seed=1]

const HEROES: Array[StringName] = [&"brakk", &"myra", &"noctis", &"vexa", &"gorran", &"duy_anh"]
const MAP_PATH: String = "res://data/maps/clashborn_map.json"


func _initialize() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var per_team: int = int(args.get("per_team", "5"))
	var minutes: float = float(args.get("minutes", "12"))
	var w: World = _world(int(args.get("seed", "1")), per_team)
	_run(w, minutes, per_team)
	quit(0)


func _world(seed: int, per_team: int) -> World:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var map: MapLayout = MapLayout.from_file(MAP_PATH)
	var w: World = World.new(seed, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.spawn_structures(w, lib)
	MatchSetup.add_vision(w)
	MatchSetup.add_jungle(w, lib)
	MatchSetup.add_shop(w, lib)
	MatchSetup.add_lane_creeps(w, lib, true)
	for team: int in 2:
		for i: int in per_team:
			var id: StringName = HEROES[(i + team) % HEROES.size()]
			MatchSetup.add_bot(w, UnitFactory.hero(w, lib.heroes[id], team, map.fountain_point(team)))
	return w


func _run(w: World, minutes: float, per_team: int) -> void:
	var per_sys: Dictionary[String, int] = {}
	var ticks: PackedInt64Array = []
	var minute_max: Array[float] = []
	var minute_sum: Array[float] = []
	var worst: Array[Array] = []  # [ms, tick, hệ thống nặng nhất, ms của nó]
	var total_ticks: int = SimClock.seconds_to_ticks(minutes * 60.0)
	for t: int in total_ticks:
		if w.winner >= 0:
			break
		var t0: int = Time.get_ticks_usec()
		w.tick += 1
		w.previous_events = w.events
		w.events = []
		var top: Array = ["", 0]
		for entry: Array in w._systems:
			var s0: int = Time.get_ticks_usec()
			(entry[2] as SimSystem).run(w)
			var key: String = (entry[2] as Object).get_script().get_global_name()
			var used: int = Time.get_ticks_usec() - s0
			per_sys[key] = per_sys.get(key, 0) + used
			if used > top[1]:
				top = [key, used]
		var dt: int = Time.get_ticks_usec() - t0
		if t > 30 and dt > 15000:
			worst.append([dt / 1000.0, w.tick, top[0], top[1] / 1000.0])
		ticks.append(dt)
		var m: int = t / (SimClock.TICKS_PER_SECOND * 60)
		while minute_max.size() <= m:
			minute_max.append(0.0)
			minute_sum.append(0.0)
		minute_max[m] = maxf(minute_max[m], dt / 1000.0)
		minute_sum[m] += dt / 1000.0
	_report(w, per_sys, ticks, minute_max, minute_sum, per_team)
	var by_sys: Dictionary[String, int] = {}
	for x: Array in worst:
		by_sys[x[2]] = by_sys.get(x[2], 0) + 1
	print("tick > 15 ms: %d lần, hệ thống nặng nhất trong tick đó: %s" % [worst.size(), str(by_sys)])


func _report(w: World, per_sys: Dictionary[String, int], ticks: PackedInt64Array, minute_max: Array[float], minute_sum: Array[float], per_team: int) -> void:
	var sorted: PackedInt64Array = ticks.duplicate()
	sorted.sort()
	var total: int = 0
	for x: int in ticks:
		total += x
	var n: int = ticks.size()
	print("== %dv%d, %d tick (%s), đơn vị cuối trận %d ==" % [per_team, per_team, n, MatchHud.clock_text(w.tick), w.entities.size()])
	print("ms/tick: tb %.2f  p50 %.2f  p95 %.2f  p99 %.2f  max %.2f" % [total / 1000.0 / n, sorted[n / 2] / 1000.0,
		sorted[n * 95 / 100] / 1000.0, sorted[n * 99 / 100] / 1000.0, sorted[n - 1] / 1000.0])
	var keys: Array = per_sys.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return per_sys[a] > per_sys[b])
	for k: String in keys:
		print("  %-22s %6.3f ms/tick  %4.1f%%" % [k, per_sys[k] / 1000.0 / n, 100.0 * per_sys[k] / total])
	var line: String = "theo phút (tb/max):"
	for m: int in minute_max.size():
		line += " %d:%.1f/%.1f" % [m, minute_sum[m] / (SimClock.TICKS_PER_SECOND * 60), minute_max[m]]
	print(line)
