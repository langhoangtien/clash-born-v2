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
## Phe người chơi (M5.1): hero/lính địch phe này không thấy thì không vẽ. -1 = vẽ hết.
var viewer_team: int = -1
## 0..1: phần đã trôi giữa tick trước và tick hiện tại.
var alpha: float = 1.0

var _previous: Dictionary[int, Vector2] = {}
## D-144: tick đơn vị trúng sát thương gần nhất (lóe đỏ).
var _hit_tick: Dictionary[int, int] = {}
var _vfx: Vfx = Vfx.new()
## Bản 3D thử (D-145): chỉ vẽ phần nằm trên mặt đất (bóng, vòng đội, vùng, hiệu ứng); hình đơn vị do View3D vẽ.
var ground_only: bool = false
var _vfx_tick: int = -1
## D-149: vùng đang nhìn (tọa độ map); đơn vị ngoài vùng không vẽ. Rỗng = vẽ hết.
var view_rect: Rect2 = Rect2()
const CULL_MARGIN: float = 400.0


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
	if world != null and world.tick != _vfx_tick:
		_vfx_tick = world.tick
		_vfx.collect(world)
		for ev: GameEvent in world.events:
			if ev.type == &"damage_taken" and ev.amount > 0.0:
				_hit_tick[ev.target_id] = ev.tick
	queue_redraw()


## D-145: cho bản 3D đọc.
func is_moving(e: Entity) -> bool:
	return _moving(e)


func hit_tick(e: Entity) -> int:
	return _hit_tick.get(e.id, -100)


func _moving(e: Entity) -> bool:
	return _previous.has(e.id) and _previous[e.id].distance_squared_to(e.position) > 1.0


func _draw() -> void:
	if world == null:
		return
	ZonePainter.draw(self, world)
	for item: Array in visible_units():
		var e: Entity = item[1]
		var at: Vector2 = item[0]
		if e.dash != null:  # ABL-08: vệt lướt
			var col: Color = _team_color(e.team).lightened(0.4)
			draw_line(at - e.facing * 110.0, at, Color(col, 0.4), e.radius * 1.6, true)
			draw_line(at - e.facing * 70.0, at, Color(col, 0.8), e.radius * 0.8, true)
		if ground_only:
			_draw_ground_mark(e, at)
		else:
			_draw_unit(e, at)
	_vfx.draw(self, world)
	for s: SkillShot in world.skill_shots:  # đạn kỹ năng (ABL-05); của địch chỉ hiện trong tầm nhìn
		if viewer_team >= 0 and s.team != viewer_team and not FogView.lit(world, viewer_team, s.position):
			continue
		var col: Color = (BLUE if s.team == 0 else RED).lightened(0.5)
		var tail: Vector2 = s.position - s.direction * minf(90.0, s.travelled + 1.0)
		draw_line(tail, s.position, Color(col, 0.35), s.half_width * 1.2, true)
		draw_line(tail, s.position, Color(col, 0.9), s.half_width * 0.4, true)
		draw_circle(s.position, s.half_width * 0.45, Color(1, 1, 1, 0.9))
	FloatingText.draw(self, world)
	for p: Projectile in world.projectiles:
		draw_circle(p.position, 7.0, Color(1, 0.95, 0.6))


## D-145: bóng + vòng màu đội dưới chân (bản 3D).
func _draw_ground_mark(e: Entity, at: Vector2) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 1.0))
	draw_circle(Vector2.ZERO, e.radius * 1.1, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if e.kind == Entity.Kind.HERO or e.kind == Entity.Kind.LANE_CREEP:
		draw_arc(at, e.radius * 1.05, 0, TAU, 32, Color(_team_color(e.team), 0.85), 4.0 if e.kind == Entity.Kind.HERO else 2.5, true)


## D-149: các đơn vị cần vẽ khung này, [vị trí hiển thị, Entity], xếp theo y. Bỏ đơn vị chết /
## không thấy (ECO-04, sương mù) và đơn vị ngoài `view_rect` (nới CULL_MARGIN cho hình cao, thanh máu).
func visible_units() -> Array[Array]:
	var area: Rect2 = view_rect.grow(CULL_MARGIN)
	var list: Array[Array] = []
	for e: Entity in world.entities:
		if not e.alive or not seen(e):
			continue
		var at: Vector2 = display_position(e)
		if view_rect.has_area() and not area.has_point(at):
			continue
		list.append([at, e])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y < b[0].y)
	return list


## Vẽ đơn vị này không: phe mình, công trình (vị trí cố định, như Dota) hoặc đang thấy.
func seen(e: Entity) -> bool:
	return viewer_team < 0 or e.team == viewer_team or Rules.is_structure(e) or Rules.is_visible(viewer_team, e)


## Vẽ mờ: GHOST (ST-11), hoặc đơn vị phe mình đang núp bụi (VIS-06) / tàng hình (VIS-02).
func faded(e: Entity) -> bool:
	if Rules.has_state(e, UnitState.Id.GHOST):
		return true
	return viewer_team >= 0 and e.team == viewer_team and (e.bush_id >= 0 or Rules.has_state(e, UnitState.Id.INVISIBLE))


func _draw_unit(e: Entity, at: Vector2) -> void:
	var color: Color = _team_color(e.team)
	draw_set_transform(at + Vector2(0, e.radius * 0.15), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, e.radius * 1.05, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	if Rules.is_structure(e):
		var stex: Texture2D = UnitSprite.texture_of(e)
		if stex == null:
			_draw_structure(e, at, color)
			return
		var sh: float = UnitSprite.height_of(e)
		UnitSprite.draw(self, world, e, stex, at + Vector2(0, e.radius * 0.35), sh, false, world.tick - _hit_tick.get(e.id, -100), Color.WHITE)
		if e.locked:
			_draw_lock(at - Vector2(0, sh * 0.45))
		_draw_health(e, at - Vector2(0, sh * 0.95), color)
		return
	if e.kind == Entity.Kind.WARD:
		_draw_ward(e, at)
		return
	if e.reincarnate_tick >= 0:  # DTH-02: nằm chờ tái sinh
		_draw_lying(e, at, color)
		return
	var hexed: bool = Rules.has_state(e, UnitState.Id.HEXED)
	var tex: Texture2D = ArtLibrary.texture(&"hex_frog") if hexed else UnitSprite.texture_of(e)
	if hexed and tex == null:  # ST-16: hình con ếch tạm
		_draw_frog(e, at, color)
		return
	var height: float = (e.radius * 3.0 if hexed else UnitSprite.height_of(e)) if tex != null else e.radius * BODY_HEIGHT
	if tex != null:
		var tint: Color = Color(1, 1, 1, 0.45) if faded(e) else Color.WHITE
		UnitSprite.draw(self, world, e, tex, at, height, _moving(e), world.tick - _hit_tick.get(e.id, -100), tint)
		if e.kind == Entity.Kind.HERO:
			draw_arc(at, e.radius * 0.9, 0, TAU, 32, Color(color, 0.7), 3.0, true)  # vòng chân màu đội
	else:
		_draw_placeholder(e, at, Color(color, 0.45) if faded(e) else color, height)
	if e.creep_tier > 0:  # CRP-12: lính siêu cấp (vòng bạc) / siêu lính (vòng vàng)
		draw_arc(at - Vector2(0, height * 0.32), e.radius * 1.1, 0, TAU, 24, Color(0.85, 0.85, 0.95) if e.creep_tier == 1 else Color(1, 0.8, 0.2), 3.0, true)
	if e.recall_until_tick >= 0:  # RCL: vòng kênh về thành
		var total: float = maxf(1.0, e.recall_until_tick - e.recall_start_tick)
		var done: float = clampf((world.tick - e.recall_start_tick) / total, 0.0, 1.0)
		draw_arc(at, e.radius * 1.8, -PI * 0.5, -PI * 0.5 + TAU * done, 32, Color(0.5, 0.8, 1.0, 0.9), 5.0, true)
	StateMarks.draw(self, e, at, height, world.tick)
	_draw_health(e, at - Vector2(0, height + 14), color)


func _draw_frog(e: Entity, at: Vector2, color: Color) -> void:
	var r: float = e.radius * 0.8
	draw_circle(at - Vector2(0, r * 0.6), r, Color(0.35, 0.75, 0.3))
	draw_circle(at - Vector2(r * 0.45, r * 1.3), r * 0.3, Color.WHITE)
	draw_circle(at - Vector2(-r * 0.45, r * 1.3), r * 0.3, Color.WHITE)
	draw_arc(at - Vector2(0, r * 0.6), r, 0, TAU, 20, color, 3.0, true)
	_draw_health(e, at - Vector2(0, r * 2.4 + 14), color)


## WRD: con mắt nhỏ (vàng = mắt vàng, xanh = mắt xanh). Phe mình: mờ, vòng tầm nhìn / nhìn tàng
## hình, cung thời gian còn lại. Ward địch đang bị thấy: viền đỏ, 6 nấc máu (theo đòn).
func _draw_ward(e: Entity, at: Vector2) -> void:
	var sentry: bool = e.true_sight_range > 0.0
	var col: Color = Color(0.35, 0.75, 1.0) if sentry else Color(1.0, 0.82, 0.25)
	var own: bool = viewer_team < 0 or e.team == viewer_team
	var c: Vector2 = at - Vector2(0, 26)
	draw_line(at, c, Color(0.3, 0.25, 0.2, 0.8), 4.0)
	draw_set_transform(c, 0.0, Vector2(1.0, 0.6))
	draw_circle(Vector2.ZERO, 16.0, Color(col, 0.55 if own else 0.95))
	draw_set_transform(Vector2.ZERO)
	draw_circle(c, 6.0, Color(0.1, 0.1, 0.15, 0.9))
	if own:
		var ring: float = e.true_sight_range if sentry else e.stats.get_stat(StatId.Id.VISION_RANGE)
		draw_arc(e.position, ring, 0, TAU, 96, Color(col, 0.18), 3.0, true)
		if e.expire_tick >= 0:
			var left: float = clampf(float(e.expire_tick - world.tick) / SimClock.seconds_to_ticks(240.0 if not sentry else 300.0), 0.0, 1.0)
			draw_arc(c, 22.0, -PI * 0.5, -PI * 0.5 + TAU * left, 24, Color(col, 0.8), 3.0, true)
	else:
		draw_arc(c, 18.0, 0, TAU, 24, Color(1, 0.25, 0.2), 3.0, true)
		var hp: int = ceili(e.health)
		for i: int in range(6):
			var r: Rect2 = Rect2(c + Vector2(-27 + i * 9, -34), Vector2(7, 6))
			draw_rect(r, Color(1, 0.3, 0.25) if i < hp else Color(0.2, 0.2, 0.2, 0.8))


## DTH-02: hero nằm ngang, mờ, vòng đếm ngược thời gian còn lại tới lúc đứng dậy.
func _draw_lying(e: Entity, at: Vector2, color: Color) -> void:
	var r: float = e.radius
	draw_set_transform(at - Vector2(0, r * 0.4), 0.0, Vector2(1.6, 0.6))
	draw_circle(Vector2.ZERO, r * 0.9, Color(color.darkened(0.3), 0.5))
	draw_set_transform(Vector2.ZERO)
	draw_circle(at - Vector2(r * 1.3, r * 0.4), r * 0.5, Color(0.96, 0.84, 0.7, 0.5))
	var total: float = SimClock.seconds_to_ticks(world.balance.reincarnate_delay)
	var left: float = clampf((e.reincarnate_tick - world.tick) / maxf(total, 1.0), 0.0, 1.0)
	draw_arc(at - Vector2(0, r * 0.4), r * 2.0, 0, TAU, 32, Color(1, 1, 1, 0.2), 4.0, true)
	draw_arc(at - Vector2(0, r * 0.4), r * 2.0, -PI * 0.5, -PI * 0.5 + TAU * left, 32, Color(1, 0.85, 0.35, 0.9), 5.0, true)


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
		_draw_lock(at - Vector2(0, r * 1.4))
	_draw_health(e, at - Vector2(0, r * 3.4), color)


## STR-02: ổ khóa trên công trình đang khóa.
func _draw_lock(c: Vector2) -> void:
	draw_rect(Rect2(c - Vector2(14, 0), Vector2(28, 22)), Color(0.15, 0.15, 0.18, 0.85))
	draw_rect(Rect2(c - Vector2(10, -3), Vector2(20, 16)), Color(0.9, 0.9, 0.9))
	draw_arc(c, 9, PI, TAU, 8, Color(0.9, 0.9, 0.9), 3.0)


func _draw_health(e: Entity, center: Vector2, color: Color) -> void:
	if e.stats == null:
		return
	var max_hp: float = maxf(1.0, e.stats.get_stat(StatId.Id.MAX_HP))
	var hero: bool = e.kind == Entity.Kind.HERO
	var width: float = 120.0 if hero else e.radius * BAR_WIDTH  # D-144: thanh máu tướng to, dễ đọc
	var bar_h: float = 14.0 if hero else BAR_HEIGHT
	var rect: Rect2 = Rect2(center - Vector2(width * 0.5, bar_h * 0.5), Vector2(width, bar_h))
	draw_rect(rect.grow(2), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(rect.position, Vector2(width * clampf(e.health / max_hp, 0, 1), bar_h)), color)


func _team_color(team: int) -> Color:
	match team:
		0:
			return BLUE
		1:
			return RED
	return NEUTRAL
