class_name Bars3D
extends Control
## Thanh máu, dấu trạng thái (StateMarks) và ổ khóa công trình (STR-02) trên đầu đơn vị (D-145, D-157):
## chiếu đỉnh đầu / chân ra màn hình rồi vẽ. D-180: cả chữ nổi (FloatingText) và biểu tượng Quyết Đấu.

## Độ cao (m) điểm chiếu chữ nổi / biểu tượng Quyết Đấu trên mặt đất.
const TEXT_HEIGHT: float = 1.8
const ICON_HEIGHT: float = 2.6

var view: MatchView3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if view == null or view.world == null:
		return
	for e: Entity in view.world.entities:
		if not e.alive or e.stats == null or e.kind == Entity.Kind.WARD:
			continue
		var at: Variant = view.head_screen(e)
		if at == null:
			continue
		var hero: bool = e.kind == Entity.Kind.HERO
		var structure: bool = Rules.is_structure(e)
		var w: float = 110.0 if hero else (130.0 if structure else 54.0)
		var h: float = 13.0 if hero else 8.0
		var col: Color = [UnitsView.BLUE, UnitsView.RED][e.team] if e.team < 2 else UnitsView.NEUTRAL
		var r: Rect2 = Rect2((at as Vector2) - Vector2(w * 0.5, h), Vector2(w, h))
		draw_rect(r.grow(2), Color(0, 0, 0, 0.7))
		var frac: float = clampf(e.health / maxf(1.0, e.stats.get_stat(StatId.Id.MAX_HP)), 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(w * frac, h)), col)
		var foot: Variant = view.foot_screen(e)
		if foot != null:
			StateMarks.draw(self, e, foot, (foot as Vector2).y - (at as Vector2).y, view.world.tick)
		if e.locked:
			_draw_lock((at as Vector2) + Vector2(0, 30))
	FloatingText.draw(self, view.world, func(p: Vector2) -> Variant: return view.ground_screen(p, TEXT_HEIGHT))
	for d: Array in Vfx.duel_icons(view.world):
		var c: Variant = view.ground_screen(d[0], ICON_HEIGHT)
		if c != null:
			draw_texture_rect(d[1], Rect2((c as Vector2) - Vector2(36, 36), Vector2(72, 72)), false, Color(1, 1, 1, d[2]))


## STR-02: ổ khóa trên công trình đang khóa.
func _draw_lock(c: Vector2) -> void:
	draw_rect(Rect2(c - Vector2(14, 0), Vector2(28, 22)), Color(0.15, 0.15, 0.18, 0.85))
	draw_rect(Rect2(c - Vector2(10, -3), Vector2(20, 16)), Color(0.9, 0.9, 0.9))
	draw_arc(c, 9, PI, TAU, 8, Color(0.9, 0.9, 0.9), 3.0)
