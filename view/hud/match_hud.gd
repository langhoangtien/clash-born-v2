class_name MatchHud
extends Control
## HUD tối thiểu (M2.5): đồng hồ trận, máu/mana, vàng, last hit, đếm ngược hồi sinh,
## tốc độ chơi thử. Tầng VIEW: chỉ đọc World và hero, không nhận chạm.

## Bên phải minimap (Minimap.SIDE ở góc trên trái). D-183: chân dung tướng + dấu "i" bên trái để biết chạm vào
## xem thông số (InfoPanels).
const PANEL: Rect2 = Rect2(292, 16, 486, 132)
const PORTRAIT: Vector2 = Vector2(104, 104)
## D-183: khung tỷ số giữa trên (InfoPanels.SCORE_HIT) — nền màu hai đội, đồng hồ giữa, dấu bảng ≡.
const SCORE_BOX: Vector2 = Vector2(360, 68)
const BAR: Vector2 = Vector2(340, 22)
const HP_COLOR: Color = Color(0.3, 0.8, 0.35)
const MANA_COLOR: Color = Color(0.3, 0.5, 1.0)

var world: World
var hero: Entity
## Tốc độ chơi thử (SimRunner.speed); >1 thì hiện cạnh đồng hồ.
var speed: int = 1
## D-108: ms SIM mỗi tick (APP đặt) — hiện cùng FPS ở góc phải trên để đo trên điện thoại.
var sim_ms: float = 0.0
## D-183: hiện dòng FPS (bảng Cài đặt).
var show_fps: bool = true


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
	var font: Font = UiStyle.sans(true)  # D-130
	var top: String = clock_text(world.tick) + ("   ×%d" % speed if speed > 1 else "")
	_score(font)
	_text(font, Vector2(size.x * 0.5, 50), top, 30, Color.WHITE, true)
	if show_fps:
		_text(font, Vector2(size.x - 230, 112), "FPS %d · SIM %.1f ms" % [Engine.get_frames_per_second(), sim_ms], 18, Color(1, 1, 1, 0.6), false)
	draw_style_box(UiStyle.box(Color(0.035, 0.05, 0.085, 0.82), UiStyle.LINE, 1, 12), PANEL)
	_portrait(font)
	var x: float = PANEL.position.x + PORTRAIT.x + 24
	var max_hp: float = maxf(1.0, hero.stats.get_stat(StatId.Id.MAX_HP))
	var max_mana: float = maxf(1.0, hero.stats.get_stat(StatId.Id.MAX_MANA))
	_bar(font, Vector2(x, 30), hero.health, max_hp, HP_COLOR)
	_bar(font, Vector2(x, 60), hero.mana, max_mana, MANA_COLOR)
	_text(font, Vector2(x, 120), "Cấp %d  Vàng %d  LH %d  %d/%d/%d" % [hero.stats.level(), hero.gold, hero.last_hits, hero.kills, hero.deaths, hero.assists], 22, Color(1, 0.85, 0.3), false)
	if hero.stats.level() < world.balance.hero_max_level:
		var need: float = float(Progression.xp_to_next(world, hero.stats.level()))
		draw_rect(Rect2(Vector2(x, 88), Vector2(BAR.x, 6)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(Vector2(x, 88), Vector2(BAR.x * clampf(hero.xp / need, 0, 1), 6)), Color(0.75, 0.5, 1.0))
	if hero.talent_slot >= 0:
		var a: AbilityInstance = Abilities.of(hero, hero.talent_slot)
		_text(font, Vector2(x, PANEL.end.y + 30), "Talent: " + a.def.talent.display_name, 22, Color(0.8, 0.6, 1.0), false)
	var wait: String = respawn_text(world, hero)
	if wait != "":
		_text(font, Vector2(size.x * 0.5, size.y * 0.4), wait, 48, Color(1, 0.4, 0.4), true)


func _bar(font: Font, at: Vector2, value: float, maximum: float, color: Color) -> void:
	draw_style_box(UiStyle.box(Color(0, 0, 0, 0.7), Color(1, 1, 1, 0.12), 1, 5), Rect2(at, BAR))
	var fill: float = BAR.x * clampf(value / maximum, 0, 1)
	if fill >= 2.0:
		draw_style_box(UiStyle.box(color, Color(0, 0, 0, 0), 0, 5), Rect2(at, Vector2(fill, BAR.y)))
	_text(font, at + Vector2(BAR.x * 0.5, BAR.y - 4), "%d / %d" % [roundi(value), roundi(maximum)], 18, Color.WHITE, true)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color, centered: bool) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if centered else 0.0
	draw_string_outline(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.8))
	draw_string(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Tỷ số hai đội hai bên đồng hồ (ECO-09), trong khung có nền màu đội; dấu ≡ cho biết chạm được (D-183).
func _score(font: Font) -> void:
	var r: Rect2 = Rect2(Vector2(size.x * 0.5 - SCORE_BOX.x * 0.5, 4), SCORE_BOX)
	var side: float = r.size.x * 0.3
	draw_style_box(UiStyle.box(Color(0.035, 0.05, 0.085, 0.85), UiStyle.LINE, 1, 12), r)
	draw_style_box(UiStyle.box(Color(0.2, 0.45, 0.95, 0.55), Color(0, 0, 0, 0), 0, 10), Rect2(r.position + Vector2(4, 4), Vector2(side, r.size.y - 8)))
	draw_style_box(UiStyle.box(Color(0.95, 0.3, 0.25, 0.55), Color(0, 0, 0, 0), 0, 10), Rect2(Vector2(r.end.x - 4 - side, r.position.y + 4), Vector2(side, r.size.y - 8)))
	_text(font, Vector2(r.position.x + 4 + side * 0.5, 50), str(MatchScore.team_kills(world, 0)), 36, Color.WHITE, true)
	_text(font, Vector2(r.end.x - 4 - side * 0.5, 50), str(MatchScore.team_kills(world, 1)), 36, Color.WHITE, true)
	for i: int in 3:  # dấu bảng tỷ số
		var y: float = r.end.y - 16 + i * 5
		draw_line(Vector2(r.get_center().x - 10, y), Vector2(r.get_center().x + 10, y), Color(1, 1, 1, 0.55), 2.0)


## D-183: chân dung tướng trong ô máu / mana + dấu "i" (chạm xem thông số).
func _portrait(font: Font) -> void:
	var box: Rect2 = Rect2(PANEL.position + Vector2(12, (PANEL.size.y - PORTRAIT.y) * 0.5), PORTRAIT)
	draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.GOLD, 2, 10), box)
	var tex: Texture2D = ArtLibrary.texture(StringName(String(hero.hero_def.id) + "_portrait")) if hero.hero_def != null else null
	if tex != null:
		draw_texture_rect(tex, box.grow(-4), false)
	var c: Vector2 = box.end - Vector2(12, 12)
	draw_circle(c, 15, UiStyle.GOLD)
	_text(font, c + Vector2(0, 7), "i", 20, Color(0.1, 0.1, 0.15), true)
