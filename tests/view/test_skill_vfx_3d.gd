extends TestCase
## D-247: hiệu ứng chiêu 3D theo công thức dữ liệu (assets/vfx/vfx.json, khóa = art_id kỹ năng): chiêu ra
## (`ability_finished`) sinh các mảnh của công thức; sát thương của chủ chiêu ngay sau đó sinh tia lóe trên mục tiêu;
## hết thời gian thì tự gỡ. Chỉ đọc World.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")

static var _lib: ContentLibrary


func _setup() -> Array:
	if _lib == null:
		_lib = ContentLibrary.load_dir()
	var w: World = World.new(1, Fixture.make())
	var k: Entity = UnitFactory.hero(w, _lib.heroes[&"duy_anh"], 0, Vector2(1000, 1000))
	var foe: Entity = Entity.new()
	foe.team = 1
	foe.position = Vector2(1200, 1000)
	foe.stats = StatBlock.new(w.balance)
	w.add_entity(foe)
	return [w, k, foe]


func test_D_247_recipe_parts_hits_and_cleanup() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var k: Entity = s[1]
	var fx: SkillVfx3D = SkillVfx3D.new()
	fx.on_event(w, GameEvent.make(&"ability_finished", w.tick, k.id, -1, AbilityDef.Slot.W))
	assert_eq(fx.kinds(), ["sweep", "burst"], "W Duy Anh: vệt quét + bụi")
	fx.on_event(w, GameEvent.make(&"damage_taken", w.tick, k.id, s[2].id, 120.0))
	assert_eq(fx.kinds(), ["sweep", "burst", "hit"], "trúng chiêu: tia lóe trên mục tiêu")
	fx.on_event(w, GameEvent.make(&"ability_finished", w.tick, k.id, -1, AbilityDef.Slot.R))
	assert_eq(fx.kinds().size(), 3, "chiêu không có công thức (R): không sinh gì")
	fx.advance(5.0)
	assert_eq(fx.kinds(), [], "hết thời gian: gỡ hết")
	fx.free()


## D-250: Xung Phong (Q) để lại vệt gió đi theo hero suốt thời gian tăng tốc (`life` = giá trị `duration` của kỹ năng).
func test_D_250_trail_follows_caster_for_duration() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var k: Entity = s[1]
	Abilities.set_rank(w, k, Abilities.of(k, AbilityDef.Slot.Q), 1)
	var fx: SkillVfx3D = SkillVfx3D.new()
	fx.on_event(w, GameEvent.make(&"ability_finished", w.tick, k.id, -1, AbilityDef.Slot.Q))
	assert_eq(fx.kinds(), ["trail"])
	k.position += Vector2(300, 0)
	fx.advance(0.1)
	assert_near(fx.get_child(0).position.x, k.position.x * MatchView3D.S, 0.001, "đi theo hero")
	fx.advance(4.0)
	assert_eq(fx.kinds(), ["trail"], "còn trong 5 s tăng tốc")
	fx.advance(1.5)
	assert_eq(fx.kinds(), [], "hết tăng tốc: gỡ")
	fx.free()
