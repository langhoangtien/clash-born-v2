class_name UnitsView
extends Node2D
## Phần nằm trên mặt đất của đơn vị (D-157, trận 3D): bóng (đơn vị ảnh đứng), vòng màu đội, vòng lính
## siêu cấp, vòng về thành, đếm ngược tái sinh, mắt, vùng chiêu, hiệu ứng, đạn. Hình đơn vị do
## MatchView3D vẽ, thanh máu / dấu trạng thái do Bars3D. Nội suy giữa hai tick bằng `alpha`.
## Tầng VIEW: chỉ đọc World.

const BLUE: Color = Color(0.25, 0.55, 1.0)
const RED: Color = Color(1.0, 0.3, 0.3)
const NEUTRAL: Color = Color(0.85, 0.75, 0.4)
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
		_draw_ground_mark(e, at)
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


## D-145, D-157: bóng (đơn vị ảnh đứng — nhân vật 3D tự có bóng mờ), vòng màu đội, CRP-12 vòng lính siêu
## cấp, RCL vòng về thành, DTH-02 đếm ngược tái sinh, WRD mắt, ST-16 ếch tạm khi thiếu hình.
func _draw_ground_mark(e: Entity, at: Vector2) -> void:
	if e.kind == Entity.Kind.WARD:
		_draw_ward(e, at)
		return
	if ModelLibrary.unit(e.art_id).is_empty():
		draw_circle(at, e.radius * 1.1, Color(0, 0, 0, 0.35))
	var color: Color = _team_color(e.team)
	if e.kind == Entity.Kind.HERO or e.kind == Entity.Kind.LANE_CREEP:
		draw_arc(at, e.radius * 1.05, 0, TAU, 32, Color(color, 0.85), 4.0 if e.kind == Entity.Kind.HERO else 2.5, true)
	if e.creep_tier > 0:  # CRP-12: lính siêu cấp (vòng bạc) / siêu lính (vòng vàng)
		draw_arc(at, e.radius * 1.35, 0, TAU, 24, Color(0.85, 0.85, 0.95) if e.creep_tier == 1 else Color(1, 0.8, 0.2), 3.0, true)
	if e.recall_until_tick >= 0:  # RCL: vòng kênh về thành
		var total: float = maxf(1.0, e.recall_until_tick - e.recall_start_tick)
		var done: float = clampf((world.tick - e.recall_start_tick) / total, 0.0, 1.0)
		draw_arc(at, e.radius * 1.8, -PI * 0.5, -PI * 0.5 + TAU * done, 32, Color(0.5, 0.8, 1.0, 0.9), 5.0, true)
	if e.reincarnate_tick >= 0:  # DTH-02: nằm chờ tái sinh
		var left: float = clampf((e.reincarnate_tick - world.tick) / maxf(SimClock.seconds_to_ticks(world.balance.reincarnate_delay), 1.0), 0.0, 1.0)
		draw_arc(at, e.radius * 2.0, 0, TAU, 32, Color(1, 1, 1, 0.2), 4.0, true)
		draw_arc(at, e.radius * 2.0, -PI * 0.5, -PI * 0.5 + TAU * left, 32, Color(1, 0.85, 0.35, 0.9), 5.0, true)
	if Rules.has_state(e, UnitState.Id.HEXED) and ArtLibrary.texture(&"hex_frog") == null:
		_draw_frog(e, at, color)


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


func _draw_frog(e: Entity, at: Vector2, color: Color) -> void:
	var r: float = e.radius * 0.8
	draw_circle(at - Vector2(0, r * 0.6), r, Color(0.35, 0.75, 0.3))
	draw_circle(at - Vector2(r * 0.45, r * 1.3), r * 0.3, Color.WHITE)
	draw_circle(at - Vector2(-r * 0.45, r * 1.3), r * 0.3, Color.WHITE)
	draw_arc(at - Vector2(0, r * 0.6), r, 0, TAU, 20, color, 3.0, true)


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


func _team_color(team: int) -> Color:
	match team:
		0:
			return BLUE
		1:
			return RED
	return NEUTRAL
