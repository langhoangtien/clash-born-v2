class_name SoundLibrary
extends RefCounted
## Mọi tra cứu âm thanh đi qua đây (D-113). Tiếng ở res://assets/audio/<id>.ogg; thiếu thì
## trả null và không phát gì, không bao giờ lỗi.

const ROOT: String = "res://assets/audio/"
## Tiếng lặp liền mạch.
const LOOP_PREFIXES: Array[String] = ["music_", "amb_", "recall_start"]

static var _cache: Dictionary[StringName, AudioStream] = {}
static var _missing: Dictionary[StringName, bool] = {}


static func stream(id: StringName) -> AudioStream:
	if id.is_empty() or _missing.has(id):
		return null
	if _cache.has(id):
		return _cache[id]
	var path: String = ROOT + String(id) + ".ogg"
	if not ResourceLoader.exists(path):
		_missing[id] = true
		return null
	var s: AudioStream = load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = LOOP_PREFIXES.any(func(p: String) -> bool: return String(id).begins_with(p))
	_cache[id] = s
	return s
