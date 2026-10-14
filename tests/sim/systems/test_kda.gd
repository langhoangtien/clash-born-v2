extends TestCase
## M4.0: KDA (ECO-09): hạ / chết / hỗ trợ trong `assist_window` giây.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


func _world() -> World:
	var b: BalanceSettings = Fixture.make()
	b.assist_window = 15.0
	return World.new(1, b)


func _hero(w: World, team: int) -> Entity:
	var e: Entity = Entity.new()
	e.team = team
	e.radius = 24.0
	e.stats = StatBlock.new(w.balance)
	e.stats.set_base(StatId.Id.MAX_HP, 1000)
	e.stats.set_base(StatId.Id.DAMAGE_TAKEN_MULTIPLIER, 1.0)
	return w.add_entity(e)


func _hit(w: World, source: Entity, target: Entity, amount: float) -> void:
	var r: DamageRequest = DamageRequest.new()
	r.source_id = source.id if source != null else -1
	r.target_id = target.id
	r.raw = amount
	r.damage_type = DamageFormulas.DamageType.PURE
	w.damage_requests.append(r)
	w.step()


func test_ECO_09_kill_death_and_assist() -> void:
	var w: World = _world()
	var a: Entity = _hero(w, 0)
	var helper: Entity = _hero(w, 0)
	var late: Entity = _hero(w, 0)
	var victim: Entity = _hero(w, 1)
	_hit(w, late, victim, 10.0)
	for i: int in range(16 * 30):
		w.step()
	_hit(w, helper, victim, 100.0)
	_hit(w, a, victim, 5000.0)
	assert_eq(a.kills, 1)
	assert_eq(victim.deaths, 1)
	assert_eq(helper.assists, 1, "gây sát thương trong 15 s trước khi chết")
	assert_eq(late.assists, 0, "quá 15 s thì không tính")
	assert_eq(a.assists, 0, "kẻ hạ không tính hỗ trợ")


func test_ECO_09_tower_kill_counts_death_and_assists_only() -> void:
	var w: World = _world()
	var a: Entity = _hero(w, 0)
	var victim: Entity = _hero(w, 1)
	_hit(w, a, victim, 100.0)
	_hit(w, null, victim, 5000.0)
	assert_eq(victim.deaths, 1)
	assert_eq(a.kills, 0)
	assert_eq(a.assists, 1)
	assert_eq(MatchScore.team_kills(w, 0), 1, "tỷ số tính theo số lần hero đội kia chết")
