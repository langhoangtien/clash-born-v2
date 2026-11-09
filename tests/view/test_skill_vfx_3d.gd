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
	assert_eq(fx.kinds(), ["cone", "disc"], "W Duy Anh (D-298): vệt quét hình quạt + đĩa bụi dựng bằng shader")
	fx.on_event(w, GameEvent.make(&"damage_taken", w.tick, k.id, s[2].id, 120.0))
	assert_eq(fx.kinds(), ["cone", "disc", "hit"], "trúng chiêu: tia lóe trên mục tiêu")
	fx.on_event(w, GameEvent.make(&"ability_finished", w.tick, k.id, -1, AbilityDef.Slot.INNATE))
	assert_eq(fx.kinds().size(), 3, "chiêu không có công thức (nội tại): không sinh gì")
	fx.advance(5.0)
	assert_eq(fx.kinds(), [], "hết thời gian: gỡ hết")
	fx.free()


## D-250: vệt gió bám đường chạy của chủ chiêu suốt `life` (R Duy Anh, Q Noctis lướt; Q Duy Anh tăng tốc). D-300: Q Duy
## Anh lại là tia gió (người chơi không muốn thêm hào quang dưới chân) nhưng dịu, uốn lượn.
func test_D_250_trail_follows_caster_and_q_buff_follows_for_duration() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var k: Entity = s[1]
	for slot: AbilityDef.Slot in [AbilityDef.Slot.Q, AbilityDef.Slot.R]:
		Abilities.set_rank(w, k, Abilities.of(k, slot), 1)
	var fx: SkillVfx3D = SkillVfx3D.new()
	fx.on_event(w, GameEvent.make(&"ability_finished", w.tick, k.id, -1, AbilityDef.Slot.R))
	assert_eq(fx.kinds(), ["trail", "ring"])
	k.position += Vector2(300, 0)
	fx.advance(0.1)
	assert_near((fx.get_child(0) as SpeedTrail3D).head().x, k.position.x * MatchView3D.S, 0.001, "đầu vệt bám theo hero")
	fx.advance(2.0)
	assert_eq(fx.kinds(), [], "hết vệt lướt: gỡ")
	fx.on_event(w, GameEvent.make(&"ability_finished", w.tick, k.id, -1, AbilityDef.Slot.Q))
	assert_eq(fx.kinds(), ["wave", "trail"], "D-303: luồng gió vụt trước + làn khí kiểu Triệu Vân")
	var air: SpeedTrail3D = fx.get_children().filter(func(n: Node) -> bool: return n is SpeedTrail3D and not n.is_queued_for_deletion())[0]
	assert_eq((air.get_child(0) as MeshInstance3D).material_override.get_shader_parameter("mode"), VfxParts.AIR)
	fx.advance(4.0)
	assert_eq(fx.kinds(), ["trail"], "còn trong 5 s tăng tốc")
	fx.advance(1.5)
	assert_eq(fx.kinds(), [], "hết tăng tốc: gỡ")
	fx.free()


## D-300: vệt bám đường chạy vẽ bằng tia gió dịu (vfx_soft dạng 16) — không còn ảnh (D-270 nạp ảnh vệt đã bỏ).
func test_D_300_trails_use_soft_wind_shader() -> void:
	for key: String in SkillVfx3D.recipes():
		if key.begins_with("_"):
			continue
		for part: Dictionary in SkillVfx3D.recipes()[key]["parts"]:
			assert_false(part.has("tex"), "%s: không còn ảnh" % key)
	var mat: ShaderMaterial = VfxParts.material({"type": "trail", "color": "#5d97ee"}, VfxParts.WIND)
	assert_eq(mat.shader, VfxParts.SHADER)
	assert_eq(mat.get_shader_parameter("mode"), VfxParts.WIND)


## D-296: mảnh dịu (shader, không ảnh) đặt ở chủ chiêu / điểm chọn (sự kiện mang `point`) / mục tiêu; hào quang
## đi theo đơn vị suốt `life` (tên giá trị kỹ năng) rồi tự gỡ.
func test_D_296_soft_parts_at_point_target_and_aura_follows() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var b: Entity = UnitFactory.hero(w, _lib.heroes[&"brakk"], 0, Vector2(500, 500))
	var myra: Entity = UnitFactory.hero(w, _lib.heroes[&"myra"], 0, Vector2(800, 800))
	var noc: Entity = UnitFactory.hero(w, _lib.heroes[&"noctis"], 0, Vector2(300, 300))
	for h: Entity in [b, myra, noc]:
		for slot: AbilityDef.Slot in [AbilityDef.Slot.W, AbilityDef.Slot.R]:
			Abilities.set_rank(w, h, Abilities.of(h, slot), 1)
	var fx: SkillVfx3D = SkillVfx3D.new()
	var ev: GameEvent = GameEvent.make(&"ability_finished", w.tick, myra.id, -1, AbilityDef.Slot.W)
	ev.point = Vector2(1500, 900)
	fx.on_event(w, ev)
	assert_eq(fx.kinds(), ["glow", "ring"])
	assert_near((fx.get_child(1) as Node3D).position.x, 1500 * MatchView3D.S, 0.001, "vành ở điểm chọn")
	fx.on_event(w, GameEvent.make(&"ability_finished", w.tick, noc.id, s[2].id, AbilityDef.Slot.R))
	assert_near((fx.get_child(2) as Node3D).position.x, (s[2] as Entity).position.x * MatchView3D.S, 0.001, "dấu ở mục tiêu")
	fx.on_event(w, GameEvent.make(&"ability_finished", w.tick, b.id, -1, AbilityDef.Slot.W))
	var shield: Node3D = fx.get_child(fx.kinds().find("dome"))
	b.position += Vector2(200, 0)
	fx.advance(0.1)
	assert_near(shield.position.x, b.position.x * MatchView3D.S, 0.001, "khiên (D-297) đi theo tướng")
	var duration: float = Abilities.value(b, Abilities.of(b, AbilityDef.Slot.W), &"duration")
	fx.advance(duration - 0.3)
	assert_true(fx.kinds().has("dome"), "còn trong thời gian giáp")
	fx.advance(0.5)
	assert_false(fx.kinds().has("dome"), "hết thời gian: gỡ")
	fx.free()


## D-296: công thức hợp lệ — khóa là art_id kỹ năng có thật, loại mảnh đã biết, tên giá trị có trong kỹ năng,
## độ đục mảnh dịu ≤ 0,85 (5v5 không chói).
func test_D_296_recipes_valid_and_soft() -> void:
	if _lib == null:
		_lib = ContentLibrary.load_dir()
	var arts: Dictionary = {}
	for a: AbilityDef in _lib.abilities.values():
		arts[String(a.art_id)] = a
	var known: Array = ["hit", "trail", "meteors"] + VfxParts.MODES.keys()
	for key: String in SkillVfx3D.recipes():
		if key.begins_with("_"):
			continue
		assert_true(arts.has(key), "công thức %s: không có kỹ năng art_id này" % key)
		var def: AbilityDef = arts.get(key)
		for part: Dictionary in SkillVfx3D.recipes()[key]["parts"]:
			assert_true(known.has(part["type"]), "%s: loại mảnh lạ %s" % [key, part["type"]])
			for k: String in ["radius", "life", "length", "width", "angle"]:
				if part.get(k) is String and def != null:
					assert_true(def.values.has(StringName(part[k])), "%s.%s: kỹ năng không có giá trị %s" % [key, k, part[k]])
			if VfxParts.is_soft(part["type"]) or part["type"] == "hit":
				assert_true(float(part.get("alpha", 0.6)) <= 0.85, "%s: %s quá đục" % [key, part["type"]])
	for hero: StringName in _lib.heroes:
		for slot: String in ["q", "w", "r"]:
			assert_true(SkillVfx3D.recipes().has("%s_%s" % [hero, slot]), "%s %s chưa có hiệu ứng" % [hero, slot])



## D-298: hiệu ứng trạng thái 3D theo id hiệu ứng (mục _effects): lốc xoáy, xích, khối băng — đi theo đơn vị suốt thời
## gian hiệu ứng, hết hiệu ứng thì gỡ; StateMarks bỏ dấu 2D của đúng trạng thái đó.
func test_D_298_effect_visuals_follow_unit_and_cover_2d_marks() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var foe: Entity = s[2]
	for id: String in ["cyclone", "root", "myra_freeze"]:
		assert_false(EffectVfx3D.parts_of(StringName(id)).is_empty(), "%s có hình 3D" % id)
	var freeze: EffectDef = load("res://content/effects/myra_freeze.tres")
	Effects.apply(w, foe, freeze, s[1], {}, "1")
	assert_true(EffectVfx3D.covers(foe, UnitState.Id.ROOTED), "đóng băng (giữ chân, D-299): bỏ vòng trói 2D")
	assert_false(EffectVfx3D.covers(foe, UnitState.Id.SILENCED))
	var v: EffectVfx3D = EffectVfx3D.new()
	v.sync(w, func(_e: Entity) -> bool: return true)
	assert_eq(v.count(), 1)
	foe.position += Vector2(100, 0)
	v.sync(w, func(_e: Entity) -> bool: return true)
	assert_near((v.get_child(0) as Node3D).position.x, foe.position.x * MatchView3D.S, 0.001, "đi theo đơn vị")
	v.sync(w, func(_e: Entity) -> bool: return false)
	assert_eq(v.count(), 0, "phe mình không thấy: không vẽ")
	foe.effects.clear()
	v.sync(w, func(_e: Entity) -> bool: return true)
	assert_eq(v.count(), 0, "hết hiệu ứng: gỡ")
	v.free()



## D-299: sao choáng 3D trên đầu cho mọi nguồn choáng (mục _states) thay sao 2D; lốc xoáy nhấc hình đơn vị lên và xoay.
func test_D_299_stun_stars_and_cyclone_lift() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var foe: Entity = s[2]
	Effects.apply(w, foe, load("res://content/effects/stun.tres") as EffectDef, s[1], {}, "2")
	assert_true(EffectVfx3D.covers(foe, UnitState.Id.STUNNED), "choáng thường: sao 3D, bỏ sao 2D")
	var v: EffectVfx3D = EffectVfx3D.new()
	v.sync(w, func(_e: Entity) -> bool: return true)
	assert_eq(v.count(), 1, "sao choáng")
	foe.effects.clear()
	Effects.refresh_states(foe)
	v.sync(w, func(_e: Entity) -> bool: return true)
	assert_eq(v.count(), 0, "hết choáng: gỡ")
	Effects.apply(w, foe, load("res://content/effects/cyclone.tres") as EffectDef, foe, {}, "2.5")
	var body: Node3D = Node3D.new()
	w.tick += 20
	EffectVfx3D.pose(w, foe, body)
	assert_true(body.position.y > 1.0, "lốc xoáy: nhấc lên không (%.2f m)" % body.position.y)
	assert_true(absf(body.rotation.y) > 0.1, "xoay")
	body.free()
	v.free()


func test_D_299_hex_frog_is_3d_model() -> void:
	var f: HexFrog3D = HexFrog3D.make(2.0)
	assert_true(f != null, "có mô hình ếch")
	(Engine.get_main_loop() as SceneTree).root.add_child(f)
	f._process(0.3)
	assert_true(f.position.y > 0.0, "đang nhảy")
	f.queue_free()


## D-305: làn khí đứng (Q Duy Anh) luôn quay về camera — rẽ về phía camera / ra xa không còn bị nhìn cạnh mỏng thành
## "vết cắt": cạnh dải = hướng chạy × hướng tới mắt.
func test_D_305_air_ribbon_faces_camera_when_turning() -> void:
	var eye: Vector3 = Vector3(0, 10, 7)  # camera trận: trên cao, chếch về +Z
	var sideways: Vector3 = SpeedTrail3D.facing_side(Vector3.RIGHT, eye)
	assert_true(absf(sideways.y) > 0.5, "chạy ngang màn hình: dải gần như đứng")
	var toward: Vector3 = SpeedTrail3D.facing_side(Vector3.BACK, eye)
	assert_near(toward.length(), 1.0, 0.001)
	assert_true(absf(toward.x) > 0.9, "chạy về phía camera: dải nằm ngang, vẫn thấy bề rộng")


## D-305: chậm vì băng (nội tại Myra, Kiếm Băng) phủ lớp màu băng lên người thay vòng tròn dưới chân; chậm khác giữ vòng.
func test_D_305_frost_slow_tints_body_instead_of_ring() -> void:
	var s: Array = _setup()
	var w: World = s[0]
	var foe: Entity = s[2]
	assert_eq(EffectVfx3D.tint_of(foe).a, 0.0)
	var vals: Dictionary = {&"slow_per_stack": 0.03, &"slow_vs_melee": 0.3, &"slow_vs_ranged": 0.2, &"attack_slow": 20.0,
		&"slow": 0.3}
	for path: String in ["myra_rhythm_stack", "frost_blade_slow_melee", "frost_blade_slow_ranged", "myra_frost_slow"]:
		foe.effects.clear()
		Effects.apply(w, foe, load("res://content/effects/%s.tres" % path) as EffectDef, s[1], vals, "1")
		assert_true(EffectVfx3D.tint_of(foe).a > 0.0, "%s: phủ màu băng" % path)
		assert_false(StateMarks.is_slowed(foe), "%s: bỏ vòng chậm 2D" % path)
	Effects.apply(w, foe, load("res://content/effects/noctis_blade_slow.tres") as EffectDef, s[1], vals, "1")
	assert_true(StateMarks.is_slowed(foe), "chậm không phải băng: vẫn vòng")
	foe.effects.clear()
	assert_eq(EffectVfx3D.tint_of(foe).a, 0.0, "hết hiệu ứng: hết màu")
