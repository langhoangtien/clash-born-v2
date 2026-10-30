class_name GraphicsSetting
extends RefCounted
## Mức đồ họa trận 3D (D-151, D-157, D-181), lưu ở user://settings.cfg (cạnh chế độ tiếng): độ phân giải
## cảnh 3D theo SCALES — THẤP 50% (mặc định), VỪA 75%, CAO 100%. Không MSAA (đo trên MatePad không đổi FPS,
## không thấy khác). Giao diện, thanh máu, chữ luôn nét.

enum Level { LOW, MEDIUM, HIGH }

const PATH: String = "user://settings.cfg"
const NAMES: Array[String] = ["Thấp", "Vừa", "Cao"]
## Tỉ lệ độ phân giải cảnh 3D theo mức.
const SCALES: Array[float] = [0.5, 0.75, 1.0]
const DEFAULT: Level = Level.LOW
## D-183: hiện FPS · SIM ms trong trận (bản thử: bật mặc định).
const SHOW_FPS_DEFAULT: bool = true


static func load_level() -> Level:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	return clampi(int(cfg.get_value("graphics", "level", DEFAULT)), 0, NAMES.size() - 1) as Level


static func save_level(level: Level) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("graphics", "level", level)
	cfg.save(PATH)


## Áp mức `level` cho khung nhìn trận.
static func apply(vp: Viewport, level: Level) -> void:
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = SCALES[level]


static func load_show_fps() -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	return bool(cfg.get_value("graphics", "show_fps", SHOW_FPS_DEFAULT))


static func save_show_fps(on: bool) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("graphics", "show_fps", on)
	cfg.save(PATH)


## D-183: mức kế tiếp (Thấp → Vừa → Cao → Thấp), lưu ngay.
static func cycle() -> Level:
	var next: Level = ((load_level() + 1) % NAMES.size()) as Level
	save_level(next)
	return next
