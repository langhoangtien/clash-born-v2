class_name GraphicsSetting
extends RefCounted
## Mức đồ họa trận 3D (D-151, D-154, D-157), lưu ở user://settings.cfg (cạnh chế độ tiếng):
## THẤP = cảnh 3D vẽ 75% độ phân giải, không khử răng cưa (mặc định); VỪA = đủ độ phân giải, không
## khử răng cưa; CAO = đủ độ phân giải + MSAA 2×. Giao diện, thanh máu luôn nét.

enum Level { LOW, MEDIUM, HIGH }

const PATH: String = "user://settings.cfg"
const NAMES: Array[String] = ["Thấp", "Vừa", "Cao"]
## Tỉ lệ độ phân giải cảnh 3D ở mức THẤP.
const LOW_SCALE: float = 0.75


static func load_level() -> Level:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	return clampi(int(cfg.get_value("graphics", "level", Level.LOW)), 0, NAMES.size() - 1) as Level


static func save_level(level: Level) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("graphics", "level", level)
	cfg.save(PATH)


## Áp mức `level` cho khung nhìn trận.
static func apply(vp: Viewport, level: Level) -> void:
	vp.msaa_3d = Viewport.MSAA_2X if level == Level.HIGH else Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = LOW_SCALE if level == Level.LOW else 1.0
