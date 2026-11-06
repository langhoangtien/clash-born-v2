class_name ArtLibrary
extends RefCounted
## Mọi tra cứu hình đi qua đây (ART.md nguyên tắc 3). Hình ở res://assets/art/<id>.png;
## thiếu thì trả null và VIEW vẽ hình tạm, không bao giờ lỗi.

const ROOT: String = "res://assets/art/"

static var _cache: Dictionary[StringName, Texture2D] = {}
static var _missing: Dictionary[StringName, bool] = {}
## D-269: hình đang nạp ngầm (luồng phụ): art_id → đường dẫn.
static var _pending: Dictionary[StringName, String] = {}


static func texture(art_id: StringName) -> Texture2D:
	if art_id.is_empty() or _missing.has(art_id):
		return null
	if _cache.has(art_id):
		return _cache[art_id]
	if _pending.has(art_id):  # D-269: đã nạp ngầm — xong thì lấy ngay, chưa xong thì chờ phần còn lại
		_cache[art_id] = ResourceLoader.load_threaded_get(_pending[art_id]) as Texture2D
		_pending.erase(art_id)
		return _cache[art_id]
	var path: String = ROOT + String(art_id) + ".png"
	if not ResourceLoader.exists(path):
		_missing[art_id] = true
		return null
	_cache[art_id] = load(path) as Texture2D
	return _cache[art_id]


## D-269: nạp ngầm (luồng phụ) các hình có thể hiện giữa trận, để lần hiện đầu không phải đọc đĩa trên luồng
## chính (log 0.1.455: ~15 lần đứng ~130 ms). Bản web không có luồng phụ → bỏ qua, nạp khi cần như cũ.
static func load_ahead(ids: Array) -> void:
	if OS.has_feature("web"):
		return
	for v: Variant in ids:
		var id: StringName = StringName(v)
		if id.is_empty() or _cache.has(id) or _missing.has(id) or _pending.has(id):
			continue
		var path: String = ROOT + String(id) + ".png"
		if not ResourceLoader.exists(path):
			_missing[id] = true
		elif ResourceLoader.load_threaded_request(path, "Texture2D") == OK:
			_pending[id] = path


## Hình của nội dung có thể hiện giữa trận: icon đồ, chiêu, hiệu ứng (buff), chân dung hero.
static func content_ids(lib: ContentLibrary) -> Array[StringName]:
	var out: Array[StringName] = []
	for list: Array in [lib.items.values(), lib.abilities.values(), lib.effects.values()]:
		for d: Variant in list:
			if d.art_id != &"":
				out.append(d.art_id)
	for id: StringName in lib.heroes:
		out.append(StringName(String(id) + "_portrait"))
	return out


static func is_pending(art_id: StringName) -> bool:
	return _pending.has(art_id)


## Test: quên mọi hình đã nạp (đang nạp ngầm thì lấy xong rồi bỏ).
static func clear_for_test() -> void:
	for id: StringName in _pending:
		ResourceLoader.load_threaded_get(_pending[id])
	_pending.clear()
	_cache.clear()
	_missing.clear()
