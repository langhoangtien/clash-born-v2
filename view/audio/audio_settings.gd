class_name AudioSettings
extends RefCounted
## D-414: cài đặt tiếng — Nhạc (nhạc nền) và Âm thanh (tiếng động trận, tiếng nền map, giao diện) tách hẳn: mỗi thứ một
## công tắc + một âm lượng (0..1), lưu riêng ở settings.cfg [audio], áp vào bus riêng (Music / Sfx, tạo khi chưa có).
## Thay chế độ gộp Bật / Tắt nhạc / Tắt hết của D-114 (đọc chế độ cũ một lần để chuyển).

const DEFAULT_PATH: String = "user://settings.cfg"
const MUSIC_BUS: String = "Music"
const SFX_BUS: String = "Sfx"
const MIN_DB: float = -60.0  ## âm lượng 0 → coi như tắt hẳn (linear_to_db(0) = -inf)

static var file: String = DEFAULT_PATH  ## tệp lưu — test đổi qua use_file()
static var music_on: bool = true
static var sfx_on: bool = true
static var music_volume: float = 1.0
static var sfx_volume: float = 1.0
static var _loaded: bool = false


## Đổi tệp lưu rồi đọc lại (test). Gán thẳng `file` từ ngoài không chắc: biến tĩnh khởi tạo lúc lớp được gọi hàm lần đầu.
static func use_file(f: String) -> void:
	file = f
	reload()


## Đọc lần đầu (gọi nhiều lần không đọc lại).
static func ensure() -> void:
	if not _loaded:
		reload()


static func reload() -> void:
	_loaded = true
	var cfg: ConfigFile = ConfigFile.new()
	var ok: bool = cfg.load(file) == OK
	var old: int = int(cfg.get_value("audio", "mode", 0)) if ok else 0  # D-114: 0 Bật · 1 Tắt nhạc · 2 Tắt hết
	music_on = bool(cfg.get_value("audio", "music_on", old == 0)) if ok else true
	sfx_on = bool(cfg.get_value("audio", "sfx_on", old != 2)) if ok else true
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 1.0)), 0.0, 1.0) if ok else 1.0
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0) if ok else 1.0
	apply()


static func set_music(on: bool) -> void:
	ensure()
	music_on = on
	_save()


static func set_sfx(on: bool) -> void:
	ensure()
	sfx_on = on
	_save()


static func set_music_volume(v: float) -> void:
	ensure()
	music_volume = clampf(v, 0.0, 1.0)
	_save()


static func set_sfx_volume(v: float) -> void:
	ensure()
	sfx_volume = clampf(v, 0.0, 1.0)
	_save()


## Bus Nhạc / Âm thanh theo cài đặt (tạo bus nếu chưa có — đổ về Master).
static func apply() -> void:
	_set_bus(MUSIC_BUS, music_on, music_volume)
	_set_bus(SFX_BUS, sfx_on, sfx_volume)


static func bus_index(name: String) -> int:
	var i: int = AudioServer.get_bus_index(name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, &"Master")
	return i


static func _set_bus(name: String, on: bool, volume: float) -> void:
	var i: int = bus_index(name)
	AudioServer.set_bus_mute(i, not on)
	AudioServer.set_bus_volume_db(i, maxf(MIN_DB, linear_to_db(volume)) if volume > 0.0 else MIN_DB)


static func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(file)
	if cfg.has_section_key("audio", "mode"):
		cfg.erase_section_key("audio", "mode")  # chế độ gộp cũ đã chuyển
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(file)
	apply()
