class_name MatchHud
extends Control
## HUD tối thiểu (M2.5): đồng hồ trận, máu/mana, vàng, last hit, đếm ngược hồi sinh,
## tốc độ chơi thử. Tầng VIEW: chỉ đọc World và hero, không nhận chạm.

const PANEL: Rect2 = Rect2(16, 16, 380, 132)
const BAR: Vector2 = Vector2(340, 22)
const HP_COLOR: Color = Color(0.3, 0.8, 0.35)
const MANA_COLOR: Color = Color(0.3, 0.5, 1.0)

var world: World
var hero: Entity
## Tốc độ chơi thử (SimRunner.speed); >1 thì hiện cạnh đồng hồ.
var speed: int = 1


static func clock_text(tick: int) -> String:
	var seconds: int = int(tick * SimClock.TICK_SECONDS)
	return "%d:%02d" % [seconds / 60, seconds % 60]


static func respawn_text(world: World, hero: Entity) -> String:
	if hero.alive:
		return ""
	return "Hồi sinh sau %d s" % ceili(maxi(0, hero.respawn_tick - world.tick) * SimClock.TICK_SECONDS)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null or hero == null:
		return
	var font: Font = ThemeDB.fallback_font
	var top: String = clock_text(world.tick) + ("   ×%d" % speed if speed > 1 else "")
	_text(font, Vector2(size.x * 0.5, 44), top, 34, Color.WHITE, true)
	draw_rect(PANEL, Color(0, 0, 0, 0.45))
	var x: float = PANEL.position.x + 20
	var max_hp: float = maxf(1.0, hero.stats.get_stat(StatId.Id.MAX_HP))
	var max_mana: float = maxf(1.0, hero.stats.get_stat(StatId.Id.MAX_MANA))
	_bar(font, Vector2(x, 30), hero.health, max_hp, HP_COLOR)
	_bar(font, Vector2(x, 60), hero.mana, max_mana, MANA_COLOR)
	_text(font, Vector2(x, 120), "Vàng %d    Last hit %d" % [hero.gold, hero.last_hits], 24, Color(1, 0.85, 0.3), false)
	var wait: String = respawn_text(world, hero)
	if wait != "":
		_text(font, Vector2(size.x * 0.5, size.y * 0.4), wait, 48, Color(1, 0.4, 0.4), true)


func _bar(font: Font, at: Vector2, value: float, maximum: float, color: Color) -> void:
	draw_rect(Rect2(at, BAR), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(at, Vector2(BAR.x * clampf(value / maximum, 0, 1), BAR.y)), color)
	_text(font, at + Vector2(BAR.x * 0.5, BAR.y - 4), "%d / %d" % [roundi(value), roundi(maximum)], 18, Color.WHITE, true)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color, centered: bool) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if centered else 0.0
	draw_string_outline(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.8))
	draw_string(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
