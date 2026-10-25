class_name Actor3D
extends Node3D
## Một đơn vị trong trận 3D (D-145, D-146). Đơn vị có mô hình trong units_3d.json: nhân vật KayKit
## với vũ khí gắn tay, bảng màu theo đội và hoạt ảnh theo trạng thái SIM (đứng, chạy, đánh, tung chiêu,
## lướt, trúng đòn). Công trình: mô hình tĩnh (D-158). Đơn vị khác: ảnh đứng quay về camera. Chỉ đọc World.
## D-159 cảm giác đòn: điểm chém của hoạt ảnh khớp tick ra đòn của SIM, khựng khung khi trúng, lóe trắng
## và giật lùi khi bị đánh, mỗi chiêu một hoạt ảnh (`skills` trong units_3d.json) phát trọn.

const BLEND: float = 0.12
## Hằng số hiển thị (giây / tỉ lệ).
const IMPACT: float = 0.42  ## điểm chém mặc định trong hoạt ảnh đánh (phần độ dài), ghi đè bằng `impact`
const HIT_STOP: float = 0.07
const FLASH: float = 0.1
## D-160: lóe dịu (đỏ cam nhạt, tối đa FLASH_ALPHA) và cách nhau ít nhất FLASH_GAP giây — nhiều đòn liên tiếp không nhấp nháy.
const FLASH_ALPHA: float = 0.28
const FLASH_GAP: float = 0.35
const FLASH_COLOR: Color = Color(1.0, 0.55, 0.4)
const LEAN: float = 0.12  ## đơn vị 3D, lùi lại khi bị đánh
const SKILL_SPEED: float = 1.3
const SKILL_LOCK_MAX: float = 0.9
const SKILL_MOVE_CANCEL: float = 0.25

var height: float = 1.0
var _cfg: Dictionary = {}
var _rig: Dictionary = {}
var _anim: AnimationPlayer
var _sprite: Sprite3D
var _model: Node3D
## ST-16: hình ếch khi bị hóa ếch (tạo khi cần).
var _frog: Sprite3D
var _meshes: Array[GeometryInstance3D] = []
var _faded: bool = false
var _playing: String = ""
var _attack_tick: int = -1
var _attack_phase: int = Entity.AttackPhase.NONE
## Mốc thời gian thật (giây, Time) cho khóa hoạt ảnh chiêu, khựng khung, lóe, giật lùi.
var _skill_from: float = -1.0
var _skill_until: float = -1.0
var _freeze_until: float = -1.0
var _flash_until: float = -1.0
var _lean: float = 0.0
var _overlay: StandardMaterial3D
var _speed: float = 1.0


static func make(e: Entity) -> Actor3D:
	var a: Actor3D = Actor3D.new()
	var cfg: Dictionary = ModelLibrary.unit(e.art_id)
	var building: Dictionary = ModelLibrary.structure(e) if cfg.is_empty() else {}
	if not building.is_empty():
		a._make_structure(e, building)
	elif cfg.is_empty():
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
	_model = model
	add_child(Look3D.blob(height))  # D-150: bóng mờ dưới chân
	model.scale = Vector3.ONE * (height / float(_rig["native"]))
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	_attach(skel, cfg.get("right", ""), "handslot.r")
	_attach(skel, cfg.get("left", ""), "handslot.l")
	_paint(model, cfg["tex"], e.team)
	for n: Node in model.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(n as GeometryInstance3D)
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


## D-158: công trình là mô hình tĩnh theo đội, cỡ theo chiều cao trong cấu hình.
func _make_structure(e: Entity, cfg: Dictionary) -> void:
	_model = ModelLibrary.medieval(cfg["model"], e.team).instantiate() as Node3D
	add_child(_model)
	height = cfg["height"]
	var box: AABB = ModelLibrary.bounds(_model)
	_model.scale = Vector3.ONE * (height / maxf(0.01, box.size.y))
	_model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * _model.scale.x


func _make_sprite(e: Entity) -> void:
	var tex: Texture2D = UnitSprite.texture_of(e)
	height = UnitSprite.height_of(e) * MatchView3D.S * float(ModelLibrary.config().get("sprite_scale", 1.0))  # D-160
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


## `faded`: GHOST / phe mình núp bụi / tàng hình (UnitsView.faded) — vẽ mờ.
func sync(w: World, e: Entity, at: Vector3, moving: bool, hit_age: int, faded: bool) -> void:
	position = at
	if _anim == null and _sprite == null:
		return  # D-158: công trình — đứng yên
	if _sprite != null:
		_sprite.flip_h = e.facing.x < 0.0
		_sprite.modulate = Color(1, 0.55, 0.5) if hit_age >= 0 and hit_age < UnitSprite.HIT_TICKS else Color.WHITE
		_sprite.modulate.a = 0.45 if faded else 1.0
		return
	_set_faded(faded)
	if _show_frog(Rules.has_state(e, UnitState.Id.HEXED)):
		return
	if e.facing != Vector2.ZERO:
		rotation.y = atan2(e.facing.x, e.facing.y)
	_feel()
	if e.reincarnate_tick >= 0:  # DTH-02: nằm chờ tái sinh — ngã rồi nằm yên ở khung cuối
		if _playing != _rig["death"]:
			_play(_rig["death"], 1.0)
	elif _skill_locked(moving):
		pass
	elif e.dash != null:
		_play(_rig["dash"], 1.4)
	elif e.cast != null:
		_play(_cfg.get("cast", _cfg["attack"]), 1.5)
	elif e.attack_phase != Entity.AttackPhase.NONE:
		_play_attack(w, e)
	elif hit_age == 0 and not moving and _playing == _rig["idle"]:
		_play(_rig["hit"], 1.0, true)
	elif _playing == _rig["hit"] and _anim.is_playing():
		pass
	else:
		_play(_rig["run"] if moving else _rig["idle"], 1.0)
	_attack_phase = e.attack_phase


## D-159: tung chiêu `slot` — phát hoạt ảnh riêng của chiêu (nếu có) đến hết, tối đa SKILL_LOCK_MAX.
func on_cast(slot: int) -> void:
	var name: String = _cfg.get("skills", {}).get(str(slot), "") if _anim != null else ""
	if name.is_empty() or not _anim.has_animation(name):
		return
	_play(name, SKILL_SPEED, true)
	_skill_from = _now()
	_skill_until = _skill_from + minf(_anim.get_animation(name).length / SKILL_SPEED, SKILL_LOCK_MAX)


## D-159: đòn đánh gần của mình vừa trúng — khựng khung.
func on_hit_given() -> void:
	_freeze_until = _now() + HIT_STOP


## D-159, D-160: bị trúng đòn / sát thương — lóe dịu; đòn đánh gần thì khựng và giật lùi.
func on_hit_taken(melee: bool) -> void:
	if _now() > _flash_until + FLASH_GAP:
		_flash_until = _now() + FLASH
	if melee:
		_freeze_until = _now() + HIT_STOP
		_lean = LEAN


func _skill_locked(moving: bool) -> bool:
	var t: float = _now()
	if t >= _skill_until:
		return false
	if moving and t - _skill_from > SKILL_MOVE_CANCEL:
		_skill_until = -1.0  # đi tiếp thì thôi hoạt ảnh chiêu
		return false
	return true


## Khựng khung, lóe trắng, giật lùi (theo thời gian thật, không theo tick).
func _feel() -> void:
	var t: float = _now()
	_anim.speed_scale = 0.0 if t < _freeze_until else _speed
	_lean = move_toward(_lean, 0.0, get_process_delta_time() * LEAN * 8.0) if t >= _freeze_until else _lean
	_model.position.z = -_lean
	var flash: float = clampf((_flash_until - t) / FLASH, 0.0, 1.0)
	if flash > 0.0 or (_overlay != null and _overlay.albedo_color.a > 0.0):
		if _overlay == null:
			_overlay = StandardMaterial3D.new()
			_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for m: GeometryInstance3D in _meshes:
				m.material_overlay = _overlay
		_overlay.albedo_color = Color(FLASH_COLOR, flash * FLASH_ALPHA)


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _set_faded(faded: bool) -> void:
	if faded == _faded:
		return
	_faded = faded
	for m: GeometryInstance3D in _meshes:
		m.transparency = 0.55 if faded else 0.0


## ST-16: hóa ếch — giấu nhân vật, hiện ảnh ếch đứng (thiếu ảnh thì UnitsView vẽ ếch tạm dưới đất).
func _show_frog(hexed: bool) -> bool:
	if hexed and _frog == null and ArtLibrary.texture(&"hex_frog") != null:
		_frog = Sprite3D.new()
		_frog.texture = ArtLibrary.texture(&"hex_frog")
		_frog.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_frog.shaded = false
		_frog.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_frog.pixel_size = height * 0.6 / _frog.texture.get_height()
		_frog.offset = Vector2(0, _frog.texture.get_height() * 0.5)
		add_child(_frog)
	_model.visible = not hexed
	if _frog != null:
		_frog.visible = hexed
	return hexed


## D-159: mỗi đòn mới phát lại từ đầu; lúc vung tay chạy sao cho điểm chém (`impact`) trúng đúng tick ra
## đòn của SIM, sau đó phần thu tay kéo dài hết thời gian hồi.
func _play_attack(w: World, e: Entity) -> void:
	var name: String = _cfg["attack"]
	var length: float = _anim.get_animation(name).length
	var impact: float = _cfg.get("impact", IMPACT)
	if e.attack_start_tick != _attack_tick:
		_attack_tick = e.attack_start_tick
		var windup: float = maxf(1.0, e.attack_release_tick - e.attack_start_tick) * SimClock.TICK_SECONDS
		_play(name, clampf(length * impact / windup, 0.6, 4.0), true)
	elif e.attack_phase == Entity.AttackPhase.RECOVERY and _attack_phase != Entity.AttackPhase.RECOVERY:
		var rest: float = maxf(1.0, e.next_attack_tick - w.tick) * SimClock.TICK_SECONDS
		_play(name, clampf(length * (1.0 - impact) / rest, 0.6, 4.0))


## Tốc độ phát đặt qua speed_scale (`_speed`) để đổi giữa chừng và khựng khung được.
func _play(name: String, speed: float, restart: bool = false) -> void:
	_speed = speed
	if name == _playing and not restart:
		return
	_anim.play(name, BLEND)
	if restart:
		_anim.seek(0.0, true)
	_playing = name
