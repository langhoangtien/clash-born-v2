extends Node2D
## Màn trận: World + map + đơn vị, camera theo hero, điều khiển (CTL-01):
## WASD/mũi tên hoặc joystick ảo → đi theo hướng; PC chuột phải → đi tới / đánh địch;
## điện thoại chạm vào địch → đánh (D-45). Nút ĐÁNH ở M2.4.

const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const HERO_ID: StringName = &"brakk"
const SEED: int = 1

@onready var map_view: MapView = $MapView
@onready var units_view: UnitsView = $UnitsView
@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $Hud/Info
@onready var joystick: TouchJoystick = $Hud/Joystick

var world: World
var runner: SimRunner
var hero: Entity
var input: MatchInput = MatchInput.new()


func _ready() -> void:
	world = World.new(SEED, load(BALANCE_PATH) as BalanceSettings)
	world.map = map_view.layout
	world.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	var library: ContentLibrary = ContentLibrary.load_dir()
	hero = UnitFactory.hero(world, library.heroes[HERO_ID], 0, world.map.fountain_point(0))
	_spawn_training_dummy()
	units_view.world = world
	input.world = world
	input.hero = hero
	runner = SimRunner.new(world)
	runner.before_step.connect(_before_step)
	camera.position = hero.position


func _process(delta: float) -> void:
	input.set_direction(_held_direction())
	tick_frame(delta)


## Một khung hình: chạy SIM theo thời gian thật, cập nhật nội suy và camera.
func tick_frame(delta: float) -> void:
	runner.advance(delta)
	units_view.alpha = runner.alpha()
	camera.position = units_view.display_position(hero)
	hud.text = "tick %d · %s · máu %.0f · WASD/joystick: đi · chuột phải: đi tới / đánh hình nộm đỏ · Esc: quay lại" % [
		world.tick, hero.art_id, hero.health]


## TẠM (M2.1, bỏ ở M2.3 khi có lính): hình nộm đỏ trước base để thử đánh thường.
func _spawn_training_dummy() -> void:
	var dummy: Entity = Entity.new()
	dummy.team = 1
	dummy.kind = Entity.Kind.NEUTRAL
	dummy.radius = 32.0
	dummy.position = world.navigation(dummy.radius).nearest_clear(world.map.fountain_point(0) + Vector2(900, -700))
	dummy.stats = StatBlock.new(world.balance)
	dummy.stats.set_base(StatId.Id.MAX_HP, 3000)
	dummy.stats.set_base(StatId.Id.PHYSICAL_ARMOR, 2)
	dummy.stats.set_base(StatId.Id.BASE_ATTACK_TIME, 1.0)
	world.add_entity(dummy)


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
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://app/main.tscn")
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		input.click_world_point(get_global_mouse_position(), true)
	elif event is InputEventScreenTouch and event.pressed:
		input.click_world_point(get_canvas_transform().affine_inverse() * (event as InputEventScreenTouch).position, false)
