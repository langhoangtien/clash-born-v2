extends TestCase
## M1.4: dựng đơn vị từ dữ liệu content/ (HeroDef → Entity).

static var _lib: ContentLibrary
static var _bal: BalanceSettings


func before_each() -> void:
	if _lib == null:
		_lib = ContentLibrary.load_dir()
		_bal = load("res://content/balance/balance_settings.tres")


func _brakk(level: int = 1) -> Entity:
	var w: World = World.new(1, _bal)
	return UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, Vector2(100, 200), level)


func test_brakk_level1_from_content() -> void:
	var e: Entity = _brakk()
	assert_eq(e.kind, Entity.Kind.HERO)
	assert_eq(e.team, 0)
	assert_eq(e.position, Vector2(100, 200))
	assert_eq(e.radius, 32.0)
	assert_eq(e.art_id, &"brakk")
	assert_near(e.stats.get_stat(StatId.Id.MAX_HP), 650.0, 0.01)
	assert_near(e.health, 650.0, 0.01, "vào trận đầy máu")
	assert_near(e.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), 3.4, 0.01)
	assert_near(e.stats.get_stat(StatId.Id.MOVEMENT_SPEED), 255.0, 0.01)
	assert_near(e.stats.get_stat(StatId.Id.PHYSICAL_DAMAGE), 74 + 30, 0.01)
	assert_near(e.stats.get_stat(StatId.Id.ATTACK_RANGE), 150.0, 0.01)


func test_STAT_04_hero_level_from_content() -> void:
	var e: Entity = _brakk(10)
	assert_near(e.stats.get_stat(StatId.Id.STRENGTH), 30 + 3.8 * 9, 0.01)


func test_ids_assigned_by_world() -> void:
	var w: World = World.new(1, _bal)
	var a: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 1, Vector2.ZERO)
	var b: Entity = UnitFactory.hero(w, _lib.heroes[&"vexa"], 1, Vector2.ZERO)
	assert_true(a.id > 0 and b.id == a.id + 1)
	assert_eq(w.entities.size(), 2)
