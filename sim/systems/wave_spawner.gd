class_name WaveSpawner
extends SimSystem
## Pha 12: đợt lính (CRP-08). Đợt đầu ở `first_wave_time`, sau đó mỗi `wave_interval`;
## đợt thứ k chia hết `siege_every_waves` có thêm lính công thành.

const LANES: PackedStringArray = ["TOP", "MID", "BOT"]
## Hằng số bố trí: khoảng cách giữa các lính khi sinh, dọc theo route.
const SPACING: float = 60.0

var _library: ContentLibrary


func _init(library: ContentLibrary) -> void:
	_library = library


func run(world: World) -> void:
	var first: int = SimClock.seconds_to_ticks(world.balance.first_wave_time)
	var interval: int = SimClock.seconds_to_ticks(world.balance.wave_interval)
	if world.tick < first or (world.tick - first) % interval != 0:
		return
	var wave: int = (world.tick - first) / interval + 1
	for team: int in range(2):
		for lane: String in LANES:
			_spawn_wave(world, team, lane, wave)


func _spawn_wave(world: World, team: int, lane: String, wave: int) -> void:
	var kinds: Array[StringName] = []
	for i: int in range(world.balance.wave_melee):
		kinds.append(&"creep_melee")
	for i: int in range(world.balance.wave_ranged):
		kinds.append(&"creep_ranged")
	if world.balance.siege_every_waves > 0 and wave % world.balance.siege_every_waves == 0:
		kinds.append(&"creep_siege")
	var route: LaneRoute = LaneRoute.of(world, lane, team)
	for i: int in range(kinds.size()):
		var at: Vector2 = route.point_at(SPACING * (kinds.size() - 1 - i))
		MatchSetup.spawn_creep(world, _library, kinds[i], team, lane, at)
