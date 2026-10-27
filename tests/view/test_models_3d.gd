extends TestCase
## D-146: cấu hình hình 3D (assets/models/units_3d.json) trỏ tới tệp có thật — mô hình, bảng màu
## theo đội, vũ khí, hoạt ảnh của rig; mọi tướng chơi được đều có mô hình.


func test_D_146_every_entry_resolves() -> void:
	var units: Dictionary = ModelLibrary.config()["units"]
	for id: String in units:
		var cfg: Dictionary = units[id]
		assert_true(ResourceLoader.exists(ModelLibrary.ROOT + cfg["model"] + ".glb"), "%s: mô hình" % id)
		for suffix: String in (["", "_blue", "_red"] if cfg.has("tex") else []):  # D-173: mô hình tự mang ảnh màu
			assert_true(ResourceLoader.exists(ModelLibrary.ROOT + cfg["tex"] + "_texture" + suffix + ".png"), "%s: bảng màu%s" % [id, suffix])
		for hand: String in ["right", "left"]:
			if cfg.has(hand):
				assert_true(ResourceLoader.exists(ModelLibrary.ROOT + cfg[hand] + ".gltf"), "%s: vũ khí %s" % [id, hand])
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
