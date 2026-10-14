class_name UnitsView
extends Node2D
## Vẽ mọi đơn vị của World (A0): bóng dưới chân, hình (hoặc hình tạm), thanh máu, hướng
## nhìn; xếp theo y (gần camera vẽ sau). Nội suy giữa hai tick bằng `alpha`.
## Tầng VIEW: chỉ đọc World.

const BLUE: Color = Color(0.25, 0.55, 1.0)
const RED: Color = Color(1.0, 0.3, 0.3)
const NEUTRAL: Color = Color(0.85, 0.75, 0.4)
## Hằng số hiển thị: hình tạm kiểu chibi cao ~2.4 bán kính, đầu ~1/3 chiều cao.
const BODY_HEIGHT: float = 2.4
const BAR_WIDTH: float = 2.2
const BAR_HEIGHT: float = 9.0
## Một tick dời xa hơn chừng này coi là dịch chuyển tức thời.
const TELEPORT_DISTANCE: float = 300.0

var world: World
## 0..1: phần đã trôi giữa tick trước và tick hiện tại.
var alpha: float = 1.0

var _previous: Dictionary[int, Vector2] = {}


## Gọi ngay trước mỗi world.step() để nhớ vị trí cũ.
func capture_previous() -> void:
	_previous.clear()
	for e: Entity in world.entities:
		_previous[e.id] = e.position


func display_position(e: Entity) -> Vector2:
	if not _previous.has(e.id) or _previous[e.id].distance_to(e.position) > TELEPORT_DISTANCE:
		return e.position  # hồi sinh / dịch chuyển: không nội suy kéo vệt
	return _previous[e.id].lerp(e.position, alpha)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var order: Array[Entity] = world.entities.duplicate()
	order.sort_custom(func(a: Entity, b: Entity) -> bool: return display_position(a).y < display_position(b).y)
	for e: Entity in order:
		if e.alive:  # hero chờ hồi sinh không vẽ (ECO-04)
			_draw_unit(e, display_position(e))
	for r: Array in world.recent_areas:
		var age: float = (world.tick - r[2]) / 15.0
		if age < 1.0:
			var col: Color = (BLUE if r[3] == 0 else RED).lightened(0.4)
			draw_circle(r[0], r[1], Color(col, 0.35 * (1.0 - age)))
			draw_arc(r[0], r[1], 0, TAU, 48, Color(col, 0.9 * (1.0 - age)), 4.0, true)
	var font: Font = ThemeDB.fallback_font
	for m: Array in world.recent_misses:
		var age: float = (world.tick - m[1]) / 20.0
		if age < 1.0:
			var at: Vector2 = m[0] - Vector2(28, 90 + 30 * age)
			draw_string_outline(font, at, "Trượt", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color(0, 0, 0, 0.8 * (1.0 - age)))
			draw_string(font, at, "Trượt", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 1.0 - age))
	for p: Projectile in world.projectiles:
		draw_circle(p.position, 7.0, Color(1, 0.95, 0.6))


func _draw_unit(e: Entity, at: Vector2) -> void:
	var color: Color = _team_color(e.team)
	draw_set_transform(at + Vector2(0, e.radius * 0.15), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, e.radius * 1.05, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	if Rules.is_structure(e):
		_draw_structure(e, at, color)
		return
	var tex: Texture2D = ArtLibrary.texture(e.art_id)
	var height: float = e.radius * BODY_HEIGHT * (3.0 if tex != null else 1.0)
	if tex != null:
		var size: Vector2 = Vector2(height, height)
		draw_texture_rect(tex, Rect2(at - Vector2(size.x * 0.5, size.y * 0.85), size), false) if e.facing.x >= 0.0 \
			else draw_texture_rect(tex, Rect2(at + Vector2(size.x * 0.5, -size.y * 0.85), Vector2(-size.x, size.y)), false)
	else:
		_draw_placeholder(e, at, color, height)
	StateMarks.draw(self, e, at, height, world.tick)
	_draw_health(e, at - Vector2(0, height + 14), color)


## Hình tạm: thân tròn màu đội + đầu, mũi tên hướng nhìn.
func _draw_placeholder(e: Entity, at: Vector2, color: Color, height: float) -> void:
	var r: float = e.radius
	var body: Vector2 = at - Vector2(0, height * 0.32)
	var head: Vector2 = at - Vector2(0, height * 0.78)
	draw_circle(body, r * 0.8, color.darkened(0.25))
	draw_circle(head, r * 0.62, Color(0.96, 0.84, 0.7))
	draw_arc(head, r * 0.62, 0, TAU, 24, color.darkened(0.5), 3.0, true)
	draw_arc(body, r * 0.8, 0, TAU, 24, color.darkened(0.6), 3.0, true)
	var tip: Vector2 = at + e.facing * r * 1.3
	draw_line(at, tip, Color(1, 1, 1, 0.85), 4.0, true)
	if e.attack_phase == Entity.AttackPhase.WINDUP:
		# Vung tay (CMB-06): cung trắng phía trước, hình chỉ đọc trạng thái SIM.
		draw_arc(at, r * 1.6, e.facing.angle() - 0.7, e.facing.angle() + 0.7, 12, Color(1, 1, 1, 0.9), 5.0, true)


## Hình tạm công trình: khối vuông màu đội; đang khóa (STR-02) thì có viền xám và ổ khóa.
func _draw_structure(e: Entity, at: Vector2, color: Color) -> void:
	var r: float = e.radius
	var body: Rect2 = Rect2(at - Vector2(r, r * 2.4), Vector2(r * 2, r * 2.4))
	draw_rect(body, color.darkened(0.35))
	draw_rect(body, Color(0, 0, 0, 0.8), false, 4.0)
	draw_circle(at - Vector2(0, r * 2.6), r * 0.45, color.lightened(0.4))
	if e.locked:
		draw_rect(body, Color(0.5, 0.5, 0.5, 0.45))
		draw_rect(Rect2(at - Vector2(10, r * 1.4), Vector2(20, 16)), Color(0.9, 0.9, 0.9))
		draw_arc(at - Vector2(0, r * 1.4), 8, PI, TAU, 8, Color(0.9, 0.9, 0.9), 3.0)
	_draw_health(e, at - Vector2(0, r * 3.4), color)


func _draw_health(e: Entity, center: Vector2, color: Color) -> void:
	if e.stats == null:
		return
	var max_hp: float = maxf(1.0, e.stats.get_stat(StatId.Id.MAX_HP))
	var width: float = e.radius * BAR_WIDTH
	var rect: Rect2 = Rect2(center - Vector2(width * 0.5, BAR_HEIGHT * 0.5), Vector2(width, BAR_HEIGHT))
	draw_rect(rect.grow(2), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(rect.position, Vector2(width * clampf(e.health / max_hp, 0, 1), BAR_HEIGHT)), color)


func _team_color(team: int) -> Color:
	match team:
		0:
			return BLUE
		1:
			return RED
	return NEUTRAL
