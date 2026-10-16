class_name BuffBar
extends Control
## Hàng buff/debuff của hero người chơi (M4.0). Như Liên Quân (D-88): nằm ngay trên chỗ nút đồ
## chủ động, bắt đầu từ mép trái chỗ đó (`left_x`, đáy `bottom_y`) và kéo sang phải, không vượt
## nút Q (`right_limit`); chưa đặt `left_x` thì căn giữa đáy màn hình. Mỗi ô: viền xanh = buff, đỏ = debuff; phần tối quét theo thời gian đã qua;
## số tầng góc dưới. Có hình (ArtLibrary theo art_id) thì vẽ hình, chưa có thì chữ viết tắt.
## Không hiện hiệu ứng `passive`. Chỉ đọc World.

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


## [hiệu ứng, là debuff, phần thời gian còn lại 0..1 (1 = vĩnh viễn), số tầng]; buff trước.
static func entries(w: World, e: Entity) -> Array:
	var buffs: Array = []
	var debuffs: Array = []
	for inst: EffectInstance in e.effects:
		if inst.def.tags.has(&"passive"):
			continue
		var total: int = inst.end_tick - inst.start_tick
		var left: float = 1.0 if inst.end_tick < 0 or total <= 0 else clampf(float(inst.end_tick - w.tick) / total, 0.0, 1.0)
		var debuff: bool = inst.def.tags.has(&"debuff")
		(debuffs if debuff else buffs).append([inst.def, debuff, left, inst.stacks])
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
	queue_redraw()


func _draw() -> void:
	if world == null or hero == null:
		return
	var list: Array = entries(world, hero)
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
	var spent: float = 1.0 - float(entry[2])
	if spent > 0.0:
		draw_rect(Rect2(box.position, Vector2(box.size.x, box.size.y * spent)), Color(0, 0, 0, 0.5))
	draw_rect(box, border, false, 3.0)
	if entry[3] > 1:
		draw_string_outline(font, box.end - Vector2(14, 4), str(entry[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
		draw_string(font, box.end - Vector2(14, 4), str(entry[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


## Chữ viết tắt tạm (tới khi có icon): từ cuối của tên, tối đa 5 ký tự, viết hoa.
static func _short(def: EffectDef) -> String:
	var name: String = def.display_name if not def.display_name.is_empty() else String(def.id)
	var words: PackedStringArray = name.split(" ", false)
	return words[-1].to_upper().left(5) if words.size() > 0 else "?"


func _center_text(font: Font, box: Rect2, text: String, font_size: int, color: Color) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, box.get_center() + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
