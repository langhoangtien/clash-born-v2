extends Node2D
## Màn trận: World + map + đơn vị, camera theo hero, điều khiển (CTL-01..04):
## WASD/mũi tên hoặc joystick ảo → đi theo hướng; nút ĐÁNH / Lính / Trụ hoặc J/K/L → đánh
## (giữ là đánh liên tục); PC chuột phải → đi tới / khóa địch; chạm vào địch → khóa (D-45).

const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
## Tướng của người chơi; màn khởi động đặt trước khi vào trận (tạm, tới khi có màn chọn tướng M8).
static var hero_id: StringName = &"brakk"
## D-94: hero và độ khó của bot đối thủ (màn khởi động đặt; "" = không có bot).
static var bot_hero_id: StringName = &"myra"
static var bot_difficulty: int = BotState.Difficulty.NORMAL
const SEED: int = 1
## CTL-02: phím PC giả lập nút ĐÁNH / đánh lính / đánh trụ (theo Rules.AttackMode).
const ATTACK_KEYS: Array[Key] = [KEY_J, KEY_K, KEY_L]
const SPEEDS: Array[int] = [1, 2, 4, 8]
const MENU_SCENE: String = "res://app/main.tscn"
const HELP: String = "J đánh · K lính · L trụ · 1/2/3 chiêu (nhắm theo chuột) · Ctrl+1..4 cộng điểm · WASD đi · chuột phải: đi tới / khóa · F tốc độ · 4–9 dùng đồ · H về thành · B shop · F2 ký hiệu map · Esc"

@onready var map_view: MapView = $MapView
@onready var units_view: UnitsView = $UnitsView
@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $Hud/Info
@onready var joystick: TouchJoystick = $Hud/Joystick
@onready var attack_buttons: AttackButtons = $Hud/AttackButtons
@onready var match_hud: MatchHud = $Hud/MatchHud
@onready var skill_buttons: SkillButtons = $Hud/SkillButtons
@onready var talent_panel: TalentPanel = $Hud/TalentPanel
@onready var aim_indicator: AimIndicator = $AimIndicator
@onready var buff_bar: BuffBar = $Hud/BuffBar

var world: World
var runner: SimRunner
var hero: Entity
## Hero bot của trận (null nếu không có), cho nút Test (D-138).
var bot_unit: Entity
var input: MatchInput = MatchInput.new()
var result: ResultPanel
var hero_def: HeroDef
var skills: SkillControls = SkillControls.new()
var fog: FogView
var audio: AudioView
var death_cam: DeathCamera = DeathCamera.new()
var quick_buy: QuickBuy
## D-128: món soạn sẵn đã lên xong trong trận này (ẩn khỏi shop, vẫn giữ trong bộ đã lưu).
var _build_done: Array[StringName] = []
var minimap: Minimap
var shop: ShopPanel


func _ready() -> void:
	UnitSprite.clear_cache()  # D-149: id đơn vị dùng lại giữa các trận
	world = World.new(SEED, load(BALANCE_PATH) as BalanceSettings)
	world.map = map_view.layout
	world.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	var library: ContentLibrary = ContentLibrary.load_dir()
	MatchSetup.spawn_structures(world, library)
	MatchSetup.add_vision(world)
	MatchSetup.add_jungle(world, library)
	MatchSetup.add_shop(world, library)
	MatchSetup.add_lane_creeps(world, library, true)
	hero_def = library.heroes[hero_id]
	for def: GameDef in library.units.values() + library.heroes.values():
		ArtLibrary.texture(def.art_id)  # nạp sẵn hình lúc vào trận, không để lần xuất hiện đầu bị giật
	hero = UnitFactory.hero(world, hero_def, 0, world.map.fountain_point(0))
	if bot_hero_id != &"":
		var foe: Entity = UnitFactory.hero(world, library.heroes[bot_hero_id], 1, world.map.fountain_point(1))
		MatchSetup.add_bot(world, foe, bot_difficulty as BotState.Difficulty)
		bot_unit = foe
	units_view.world = world
	units_view.viewer_team = hero.team
	fog = FogView.new()
	fog.name = "Fog"
	fog.world = world
	fog.team = hero.team
	fog.place = units_view.display_position
	add_child(fog)
	move_child(fog, units_view.get_index())  # trên map, dưới đơn vị
	minimap = Minimap.new()
	minimap.name = "Minimap"
	$Hud.add_child(minimap)
	minimap.setup(world, hero)
	input.world = world
	input.hero = hero
	runner = SimRunner.new(world)
	runner.before_step.connect(_before_step)
	if MapBaker.can_bake():
		runner.attach_to_render()  # D-152: SIM chạy trên luồng phụ trong lúc máy vẽ khung
	_setup_audio()
	_setup_quick_buy()
	_setup_test_panel()
	camera.position = hero.position
	skills.world = world
	skills.hero = hero
	skills.input = input
	skills.buttons = skill_buttons
	skills.indicator = aim_indicator
	skills.talents = talent_panel
	var item_buttons: ItemButtons = ItemButtons.new()
	item_buttons.name = "ItemButtons"
	$Hud.add_child(item_buttons)
	item_buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skills.items = item_buttons
	shop = ShopPanel.new()
	shop.name = "ShopPanel"
	$Hud.add_child(shop)
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop.world = world
	shop.z_index = 10  # D-115: bảng shop / tỷ số vẽ trên cụm nút điều khiển
	shop.hero = hero
	shop.buy_pressed.connect(func(id: StringName) -> void: world.submit(Command.buy(hero.id, id)))  # SHOP-01
	shop.sell_pressed.connect(func(i: int) -> void: world.submit(Command.sell(hero.id, i)))  # SHOP-05
	shop.build = BuildPresets.load_build(hero_id)  # D-120: bộ đồ soạn sẵn của tướng này
	shop.build_changed.connect(func(b: Array[StringName]) -> void: BuildPresets.save_build(hero_id, _build_done + b))
	var info: InfoPanels = InfoPanels.new()
	info.name = "InfoPanels"
	$Hud.add_child(info)
	info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info.world = world
	info.z_index = 10
	info.hero = hero
	skills.connect_signals()
	match_hud.world = world
	buff_bar.world = world
	buff_bar.hero = hero
	match_hud.hero = hero
	hud.text = HELP
	hud.visible = not OS.has_feature("mobile")  # D-144: phím tắt chỉ có ích trên máy tính


func _process(delta: float) -> void:
	input.set_direction(_held_direction())
	for mode: int in range(ATTACK_KEYS.size()):
		input.set_attack_held(mode, attack_buttons.is_held(mode) or Input.is_physical_key_pressed(ATTACK_KEYS[mode]))
	tick_frame(delta)


## Một khung hình: chạy SIM theo thời gian thật, cập nhật nội suy và camera.
func tick_frame(delta: float) -> void:
	runner.advance(delta)
	audio.flush()  # D-152: tiếng của các tick vừa chạy
	units_view.alpha = runner.alpha()
	var follow: Vector2 = death_cam.update(hero.alive, units_view.display_position(hero), _held_direction(), delta, _map_bounds())  # CAM-01
	if minimap.peeking and death_cam.active():
		death_cam.jump(minimap.peek_point, _map_bounds())  # CAM-01b
	camera.position = minimap.peek_point if minimap.peeking else follow
	if quick_buy != null:  # SHOP-10: món nên mua lúc này
		_drop_finished_build()
		var next: ItemDef = BuildPlan.next_buy(world, hero, shop.build if not shop.build.is_empty() else hero_def.bot_item_build)
		quick_buy.show_item(next, Shop.price(world, hero, next) if next != null else 0)
	var view_size: Vector2 = get_viewport_rect().size / camera.zoom
	minimap.camera_rect = Rect2(camera.position - view_size * 0.5, view_size)
	fog.view_rect = minimap.camera_rect  # D-108: chỉ tô sương trong khung camera
	audio.listener = camera.position
	units_view.view_rect = fog.view_rect  # D-149: không vẽ đơn vị ngoài khung nhìn
	match_hud.speed = runner.speed
	match_hud.sim_ms = runner.step_ms
	skills.refresh()
	var zone: Rect2 = skills.items.zone_rect()  # D-88: buff/debuff ngay trên chỗ nút đồ, như Liên Quân
	var origin: Vector2 = skills.items.global_position - buff_bar.global_position
	buff_bar.left_x = origin.x + zone.position.x
	buff_bar.bottom_y = origin.y + zone.position.y - 10.0
	buff_bar.right_limit = skill_buttons.global_position.x - buff_bar.global_position.x + skill_buttons.skill_center(0).x - SkillButtons.SKILL_RADIUS
	if world.winner >= 0 and result == null:
		_show_result()


func _exit_tree() -> void:
	runner.detach()  # D-152


func _show_result() -> void:
	result = ResultPanel.new()
	$Hud.add_child(result)
	result.show_result(world, hero)
	result.replay_pressed.connect(func() -> void: get_tree().reload_current_scene())
	result.menu_pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))


## D-53: phím F đổi tốc độ chơi thử ×1 → ×2 → ×4 → ×8 → ×1.
func cycle_speed() -> void:
	var i: int = SPEEDS.find(runner.speed)
	runner.speed = SPEEDS[(i + 1) % SPEEDS.size()]


func _before_step() -> void:
	units_view.capture_previous()
	input.flush()


## Joystick ảo ưu tiên; không chạm thì đọc WASD / mũi tên.
func _held_direction() -> Vector2:
	if joystick.active:
		return joystick.direction
	var dir: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	return dir


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_F:
		cycle_speed()
	elif event is InputEventKey and event.pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_B:
		shop.toggle()  # D-81: bảng shop tạm
	elif event is InputEventKey and event.pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_F2:
		map_view.toggle_overlay(&"labels")  # D-77: ký hiệu map dev
	elif event is InputEventKey and event.pressed and not (event as InputEventKey).echo and skills.handle_key(event, get_global_mouse_position()):
		pass
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(MENU_SCENE)
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		input.click_world_point(get_global_mouse_position(), true)
	elif event is InputEventScreenDrag and death_cam.active():
		death_cam.drag((event as InputEventScreenDrag).relative / camera.zoom, _map_bounds())  # CAM-01
	elif event is InputEventScreenTouch and event.pressed:
		input.click_world_point(get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position, false)


## D-114: âm thanh theo sự kiện trận, nhạc trận + tiếng nền map, nút chế độ tiếng (phím M).
func _setup_audio() -> void:
	audio = AudioView.new()
	audio.name = "Audio"
	add_child(audio)
	audio.setup_match(hero.team, hero.id)
	runner.stepped.connect(func() -> void: audio.on_step(world))
	audio.play_music(&"music_match", &"amb_map")
	var toggle: SoundToggle = SoundToggle.new()
	toggle.name = "SoundToggle"
	$Hud.add_child(toggle)
	toggle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toggle.pressed.connect(func() -> void:
		audio.cycle_mode()
		toggle.queue_redraw())


func _map_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, world.map.world_size())


## D-138: nút Test — cộng vàng / lên cấp cho mình hoặc bot qua lệnh CHEAT_* (CMD-06).
func _setup_test_panel() -> void:
	var panel: TestPanel = TestPanel.new()
	panel.name = "TestPanel"
	panel.has_bot = bot_unit != null
	$Hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.action.connect(_on_test_action)


func _on_test_action(who: int, what: StringName) -> void:
	var target: Entity = hero if who == 0 else bot_unit
	if target == null:
		return
	if what == &"gold":
		world.submit(Command.cheat_gold(target.id, 10000))
	else:
		world.submit(Command.cheat_level(target.id, 1 if what == &"level" else world.balance.hero_max_level))


## SHOP-10 (D-117): nút mua nhanh theo thứ tự lên đồ gợi ý của hero.
func _setup_quick_buy() -> void:
	quick_buy = QuickBuy.new()
	quick_buy.name = "QuickBuy"
	$Hud.add_child(quick_buy)
	quick_buy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quick_buy.pressed.connect(func(id: StringName) -> void: world.submit(Command.buy(hero.id, id)))



## D-128: món soạn sẵn đã lên xong thì tự bỏ khỏi danh sách trong trận (bộ đã lưu giữ nguyên cho trận sau).
func _drop_finished_build() -> void:
	if shop.build.is_empty():
		return
	var left: Array[StringName] = BuildPlan.pending(world, hero, shop.build)
	if left.size() != shop.build.size():
		for id: StringName in shop.build:
			if not left.has(id):
				_build_done.append(id)
		shop.build = left
		shop.queue_redraw()
