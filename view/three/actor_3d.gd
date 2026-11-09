class_name Actor3D
extends Node3D
## Một đơn vị trong trận 3D (D-145, D-146): mô hình tự mang xương + hoạt ảnh (D-321: gỡ KayKit), hoạt ảnh theo trạng thái SIM.
## Công trình: mô hình tĩnh (D-158). Đơn vị khác: ảnh đứng quay về camera. Chỉ đọc World.
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
var _frog: HexFrog3D
var _meshes: Array[GeometryInstance3D] = []
## D-161: vật liệu đặc của từng bề mặt (theo _meshes), để trả lại sau khi hết mờ.
var _solid: Array[Array] = []
var _base: Array[Array] = []  ## D-322: vật liệu gốc (EffectLook đổi ảnh màu theo hiệu ứng)
var _look: Dictionary = {}
var _faded: bool = false
var _playing: String = ""
var _rate: AnimRate  # D-277: lính / quái 30 lần / giây; null = hero (mỗi khung)
var _attack_tick: int = -1
var _swing: int = -1  # D-249: số đòn đã đánh (chọn hoạt ảnh luân phiên)
var _attack_phase: int = Entity.AttackPhase.NONE
## Mốc thời gian thật (giây, Time) cho khóa hoạt ảnh chiêu, khựng khung, lóe, giật lùi.
var _skill_from: float = -1.0
var _skill_until: float = -1.0
var _freeze_until: float = -1.0
var _flash_until: float = -1.0
var _lean: float = 0.0
var _overlay: StandardMaterial3D
var _tint: Color = Color(0, 0, 0, 0)  # D-305: màu phủ của hiệu ứng (băng), dùng chung lớp lóe
var _speed: float = 1.0
var _stunned: bool = false  # D-230


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
	model.scale = Vector3.ONE * (height / float(_rig.get("native", ModelLibrary.bounds(model).size.y)))
	model.rotation.y = deg_to_rad(cfg.get("yaw", 0.0))
	_anim = model.find_children("*", "AnimationPlayer", true, false)[0]  # D-173: mô hình tự mang xương + hoạt ảnh
	ModelLibrary.dress_own(model, cfg, e.team)  # D-209 màu phe
	for n: Node in model.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(n as GeometryInstance3D)
		var mats: Array = []
		if n is MeshInstance3D:
			for k: int in (n as MeshInstance3D).mesh.get_surface_count():
				mats.append((n as MeshInstance3D).get_active_material(k))
		_solid.append(mats)
		_base.append(mats.duplicate())
	for anim: String in [_rig["idle"], _rig["run"], _rig.get("stun", ""), _cfg.get("sprint", _rig.get("sprint", "")), _cfg.get("stealth", "")].filter(_anim.has_animation):
		_anim.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	if e.kind != Entity.Kind.HERO:
		_rate = AnimRate.attach(_anim, e.id)


## Đổi bảng màu mọi lưới trong `root` sang bản theo đội (vũ khí giữ màu gốc).
## D-158: công trình là mô hình tĩnh theo đội, cỡ theo chiều cao trong cấu hình.
func _make_structure(e: Entity, cfg: Dictionary) -> void:
	_model = ModelLibrary.static_scene(cfg["model"], e.team).instantiate() as Node3D
	ModelLibrary.apply_team_texture(_model, cfg["model"], e.team)  # D-167
	ModelLibrary.use_vertex_colors_in(_model)
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
	if _rate != null:  # D-277: lính / quái chạy hoạt ảnh 30 lần / giây
		_rate.tick(get_process_delta_time(), Engine.get_process_frames())
	if _sprite != null:
		_sprite.flip_h = e.facing.x < 0.0
		_sprite.modulate = Color(1, 0.55, 0.5) if hit_age >= 0 and hit_age < UnitSprite.HIT_TICKS else Color.WHITE
		_sprite.modulate.a = 0.45 if faded else 1.0
		return
	_set_faded(faded)
	if _show_frog(Rules.has_state(e, UnitState.Id.HEXED)):
		return
	if e.facing != Vector2.ZERO: rotation.y = atan2(e.facing.x, e.facing.y)
	_tint = EffectVfx3D.tint_of(e)
	var look: Dictionary = EffectLook.of(_cfg, e)
	if look.get("skin", "") != _look.get("skin", ""):
		EffectLook.apply_skin(_meshes, _base, _solid, look.get("skin", ""), _cfg.get("skin_of", ""), _faded)
	_look = look
	_feel()
	_stunned = e.cast == null and not Rules.can_move(e) and not Rules.can_attack(e)
	if e.reincarnate_tick >= 0:  # DTH-02: nằm chờ tái sinh — ngã rồi nằm yên ở khung cuối
		if _playing != _rig["death"]:
			_play(_rig["death"], 1.0)
	elif e.dash != null:  # D-229: lao tới trước cả hoạt ảnh chiêu; D-238: hoạt ảnh vừa hết lúc tới nơi
		_play(_cfg.get("dash", _rig["dash"]), ModelLibrary.dash_speed(w, e, _anim, _cfg.get("dash", _rig["dash"])))
		position.y += ModelLibrary.dash_hop(_cfg, _anim)  # D-243: nhảy vòng cung
	elif _skill_locked(moving):
		pass
	elif e.cast != null:
		_play(_cfg.get("cast", _cfg["attack"]), 1.5)
	elif _attack_shown(e, moving):
		_play_attack(w, e)
	elif hit_age == 0 and not moving and _playing == _rig["idle"]:
		_play(_rig["hit"], 1.0, true)
	elif _playing == _rig["hit"] and _anim.is_playing():
		pass
	else:
		var stun: String = _rig.get("stun", "") if not Rules.can_move(e) and not Rules.can_attack(e) else ""  # ST-01
		_play(ModelLibrary.run_anim(_cfg, _rig, _anim, e) if moving else (stun if _anim.has_animation(stun) else _rig["idle"]), 1.0)
	_attack_phase = e.attack_phase


## CMB-06, D-208: thu tay bị di chuyển hủy — đang đi thì chạy; D-216: không đánh được (choáng…) thì thôi đòn.
func _attack_shown(e: Entity, moving: bool) -> bool:
	var still: bool = Rules.can_attack(e) and e.attack_phase == Entity.AttackPhase.RECOVERY and not moving  # D-216
	return e.attack_phase == Entity.AttackPhase.WINDUP or (still and (_playing == _cfg["attack"] or _attack_phase != e.attack_phase))


## D-159: phát hoạt ảnh riêng của chiêu `slot`; D-230: có thời gian vung (ABL-03) thì điểm trúng rơi đúng lúc nổ.
func on_cast(slot: int, windup: float = 0.0) -> void:
	var name: String = _cfg.get("skills", {}).get(str(slot), "") if _anim != null else ""
	if name.is_empty() or not _anim.has_animation(name):
		return
	var length: float = _anim.get_animation(name).length
	var speed: float = ModelLibrary.skill_speed(_cfg, slot, length, windup, SKILL_SPEED)
	_play(name, speed, true)
	_skill_from = _now()
	_skill_until = _skill_from + minf(length / speed, maxf(SKILL_LOCK_MAX, windup + 0.4))


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
	if t >= _skill_until or _stunned:  # D-230: bị choáng giữa lúc vung chiêu → chiêu mất (ABL-03), thôi hoạt ảnh
		_skill_until = -1.0
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
	if flash > 0.0 or _tint.a > 0.0 or (_overlay != null and _overlay.albedo_color.a > 0.0):
		_ensure_overlay()  # D-305: lóe đè lên màu băng khi mạnh hơn
		_overlay.albedo_color = Color(FLASH_COLOR, flash * FLASH_ALPHA) if flash * FLASH_ALPHA > _tint.a else _tint


## Lớp lóe trắng phủ lên mô hình (cộng sáng); D-271: màn làm nóng gắn sẵn để Vulkan dựng pipeline từ trước.
func _ensure_overlay() -> void:
	if _overlay != null:
		return
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for m: GeometryInstance3D in _meshes:
		m.material_overlay = _overlay


## D-271: gắn lớp lóe với độ sáng nhỏ (chỉ để vẽ thử ở màn làm nóng).
func prime_flash() -> void:
	if _anim == null:
		return
	_ensure_overlay()
	_overlay.albedo_color = Color(FLASH_COLOR, 0.05)


func has_flash_overlay() -> bool:
	return _overlay != null


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _set_faded(faded: bool) -> void:
	if faded == _faded:
		return
	_faded = faded
	for i: int in _meshes.size():  # D-161: đổi vật liệu (Compatibility bỏ qua transparency)
		var mi: MeshInstance3D = _meshes[i] as MeshInstance3D
		if mi == null:
			continue
		for k: int in mi.mesh.get_surface_count():
			var solid: Material = _solid[i][k]
			mi.set_surface_override_material(k, ModelLibrary.faded_material(solid) if faded else solid)


## ST-16: hóa ếch — giấu nhân vật, hiện ếch 3D nhảy tưng (D-299, HexFrog3D); thiếu mô hình thì UnitsView vẽ ếch tạm.
func _show_frog(hexed: bool) -> bool:
	if hexed and _frog == null:
		_frog = HexFrog3D.make(height)
		if _frog != null:
			add_child(_frog)
	_model.visible = not hexed
	if _frog != null:
		_frog.visible = hexed
	return hexed


## D-159: mỗi đòn mới phát lại từ đầu; lúc vung tay chạy sao cho điểm chém (`impact`) trúng đúng tick ra
## đòn của SIM, sau đó phần thu tay kéo dài hết thời gian hồi.
func _play_attack(w: World, e: Entity) -> void:
	var fresh: bool = e.attack_start_tick != _attack_tick
	if fresh:
		_attack_tick = e.attack_start_tick
		_swing += 1
	var pick: Array = ModelLibrary.attack_pick(_cfg.merged(_look, true), _swing, IMPACT)  # D-249; D-322 đòn theo hiệu ứng
	var length: float = _anim.get_animation(pick[0]).length
	if fresh:
		var windup: float = maxf(1.0, e.attack_release_tick - e.attack_start_tick) * SimClock.TICK_SECONDS
		_play(pick[0], clampf(length * pick[1] / windup, 0.6, 4.0), true)
	elif e.attack_phase == Entity.AttackPhase.RECOVERY and _attack_phase != Entity.AttackPhase.RECOVERY:
		var rest: float = maxf(1.0, e.next_attack_tick - w.tick) * SimClock.TICK_SECONDS
		_play(pick[0], clampf(length * (1.0 - pick[1]) / rest, 0.6, 4.0))


## Tốc độ phát đặt qua speed_scale (`_speed`) để đổi giữa chừng và khựng khung được.
func _play(name: String, speed: float, restart: bool = false) -> void:
	_speed = speed
	if name == _playing and not restart:
		return
	_anim.play(name, BLEND)
	if restart:
		_anim.seek(0.0, true)
	_playing = name

