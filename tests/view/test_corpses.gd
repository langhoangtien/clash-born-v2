extends TestCase
## D-210: lính / quái chết bị gỡ khỏi World ngay (DeathSystem) — VIEW giữ hình lại phát hoạt ảnh chết, nằm một
## lúc rồi lún xuống đất và gỡ.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


func _wolf() -> Actor3D:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = Entity.new()
	e.kind = Entity.Kind.NEUTRAL
	e.team = 2
	e.art_id = &"neutral_wolf"
	e.stats = StatBlock.new(w.balance)
	w.add_entity(e)
	var a: Actor3D = Actor3D.make(e)
	a.sync(w, e, Vector3.ZERO, false, -100, false)
	return a


func test_D_210_dead_unit_plays_death_then_sinks_and_frees() -> void:
	var a: Actor3D = _wolf()
	var c: Corpses = Corpses.new()
	assert_true(c.add(a, 0.0), "mô hình có hoạt ảnh chết thì giữ lại")
	assert_eq(a._playing, "death")
	var lie: float = a._anim.get_animation("death").length + Corpses.LIE
	c.update(lie - 0.01, 0.1)
	assert_eq(a.position.y, 0.0, "nằm yên tới hết hoạt ảnh + LIE")
	c.update(lie + Corpses.SINK * 0.5, 0.1)
	assert_true(a.position.y < 0.0, "lún xuống đất")
	c.update(lie + Corpses.SINK + 0.01, 0.1)
	assert_true(a.is_queued_for_deletion(), "lún xong thì gỡ")
	assert_eq(c.count(), 0)
