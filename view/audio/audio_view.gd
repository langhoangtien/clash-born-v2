class_name AudioView
extends Node
## VIEW (D-114): phát tiếng do AudioCues chọn, nhạc nền và tiếng nền map.
## - Nhỏ dần theo khoảng cách tới camera, quá xa thì bỏ.
## - Chống ồn: tối đa VOICES tiếng cùng lúc, cùng một tiếng cách nhau ít nhất MIN_GAP_MS.
## - Chế độ tiếng (Bật / Tắt nhạc / Tắt hết) lưu ở user://settings.cfg.

enum Mode { ALL, NO_MUSIC, MUTE }

const VOICES: int = 12
const MIN_GAP_MS: int = 70
## Lính đánh liên tục cả trận: cùng một tiếng lính cách nhau lâu hơn để không ồn.
const CREEP_GAP_MS: int = 220
## Khoảng cách (đơn vị map): trong NEAR nghe đủ, tới FAR nhỏ còn FAR_DB, xa hơn không phát.
const NEAR: float = 900.0
const FAR: float = 2600.0
const FAR_DB: float = -22.0
## Độ lớn thêm theo kênh (dB), sau khi file đã được cân (D-113).
const GROUP_DB: Dictionary[StringName, float] = {&"sfx": 0.0, &"ui": -2.0, &"vo": 2.0}
const MUSIC_DB: float = -6.0
const AMB_DB: float = -2.0
const SETTINGS_PATH: String = "user://settings.cfg"
const MODE_NAMES: Array[String] = ["Tiếng: Bật", "Nhạc: Tắt", "Tiếng: Tắt"]

static var mode: int = -1

## Tâm camera; tiếng có vị trí tính khoảng cách từ đây.
var listener: Vector2 = Vector2.ZERO
var cues: AudioCues

var _players: Array[AudioStreamPlayer] = []
var _loops: Dictionary[int, AudioStreamPlayer] = {}
var _last_ms: Dictionary[StringName, int] = {}
var _music: AudioStreamPlayer
var _amb: AudioStreamPlayer
## D-152: tiếng đã chọn sau mỗi tick, chờ flush() phát (tick có thể chạy trên luồng phụ).
var _pending: Array[AudioCues.Cue] = []
var _ended: bool = false


func _ready() -> void:
	load_mode()
	for i: int in range(VOICES):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_amb = AudioStreamPlayer.new()
	add_child(_amb)


func setup_match(team: int, hero_id: int) -> void:
	cues = AudioCues.new()
	cues.team = team
	cues.hero_id = hero_id


## Gọi sau mỗi tick SIM (được gọi trên luồng phụ, D-152): chỉ chọn tiếng, không đụng node.
func on_step(world: World) -> void:
	if cues == null:
		return
	_pending.append_array(cues.collect(world))  # luôn đọc để giữ trạng thái (chuỗi hạ gục…)
	_ended = _ended or world.winner >= 0


## Phát các tiếng đã chọn (luồng chính, mỗi khung).
func flush() -> void:
	for c: AudioCues.Cue in _pending:
		if c.stop:
			_stop_loop(c.key)
		elif mode != Mode.MUTE:
			_play(c)
	_pending.clear()
	if _ended:
		_amb.stop()
		_music.stop()


func play_music(id: StringName, amb_id: StringName = &"") -> void:
	_start(_music, id, MUSIC_DB, mode == Mode.ALL)
	_start(_amb, amb_id, AMB_DB, mode != Mode.MUTE)


func cycle_mode() -> void:
	mode = (mode + 1) % MODE_NAMES.size()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "mode", mode)
	cfg.save(SETTINGS_PATH)
	_music.stream_paused = mode != Mode.ALL
	_amb.stream_paused = mode == Mode.MUTE
	if mode == Mode.MUTE:
		for p: AudioStreamPlayer in _players:
			p.stop()


static func load_mode() -> void:
	if mode >= 0:
		return
	var cfg: ConfigFile = ConfigFile.new()
	mode = int(cfg.get_value("audio", "mode", Mode.ALL)) if cfg.load(SETTINGS_PATH) == OK else Mode.ALL


## Độ lớn (dB) của tiếng tại `at` khi camera ở `listener`; NAN = quá xa, không phát.
static func distance_db(at: Vector2, listener_at: Vector2) -> float:
	if not at.is_finite():
		return 0.0
	var d: float = at.distance_to(listener_at)
	if d > FAR:
		return NAN
	return 0.0 if d <= NEAR else lerpf(0.0, FAR_DB, (d - NEAR) / (FAR - NEAR))


func _play(c: AudioCues.Cue) -> void:
	var s: AudioStream = SoundLibrary.stream(c.id)
	var db: float = distance_db(c.at, listener)
	if s == null or is_nan(db):
		return
	var now: int = Time.get_ticks_msec()
	var gap: int = CREEP_GAP_MS if String(c.id).begins_with("creep_") else MIN_GAP_MS
	if now - _last_ms.get(c.id, -100000) < gap:
		return
	_last_ms[c.id] = now
	var p: AudioStreamPlayer = _free_player(c.group)
	if p == null:
		return
	if c.key >= 0:
		_stop_loop(c.key)
		_loops[c.key] = p
	p.stream = s
	p.volume_db = db + GROUP_DB.get(c.group, 0.0)
	p.play()


## Người phát rảnh; hết thì lấy tiếng hiệu ứng đã phát lâu nhất (giọng thông báo luôn được ưu tiên).
func _free_player(group: StringName) -> AudioStreamPlayer:
	var oldest: AudioStreamPlayer = null
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			return p
		if _loops.values().has(p):
			continue
		if oldest == null or p.get_playback_position() > oldest.get_playback_position():
			oldest = p
	return oldest if group == &"vo" or group == &"ui" else null


func _stop_loop(key: int) -> void:
	if _loops.has(key):
		_loops[key].stop()
		_loops.erase(key)


func _start(p: AudioStreamPlayer, id: StringName, db: float, audible: bool) -> void:
	var s: AudioStream = SoundLibrary.stream(id)
	if s == null:
		p.stop()
		return
	p.stream = s
	p.volume_db = db
	p.play()
	p.stream_paused = not audible
