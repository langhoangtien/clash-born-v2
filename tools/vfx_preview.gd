extends SceneTree
## D-296: xem trước hiệu ứng chiêu trong cảnh trận thật — 6 tướng xếp hàng trước camera (mỗi tướng một hình nộm địch
## trước mặt), tung lần lượt Q / W / R của cả 6 cùng lúc rồi chụp ảnh sau `--delay` giây. Cần cửa sổ:
##   xvfb-run -a godot --path . --resolution 1920x1080 -s tools/vfx_preview.gd -- --out=/đường/dẫn/thư_mục [--delay=0.15]

const SCENE: String = "res://app/match_scene.tscn"
const HEROES: Array[StringName] = [&"duy_anh", &"brakk", &"myra", &"noctis", &"vexa", &"gorran"]
const SLOTS: Array[int] = [AbilityDef.Slot.Q, AbilityDef.Slot.W, AbilityDef.Slot.R]
const GAP: float = 260.0

var _scene: Node
var _out: String = ""
var _delay: float = 0.15
var _casters: Array[Entity] = []
var _dummies: Array[Entity] = []
var _slot: int = -1
var _fired_at: int = 0
var _ready_frames: int = 0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		if kv[0] == "out":
			_out = kv[1]
		elif kv[0] == "delay":
			_delay = float(kv[1])
	var script: GDScript = load(SCENE.get_basename() + ".gd") as GDScript
	script.set("hero_id", &"duy_anh")
	script.set("bot_hero_id", &"noctis")
	_scene = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	var w: World = _scene.get("world")
	if w == null:
		return false
	var loading: Variant = _scene.get("loading")
	if loading != null and not loading.call("finished"):
		return false
	if _casters.is_empty():
		_setup(w)
		return false
	_ready_frames += 1
	if _ready_frames < 10:
		return false
	if _slot < 0 or _ready_frames - _fired_at >= 3:  # hiệu ứng đứng ở đúng `delay` giây, vẽ 3 khung rồi chụp
		if _slot >= 0:
			root.get_texture().get_image().save_png("%s/vfx_%s.png" % [_out, "qwr"[_slot]])
			print("chụp ", "qwr"[_slot], " · đạn kỹ năng: ", (_scene.get("view_3d") as MatchView3D).skill_shots.count(), " / ", w.skill_shots.size())
		_slot += 1
		if _slot >= SLOTS.size():
			return true
		_fire(w, SLOTS[_slot])
	return false


func _setup(w: World) -> void:
	(_scene.get("runner") as SimRunner).paused = true
	(_scene.get("view_3d") as MatchView3D).skill_vfx.set_process(false)  # tự đẩy thời gian hiệu ứng (máy chậm)
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var me: Entity = _scene.get("hero")  # camera theo tướng người chơi → nó là Duy Anh ở giữa hàng
	var center: Vector2 = w.navigation(me.radius).nearest_clear(w.map.world_size() * 0.5 + Vector2(120, 150))
	var base: Vector2 = center - Vector2(GAP * 2.0, 0)
	for i: int in HEROES.size():
		var at: Vector2 = base + Vector2(GAP * (i if i > 0 else 2), 0) if i != 2 else base
		var h: Entity = me if i == 0 else UnitFactory.hero(w, lib.heroes[HEROES[i]], 0, at)
		h.position = at
		h.facing = Vector2.UP
		for slot: int in SLOTS:
			Abilities.set_rank(w, h, Abilities.of(h, slot), 1)
		_casters.append(h)
		_dummies.append(UnitFactory.hero(w, lib.heroes[&"brakk"], 1, at + Vector2(0, -230)))


func _fire(w: World, slot: int) -> void:
	var view: MatchView3D = _scene.get("view_3d")
	view.skill_vfx.advance(60.0)  # gỡ hiệu ứng của lần chụp trước
	w.skill_shots.clear()
	w.zones.clear()
	w.pending_areas.clear()
	for i: int in _casters.size():
		var h: Entity = _casters[i]
		var a: AbilityInstance = Abilities.of(h, slot)
		var target: int = _dummies[i].id if a.def.targeting == AbilityDef.Targeting.UNIT else -1
		var ev: GameEvent = GameEvent.make(&"ability_finished", w.tick, h.id, target, slot)
		ev.point = _dummies[i].position
		ev.direction = Vector2.UP
		view.skill_vfx.on_event(w, ev)
		view.skill_vfx.on_event(w, GameEvent.make(&"damage_taken", w.tick, h.id, _dummies[i].id, 100.0))
		_zones(w, h, a, _dummies[2].position + Vector2(0, 60))  # vùng chiêu đặt giữa màn hình (chỗ trống)
		if a.def.art_id == &"myra_q":
			var s: SkillShot = SkillShot.new()
			s.source_id = h.id
			s.team = 0
			s.position = h.position + Vector2(0, -120)
			s.direction = Vector2.UP
			s.half_width = 60.0
			w.skill_shots.append(s)
	view.skill_vfx.advance(_delay)
	_fired_at = _ready_frames


## Vùng tồn tại / vùng có độ trễ của kỹ năng (đặt tay vào World, giữa chừng thời gian) — ZoneView3D vẽ.
func _zones(w: World, h: Entity, a: AbilityInstance, at: Vector2) -> void:
	var radius: float = Abilities.value(h, a, &"radius") if a.def.values.has(&"radius") else 250.0
	var zone: ActionDef = _find(a.def.on_cast, ZoneAction)
	if zone != null:
		var z: ActiveZone = ActiveZone.new()
		z.action = zone
		z.source_id = h.id
		z.center = at
		z.radius = radius
		z.start_tick = w.tick - 30
		z.end_tick = w.tick + 60
		z.interval_ticks = 15
		w.zones.append(z)
		return
	if a.def.values.has(&"delay"):
		var p: PendingArea = PendingArea.new()
		p.action = _find(a.def.on_cast, AreaAction)
		p.source_id = h.id
		p.center = at
		p.radius = radius
		p.start_tick = w.tick - 15
		p.due_tick = w.tick + 15
		w.pending_areas.append(p)


static func _find(list: Array, type: Variant) -> ActionDef:
	for x: Variant in list:
		if is_instance_of(x, type):
			return x
		if x is Resource:
			for prop: Dictionary in (x as Resource).get_property_list():
				var v: Variant = (x as Resource).get(prop["name"])
				if v is Array:
					var got: ActionDef = _find(v, type)
					if got != null:
						return got
	return null
