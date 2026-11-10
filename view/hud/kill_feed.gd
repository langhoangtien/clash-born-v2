class_name KillFeed
extends Control
## D-339 (EVT `hero_died`): thông báo hạ gục kiểu Dota / Liên Quân — băng giữa phía trên: [kẻ hạ] ⚔ [bị hạ] (chân dung
## viền màu đội, tên), "Hạ gục đầu tiên", chuỗi hạ liên tiếp (cùng một hero, mỗi mạng cách nhau ≤ MULTI_S giây): Hạ đôi /
## Hạ ba / Hạ bốn / Hủy diệt. Bị trụ / lính / quái hạ thì ghi thế. Chỉ VIEW: đọc world.events (cả previous_events khi một
## khung chạy hai tick) và `killer_id` của hero chết. D-341: băng nhỏ, nền mờ, tên mờ (chân dung + vàng là chính), hiện
## vàng kẻ hạ nhận (sự kiện `kill_credited`, ECO-08 / ECO-10) — đỡ che màn hình.

const SHOW_S: float = 3.5
const FADE_S: float = 0.6
const MAX_ROWS: int = 2
const MULTI_S: float = 10.0
const ROW: Vector2 = Vector2(400, 60)
const TOP: float = 160.0
const FACE_R: float = 22.0
const GOLD: Color = Color(1, 0.82, 0.35)
const STREAK: Array[String] = ["", "", "Hạ đôi", "Hạ ba", "Hạ bốn", "Hủy diệt"]
const BLUE: Color = Color(0.3, 0.55, 1.0)
const RED: Color = Color(1.0, 0.38, 0.34)

var world: World
var _seen: int = 0
var _rows: Array[Dictionary] = []          ## {killer, victim, killer_team, victim_team, tag, gold, age}
var _first_done: bool = false
var _streak: Dictionary[int, Array] = {}   ## hero → [số mạng, tick mạng cuối]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if world == null and get_parent() != null:
		world = get_parent().get("world")  # MatchHud có world khi màn trận gắn
	if world != null and world.tick > _seen and not world.mid_tick:
		if world.tick - _seen >= 2:
			_scan(world.previous_events)
		_scan(world.events)
		_seen = world.tick
	var changed: bool = false
	for r: Dictionary in _rows:
		r["age"] = float(r["age"]) + delta
	while not _rows.is_empty() and float(_rows[0]["age"]) > SHOW_S:
		_rows.pop_front()
		changed = true
	if changed or not _rows.is_empty():
		queue_redraw()


func _scan(events: Array[GameEvent]) -> void:
	var gold: Dictionary[int, int] = {}  # nạn nhân → vàng kẻ hạ (kill_credited phát trước hero_died)
	for ev: GameEvent in events:
		if ev.type == &"kill_credited":
			gold[ev.target_id] = int(ev.amount)
		elif ev.type == &"hero_died":
			add_kill(world.find_entity(ev.target_id), gold.get(ev.target_id, 0))


## Một mạng (cũng dùng trong test); `gold` = vàng kẻ hạ nhận (0: không hiện).
func add_kill(victim: Entity, gold: int = 0) -> void:
	if victim == null:
		return
	var killer: Entity = world.find_entity(victim.killer_id)
	var row: Dictionary = {"victim": victim, "victim_team": victim.team, "killer": killer, "age": 0.0,
		"killer_team": killer.team if killer != null else 2, "tag": "", "gold": 0}
	if killer != null and killer.kind == Entity.Kind.HERO and killer.team != victim.team:
		row["gold"] = gold
		var s: Array = _streak.get(killer.id, [0, -100000])
		var n: int = int(s[0]) + 1 if world.tick - int(s[1]) <= SimClock.seconds_to_ticks(MULTI_S) else 1
		_streak[killer.id] = [n, world.tick]
		row["tag"] = STREAK[mini(n, STREAK.size() - 1)]
		if not _first_done:
			row["tag"] = "Hạ gục đầu tiên" if row["tag"] == "" else row["tag"]
			_first_done = true
	_rows.append(row)
	while _rows.size() > MAX_ROWS:
		_rows.pop_front()
	queue_redraw()


## Chữ mô tả (test + trợ năng): "Gorran hạ Myra", "Myra bị trụ hạ".
static func line_of(row: Dictionary) -> String:
	var victim: String = _name(row["victim"])
	var killer: Entity = row["killer"]
	if killer == null:
		return victim + " đã chết"
	if killer.kind == Entity.Kind.HERO:
		return _name(killer) + " hạ " + victim
	return victim + " bị " + {Entity.Kind.TOWER: "trụ", Entity.Kind.CORE: "nhà chính", Entity.Kind.LANE_CREEP: "lính",
		Entity.Kind.NEUTRAL: "quái rừng"}.get(killer.kind, "kẻ địch") + " hạ"


func rows() -> Array[Dictionary]:
	return _rows


func _draw() -> void:
	for i: int in _rows.size():
		var r: Dictionary = _rows[i]
		var a: float = clampf((SHOW_S - float(r["age"])) / FADE_S, 0.0, 1.0)
		var box: Rect2 = Rect2(Vector2(size.x * 0.5 - ROW.x * 0.5, TOP + i * (ROW.y + 6)), ROW)
		draw_style_box(UiStyle.box(Color(0.04, 0.06, 0.1, 0.42 * a), Color(_color(r["killer_team"]), 0.35 * a), 1, 12), box)
		var mid: Vector2 = box.get_center()
		_face(r["killer"], Vector2(box.position.x + 32, mid.y), r["killer_team"], a)
		_face(r["victim"], Vector2(box.end.x - 32, mid.y), r["victim_team"], a)
		var tag: String = String(r["tag"])
		_swords(mid + Vector2(0, -10.0 if tag != "" else -4.0), a)
		if int(r["gold"]) > 0:
			UiStyle.text_center(self, UiStyle.serif(true), Vector2(box.position.x + 100, mid.y + 8), "+%d" % int(r["gold"]), 22, Color(GOLD, a))
		if tag != "":
			UiStyle.text_center(self, UiStyle.serif(true), mid + Vector2(0, 24), tag, 18, Color(GOLD, 0.9 * a))
		else:
			UiStyle.text_center(self, UiStyle.serif(false), mid + Vector2(0, 24), line_of(r), 15, Color(1, 1, 1, 0.55 * a))


## Hai kiếm bắt chéo (dấu hạ gục).
func _swords(at: Vector2, a: float) -> void:
	for s: float in [-1.0, 1.0]:
		draw_line(at + Vector2(-9 * s, 9), at + Vector2(9 * s, -9), Color(1, 0.9, 0.7, 0.85 * a), 3.0)
		draw_line(at + Vector2(-5 * s, 2), at + Vector2(-2 * s, 5), Color(1, 0.9, 0.7, 0.85 * a), 3.0)


func _face(e: Entity, at: Vector2, team: int, a: float) -> void:
	UiStyle.orb(self, at, FACE_R + 1.0, Color(_color(team).darkened(0.5), 0.8 * a))
	var tex: Texture2D = ArtLibrary.texture(StringName(String(e.hero_def.id) + "_portrait")) if e != null and e.hero_def != null else null
	if tex != null:
		draw_texture_rect(tex, Rect2(at - Vector2(FACE_R, FACE_R) * 0.9, Vector2(FACE_R, FACE_R) * 1.8), false, Color(1, 1, 1, a))
	draw_arc(at, FACE_R, 0.0, TAU, 32, Color(_color(team), 0.8 * a), 2.0)


static func _color(team: int) -> Color:
	return BLUE if team == 0 else RED if team == 1 else Color(0.75, 0.75, 0.75)


static func _name(e: Entity) -> String:
	if e == null:
		return "?"
	return e.hero_def.display_name.get_slice(" · ", 0) if e.hero_def != null else "?"
