extends TestCase
## Dựng trận: lưới tìm đường của lính dựng sẵn lúc vào trận, không dựng giữa trận (tránh giật ở đợt lính đầu).

const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"


func test_creep_navigation_built_at_setup_not_at_first_wave() -> void:
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	w.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	var lib: ContentLibrary = ContentLibrary.load_dir()
	World._nav_cache.clear()
	MatchSetup.spawn_structures(w, lib)
	MatchSetup.add_lane_creeps(w, lib, true)
	var built: int = World.nav_builds
	var creeps: int = 0
	while creeps == 0:
		w.step()
		creeps = w.entities.filter(func(e: Entity) -> bool: return e.kind == Entity.Kind.LANE_CREEP).size()
	w.step()
	assert_eq(World.nav_builds, built, "đợt lính đầu không dựng lưới tìm đường mới")


## D-156: mọi loại đơn vị có thể xuất hiện giữa trận (mắt từ shop, đơn vị triệu hồi…) đã có lưới tìm đường
## từ lúc vào trận — lần cắm mắt đầu tiên không dựng lưới mới (~200 ms, giật ở giây 22).
func test_D_156_every_unit_navigation_built_at_setup() -> void:
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	var lib: ContentLibrary = ContentLibrary.load_dir()
	World._nav_cache.clear()
	MatchSetup.spawn_structures(w, lib)
	MatchSetup.add_shop(w, lib)
	var built: int = World.nav_builds
	for def: UnitDef in lib.units.values():
		w.navigation(def.stats.collision_radius)
	assert_eq(World.nav_builds, built, "không dựng lưới tìm đường mới giữa trận")


## D-285: tạo tướng thì dựng sẵn lưới tìm đường cho cỡ thân tướng đó — lần đi đầu tiên của bot không dựng lưới
## giữa trận (log máy: tick 3–4 đứng ~330 ms, BotController 184 ms ở máy chủ khi tướng có cỡ thân riêng).
func test_D_285_hero_navigation_built_when_hero_created() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	for id: StringName in lib.heroes:
		var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
		w.map = load(MAP_PATH) as MapLayout
		World._nav_cache.clear()
		var h: Entity = UnitFactory.hero(w, lib.heroes[id], 1, w.map.fountain_point(1))
		var built: int = World.nav_builds
		w.navigation(h.radius)
		assert_eq(World.nav_builds, built, "tướng %s: lưới tìm đường có sẵn từ lúc tạo" % id)
