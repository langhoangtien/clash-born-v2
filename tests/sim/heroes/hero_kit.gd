extends RefCounted
## Tiện ích chung cho test kịch bản tướng (D-347): dựng World có map, hero theo bậc chiêu, hình nộm, chạy tick, đọc hiệu ứng.

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const Slot := AbilityDef.Slot
const SLOTS: Array[int] = [Slot.INNATE, Slot.Q, Slot.W, Slot.R]

static var _map: MapLayout
static var lib: ContentLibrary


static func world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		lib = ContentLibrary.load_dir()
	var w: World = World.new(4, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return w


static func center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-700, 700)


## Hero `id` phe 0 ở giữa map; `ranks` = [nội tại, Q, W, R].
static func hero(w: World, id: StringName, ranks: Array = [0, 0, 0, 0], team: int = 0, at: Vector2 = Vector2.INF) -> Entity:
	var h: Entity = UnitFactory.hero(w, lib.heroes[id], team, w.navigation(36.0).nearest_clear(center() if at == Vector2.INF else at))
	for i: int in 4:
		if int(ranks[i]) > 0:
			Abilities.set_rank(w, h, Abilities.of(h, SLOTS[i]), int(ranks[i]))
	h.mana = 5000.0
	h.stats.recompute()
	return h


## Cấp 20, mọi chiêu tối đa, chọn talent của ô `talent` (-1 = không).
static func hero20(w: World, id: StringName, talent: int = -1) -> Entity:
	var h: Entity = hero(w, id)
	Progression.add_xp(w, h, 100000.0)
	h.skill_points = 0
	for slot: int in SLOTS:
		var a: AbilityInstance = Abilities.of(h, slot)
		Abilities.set_rank(w, h, a, a.def.expected_ranks())
	h.mana = 5000.0
	if talent >= 0:
		w.submit(Command.choose_talent(h.id, talent))
	w.step()
	return h


## Hình nộm 100 000 máu, giáp 0, không đánh (tầm 0).
static func dummy(w: World, at: Vector2, kind: Entity.Kind = Entity.Kind.HERO, team: int = 1) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.kind = kind
	e.radius = 24.0
	e.position = at
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 100000)
	e.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	e.stats.set_base(StatId.Id.PHYSICAL_DAMAGE, 100)
	e.stats.set_base(StatId.Id.ATTACK_RANGE, 0)
	e.stats.set_base(StatId.Id.MOVEMENT_SPEED, 300)
	e.attack_point = 0.1
	e.stats.recompute()
	e.health = 100000.0
	return w.add_entity(e)


static func steps(w: World, n: int) -> void:
	for i: int in n:
		w.step()


static func has_state(e: Entity, s: UnitState.Id) -> bool:
	return e.effects.any(func(i: EffectInstance) -> bool: return i.def.states.has(s))


static func amp(h: Entity) -> float:
	return 1.0 + h.stats.get_stat(StatId.Id.SPELL_AMPLIFICATION)  # CMB-13
