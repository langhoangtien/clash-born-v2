class_name World
extends RefCounted
## Toàn bộ trạng thái một trận và vòng tick (ARCHITECTURE mục 4). Xác định (D-30):
## cùng seed + cùng Command → cùng trạng thái từng tick.

## Thứ tự pha cố định của một tick.
enum Phase { COMMAND, EFFECT, STATE, VISION, CONTROLLER, MOVEMENT, ABILITY, ATTACK, DAMAGE, TRIGGER, DEATH, SPAWN }

var tick: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var balance: BalanceSettings
## Luôn sắp theo id tăng dần.
var entities: Array[Entity] = []

var _next_id: int = 1
var _systems: Array[Array] = []  # [phase, thứ tự đăng ký, SimSystem]


func _init(seed_value: int, p_balance: BalanceSettings) -> void:
	rng.seed = seed_value
	balance = p_balance
	add_system(StateSystem.new(), Phase.STATE)


func add_system(system: SimSystem, phase: Phase) -> void:
	_systems.append([phase, _systems.size(), system])
	_systems.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))


## Cấp id, tính chỉ số lần đầu, đầy máu/mana.
func add_entity(e: Entity) -> Entity:
	e.id = _next_id
	_next_id += 1
	if e.stats != null:
		e.stats.recompute()
		e.health = e.stats.get_stat(StatId.Id.MAX_HP)
		e.mana = e.stats.get_stat(StatId.Id.MAX_MANA)
	entities.append(e)
	return e


func remove_entity(e: Entity) -> void:
	entities.erase(e)


func step() -> void:
	tick += 1
	for entry: Array in _systems:
		(entry[2] as SimSystem).run(self)


## Băm toàn bộ trạng thái để so hai lần chạy (test phát lại, D-30).
func state_hash() -> PackedByteArray:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(PackedInt64Array([tick, rng.seed, rng.state, entities.size()]).to_byte_array())
	for e: Entity in entities:
		ctx.update(PackedInt64Array([e.id, e.team, e.kind]).to_byte_array())
		ctx.update(PackedFloat64Array([e.position.x, e.position.y, e.radius, e.health, e.mana]).to_byte_array())
		if e.stats != null:
			ctx.update(e.stats.values().to_byte_array())
	return ctx.finish()
