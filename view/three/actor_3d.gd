class_name Actor3D
extends Node3D
## Một đơn vị trong bản 3D thử (D-145, D-146). Đơn vị có mô hình trong units_3d.json: nhân vật KayKit
## với vũ khí gắn tay, bảng màu theo đội và hoạt ảnh theo trạng thái SIM (đứng, chạy, đánh, tung chiêu,
## lướt, trúng đòn). Đơn vị khác: ảnh đứng luôn quay về camera (billboard) như bản 2D. Chỉ đọc World.

const BLEND: float = 0.12

var height: float = 1.0
var _cfg: Dictionary = {}
var _rig: Dictionary = {}
var _anim: AnimationPlayer
var _sprite: Sprite3D
var _playing: String = ""
var _attack_tick: int = -1


static func make(e: Entity) -> Actor3D:
	var a: Actor3D = Actor3D.new()
	var cfg: Dictionary = ModelLibrary.unit(e.art_id)
	if cfg.is_empty():
		a._make_sprite(e)
	else:
		a._make_model(e, cfg)
	return a


func _make_model(e: Entity, cfg: Dictionary) -> void:
	_cfg = cfg
	_rig = ModelLibrary.rig(cfg["rig"])
	height = cfg["height"]
	var model: Node3D = ModelLibrary.scene(cfg["model"] + ".glb").instantiate() as Node3D
	add_child(model)
	add_child(Look3D.blob(height))  # D-150: bóng mờ dưới chân
	model.scale = Vector3.ONE * (height / float(_rig["native"]))
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	_attach(skel, cfg.get("right", ""), "handslot.r")
	_attach(skel, cfg.get("left", ""), "handslot.l")
	_paint(model, cfg["tex"], e.team)
	_anim = AnimationPlayer.new()
	model.add_child(_anim)
	_anim.add_animation_library(&"", ModelLibrary.animations(cfg["rig"]))
	for key: String in ["idle", "run"]:
		_anim.get_animation(_rig[key]).loop_mode = Animation.LOOP_LINEAR


func _attach(skel: Skeleton3D, weapon: String, bone: String) -> void:
	if weapon.is_empty():
		return
	var slot: BoneAttachment3D = BoneAttachment3D.new()
	slot.bone_name = bone
	skel.add_child(slot)
	slot.add_child(ModelLibrary.scene(weapon + ".gltf").instantiate())


## Đổi bảng màu mọi lưới trong `root` sang bản theo đội (vũ khí giữ màu gốc).
func _paint(root: Node, tex: String, team: int) -> void:
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		if n.get_parent() is BoneAttachment3D or n.get_parent().get_parent() is BoneAttachment3D:
			continue
		var mi: MeshInstance3D = n as MeshInstance3D
		for i: int in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, ModelLibrary.team_material(mi.mesh.surface_get_material(i), tex, team))


func _make_sprite(e: Entity) -> void:
	var tex: Texture2D = UnitSprite.texture_of(e)
	height = UnitSprite.height_of(e) * MatchView3D.S
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if tex != null:
		_sprite.texture = tex
		_sprite.pixel_size = height / tex.get_height()
		_sprite.offset = Vector2(0, tex.get_height() * 0.5)
	add_child(_sprite)


func sync(w: World, e: Entity, at: Vector3, moving: bool, hit_age: int) -> void:
	position = at
	if _sprite != null:
		_sprite.flip_h = e.facing.x < 0.0
		_sprite.modulate = Color(1, 0.55, 0.5) if hit_age >= 0 and hit_age < UnitSprite.HIT_TICKS else Color.WHITE
		return
	if e.facing != Vector2.ZERO:
		rotation.y = atan2(e.facing.x, e.facing.y)
	if e.dash != null:
		_play(_rig["dash"], 1.4)
	elif e.cast != null:
		_play(_cfg.get("cast", _cfg["attack"]), 1.5)
	elif e.attack_phase != Entity.AttackPhase.NONE:
		_play_attack(e)
	elif hit_age == 0 and not moving and _playing == _rig["idle"]:
		_play(_rig["hit"], 1.0, true)
	elif _playing == _rig["hit"] and _anim.is_playing():
		pass
	else:
		_play(_rig["run"] if moving else _rig["idle"], 1.0)


## Mỗi đòn đánh mới phát lại từ đầu, kéo dài đúng một chu kỳ đánh.
func _play_attack(e: Entity) -> void:
	var name: String = _cfg["attack"]
	var cycle: float = 1.0 / maxf(0.2, e.stats.attacks_per_second())
	var speed: float = clampf(_anim.get_animation(name).length / cycle, 0.6, 3.5)
	if e.attack_start_tick != _attack_tick:
		_attack_tick = e.attack_start_tick
		_play(name, speed, true)


func _play(name: String, speed: float, restart: bool = false) -> void:
	if name == _playing and not restart:
		return
	_anim.play(name, BLEND, speed)
	if restart:
		_anim.seek(0.0, true)
	_playing = name
