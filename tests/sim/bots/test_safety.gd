extends TestCase
## M7.1: vùng nguy hiểm trụ (DEF-09), vị trí an toàn cho hero (DEF-10).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"

static var _map: MapLayout
static var _lib: ContentLibrary


func _world() -> World:
	if _map == null:
		_map = load(MAP_PATH) as MapLayout
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = _map
	return w


func _center() -> Vector2:
	return _map.world_size() * 0.5 + Vector2(-900, 900)


func _dir() -> Vector2:
	return Vector2(1, -1).normalized()


## [world, hero đội 0, trụ đội 1 cách hero 1200].
func _setup() -> Array:
	var w: World = _world()
	var hero: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, _center())
	var tower: Entity = UnitFactory.unit(w, _lib.units[&"tower_t1"], Entity.Kind.TOWER, 1, _center() + _dir() * 1200.0)
	return [w, hero, tower]


## Khoảng (từ tâm trụ) tới mép vùng nguy hiểm với hero.
func _edge(w: World, hero: Entity, tower: Entity) -> float:
	return tower.radius + tower.stats.get_stat(StatId.Id.ATTACK_RANGE) + hero.radius + w.balance.tower_danger_margin


func _creep(w: World, at: Vector2) -> Entity:
	return UnitFactory.unit(w, _lib.units[&"creep_melee"], Entity.Kind.LANE_CREEP, 0, at)


func test_DEF_09_tower_danger_zone() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var tower: Entity = s[2]
	var edge: float = _edge(w, s[1], tower)
	assert_eq(Rules.tower_threat_at(w, 0, tower.position - _dir() * (edge - 5.0), s[1].radius), [tower], "trong vùng")
	assert_true(Rules.tower_threat_at(w, 0, tower.position - _dir() * (edge + 5.0), s[1].radius).is_empty(), "ngoài vùng")
	assert_true(Rules.tower_threat_at(w, 1, tower.position, s[1].radius).is_empty(), "trụ phe mình không nguy hiểm")


func test_DEF_10_outside_safe_inside_unsafe_alone() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var hero: Entity = s[1]
	var tower: Entity = s[2]
	var edge: float = _edge(w, hero, tower)
	assert_true(Rules.is_safe_for_hero(w, hero, tower.position - _dir() * (edge + 10.0)))
	assert_false(Rules.is_safe_for_hero(w, hero, tower.position - _dir() * (edge - 10.0)), "một mình trong vùng trụ")


func test_DEF_10_dive_with_tanking_creeps_and_enough_hp() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var hero: Entity = s[1]
	var tower: Entity = s[2]
	var spot: Vector2 = tower.position - _dir() * 400.0
	var c1: Entity = _creep(w, tower.position - _dir() * 300.0)
	_creep(w, tower.position - _dir() * 320.0 + Vector2(40, 40))
	tower.order = Order.attack(c1.id)
	assert_true(Rules.is_safe_for_hero(w, hero, spot), "trụ bắn lính, đủ 2 lính đỡ, máu đầy")
	hero.health = hero.stats.get_stat(StatId.Id.MAX_HP) * 0.5
	assert_false(Rules.is_safe_for_hero(w, hero, spot), "máu dưới 60%")
	hero.health = hero.stats.get_stat(StatId.Id.MAX_HP)
	tower.order = Order.attack(hero.id)
	assert_false(Rules.is_safe_for_hero(w, hero, spot), "trụ đang nhắm mình: không bao giờ an toàn")
	tower.order = Order.attack(c1.id)
	c1.alive = false
	assert_false(Rules.is_safe_for_hero(w, hero, spot), "chỉ còn 1 lính đỡ")


func test_DEF_09_enemy_fountain_never_safe() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	assert_false(Rules.is_safe_for_hero(w, s[1], _map.fountain_point(1)))
	assert_true(Rules.is_safe_for_hero(w, s[1], _map.fountain_point(0)), "fountain nhà thì an toàn")
