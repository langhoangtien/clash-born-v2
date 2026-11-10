extends SceneTree
## ST.4 (D-331): trận bot đấu bot không giao diện cho Clashborn Stats — mỗi seed một đội hình ngẫu nhiên không trùng
## (MATCH-02), chạy tới khi có đội thắng (tối đa `--cap` phút), ghi biên bản (MatchRecord) mỗi dòng một JSON.
## godot --headless --path . -s tools/stats/sim_matches.gd -- --out=matches.jsonl [--mode=3] [--seeds=1-20]
##   [--cap=40] [--version=0.1.560]   (trận hết giờ chưa phân thắng thua thì bỏ — biên bản cần đội thắng)
## Gửi lên: tools/stats/upload_matches.sh matches.jsonl

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"


func _initialize() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var size: int = int(args.get("mode", "3"))
	var span: PackedStringArray = String(args.get("seeds", "1-10")).split("-")
	var version: String = args.get("version", Updater.current_name())
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var out: FileAccess = FileAccess.open(args.get("out", "user://matches.jsonl"), FileAccess.WRITE)
	for seed: int in range(int(span[0]), int(span[-1]) + 1):
		var cfg: MatchConfig = MatchConfig.make(size, _picks(lib, size, seed), [], BotState.Difficulty.NORMAL, seed)
		var w: World = World.new(seed, load(BALANCE_PATH) as BalanceSettings)
		w.map = load(MAP_PATH) as MapLayout
		w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
		MatchSetup.build(w, lib, cfg)
		var cap: int = SimClock.seconds_to_ticks(float(args.get("cap", "40")) * 60.0)
		while w.winner < 0 and w.tick < cap:
			w.step()
		print("seed %d: %s → %s sau %s" % [seed, cfg.slots.map(func(s: MatchSlot) -> String: return String(s.hero_id)),
			"đội %d thắng" % w.winner if w.winner >= 0 else "hết giờ (bỏ)", MatchHud.clock_text(w.tick)])
		if w.winner >= 0:
			out.store_line(JSON.stringify(MatchRecord.of(w, cfg, version)))
			out.flush()
	out.close()
	quit(0)


## Đội hình ngẫu nhiên theo seed (không trùng cả trận — MATCH-02).
static func _picks(lib: ContentLibrary, size: int, seed: int) -> Array[StringName]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var pool: Array[StringName] = []
	for id: StringName in lib.heroes:
		pool.append(id)
	pool.sort()
	var picks: Array[StringName] = []
	for k: int in 2 * size:
		picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picks
