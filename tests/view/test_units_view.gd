extends TestCase
## M1.4: vẽ đơn vị từ World (A0): nội suy vị trí, hình tạm khi thiếu hình, màn trận dựng được.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


func test_art_library_missing_id_returns_null() -> void:
	assert_eq(ArtLibrary.texture(&"no_such_art_id"), null)
	assert_eq(ArtLibrary.texture(&""), null)


func test_interpolates_between_ticks() -> void:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = Entity.new()
	e.stats = StatBlock.new(w.balance)
	w.add_entity(e)
	var view: UnitsView = UnitsView.new()
	view.world = w
	view.capture_previous()
	e.position = Vector2(30, 0)  # như sau một tick đi 30
	view.alpha = 0.5
	assert_eq(view.display_position(e), Vector2(15, 0))
	view.capture_previous()
	assert_eq(view.display_position(e), Vector2(30, 0))


func test_new_unit_without_previous_draws_at_current() -> void:
	var w: World = World.new(1, Fixture.make())
	var view: UnitsView = UnitsView.new()
	view.world = w
	var e: Entity = Entity.new()
	e.position = Vector2(5, 5)
	w.add_entity(e)
	view.alpha = 0.3
	assert_eq(view.display_position(e), Vector2(5, 5))


func test_match_scene_builds_with_a_hero_and_follows_it() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var scene: Node = (load("res://app/match_scene.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	assert_eq(scene.world.entities.size(), 24 + 2, "22 trụ + 2 nhà chính + hero + bot (lính ra ở giây 15)")
	var hero: Entity = scene.hero
	assert_eq(hero.kind, Entity.Kind.HERO)
	scene.tick_frame(1.0)
	assert_eq(scene.world.tick, SimRunner.MAX_STEPS_PER_FRAME)
	assert_true(hero.order.type == Order.Type.IDLE, "không còn tự đi tuần: chỉ đi khi người chơi ra lệnh")
	assert_true(scene.camera.position.distance_to(scene.units_view.display_position(hero)) < 0.01, "camera theo hero")
	scene.free()


func test_ST_state_marks_detect_slow() -> void:
	var w: World = World.new(1, BalanceSettings.new())
	var e: Entity = Entity.new()
	e.stats = StatBlock.new(w.balance)
	w.add_entity(e)
	assert_false(StateMarks.is_slowed(e))
	var d: EffectDef = EffectDef.new()
	d.id = &"slow"
	d.duration = "1"
	d.tags = [&"debuff"]
	var m: ModifierDef = ModifierDef.new()
	m.stat = &"movement_speed"
	m.op = ModifierDef.Op.MULTIPLY
	m.value = "0.7"
	d.modifiers = [m]
	Effects.apply(w, e, d, null)
	assert_true(StateMarks.is_slowed(e))
