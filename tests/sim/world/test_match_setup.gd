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
