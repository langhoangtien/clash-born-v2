class_name ArtLibrary
extends RefCounted
## Mọi tra cứu hình đi qua đây (ART.md nguyên tắc 3). Hình ở res://assets/art/<id>.png;
## thiếu thì trả null và VIEW vẽ hình tạm, không bao giờ lỗi.

const ROOT: String = "res://assets/art/"

static var _cache: Dictionary[StringName, Texture2D] = {}
static var _missing: Dictionary[StringName, bool] = {}


static func texture(art_id: StringName) -> Texture2D:
	if art_id.is_empty() or _missing.has(art_id):
		return null
	if _cache.has(art_id):
		return _cache[art_id]
	var path: String = ROOT + String(art_id) + ".png"
	if not ResourceLoader.exists(path):
		_missing[art_id] = true
		return null
	_cache[art_id] = load(path) as Texture2D
	return _cache[art_id]
