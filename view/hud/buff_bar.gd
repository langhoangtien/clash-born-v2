class_name BuffBar
extends Control
## Hàng buff/debuff của hero người chơi (M4.0). Như Liên Quân (D-88): nằm ngay trên chỗ nút đồ
## chủ động, bắt đầu từ mép trái chỗ đó (`left_x`, đáy `bottom_y`) và kéo sang phải, không vượt
## nút Q (`right_limit`); chưa đặt `left_x` thì căn giữa đáy màn hình. Mỗi ô: viền xanh = buff, đỏ = debuff;
## viền sáng chạy quanh ô theo thời gian còn lại (D-134: từ giữa cạnh trên, chiều kim đồng hồ, ngắn dần);
## số tầng góc dưới. Có hình (ArtLibrary theo art_id) thì vẽ hình, chưa có thì chữ viết tắt.
## Không hiện hiệu ứng `passive`. Chỉ đọc World.
## D-163: nhiều lần cùng một hiệu ứng gộp một ô (số = tổng số lần, viền = lần còn lâu nhất); sát thương
## vĩnh viễn từ Quyết Đấu (DUL-07) là một ô riêng ghi "+40" / "−20" (dùng hình của hiệu ứng Quyết Đấu
## lần gần nhất hero dính).

const ICON: float = 44.0
const GAP: float = 6.0
const BOTTOM_MARGIN: float = 14.0

var world: World
var hero: Entity
## Mép trái của nút Q (px màn hình); hàng icon không vượt qua.
var right_limit: float = INF
## Mép trái và đáy của hàng (px trong Control); INF = căn giữa đáy màn hình.
var left_x: float = INF
var bottom_y: float = INF
## D-163: hiệu ứng Quyết Đấu (state DUELING) gần nhất hero dính — hình cho ô sát thương vĩnh viễn.
var _duel_def: EffectDef


## [hiệu ứng, là debuff, phần thời gian còn lại 0..1 (1 = vĩnh viễn), số lần, chữ thêm]; buff trước.
## `duel_def`: hình cho ô sát thương vĩnh viễn của Quyết Đấu (null thì không hiện ô đó).
static func entries(w: World, e: Entity, duel_def: EffectDef = null) -> Array:
	var groups: Dictionary[EffectDef, Array] = {}
	var order: Array[EffectDef] = []
	for inst: EffectInstance in e.effects:
		if inst.def.tags.has(&"passive"):
			continue
		var total: int = inst.end_tick - inst.start_tick
		var left: float = 1.0 if inst.end_tick < 0 or total <= 0 else clampf(float(inst.end_tick - w.tick) / total, 0.0, 1.0)
		if not groups.has(inst.def):
			groups[inst.def] = [inst.def, inst.def.tags.has(&"debuff"), left, 0, ""]
			order.append(inst.def)
		var g: Array = groups[inst.def]
		g[2] = maxf(g[2], left)
		g[3] += maxi(1, inst.stacks)
	var buffs: Array = []
	var debuffs: Array = []
	if duel_def != null and absf(e.duel_damage) >= 0.5:  # DUL-07
		var value: int = roundi(e.duel_damage)
		(debuffs if value < 0 else buffs).append([duel_def, value < 0, 1.0, 1, ("+%d" if value > 0 else "%d") % value])
	for d: EffectDef in order:
		(debuffs if groups[d][1] else buffs).append(groups[d])
	return buffs + debuffs


## Cỡ ô: thu nhỏ khi quá nhiều hiệu ứng để cả hàng vẫn nằm bên trái nút Q.
func icon_size(count: int) -> float:
	if count <= 0:
		return ICON
	var start: float = left_x if is_finite(left_x) else 0.0
	var room: float = minf(right_limit, size.x) - start - GAP - maxi(0, count - 1) * GAP
	return clampf(room / count, 16.0, ICON)


func row_rect(count: int) -> Rect2:
	var icon: float = icon_size(count)
	var width: float = count * icon + maxi(0, count - 1) * GAP
	var left: float = left_x if is_finite(left_x) else size.x * 0.5 - width * 0.5
	left = minf(left, right_limit - GAP - width)
	var bottom: float = bottom_y if is_finite(bottom_y) else size.y - BOTTOM_MARGIN
	return Rect2(Vector2(maxf(left, 0.0), bottom - icon), Vector2(width, icon))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if hero != null:
		for inst: EffectInstance in hero.effects:
			if inst.def.states.has(UnitState.Id.DUELING):
				_duel_def = inst.def
	queue_redraw()


func _draw() -> void:
	if world == null or hero == null:
		return
	var list: Array = entries(world, hero, _duel_def)
	var row: Rect2 = row_rect(list.size())
	var font: Font = ThemeDB.fallback_font
	var icon: float = row.size.y
	for i: int in range(list.size()):
		var box: Rect2 = Rect2(row.position + Vector2(i * (icon + GAP), 0), Vector2(icon, icon))
		_draw_icon(font, box, list[i])


func _draw_icon(font: Font, box: Rect2, entry: Array) -> void:
	var def: EffectDef = entry[0]
	var border: Color = Color(1.0, 0.35, 0.3) if entry[1] else Color(0.35, 0.9, 0.45)
	draw_rect(box, Color(0.08, 0.1, 0.14, 0.85))
	var tex: Texture2D = ArtLibrary.texture(def.art_id)
	if tex != null:
		draw_texture_rect(tex, box.grow(-3), false)
	else:
		_center_text(font, box, _short(def), 14, Color.WHITE)
	draw_rect(box, Color(border, 0.25), false, 3.0)  # rãnh mờ = phần thời gian đã qua
	var trail: PackedVector2Array = border_trail(box, float(entry[2]))  # D-134
	if trail.size() >= 2:
		draw_polyline(trail, border, 3.0)
	if not String(entry[4]).is_empty():  # D-163: số sát thương Quyết Đấu
		var txt: String = entry[4]
		var w: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var at: Vector2 = Vector2(box.get_center().x - w * 0.5, box.end.y - 4)
		draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
		draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, border.lightened(0.3))
	if entry[3] > 1:
		draw_string_outline(font, box.end - Vector2(14, 4), str(entry[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
		draw_string(font, box.end - Vector2(14, 4), str(entry[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


## D-134: đường viền từ giữa cạnh trên theo chiều kim đồng hồ, dài bằng `left` (0..1) chu vi.
static func border_trail(box: Rect2, left: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if left <= 0.0:
		return out
	var corners: Array[Vector2] = [Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y),
		box.position, Vector2(box.get_center().x, box.position.y)]
	var remain: float = clampf(left, 0.0, 1.0) * 2.0 * (box.size.x + box.size.y)
	var at: Vector2 = Vector2(box.get_center().x, box.position.y)
	out.append(at)
	for c: Vector2 in corners:
		var d: float = at.distance_to(c)
		if remain <= d:
			out.append(at.move_toward(c, remain))
			return out
		remain -= d
		at = c
		out.append(at)
	return out


## Chữ viết tắt tạm (tới khi có icon): từ cuối của tên, tối đa 5 ký tự, viết hoa.
static func _short(def: EffectDef) -> String:
	var name: String = def.display_name if not def.display_name.is_empty() else String(def.id)
	var words: PackedStringArray = name.split(" ", false)
	return words[-1].to_upper().left(5) if words.size() > 0 else "?"


func _center_text(font: Font, box: Rect2, text: String, font_size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, box.get_center() + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
