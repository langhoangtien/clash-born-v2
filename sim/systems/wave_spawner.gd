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
	var tier: int = creep_tier(world, team, lane)
	var kinds: Array[StringName] = []
	for i: int in range(world.balance.wave_melee + (world.balance.mega_extra_melee if tier == 2 else 0)):
		kinds.append(&"creep_melee")
	for i: int in range(world.balance.wave_ranged):
		kinds.append(&"creep_ranged")
	if world.balance.siege_every_waves > 0 and wave % world.balance.siege_every_waves == 0:
		kinds.append(&"creep_siege")
	var route: LaneRoute = LaneRoute.of(world, lane, team)
	for i: int in range(kinds.size()):
		var at: Vector2 = route.point_at(SPACING * (kinds.size() - 1 - i))
		var c: Entity = MatchSetup.spawn_creep(world, _library, kinds[i], team, lane, at)
		empower(world, c, tier)


## CRP-12: 0 = thường, 1 = siêu cấp (trụ 3 địch trên lane đã đổ), 2 = siêu lính (cả 3 trụ 3 địch đã đổ).
static func creep_tier(world: World, team: int, lane: String) -> int:
	var fallen: int = 0
	var this_lane: bool = false
	var map: MapLayout = world.map
	for i: int in range(map.tower_ids.size()):
		if map.tower_teams[i] != team and map.tower_tiers[i] == 3 and world.destroyed_structures.has(StringName(map.tower_ids[i])):
			fallen += 1
			this_lane = this_lane or map.tower_lanes[i] == lane
	return 2 if fallen >= 3 else (1 if this_lane else 0)


## CRP-11 + CRP-12: nhân máu tối đa, sát thương (và vàng của siêu lính) cho lính vừa sinh.
static func empower(world: World, c: Entity, tier: int) -> void:
	var b: BalanceSettings = world.balance
	var steps: int = int(world.tick / maxi(1, SimClock.seconds_to_ticks(b.creep_upgrade_interval))) if b.creep_upgrade_interval > 0.0 else 0
	var hp: float = 1.0 + steps * b.creep_upgrade_step
	var dmg: float = hp
	if tier == 1:
		hp *= b.super_creep_hp
		dmg *= b.super_creep_damage
	elif tier == 2:
		hp *= b.mega_creep_hp
		dmg *= b.mega_creep_damage
		c.bounty_gold = int(c.bounty_gold * b.mega_creep_bounty)
	c.creep_tier = tier
	if hp == 1.0 and dmg == 1.0:
		return
	c.stats.set_base(StatId.Id.MAX_HP, c.stats.base(StatId.Id.MAX_HP) * hp)
	c.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, c.stats.base(StatId.Id.PHYSICAL_DAMAGE) * dmg)
	c.stats.recompute()
	c.health = c.stats.get_stat(StatId.Id.MAX_HP)
