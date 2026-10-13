extends Node2D
## Màn trận (M1.4): World + map + đơn vị, camera theo hero.
## TẠM (bỏ ở M1.5 khi có điều khiển): hero tự đi tuần lane giữa để thấy chuyển động.

const BALANCE_PATH: String = "res://content/balance/balance_settings.tres"
const HERO_ID: StringName = &"brakk"
const SEED: int = 1

@onready var map_view: MapView = $MapView
@onready var units_view: UnitsView = $UnitsView
@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $Hud/Info

var world: World
var runner: SimRunner
var hero: Entity

var _patrol: PackedVector2Array = PackedVector2Array()
var _patrol_index: int = 0


func _ready() -> void:
	world = World.new(SEED, load(BALANCE_PATH) as BalanceSettings)
	world.map = map_view.layout
	world.add_system(MovementSystem.new(), World.Phase.MOVEMENT)
	var library: ContentLibrary = ContentLibrary.load_dir()
	hero = UnitFactory.hero(world, library.heroes[HERO_ID], 0, world.map.fountain_point(0))
	units_view.world = world
	runner = SimRunner.new(world)
	runner.before_step.connect(_before_step)
	_patrol = world.map.route("MID", 0)
	camera.position = hero.position


func _process(delta: float) -> void:
	tick_frame(delta)


## Một khung hình: chạy SIM theo thời gian thật, cập nhật nội suy và camera.
func tick_frame(delta: float) -> void:
	runner.advance(delta)
	units_view.alpha = runner.alpha()
	camera.position = units_view.display_position(hero)
	hud.text = "tick %d · %s · máu %.0f · Esc: quay lại" % [world.tick, hero.art_id, hero.health]


func _before_step() -> void:
	units_view.capture_previous()
	_patrol_step()


## TẠM (M1.4): đi lần lượt qua các điểm của lane giữa, hết thì quay đầu.
func _patrol_step() -> void:
	if hero.order.type == Order.Type.MOVE and not hero.order.finished:
		return
	_patrol_index = (_patrol_index + 1) % _patrol.size()
	world.submit(Command.move_to(hero.id, _patrol[_patrol_index]))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://app/main.tscn")
