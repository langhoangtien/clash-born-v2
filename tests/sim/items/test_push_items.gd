extends TestCase
## D-121: đồ đẩy trụ — Lưỡi Hái Hủy Diệt giảm giáp cả trụ, Mảnh Trăng tốc đánh.

const MAP_PATH: String = "res://data/maps/clashborn.tres"


func _world() -> Array:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load("res://content/balance/balance_settings.tres") as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	MatchSetup.spawn_structures(w, lib)
	MatchSetup.add_shop(w, lib)
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	return [w, lib]


func test_D_121_desolator_attack_lowers_tower_armor() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var lib: ContentLibrary = s[1]
	var tower: Entity = Objectives.next_for_lane(w, 0, "MID")
	tower.locked = false
	var hero: Entity = UnitFactory.hero(w, lib.heroes[&"noctis"], 0, tower.position + Vector2(-200, 200))
	Items.give(w, hero, w.item_catalog[&"desolator"])
	var armor: float = tower.stats.get_stat(StatId.Id.PHYSICAL_ARMOR)
	w.submit(Command.attack(hero.id, tower.id))
	for i: int in range(60):
		w.step()
	assert_near(tower.stats.get_stat(StatId.Id.PHYSICAL_ARMOR), armor - 6.0, 0.01, "đòn đánh giảm 6 giáp của trụ")


func test_D_121_moon_shard_built_from_hyperstone_and_claws() -> void:
	var s: Array = _world()
	var w: World = s[0]
	var lib: ContentLibrary = s[1]
	var hero: Entity = UnitFactory.hero(w, lib.heroes[&"noctis"], 0, Vector2(1000, 1000))
	var before: float = hero.stats.get_stat(StatId.Id.ATTACK_SPEED)
	Items.give(w, hero, w.item_catalog[&"moon_shard"])
	w.step()
	assert_near(hero.stats.get_stat(StatId.Id.ATTACK_SPEED) - before, 1.5, 0.001)
	assert_eq((w.item_catalog[&"moon_shard"] as ItemDef).components, [&"hyperstone", &"claws_fury"] as Array[StringName])
