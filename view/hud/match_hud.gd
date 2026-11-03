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
	_text(font, Vector2(size.x * 0.5, 44), top, 28, Color.WHITE, true)
	if show_fps:
		_text(font, Vector2(size.x - 230, 112), "FPS %d · SIM %.1f ms" % [Engine.get_frames_per_second(), sim_ms], 18, Color(1, 1, 1, 0.6), false)
	UiStyle.soft_frame(self, Rect2(PANEL.position + Vector2(PORTRAIT.x * 0.5, 8), PANEL.size - Vector2(PORTRAIT.x * 0.5, 16)), 20)  # D-222
	var x: float = PANEL.position.x + PORTRAIT.x + 24
	var max_hp: float = maxf(1.0, hero.stats.get_stat(StatId.Id.MAX_HP))
	var max_mana: float = maxf(1.0, hero.stats.get_stat(StatId.Id.MAX_MANA))
	_bar(font, Vector2(x, 30), hero.health, max_hp, HP_COLOR)
	_bar(font, Vector2(x, 60), hero.mana, max_mana, MANA_COLOR)
	UiStyle.coin(self, Vector2(x + 10, 113), 10.0)
	_text(font, Vector2(x + 26, 120), "%d    LH %d    %d/%d/%d" % [hero.gold, hero.last_hits, hero.kills, hero.deaths, hero.assists], 21, Color(1, 0.88, 0.5), false)
	if hero.stats.level() < world.balance.hero_max_level:
		var need: float = float(Progression.xp_to_next(world, hero.stats.level()))
		UiStyle.soft_bar(self, Rect2(Vector2(x + 6, 88), Vector2(BAR.x - 12, 7)), hero.xp / need, Color(0.75, 0.5, 1.0))
	_portrait(font)
	if hero.talent_slot >= 0:
		var a: AbilityInstance = Abilities.of(hero, hero.talent_slot)
		_text(font, Vector2(x, PANEL.end.y + 30), "Talent: " + a.def.talent.display_name, 22, Color(0.8, 0.6, 1.0), false)
	var wait: String = respawn_text(world, hero)
	if wait != "":
		_text(font, Vector2(size.x * 0.5, size.y * 0.4), wait, 48, Color(1, 0.4, 0.4), true)


func _bar(font: Font, at: Vector2, value: float, maximum: float, color: Color) -> void:
	UiStyle.soft_bar(self, Rect2(at, BAR), value / maximum, color)  # D-222
	_text(font, at + Vector2(BAR.x * 0.5, BAR.y - 4), "%d / %d" % [roundi(value), roundi(maximum)], 18, Color.WHITE, true)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color, centered: bool) -> void:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if centered else 0.0
	draw_string_outline(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.8))
	draw_string(font, at - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Tỷ số hai đội hai bên đồng hồ (ECO-09); chạm mở bảng tỷ số (D-183). D-225: hai cánh xanh / đỏ hình thang (mép
## trong vát, đầu ngoài bo), ô đồng hồ giữa tối viền vàng, mũi nhọn vàng dưới giữa, dấu ≡ nhỏ.
func _score(font: Font) -> void:
	var r: Rect2 = Rect2(Vector2(size.x * 0.5 - SCORE_BOX.x * 0.5, 4), SCORE_BOX)
	var c: Vector2 = r.get_center()
	var mid_w: float = 120.0
	var slant: float = 16.0
	for team: int in 2:
		var sx: float = -1.0 if team == 0 else 1.0
		var inner: float = c.x + sx * (mid_w * 0.5 - 6.0)
		var outer: float = c.x + sx * (r.size.x * 0.5)
		var pts: PackedVector2Array = PackedVector2Array([Vector2(inner, r.position.y + 6), Vector2(inner - sx * slant, r.end.y - 6)])
		for k: int in range(9):  # đầu ngoài bo tròn
			var a: float = PI * 0.5 - PI * k / 8.0
			pts.append(Vector2(outer - sx * 26.0 + sx * cos(a) * 26.0, c.y + sin(a) * (r.size.y * 0.5 - 6)))
		var col: Color = Color(0.2, 0.46, 0.95) if team == 0 else Color(0.9, 0.27, 0.24)
		var shadow: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			shadow.append(p + Vector2(0, 3))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
		draw_colored_polygon(pts, col)
		var edge: PackedVector2Array = pts.duplicate()
		edge.append(pts[0])
		draw_polyline(edge, Color(UiStyle.GOLD_DEEP, 0.95), 2.0, true)
		_text(font, Vector2((inner + outer) * 0.5 + sx * 4.0, c.y + 12), str(MatchScore.team_kills(world, team)), 34, Color.WHITE, true)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - 14, r.end.y - 4), Vector2(c.x + 14, r.end.y - 4), Vector2(c.x, r.end.y + 9)]), UiStyle.GOLD)
	UiStyle.soft_frame(self, Rect2(c.x - mid_w * 0.5, r.position.y, mid_w, r.size.y), 12, Color(0.04, 0.06, 0.1, 0.97))
	for i: int in 3:  # dấu bảng tỷ số
		var y: float = r.end.y - 13 + i * 3.5
		draw_line(Vector2(c.x - 8, y), Vector2(c.x + 8, y), Color(UiStyle.GOLD, 0.7), 1.5)


## D-183: chân dung tướng (chạm xem thông số). D-222: tròn, viền vàng, huy hiệu cấp ở góc dưới; bỏ dấu "i" (giống cảnh báo).
func _portrait(font: Font) -> void:
	var r: float = PORTRAIT.x * 0.5
	var c: Vector2 = PANEL.position + Vector2(12 + r, PANEL.size.y * 0.5)
	UiStyle.orb(self, c, r + 6.0, Color(0.1, 0.16, 0.26))
	var tex: Texture2D = ArtLibrary.texture(StringName(String(hero.hero_def.id) + "_portrait")) if hero.hero_def != null else null
	if tex != null:
		var pts: PackedVector2Array = PackedVector2Array()
		var uvs: PackedVector2Array = PackedVector2Array()
		for k: int in 40:
			var d: Vector2 = Vector2.from_angle(TAU * k / 40.0)
			pts.append(c + d * (r - 2.0))
			uvs.append(Vector2(0.5, 0.5) + d * 0.5)
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, tex)
	draw_arc(c, r - 1.0, 0, TAU, 64, UiStyle.GOLD, 2.5, true)
	var badge: Vector2 = c + Vector2(-r * 0.72, r * 0.72)
	UiStyle.orb(self, badge, 17.0, Color(0.12, 0.2, 0.36))
	_text(font, badge + Vector2(0, 7), str(hero.stats.level()), 20, Color.WHITE, true)
