class_name UnitSprite
extends RefCounted
## Ảnh đơn vị cho hình ảnh đứng của trận 3D (D-144, D-157): chọn ảnh (bản theo đội trước) và chiều cao
## theo loại. Ảnh đã nhập với chân chạm đáy ô (tools/import_units.py). Chỉ đọc World.

## Chiều cao hình = bán kính × hệ số (hằng số hiển thị).
const HEIGHT: Dictionary = {
	Entity.Kind.HERO: 6.4, Entity.Kind.LANE_CREEP: 5.0, Entity.Kind.NEUTRAL: 5.6,
	Entity.Kind.TOWER: 6.4, Entity.Kind.CORE: 5.2,
}
const SIEGE_HEIGHT: float = 6.8
## Bao lâu sau khi trúng đòn còn lóe (tick).
const HIT_TICKS: int = 5


## Ảnh của đơn vị: `<art_id>_blue|_red` → `<art_id>`; trụ bậc 4 (lính gác nhà) dùng `tower_guard_*`.
static func texture_of(e: Entity) -> Texture2D:
	var key: int = e.id
	if _cache.has(key) and _cache_art[key] == e.art_id:
		return _cache[key]
	var tex: Texture2D = _find(e)
	_cache[key] = tex
	_cache_art[key] = e.art_id
	return tex


## D-149: ảnh theo id đơn vị (phe, art_id, bậc trụ không đổi trong đời đơn vị) — tránh ghép chuỗi mỗi khung.
static var _cache: Dictionary[int, Texture2D] = {}
static var _cache_art: Dictionary[int, StringName] = {}


static func clear_cache() -> void:
	_cache.clear()
	_cache_art.clear()


static func _find(e: Entity) -> Texture2D:
	var base: String = String(e.art_id)
	if e.kind == Entity.Kind.TOWER and e.tier == 4:
		base = "tower_guard"
	if e.team == 0 or e.team == 1:
		var tex: Texture2D = ArtLibrary.texture(StringName(base + ("_blue" if e.team == 0 else "_red")))
		if tex != null:
			return tex
	return ArtLibrary.texture(StringName(base))


static func height_of(e: Entity) -> float:
	if e.siege:
		return e.radius * SIEGE_HEIGHT
	return e.radius * HEIGHT.get(e.kind, 5.0)
