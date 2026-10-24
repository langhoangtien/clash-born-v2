class_name UnitSprite
extends RefCounted
## Hình đơn vị trong trận (D-144): chọn ảnh (bản theo đội trước), cỡ theo loại, và hoạt ảnh vẽ
## bằng biến đổi — nhún khi đi, ngả ra sau lúc vung tay, lao tới khi ra đòn, phồng khi tung chiêu,
## lóe đỏ khi trúng đòn. Ảnh đã nhập với chân chạm đáy ô (tools/import_units.py). Chỉ đọc World.

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


## Vẽ `tex` neo đáy tại `at`. `moving`: đang di chuyển; `hit_age`: số tick từ lần trúng đòn (-1 = không).
static func draw(ci: CanvasItem, w: World, e: Entity, tex: Texture2D, at: Vector2, height: float,
		moving: bool, hit_age: int, tint: Color) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var offset: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	var squash: Vector2 = Vector2.ONE
	var flip: float = -1.0 if e.facing.x < 0.0 else 1.0
	if moving and not Rules.is_structure(e):
		offset.y -= absf(sin(t * 9.0 + e.id)) * height * 0.035
		angle = sin(t * 9.0 + e.id) * 0.04
	match e.attack_phase:
		Entity.AttackPhase.WINDUP:
			var p: float = clampf(float(w.tick - e.attack_start_tick) / maxf(1.0, e.attack_release_tick - e.attack_start_tick), 0.0, 1.0)
			angle -= 0.14 * p * flip  # ngả ra sau lấy đà
			squash = Vector2(1.0 - 0.04 * p, 1.0 + 0.04 * p)
		Entity.AttackPhase.RECOVERY:
			var since: float = float(w.tick - e.attack_release_tick)
			if since >= 0.0 and since < 6.0:
				offset += e.facing * e.radius * 0.5 * (1.0 - since / 6.0)  # lao tới
				angle += 0.1 * (1.0 - since / 6.0) * flip
	if e.cast != null:
		var pulse: float = 1.0 + 0.05 * sin(t * 20.0)
		squash *= pulse
		ci.draw_circle(at, e.radius * 1.4, Color(1, 0.95, 0.6, 0.18))
	var col: Color = tint
	if hit_age >= 0 and hit_age < HIT_TICKS:
		col = col.lerp(Color(1, 0.35, 0.3, tint.a), 0.55 * (1.0 - float(hit_age) / HIT_TICKS))
	ci.draw_set_transform(at + offset, angle, Vector2(squash.x * flip, squash.y))
	ci.draw_texture_rect(tex, Rect2(Vector2(-height * 0.5, -height), Vector2(height, height)), false, col)
	ci.draw_set_transform(Vector2.ZERO)
