class_name Bars3D
extends Control
## Thanh máu trên đầu đơn vị cho bản 3D thử (D-145): chiếu đỉnh đầu ra màn hình rồi vẽ.

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
