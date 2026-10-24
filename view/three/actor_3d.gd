class_name Actor3D
extends Node3D
## Một đơn vị trong bản 3D thử (D-145). Tướng: mô hình 3D, hoạt ảnh theo trạng thái SIM (đứng, chạy,
## đánh, tung chiêu, lướt). Đơn vị khác: ảnh đứng luôn quay về camera (billboard) như bản 2D.

const LOOPS: Array[StringName] = [&"Idle", &"Running", &"Walking"]
## Chiều cao gốc của mô hình robot thử (đơn vị 3D, đo bằng ảnh chụp).
const MODEL_HEIGHT: float = 5.0

var height: float = 1.0
var _model: Node3D
var _anim: AnimationPlayer
var _sprite: Sprite3D
var _playing: StringName = &""


static func make(e: Entity, hero_scene: PackedScene, hero_height: float) -> Actor3D:
	var a: Actor3D = Actor3D.new()
	if e.kind == Entity.Kind.HERO and hero_scene != null:
		a._model = hero_scene.instantiate() as Node3D
		a.add_child(a._model)
		a._model.scale = Vector3.ONE * (hero_height / MODEL_HEIGHT)
		a.height = hero_height
		var found: Array[Node] = a._model.find_children("*", "AnimationPlayer", true, false)
		if not found.is_empty():
			a._anim = found[0] as AnimationPlayer
			for n: StringName in LOOPS:
				if a._anim.has_animation(n):
					a._anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		return a
	var tex: Texture2D = UnitSprite.texture_of(e)
	a.height = UnitSprite.height_of(e) * MatchView3D.S
	a._sprite = Sprite3D.new()
	a._sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	a._sprite.shaded = false
	a._sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	a._sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if tex != null:
		a._sprite.texture = tex
		a._sprite.pixel_size = a.height / tex.get_height()
		a._sprite.offset = Vector2(0, tex.get_height() * 0.5)
	a.add_child(a._sprite)
	return a


func sync(w: World, e: Entity, at: Vector3, moving: bool, hit_age: int) -> void:
	position = at
	if _sprite != null:
		_sprite.flip_h = e.facing.x < 0.0
		_sprite.modulate = Color(1, 0.55, 0.5) if hit_age >= 0 and hit_age < UnitSprite.HIT_TICKS else Color.WHITE
		return
	if e.facing != Vector2.ZERO:
		rotation.y = atan2(e.facing.x, e.facing.y)
	if _anim == null:
		return
	var want: StringName = &"Idle"
	var speed: float = 1.0
	if e.dash != null:
		want = &"Jump"
	elif e.cast != null:
		want = &"Wave"
		speed = 1.6
	elif e.attack_phase != Entity.AttackPhase.NONE:
		want = &"Punch"
		speed = clampf(e.stats.attacks_per_second() * 1.2, 0.8, 3.0)
	elif moving:
		want = &"Running"
	if want != _playing or (want == &"Punch" and not _anim.is_playing()):
		_anim.play(want, 0.12, speed)
		_playing = want
