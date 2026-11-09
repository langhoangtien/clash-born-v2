class_name Wading3D
extends MultiMeshInstance3D
## D-313: lội sông (chỉ VIEW) — người chơi: "đi trên sông như đi trên băng". Đơn vị đứng trong nước (kênh A ảnh nước
## decor.py: mặt nước theo bờ cong) lún xuống tới bắp chân (mặt nước đục che chân) và có vòng gợn nước lan ra quanh chân.
## Vòng gợn: MultiMesh các tấm phẳng sát mặt nước, shader vòng tròn lan + mờ dần theo pha riêng từng đơn vị.

const SINK: float = 0.24          ## lún sâu nhất (m), ở chỗ nước đã cách bờ
const RIPPLE_SIZE: float = 1.6    ## cạnh tấm gợn (m)
const MAX_RIPPLES: int = 48
const SHADER: Shader = preload("res://view/three/ripple.gdshader")


func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	var quad: PlaneMesh = PlaneMesh.new()
	quad.size = Vector2.ONE * RIPPLE_SIZE
	multimesh.mesh = quad
	multimesh.instance_count = MAX_RIPPLES
	multimesh.visible_instance_count = 0
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SHADER
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Mỗi khung (MatchView3D): lớp lội nước là con của mặt nước (Terrain3D.water); không có nước thì bỏ qua.
static func update_in(water: Node, actors: Dictionary[int, Actor3D]) -> void:
	if water != null and water.get_child_count() > 0:
		(water.get_child(0) as Wading3D).update(actors)


## Sau khi đặt vị trí các hình đơn vị: hạ hình trong nước, đặt vòng gợn dưới chân (id lẻ / chẵn lệch pha).
func update(actors: Dictionary[int, Actor3D]) -> void:
	var n: int = 0
	for id: int in actors:
		var a: Actor3D = actors[id]
		if not a.visible:
			continue
		var wet: float = wetness(Vector2(a.position.x, a.position.z) / MatchView3D.S)
		if wet <= 0.0:
			continue
		a.position.y -= SINK * wet
		if n < MAX_RIPPLES:
			multimesh.set_instance_transform(n, Transform3D(Basis(), Vector3(a.position.x, Terrain3D.WATER_Y + 0.01, a.position.z)))
			multimesh.set_instance_custom_data(n, Color(fmod(float(id) * 0.37, 1.0), wet, 0, 0))
			n += 1
	multimesh.visible_instance_count = n


## 0 trên cạn → 1 khi đã xuống nước hẳn (theo kênh A ảnh nước: 0,5 là mép bờ).
static func wetness(p: Vector2) -> float:
	var img: Image = Terrain3D.depth_image()
	var r: Rect2 = Terrain3D.mask_rect()
	var uv: Vector2 = (p - r.position) / r.size * Vector2(img.get_size())
	if not Rect2(Vector2.ZERO, Vector2(img.get_size())).has_point(uv):
		return 0.0
	return smoothstep(0.5, 0.75, img.get_pixelv(Vector2i(uv)).a)
