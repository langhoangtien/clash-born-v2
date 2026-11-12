class_name HeroModelView
extends Control
## D-412: khung xem mô hình 3D của tướng đang chọn (màn chọn tướng, thẻ "Mô hình"): vuốt ngang xoay quanh trục đứng (có
## quán tính nhẹ, không tự xoay khi đang chạm), chụm hai ngón / lăn chuột phóng to thu nhỏ, chạm đúp về góc mặc định;
## hàng nút hoạt ảnh (Đứng / Chạy / Đánh / Q / W / R / Choáng / Chết) theo đúng tên trong cấu hình của tướng — tướng không
## có hoạt ảnh nào thì không có nút đó; "Đứng" lặp mặc định, hoạt ảnh một lần phát xong về "Đứng". Tướng còn mượn mô hình
## (`_tam` trong units_3d.json) hiện nhãn "mô hình tạm". Chỉ đọc dữ liệu, không đụng trận.

## Hằng số giao diện / cảm giác vuốt.
const BAR_H: float = 64.0
const BUTTON_W: float = 108.0
const BUTTON_GAP: float = 8.0
const TURN_PER_PX: float = 0.008   ## rad mỗi px vuốt
const SPIN_DECAY: float = 4.0      ## quán tính giảm theo e^(-k·giây)
const SPIN_STOP: float = 0.05      ## rad / s — dưới mức này thì dừng
const WHEEL_STEP: float = 0.9      ## mỗi nấc lăn chuột nhân zoom
const LABELS: Dictionary[StringName, String] = {&"idle": "Đứng", &"run": "Chạy", &"attack": "Đánh", &"q": "Q", &"w": "W",
	&"r": "R", &"stun": "Choáng", &"death": "Chết"}
const LOOPING: Array[StringName] = [&"idle", &"run", &"stun"]

var stage: HeroStage3D
var viewport: SubViewport
## [[khóa, tên hoạt ảnh]] của tướng đang xem (chỉ hoạt ảnh mô hình có).
var animations: Array[Array] = []
var playing: StringName = &""
var hero_id: StringName = &""
var temporary: bool = false
var spin: float = 0.0               ## rad / s quán tính
var _note: Label                    ## nhãn trên khung 3D: "mô hình tạm" + cách vuốt
var _touches: Dictionary[int, Vector2] = {}
var _pinch: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box: SubViewportContainer = SubViewportContainer.new()
	box.name = "Box"
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -(BAR_H + 8.0)  # khung 3D phía trên, hàng nút hoạt ảnh bên dưới
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	box.add_child(viewport)
	stage = HeroStage3D.new()
	viewport.add_child(stage)
	_note = Label.new()
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_theme_font_size_override("font_size", 20)
	_note.add_theme_color_override("font_color", UiStyle.DIM)
	_note.position = Vector2(16, 10)
	add_child(_note)


## Khóa → tên hoạt ảnh theo cấu hình units_3d.json (`rigs`, `attack`, `skills` "1".."3" = Q / W / R); bỏ tên mô hình không có.
static func animation_list(cfg: Dictionary, rig: Dictionary, ap: AnimationPlayer) -> Array[Array]:
	var skills: Dictionary = cfg.get("skills", {})
	var want: Array[Array] = [[&"idle", rig.get("idle", "")], [&"run", rig.get("run", "")], [&"attack", cfg.get("attack", "")],
		[&"q", skills.get("1", "")], [&"w", skills.get("2", "")], [&"r", skills.get("3", "")], [&"stun", rig.get("stun", "")],
		[&"death", rig.get("death", "")]]
	var out: Array[Array] = []
	for pair: Array in want:
		if ap != null and String(pair[1]) != "" and ap.has_animation(String(pair[1])):
			out.append(pair)
	return out


## Xem tướng của `p` (cùng tướng thì giữ nguyên).
func show_hero(p: HeroPreview) -> void:
	if p.def.id == hero_id and stage.actor != null:
		return
	hero_id = p.def.id
	stage.show_unit(p.lv1)
	var cfg: Dictionary = ModelLibrary.unit(p.lv1.art_id)
	temporary = cfg.has("_tam")
	animations = animation_list(cfg, ModelLibrary.rig(cfg["rig"]), stage.anim) if cfg.has("rig") else []
	spin = 0.0
	if stage.anim != null and not stage.anim.animation_finished.is_connected(_on_finished):
		stage.anim.animation_finished.connect(_on_finished)
	play(&"idle")
	_note.text = ("mô hình tạm\n" if temporary else "") + "Vuốt để xoay · chụm / lăn chuột: phóng to · chạm đúp: góc cũ"
	queue_redraw()


## Gỡ mô hình (đổi thẻ / rời màn).
func clear() -> void:
	stage.clear()
	hero_id = &""
	animations.clear()
	playing = &""


func play(key: StringName) -> void:
	for pair: Array in animations:
		if pair[0] == key:
			stage.anim.play(String(pair[1]), 0.12)  # Đứng / Chạy / Choáng lặp sẵn (Actor3D.make)
			playing = key
			queue_redraw()
			return


func _on_finished(_name: StringName) -> void:
	if not LOOPING.has(playing):
		play(&"idle")


func view_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x, maxf(0.0, size.y - BAR_H - 8.0)))


func button_rect(i: int) -> Rect2:
	return Rect2(Vector2(i * (BUTTON_W + BUTTON_GAP), size.y - BAR_H), Vector2(BUTTON_W, BAR_H))


func _process(delta: float) -> void:
	if _touches.is_empty() and absf(spin) > SPIN_STOP:  # quán tính sau khi thả tay
		stage.yaw += spin * delta
		spin *= exp(-SPIN_DECAY * delta)
		stage.place_camera()
	elif _touches.is_empty():
		spin = 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b: MouseButton = (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP or b == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(WHEEL_STEP if b == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL_STEP)
	elif event is InputEventMagnifyGesture:
		zoom_by(1.0 / (event as InputEventMagnifyGesture).factor)
	accept_event()


func _touch(t: InputEventScreenTouch) -> void:
	if not t.pressed:
		_touches.erase(t.index)
		return
	for i: int in animations.size():
		if button_rect(i).has_point(t.position):
			play(animations[i][0])
			return
	if t.double_tap:
		stage.reset_view()
		spin = 0.0
		return
	_touches[t.index] = t.position
	spin = 0.0
	_pinch = _spread()


func _drag(d: InputEventScreenDrag) -> void:
	if not _touches.has(d.index):
		return
	_touches[d.index] = d.position
	if _touches.size() >= 2:  # chụm / mở hai ngón
		var now: float = _spread()
		if _pinch > 1.0 and now > 1.0:
			zoom_by(_pinch / now)
		_pinch = now
		return
	turn_by(d.relative.x)
	spin = d.velocity.x * TURN_PER_PX


## Vuốt `px` điểm ảnh ngang → xoay.
func turn_by(px: float) -> void:
	stage.yaw += px * TURN_PER_PX
	stage.place_camera()


func zoom_by(factor: float) -> void:
	stage.zoom *= factor
	stage.place_camera()


func _spread() -> float:
	var pts: Array[Vector2] = _touches.values()
	return pts[0].distance_to(pts[1]) if pts.size() >= 2 else 0.0


func _draw() -> void:
	draw_style_box(UiStyle.box(UiStyle.CARD, UiStyle.LINE, 1, 10), view_rect().grow(2))
	for i: int in animations.size():
		var key: StringName = animations[i][0]
		UiStyle.button(self, button_rect(i), &"gold" if key == playing else &"ghost", LABELS[key], "", 22)
