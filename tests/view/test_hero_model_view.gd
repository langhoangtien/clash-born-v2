extends TestCase
## D-412: khung xem mô hình 3D ở màn chọn tướng (thẻ Mô hình) — đúng một mô hình + AnimationPlayer, vuốt xoay (quán tính,
## không tự xoay khi đang chạm), phóng to trong giới hạn, chạm đúp về góc cũ, nút hoạt ảnh phát đúng tên theo cấu hình,
## hoạt ảnh một lần xong về Đứng, đổi tướng / đổi thẻ giải phóng mô hình cũ, duyệt mọi tướng trong content/heroes.

const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"


func _select() -> HeroSelect:
	var lib: ContentLibrary = ContentLibrary.load_dir()
	var heroes: Array[HeroDef] = []
	var ids: Array = lib.heroes.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		heroes.append(lib.heroes[id])
	var s: HeroSelect = HeroSelect.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	s.size = Vector2(1920, 1080)
	s.setup(heroes, load(BALANCE_PATH) as BalanceSettings)
	s.press_at(s.tab_rect(HeroDetail.Tab.MODEL).get_center())
	return s


func _actors(v: HeroModelView) -> Array[Node]:
	return v.stage.find_children("*", "Actor3D", true, false)


func _touch(v: HeroModelView, at: Vector2, pressed: bool, double: bool = false) -> void:
	var t: InputEventScreenTouch = InputEventScreenTouch.new()
	t.position = at
	t.pressed = pressed
	t.double_tap = double
	v._gui_input(t)


func test_D_412_one_model_with_animation_player() -> void:
	var s: HeroSelect = _select()
	var v: HeroModelView = s.model_view
	assert_true(v.visible, "thẻ Mô hình mở → khung 3D hiện")
	assert_eq(_actors(v).size(), 1, "đúng một mô hình")
	assert_true(v.stage.anim != null, "có AnimationPlayer")
	assert_eq(v.playing, &"idle", "mặc định Đứng")
	assert_eq(String(v.stage.anim.current_animation), "idle")
	s.press_at(s.tab_rect(HeroDetail.Tab.SKILLS).get_center())
	assert_false(v.visible)
	assert_eq(_actors(v).size(), 0, "đổi thẻ → gỡ mô hình")
	s.free()


func test_D_412_drag_turns_with_inertia_zoom_and_double_tap_reset() -> void:
	var s: HeroSelect = _select()
	var v: HeroModelView = s.model_view
	var yaw0: float = v.stage.yaw
	var mid: Vector2 = v.view_rect().get_center()
	_touch(v, mid, true)
	var d: InputEventScreenDrag = InputEventScreenDrag.new()
	d.position = mid + Vector2(80, 0)
	d.relative = Vector2(80, 0)
	d.velocity = Vector2(600, 0)
	v._gui_input(d)
	assert_true(v.stage.yaw > yaw0, "vuốt phải → xoay")
	var held: float = v.stage.yaw
	v._process(0.1)
	assert_eq(v.stage.yaw, held, "đang chạm thì không tự xoay")
	_touch(v, mid, false)
	v._process(0.1)
	assert_true(v.stage.yaw > held, "thả tay → quán tính xoay tiếp")
	for i: int in 200:
		v._process(0.1)
	assert_eq(v.spin, 0.0, "quán tính tắt dần")
	for i: int in 30:
		v.zoom_by(0.8)
	assert_eq(v.stage.zoom, HeroStage3D.ZOOM_MIN, "phóng to có giới hạn")
	for i: int in 30:
		v.zoom_by(1.25)
	assert_eq(v.stage.zoom, HeroStage3D.ZOOM_MAX, "thu nhỏ có giới hạn")
	_touch(v, mid, true, true)
	assert_eq(v.stage.yaw, HeroStage3D.DEFAULT_YAW, "chạm đúp → góc mặc định")
	assert_eq(v.stage.zoom, 1.0)
	s.free()


func test_D_412_buttons_play_configured_animations_then_back_to_idle() -> void:
	var s: HeroSelect = _select()
	var v: HeroModelView = s.model_view
	s.press_at(s.card_rect(s.previews.map(func(p: HeroPreview) -> StringName: return p.def.id).find(&"gorran")).get_center())
	assert_eq(v.hero_id, &"gorran")
	var keys: Array = v.animations.map(func(a: Array) -> StringName: return a[0])
	for k: StringName in [&"idle", &"run", &"attack", &"q", &"w", &"r", &"stun", &"death"]:
		assert_true(keys.has(k), "gorran có hoạt ảnh %s" % k)
	for i: int in v.animations.size():
		_touch(v, v.button_rect(i).get_center(), true)
		_touch(v, v.button_rect(i).get_center(), false)
		assert_eq(v.playing, v.animations[i][0])
		assert_eq(String(v.stage.anim.current_animation), String(v.animations[i][1]), "nút %s phát đúng tên" % v.animations[i][0])
	v.play(&"attack")
	v.stage.anim.advance(v.stage.anim.current_animation_length + 0.1)
	assert_eq(v.playing, &"idle", "hoạt ảnh một lần xong → về Đứng")
	s.free()


func test_D_412_every_hero_builds_and_old_model_is_freed() -> void:
	var s: HeroSelect = _select()
	var v: HeroModelView = s.model_view
	var slowest: float = 0.0
	for i: int in s.previews.size():
		var old: WeakRef = weakref(v.stage.actor)
		var t0: int = Time.get_ticks_usec()
		s.press_at(s.card_rect(i).get_center())
		slowest = maxf(slowest, (Time.get_ticks_usec() - t0) / 1000.0)
		var id: StringName = s.previews[i].def.id
		assert_eq(v.hero_id, id)
		assert_eq(_actors(v).size(), 1, "%s: đúng một mô hình" % id)
		assert_true(v.stage.anim != null, "%s: có AnimationPlayer" % id)
		assert_true(v.animations.size() >= 2 and v.animations[0][0] == &"idle", "%s: có Đứng + ít nhất một hoạt ảnh khác" % id)
		assert_eq(v.temporary, ModelLibrary.unit(s.previews[i].lv1.art_id).has("_tam"), "%s: nhãn mô hình tạm" % id)
		if i > 0:
			assert_true(old.get_ref() == null, "%s: mô hình cũ đã giải phóng" % id)
	print("D-412: đổi tướng chậm nhất %.0f ms (%d tướng)" % [slowest, s.previews.size()])
	s.free()


func test_D_412_animation_list_skips_missing() -> void:
	var ap: AnimationPlayer = AnimationPlayer.new()
	var lib: AnimationLibrary = AnimationLibrary.new()
	for n: String in ["idle", "run", "attack", "skill_2"]:
		lib.add_animation(n, Animation.new())
	ap.add_animation_library(&"", lib)
	var got: Array[Array] = HeroModelView.animation_list({"attack": "attack", "skills": {"2": "skill_2", "3": "skill_3"}},
		{"idle": "idle", "run": "run", "stun": "stun", "death": "death"}, ap)
	assert_eq(got.map(func(a: Array) -> StringName: return a[0]), [&"idle", &"run", &"attack", &"w"], "không có tên thì không có nút")
	ap.free()
