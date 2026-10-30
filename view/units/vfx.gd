class_name Vfx
extends RefCounted
## Hiệu ứng chiêu / đòn trên bản đồ (D-144), chỉ đọc World: vùng vừa nổ (tròn, chữ nhật, quạt),
## vòng sáng lúc tung chiêu, tia chém khi đòn trúng, dây Quyết Đấu. Sự kiện được UnitsView gom lại
## mỗi tick vào `flashes` [loại, vị trí, hướng, tick, đội].

const BLUE: Color = Color(0.25, 0.55, 1.0)
const RED: Color = Color(1.0, 0.3, 0.3)
const LIFE: Dictionary = {&"cast": 12, &"slash": 6, &"deflect": 10}

var flashes: Array = []


func collect(w: World) -> void:
	flashes = flashes.filter(func(f: Array) -> bool: return w.tick - f[3] < LIFE.get(f[0], 10))
	for ev: GameEvent in w.events:
		var src: Entity = w.find_entity(ev.source_id)
		var tgt: Entity = w.find_entity(ev.target_id)
		match ev.type:
			&"ability_cast":
				if src != null:
					flashes.append([&"cast", src.position, src.facing, ev.tick, src.team])
			&"attack_landed":
				if src != null and tgt != null and src.projectile_speed <= 0.0 and src.kind == Entity.Kind.HERO:
					flashes.append([&"slash", tgt.position, (tgt.position - src.position).normalized(), ev.tick, src.team])
			&"attack_deflected":
				if tgt != null:
					flashes.append([&"deflect", tgt.position, Vector2.UP, ev.tick, tgt.team])


func draw(ci: GroundCanvas, w: World) -> void:
	for r: Array in w.recent_areas:
		var age: float = (w.tick - r[2]) / 15.0
		if age < 1.0:
			_area(ci, r, Color((BLUE if r[3] == 0 else RED).lightened(0.4), 1.0 - age))
	for f: Array in flashes:
		var age: float = float(w.tick - f[3]) / LIFE.get(f[0], 10)
		var col: Color = (BLUE if f[4] == 0 else RED).lightened(0.5)
		match f[0]:
			&"cast":
				ci.draw_arc(f[1], 40.0 + 70.0 * age, 0, TAU, 40, Color(col, 0.8 * (1.0 - age)), 5.0, true)
			&"slash":
				var a: float = (f[2] as Vector2).angle()
				ci.draw_arc(f[1] - Vector2(0, 50), 46.0, a - 0.9, a + 0.9, 14, Color(1, 1, 1, 0.9 * (1.0 - age)), 7.0 * (1.0 - age) + 1.0, true)
			&"deflect":
				ci.draw_arc(f[1] - Vector2(0, 60), 50.0 + 20.0 * age, -2.4, -0.7, 16, Color(0.6, 0.9, 1.0, 1.0 - age), 9.0, true)
	_duels(ci, w)


static func _area(ci: GroundCanvas, r: Array, col: Color) -> void:
	var at: Vector2 = r[0]
	match r[4] if r.size() > 4 else AreaAction.Shape.CIRCLE:
		AreaAction.Shape.CONE:
			var mid: float = (r[5] as Vector2).angle()
			var half: float = deg_to_rad(r[6]) * 0.5
			ci.draw_sector(at, r[1], mid - half, mid + half, Color(col, 0.5 * col.a))
			ci.draw_arc(at, r[1], mid - half, mid + half, 20, col, 6.0, true)
			ci.draw_line(at, at + Vector2.from_angle(mid - half) * r[1], col, 6.0, true)
			ci.draw_line(at, at + Vector2.from_angle(mid + half) * r[1], col, 6.0, true)
		AreaAction.Shape.RECT:
			var d: Vector2 = r[5]
			var side: Vector2 = d.orthogonal() * r[8]
			var end: Vector2 = at + d * r[7]
			ci.draw_colored_polygon(PackedVector2Array([at + side, end + side, end - side, at - side]), Color(col, 0.35 * col.a))
		_:
			ci.draw_circle(at, r[1], Color(col, 0.35 * col.a))
			ci.draw_arc(at, r[1], 0, TAU, 48, Color(col, 0.9 * col.a), 4.0, true)


## DUL: vòng đỏ dưới chân hai bên và dây nối khi đang Quyết Đấu.
static func _duels(ci: GroundCanvas, w: World) -> void:
	for e: Entity in w.entities:
		if e.duel == null or e.duel.knight_id != e.id:
			continue
		var foe: Entity = w.find_entity(e.duel.foe_id)
		if foe == null:
			continue
		var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
		for u: Entity in [e, foe]:
			ci.draw_set_transform(u.position, 0.0, Vector2(1.0, 0.55))
			ci.draw_arc(Vector2.ZERO, u.radius * 2.6, 0, TAU, 48, Color(1, 0.2, 0.15, pulse), 7.0, true)
			ci.draw_set_transform(Vector2.ZERO)
		ci.draw_dashed_line(e.position, foe.position, Color(1, 0.3, 0.2, 0.8), 5.0, 14.0)


## DUL: biểu tượng Quyết Đấu giữa hai bên — [điểm giữa (px thế giới), hình, độ đậm]; Bars3D vẽ trên màn
## hình (D-180: lớp mặt đất không vẽ ảnh).
static func duel_icons(w: World) -> Array[Array]:
	var out: Array[Array] = []
	for e: Entity in w.entities:
		if e.duel == null or e.duel.knight_id != e.id:
			continue
		var foe: Entity = w.find_entity(e.duel.foe_id)
		var icon: Texture2D = _duel_icon(e)
		if foe != null and icon != null:
			out.append([(e.position + foe.position) * 0.5, icon, 0.6 + 0.4 * (0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0))])
	return out


## Hình của hiệu ứng Quyết Đấu đang có (state DUELING) — lấy từ dữ liệu, không gắn cứng.
static func _duel_icon(e: Entity) -> Texture2D:
	for inst: EffectInstance in e.effects:
		if inst.def.states.has(UnitState.Id.DUELING):
			return ArtLibrary.texture(inst.def.art_id)
	return null
