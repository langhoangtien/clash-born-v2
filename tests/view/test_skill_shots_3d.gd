extends TestCase
## D-296: đạn kỹ năng vẽ 3D (vệt dịu + đốm đầu) theo mảnh `shot` của kỹ năng; đạn địch ngoài tầm nhìn không vẽ;
## sự kiện `ability_finished` mang điểm chọn để vẽ hiệu ứng đúng chỗ.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")
const MAP_PATH: String = "res://data/maps/clashborn.tres"
const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"


func _shot(w: World, src: Entity, at: Vector2) -> SkillShot:
	var s: SkillShot = SkillShot.new()
	s.source_id = src.id
	s.team = src.team
	s.position = at
	s.direction = Vector2.RIGHT
	s.half_width = 60.0
	w.skill_shots.append(s)
	return s


func test_D_296_skill_shot_drawn_3d_with_ability_color() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, Fixture.make())
	var myra: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 0, Vector2(500, 500))
	var s: SkillShot = _shot(w, myra, Vector2(700, 500))
	assert_eq(SkillShots3D.shot_part(w, s).get("color"), "#7fb2e0", "màu theo mảnh shot của Myra")
	var v: SkillShots3D = SkillShots3D.new()
	v.sync(w)
	assert_eq(v.count(), 1)
	assert_near((v.get_child(0) as Node3D).position.x, 700 * MatchView3D.S, 0.001)
	w.skill_shots.clear()
	v.sync(w)
	assert_eq(v.count(), 0, "đạn hết: gỡ")
	v.free()


func test_D_296_enemy_shot_hidden_outside_vision() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, Fixture.make())
	var foe: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 1, Vector2(5000, 5000))
	UnitFactory.hero(w, lib.heroes[&"brakk"], 0, Vector2(500, 500))
	_shot(w, foe, Vector2(5200, 5000))
	var v: SkillShots3D = SkillShots3D.new()
	v.viewer_team = 0
	v.sync(w)
	assert_eq(v.count(), 0, "đạn địch ngoài tầm nhìn phe mình")
	v.free()


func test_D_296_ability_finished_carries_point() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, load(BALANCE_PATH) as BalanceSettings)
	w.map = load(MAP_PATH) as MapLayout
	var at: Vector2 = w.map.fountain_point(0) + Vector2(300, -300)
	var myra: Entity = UnitFactory.hero(w, lib.heroes[&"myra"], 0, at)
	Abilities.set_rank(w, myra, Abilities.of(myra, AbilityDef.Slot.W), 1)
	myra.mana = 1000.0
	var point: Vector2 = at + Vector2(250, 0)
	w.submit(Command.cast(myra.id, AbilityDef.Slot.W, -1, point))
	var got: GameEvent = null
	for i: int in 60:
		w.step()
		for ev: GameEvent in w.events:
			if ev.type == &"ability_finished":
				got = ev
		if got != null:
			break
	assert_true(got != null, "chiêu ra")
	assert_eq(got.point, point, "sự kiện mang điểm chọn")
