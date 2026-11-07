class_name ShaderWarmup
extends Node3D
## D-260: "làm nóng" shader lúc vào trận. Vulkan biên dịch đường vẽ (pipeline) lần đầu một vật liệu lên màn hình →
## khung đó khựng (người chơi: 50 → 11 fps). Trong màn "Đang tải…" đặt trước camera một bản của mọi mô hình đơn vị
## (mỗi phe, kèm bản mờ trong bụi), công trình, đạn và mọi mảnh hiệu ứng chiêu trong vfx.json, vẽ FRAMES khung rồi gỡ.
## Chỉ là hình — APP không chạy SIM cho tới khi xong.

const FRAMES: int = 4  ## số khung vẽ thử (vài khung để chắc mọi đường vẽ đã được dựng)
const STEP: float = 0.6  ## khoảng cách lưới (đơn vị 3D) giữa các vật vẽ thử
const COLS: int = 12

var done: bool = false
## D-271: có vẽ thử đống đổ nát trụ.
var has_rubble: bool = false
var _frames: int = 0
var _count: int = 0


## Tạo và đặt quanh điểm camera đang nhìn (`focus`, đơn vị 3D); APP gọi step() mỗi khung.
static func make(projectiles: Projectiles3D, focus: Vector3) -> ShaderWarmup:
	var w: ShaderWarmup = ShaderWarmup.new()
	w.position = focus
	for e: Entity in sample_entities():
		var a: Actor3D = Actor3D.make(e)
		w._place(a)
		a.prime_flash()  # D-271: lớp lóe khi trúng đòn
		if a._anim != null:
			var faded: Actor3D = Actor3D.make(e)
			w._place(faded)
			faded._set_faded(true)  # bản mờ (bụi, tàng hình phe mình)
			faded.prime_flash()
	for cfg: Dictionary in ModelLibrary.config()["units"].values():
		if cfg.has("projectile"):
			w._projectile(projectiles, cfg["projectile"])
	w._projectile(projectiles, ModelLibrary.config().get("projectiles", {}).get("default", {}))
	w._rubble()
	for recipe: Dictionary in SkillVfx3D.recipes().values().filter(func(r: Variant) -> bool: return r is Dictionary):
		for part: Dictionary in recipe.get("parts", []):
			w._vfx(part)
	return w


## Mỗi loại đơn vị theo các phe nó có thể thuộc, mỗi bậc trụ và nhà chính theo hai phe.
static func sample_entities() -> Array[Entity]:
	var out: Array[Entity] = []
	for art: String in ModelLibrary.config()["units"].keys():
		var neutral: bool = art.begins_with("neutral_")
		for team: int in ([2] if neutral else [0, 1]):
			out.append(_entity(StringName(art), Entity.Kind.NEUTRAL if neutral else Entity.Kind.HERO, team, 0))
	for key: String in ModelLibrary.config().get("structures", {}).keys():
		var tower: bool = key.begins_with("tower_t")
		for team: int in [0, 1]:
			out.append(_entity(&"tower" if tower else StringName(key), Entity.Kind.TOWER if tower else Entity.Kind.CORE, team,
				int(key.trim_prefix("tower_t")) if tower else 0))
	return out


static func _entity(art: StringName, kind: Entity.Kind, team: int, tier: int) -> Entity:
	var e: Entity = Entity.new()
	e.art_id = art
	e.kind = kind
	e.team = team
	e.tier = tier
	return e


## Số vật đang vẽ thử (cho test / chẩn đoán).
func count() -> int:
	return _count


func step() -> void:
	_frames += 1
	if _frames >= FRAMES and not done:
		done = true
		queue_free()


func _place(n: Node3D) -> void:
	n.position = Vector3((_count % COLS - COLS * 0.5) * STEP, 0.0, (_count / COLS - 2) * STEP)
	add_child(n)
	_count += 1


## D-271: đống đổ nát khi trụ đổ (Scenery3D) — nạp GLB + dựng shader từ màn tải.
func _rubble() -> void:
	var cfg: Dictionary = ModelLibrary.scenery().get("rubble", {})
	if cfg.is_empty():
		return
	var n: Node3D = ModelLibrary.static_scene(cfg["model"]).instantiate() as Node3D
	ModelLibrary.apply_team_texture(n, cfg["model"], -1)
	ModelLibrary.use_vertex_colors_in(n)
	_place(n)
	has_rubble = true


func _projectile(projectiles: Projectiles3D, cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	for team: int in [0, 1]:
		if cfg.has("model"):
			var n: Node3D = ModelLibrary.static_scene(cfg["model"], team).instantiate() as Node3D
			ModelLibrary.apply_team_texture(n, cfg["model"], team)
			_place(n)
		else:
			_place(projectiles._primitive(cfg.get("shape", "orb"), Color.WHITE))


func _vfx(part: Dictionary) -> void:
	match part["type"]:
		"arc":
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = QuadMesh.new()
			mi.material_override = SkillVfx3D._tint_material(part)
			_place(mi)
		"hit":
			_place(VfxParts.make(SkillVfx3D.soft_hit(part), 0.5))
		_ when VfxParts.is_soft(part["type"]):  # D-296: mảnh dịu (một shader, mỗi loại hình một lần)
			var size: Variant = Vector2(0.4, 0.8) if part["type"] in ["shot", "wave"] else 0.3
			_place(VfxParts.make(part, size))
		"trail":
			var t: SpeedTrail3D = SpeedTrail3D.make(part, SkillVfx3D._tint_material(part))
			_place(t)
			t.position = Vector3.ZERO
			for k: int in 3:  # dựng dải + bật hạt để đường vẽ của chúng được biên dịch
				t.update(global_position + Vector3(k * 0.3, 0, 0) if is_inside_tree() else Vector3(k * 0.3, 0, 0), true, 0.05)
