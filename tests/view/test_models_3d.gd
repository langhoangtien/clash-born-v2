extends TestCase
## D-146: cấu hình hình 3D (assets/models/units_3d.json) trỏ tới tệp có thật — mô hình + hoạt ảnh của rig; mọi tướng chơi
## được đều có mô hình. D-321: gỡ KayKit (bảng màu / vũ khí gắn tay của rig dùng chung).


func test_D_146_every_entry_resolves() -> void:
	var units: Dictionary = ModelLibrary.config()["units"]
	for id: String in units:
		var cfg: Dictionary = units[id]
		assert_true(ResourceLoader.exists(ModelLibrary.MODELS + cfg["model"] + ".glb"), "%s: mô hình" % id)
		var lib: AnimationLibrary = ModelLibrary.unit_animations(cfg)
		var rig: Dictionary = ModelLibrary.rig(cfg["rig"])
		for key: String in ["idle", "run", "dash", "hit", "death"]:
			assert_true(lib.has_animation(rig[key]), "%s: hoạt ảnh %s" % [id, key])
		for key: String in ["attack", "cast"]:
			if cfg.has(key):
				assert_true(lib.has_animation(cfg[key]), "%s: hoạt ảnh %s = %s" % [id, key, cfg[key]])


func test_D_146_playable_heroes_have_models() -> void:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	for id: StringName in lib.heroes:
		assert_false(ModelLibrary.unit(lib.heroes[id].art_id).is_empty(), "%s có mô hình 3D" % id)


## D-203, D-213: quái tự mang xương (rig `Creature`) có đủ hoạt ảnh rig cần; D-218: trụ có ảnh màu theo đội.
func test_D_203_creature_models_have_rig_animations() -> void:
	var rig: Dictionary = ModelLibrary.rig("Creature")
	var n: int = 0
	for art: String in ModelLibrary.config()["units"]:
		var cfg: Dictionary = ModelLibrary.config()["units"][art]
		if cfg.get("rig", "") != "Creature":
			continue
		n += 1
		var m: Node = ModelLibrary.scene(cfg["model"] + ".glb").instantiate()
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		for key: String in ["idle", "run", "dash", "hit", "death"]:
			assert_true(ap.has_animation(rig[key]), "%s có hoạt ảnh %s" % [art, rig[key]])
		assert_true(ap.has_animation(cfg["attack"]), "%s có hoạt ảnh đánh" % art)
		m.free()
	assert_true(n >= 2, "có quái Blender (%d)" % n)
	for team: int in 2:
		assert_true(ModelLibrary.static_scene("style/structures/tower", team) != null, "trụ đội %d" % team)


## D-209: mô hình tự mang xương có `team_tex` dùng ảnh màu theo phe (lính Tripo + afk.ai).
func test_D_209_own_rig_team_texture() -> void:
	var w: World = World.new(1, preload("res://tests/sim/core/balance_fixture.gd").make())
	for team: int in [0, 1]:
		var e: Entity = Entity.new()
		e.kind = Entity.Kind.LANE_CREEP
		e.team = team
		e.art_id = &"creep_melee"
		e.stats = StatBlock.new(w.balance)
		w.add_entity(e)
		var a: Actor3D = Actor3D.make(e)
		var mi: MeshInstance3D = a.find_children("*", "MeshInstance3D", true, false).filter(
				func(n: Node) -> bool: return not ((n as MeshInstance3D).mesh is QuadMesh))[0]
		var tex: Texture2D = (mi.get_active_material(0) as StandardMaterial3D).albedo_texture
		assert_true(tex.resource_path.ends_with(("_blue" if team == 0 else "_red") + ".jpg"), "phe %d: %s" % [team, tex.resource_path])
		a.free()
