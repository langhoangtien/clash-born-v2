class_name BuildPresets
extends RefCounted
## SHOP-10 (D-120): bộ đồ soạn sẵn của người chơi, mỗi tướng một bộ, lưu user://builds.cfg.

const PATH: String = "user://builds.cfg"


static func load_build(hero_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) == OK:
		for id: String in cfg.get_value("builds", String(hero_id), PackedStringArray()):
			out.append(StringName(id))
	return out


static func save_build(hero_id: StringName, build: Array[StringName]) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	var ids: PackedStringArray = PackedStringArray()
	for id: StringName in build:
		ids.append(String(id))
	cfg.set_value("builds", String(hero_id), ids)
	cfg.save(PATH)
