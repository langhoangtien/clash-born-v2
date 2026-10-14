extends Node2D
## Màn trận: World + map + đơn vị, camera theo hero, điều khiển (CTL-01..04):
## WASD/mũi tên hoặc joystick ảo → đi theo hướng; nút ĐÁNH / Lính / Trụ hoặc J/K/L → đánh
## (giữ là đánh liên tục); PC chuột phải → đi tới / khóa địch; chạm vào địch → khóa (D-45).

const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const HERO_ID: StringName = &"brakk"
const SEED: int = 1
## CTL-02: phím PC giả lập nút ĐÁNH / đánh lính / đánh trụ (theo Rules.AttackMode).
const ATTACK_KEYS: Array[Key] = [KEY_J, KEY_K, KEY_L]
const SPEEDS: Array[int] = [1, 2, 4, 8]
const MENU_SCENE: String = "res://app/main.tscn"
const HELP: String = "J đánh · K lính · L trụ · 1/2/3 chiêu (nhắm theo chuột) · Ctrl+1..4 cộng điểm · WASD đi · chuột phải: đi tới / khóa · F tốc độ · Esc"

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
var input: MatchInput = MatchInput.new()
var result: ResultPanel
var hero_def: HeroDef
var skills: SkillControls = SkillControls.new()


func _ready() -> void:
	world = World.new(SEED, load(BALANCE_PATH) as BalanceSettings)
	world.map = map_view.layout
	world.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	var library: ContentLibrary = ContentLibrary.load_dir()
	MatchSetup.spawn_structures(world, library)
	MatchSetup.add_lane_creeps(world, library, true)
	hero_def = library.heroes[HERO_ID]
	hero = UnitFactory.hero(world, hero_def, 0, world.map.fountain_point(0))
	units_view.world = world
	input.world = world
	input.hero = hero
	runner = SimRunner.new(world)
	runner.before_step.connect(_before_step)
	camera.position = hero.position
	skills.world = world
	skills.hero = hero
	skills.input = input
	skills.buttons = skill_buttons
	skills.indicator = aim_indicator
	skills.talents = talent_panel
	skills.connect_signals()
	match_hud.world = world
	buff_bar.world = world
	buff_bar.hero = hero
	match_hud.hero = hero
	hud.text = HELP


func _process(delta: float) -> void:
	input.set_direction(_held_direction())
	for mode: int in range(ATTACK_KEYS.size()):
		input.set_attack_held(mode, attack_buttons.is_held(mode) or Input.is_physical_key_pressed(ATTACK_KEYS[mode]))
	tick_frame(delta)


## Một khung hình: chạy SIM theo thời gian thật, cập nhật nội suy và camera.
func tick_frame(delta: float) -> void:
	runner.advance(delta)
	units_view.alpha = runner.alpha()
	camera.position = units_view.display_position(hero)
	match_hud.speed = runner.speed
	skills.refresh()
	buff_bar.right_limit = skill_buttons.global_position.x + skill_buttons.skill_center(0).x - SkillButtons.SKILL_RADIUS
	if world.winner >= 0 and result == null:
		_show_result()


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
	elif event is InputEventKey and event.pressed and not (event as InputEventKey).echo and skills.handle_key(event, get_global_mouse_position()):
		pass
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(MENU_SCENE)
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		input.click_world_point(get_global_mouse_position(), true)
	elif event is InputEventScreenTouch and event.pressed:
		input.click_world_point(get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position, false)
