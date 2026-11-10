class_name SyncCheck
extends RefCounted
## M9.3 (D-336): kiểm tra tất định giữa máy (điện thoại ARM ↔ máy chủ x86) trước khi làm online lockstep. Một trận 3v3
## toàn bot cấu hình cố định (bot nằm trong SIM → cấu hình đủ xác định cả trận, không cần nhật ký lệnh); chạy SECONDS
## giây trận, mỗi giây ghi mã băm toàn World + mã băm từng đơn vị. Chạy từng đoạn (`advance`) để app hiện tiến độ.
## Hai máy cùng phiên bản phải ra đúng cùng chuỗi; tools/sync_compare.py chỉ ra giây + đơn vị lệch đầu tiên.

const SECONDS: int = 300
const SEED: int = 2026
const HEROES: Array[StringName] = [&"brakk", &"myra", &"vexa", &"noctis", &"gorran", &"duy_anh"]
const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

var world: World
## Mỗi giây: {"t": giây, "hash": hex 64, "units": {"<id>": hex 32}}.
var seconds: Array[Dictionary] = []
var total_ticks: int


static func config() -> MatchConfig:
	return MatchConfig.make(3, HEROES, [], BotState.Difficulty.NORMAL, SEED)


func _init(seconds_to_run: int = SECONDS) -> void:
	total_ticks = seconds_to_run * SimClock.TICKS_PER_SECOND
	var cfg: MatchConfig = config()
	world = World.new(cfg.seed, load(BALANCE_PATH) as BalanceSettings)
	world.map = load(MAP_PATH) as MapLayout
	world.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	MatchSetup.build(world, ContentLibrary.load_dir(), cfg)


func done() -> bool:
	return world.tick >= total_ticks or world.winner >= 0


func progress() -> float:
	return float(world.tick) / float(total_ticks)


## Chạy thêm tối đa `ticks` tick (dừng khi xong); ghi mốc mỗi giây.
func advance(ticks: int) -> void:
	for i: int in ticks:
		if done():
			return
		world.step()
		if world.tick % SimClock.TICKS_PER_SECOND == 0:
			_record()


func _record() -> void:
	var units: Dictionary = {}
	for e: Entity in world.entities:
		units[str(e.id)] = world.entity_digest(e).hex_encode()
	seconds.append({"t": world.tick / SimClock.TICKS_PER_SECOND, "hash": world.state_hash().hex_encode(), "units": units})


## Kết quả gửi lên máy chủ / ghi file.
func result(meta: Dictionary) -> Dictionary:
	return {"meta": meta.merged({"seed": SEED, "seconds": total_ticks / SimClock.TICKS_PER_SECOND, "ticks": world.tick}),
		"seconds": seconds}
