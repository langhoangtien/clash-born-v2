class_name PerfSettings
extends RefCounted
## D-268: công tắc "Ghi log hiệu năng" (Cài đặt), lưu user://settings.cfg; mặc định tắt (tắt thì không tốn gì).

const PATH: String = "user://settings.cfg"


static func enabled() -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	return bool(cfg.get_value("perf", "log", false))


static func save_enabled(on: bool) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("perf", "log", on)
	cfg.save(PATH)
