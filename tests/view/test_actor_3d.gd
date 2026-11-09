extends TestCase
## Nhân vật 3D (D-157, D-161): phe mình núp bụi / tàng hình (VIS-06, VIS-02) vẽ mờ bằng vật liệu trong suốt
## — trình vẽ Compatibility bỏ qua GeometryInstance3D.transparency nên phải đổi vật liệu.

const Fixture = preload("res://tests/sim/core/balance_fixture.gd")


func _hero_actor() -> Array:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = Entity.new()
	e.kind = Entity.Kind.HERO
	e.team = 0
	e.art_id = &"duy_anh"
	e.stats = StatBlock.new(w.balance)
	w.add_entity(e)
	return [w, e, Actor3D.make(e)]


func _all_transparent(a: Actor3D) -> bool:
	for n: Node in a.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh is QuadMesh:
			continue  # bóng mờ dưới chân
		for i: int in mi.mesh.get_surface_count():
			var m: BaseMaterial3D = mi.get_active_material(i) as BaseMaterial3D
			if m == null or m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				return false
	return true


func test_VIS_06_faded_actor_uses_transparent_materials() -> void:
	var r: Array = _hero_actor()
	var a: Actor3D = r[2]
	a.sync(r[0], r[1], Vector3.ZERO, false, -100, true)
	assert_true(_all_transparent(a), "mọi lưới (cả vũ khí) trong suốt khi mờ")
	a.sync(r[0], r[1], Vector3.ZERO, false, -100, false)
	assert_false(_all_transparent(a), "hết mờ thì về vật liệu đặc")
	a.free()


## Lỗi người chơi báo (D-208): quái vừa đánh xong đuổi theo thì trượt trên đất — pha thu tay vẫn phát hoạt ảnh
## đánh dù đang đi. CMB-06: thu tay bị di chuyển hủy, hoạt ảnh theo sim → đang đi thì chạy.
func test_CMB_06_recovery_while_moving_plays_run() -> void:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = Entity.new()
	e.kind = Entity.Kind.NEUTRAL
	e.team = 2
	e.art_id = &"neutral_wolf"
	e.stats = StatBlock.new(w.balance)
	w.add_entity(e)
	var a: Actor3D = Actor3D.make(e)
	e.attack_phase = Entity.AttackPhase.RECOVERY
	a.sync(w, e, Vector3.ZERO, false, -100, false)
	assert_eq(a._playing, "attack", "thu tay đứng yên: hoạt ảnh đánh")
	a.sync(w, e, Vector3.ZERO, true, -100, false)
	assert_eq(a._playing, "run", "thu tay mà đang đi: chạy, không trượt")
	a.sync(w, e, Vector3.ZERO, false, -100, false)
	assert_eq(a._playing, "idle", "đã thôi đòn thì không quay lại hoạt ảnh đánh")
	a.free()


func _unit(w: World, art: StringName, kind: Entity.Kind) -> Entity:
	var e: Entity = Entity.new()
	e.kind = kind
	e.team = 1
	e.art_id = art
	e.stats = StatBlock.new(w.balance)
	return w.add_entity(e)


## Lỗi người chơi báo (D-216): đánh choáng lính mà hình vẫn đánh tiếp — đang thu tay thì VIEW cứ phát hoạt ảnh
## đánh. ST-01: choáng không đánh, không đi → hoạt ảnh choáng (nếu mô hình có, vd lính), không thì đứng yên (sói).
func test_ST_01_stunned_unit_does_not_play_attack() -> void:
	var w: World = World.new(1, Fixture.make())
	for pair: Array in [[&"creep_melee", Entity.Kind.LANE_CREEP, "stun"], [&"neutral_wolf", Entity.Kind.NEUTRAL, "idle"]]:
		var e: Entity = _unit(w, pair[0], pair[1])
		var a: Actor3D = Actor3D.make(e)
		e.attack_phase = Entity.AttackPhase.RECOVERY
		a.sync(w, e, Vector3.ZERO, false, -100, false)
		assert_eq(a._playing, "attack", "%s: đang thu tay" % pair[0])
		e.states |= 1 << UnitState.Id.STUNNED
		a.sync(w, e, Vector3.ZERO, false, -100, false)
		assert_eq(a._playing, pair[2], "%s: bị choáng thì thôi đánh" % pair[0])
		a.free()


## D-229: đang được tăng tốc (hệ số tốc chạy ≥ sprint_above) thì chạy dáng nước rút; lao tới phát hoạt ảnh lao
## riêng của đơn vị, kể cả ngay sau khi tung chiêu (không trôi người).
func test_D_229_sprint_when_hasted_and_dash_animation() -> void:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = _unit(w, &"duy_anh", Entity.Kind.HERO)
	var a: Actor3D = Actor3D.make(e)
	a.sync(w, e, Vector3.ZERO, true, -100, false)
	assert_eq(a._playing, "run", "chạy thường")
	e.stats.add_modifier(StatModifier.make(StatId.Id.MOVEMENT_SPEED, ModifierDef.Op.MULTIPLY, 1.4, 99))
	a.sync(w, e, Vector3.ZERO, true, -100, false)
	assert_eq(a._playing, "sprint", "tăng tốc 40%: chạy nước rút")
	a.on_cast(2)
	e.dash = DashState.new()
	a.sync(w, e, Vector3.ZERO, true, -100, false)
	assert_eq(a._playing, "dash", "đang lao tới: hoạt ảnh lao, không bị hoạt ảnh chiêu giữ lại")
	a.free()


## D-230 (người chơi: chiêu Brakk trông như phát ngay, bị choáng giữa lúc vung vẫn thấy động tác): hoạt ảnh chiêu
## có thời gian vung chạy để điểm trúng rơi đúng lúc nổ; bị choáng thì thôi hoạt ảnh chiêu.
func test_D_230_skill_animation_timed_to_windup_and_cancelled_by_stun() -> void:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = _unit(w, &"brakk", Entity.Kind.HERO)
	var a: Actor3D = Actor3D.make(e)
	a.sync(w, e, Vector3.ZERO, false, -100, false)
	a.on_cast(1, 0.5)
	var length: float = a._anim.get_animation("skill_1").length
	assert_near(a._speed, length * 0.6 / 0.5, 0.01, "điểm trúng (0,6 độ dài) rơi sau 0,5 s")
	assert_eq(a._playing, "skill_1")
	e.states |= 1 << UnitState.Id.STUNNED
	a.sync(w, e, Vector3.ZERO, false, -100, false)
	assert_ne(a._playing, "skill_1", "bị choáng: thôi hoạt ảnh chiêu")
	a.free()


## D-245: đang tàng hình (INVISIBLE, vd Màn Đêm của Noctis) mà di chuyển thì đi dáng lén (`stealth` trong units_3d.json).
func test_D_245_stealth_walk_when_invisible() -> void:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = _unit(w, &"noctis", Entity.Kind.HERO)
	var a: Actor3D = Actor3D.make(e)
	a.sync(w, e, Vector3.ZERO, true, -100, false)
	assert_eq(a._playing, "run", "chạy thường")
	e.states |= 1 << UnitState.Id.INVISIBLE
	a.sync(w, e, Vector3.ZERO, true, -100, true)
	assert_eq(a._playing, "stealth", "tàng hình: đi lén")
	a.sync(w, e, Vector3.ZERO, false, -100, true)
	assert_eq(a._playing, "idle", "đứng yên vẫn là dáng đứng")
	a.free()


## D-249: đơn vị có `attack_alt` (units_3d.json) thì các đòn đánh luân phiên hai hoạt ảnh (Noctis hai kiểu chém).
func test_D_249_attacks_alternate_two_animations() -> void:
	var w: World = World.new(1, Fixture.make())
	var e: Entity = _unit(w, &"noctis", Entity.Kind.HERO)
	var a: Actor3D = Actor3D.make(e)
	var seen: Array[String] = []
	for k: int in 3:
		e.attack_phase = Entity.AttackPhase.WINDUP
		e.attack_start_tick = 10 + k * 40
		e.attack_release_tick = e.attack_start_tick + 9
		a.sync(w, e, Vector3.ZERO, false, -100, false)
		seen.append(a._playing)
	assert_eq(seen, ["attack", "attack_2", "attack"], "đòn 1, 2, 3 luân phiên")
	a.free()


func test_D_277_creeps_animate_at_half_rate_heroes_full() -> void:
	var w: World = World.new(1, Fixture.make())
	var creep: Actor3D = Actor3D.make(_unit(w, &"creep_melee", Entity.Kind.LANE_CREEP))
	var hero: Actor3D = Actor3D.make(_unit(w, &"duy_anh", Entity.Kind.HERO))
	assert_eq(creep._anim.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "lính: xương cập nhật tay")
	assert_eq(hero._anim.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE, "hero: 60 lần / giây như cũ")
	var done: Array[bool] = []
	for f: int in 4:
		done.append(creep._rate.tick(1.0 / 60.0, f))
	assert_eq(done.count(true), 2, "30 lần / giây: cách một khung")
	assert_true(done[0] != done[1], "so le theo đơn vị")
	assert_true(hero._rate == null, "hero tự chạy")
	creep.free()
	hero.free()


func test_D_277_corpse_animates_on_its_own() -> void:
	var w: World = World.new(1, Fixture.make())
	var creep: Actor3D = Actor3D.make(_unit(w, &"creep_melee", Entity.Kind.LANE_CREEP))
	assert_true(Corpses.new().add(creep, 0.0))
	assert_eq(creep._anim.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE,
		"xác không còn được đồng bộ: hoạt ảnh chết tự chạy")
	creep.free()


## D-322 / D-323 / D-324 / D-326: Gorran — kiếm trong bao sau lưng, đánh thường đấm; đang có gorran_rage thì da đỏ (ảnh màu
## `skin`), sau props_after (lúc tay tới sau vai) kiếm hiện trên tay và cán sau lưng ẩn (bao vẫn đeo), đánh luân phiên
## chém tay phải / tay trái; hết hiệu ứng trả về hình gốc.
func test_D_326_rage_draws_swords_from_back_red_skin_slash_trail() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var w: World = World.new(1, BalanceSettings.new())
	var g: Entity = UnitFactory.hero(w, lib.heroes[&"gorran"], 0, Vector2(500, 500))
	var cfg: Dictionary = ModelLibrary.unit(g.art_id)
	var a: Actor3D = Actor3D.make(g)
	var calm: Dictionary = EffectLook.of(cfg, g, w.tick)
	EffectLook.apply(a._meshes, a._base, a._solid, calm, cfg, false)
	assert_eq(_surfaces(a), [5, 0, 2], "chưa Cuồng Hóa: thân, bao + cán kiếm sau lưng; kiếm trên tay ẩn")
	assert_eq(ModelLibrary.attack_pick(cfg.merged(calm, true), 0, 0.4)[0], "attack", "đánh thường: đấm")
	var values: Dictionary = {&"bat_cut": 0.3, &"regen": 15.0, &"move_bonus": 30.0, &"rage_damage": 0.0, &"duration": 25.0}
	Effects.apply(w, g, load("res://content/effects/gorran_rage.tres") as EffectDef, g, values, "25")
	var look: Dictionary = EffectLook.of(cfg, g, w.tick)
	assert_false(look["drawn"], "vừa Cuồng Hóa: tay chưa tới sau vai, chưa rút")
	assert_true(ResourceLoader.exists(ModelLibrary.MODELS + String(look.get("skin", ""))), "có ảnh da đỏ")
	look = EffectLook.of(cfg, g, w.tick + SimClock.seconds_to_ticks(float(look["props_after"])))
	assert_true(look["drawn"], "rút xong")
	EffectLook.apply(a._meshes, a._base, a._solid, look, cfg, false)
	assert_eq(_surfaces(a), [4, 1, 2], "da đỏ, kiếm trên tay + bao hiện, cán sau lưng ẩn")
	assert_true(_trail(a), "D-326: rút kiếm thì có vệt chém bám lưỡi kiếm")
	var picks: Array = [ModelLibrary.attack_pick(cfg.merged(look, true), 0, 0.4)[0], ModelLibrary.attack_pick(cfg.merged(look, true), 1, 0.4)[0]]
	assert_eq(picks, ["attack_rage", "attack_rage_l"], "chém luân phiên tay phải / tay trái")
	for anim: String in ["attack", "attack_rage", "attack_rage_l", "skill_3"]:
		assert_true(a._anim.has_animation(anim), "mô hình có hoạt ảnh " + anim)
	EffectLook.apply(a._meshes, a._base, a._solid, calm, cfg, false)
	assert_eq(_surfaces(a), [5, 0, 2], "hết hiệu ứng: da gốc, kiếm về bao")
	assert_false(_trail(a), "cất kiếm: gỡ vệt chém")
	a.free()


func _trail(a: Actor3D) -> bool:
	var mi: MeshInstance3D = a._meshes[0] as MeshInstance3D
	var t: Node = mi.get_node(mi.skeleton).get_node_or_null(NodePath(SwordTrail3D.NAME))
	return t != null and not t.is_queued_for_deletion()


## [bề mặt giữ vật liệu gốc, bề mặt đổi ảnh da, bề mặt ẩn] của lưới đầu tiên.
func _surfaces(a: Actor3D) -> Array[int]:
	var out: Array[int] = [0, 0, 0]
	for k: int in a._base[0].size():
		var m: Material = a._solid[0][k]
		out[0 if m == a._base[0][k] else 2 if m is ShaderMaterial else 1] += 1
	return out
