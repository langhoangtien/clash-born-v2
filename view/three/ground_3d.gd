class_name Ground3D
extends MeshInstance3D
## Mặt đất bản 3D (D-145, D-155): một mặt phẳng phủ vùng camera thấy, shader ghép ba lớp:
##   1. bản đồ tĩnh — ảnh nướng một lần (MapBaker) gộp thành một ảnh có mipmap, không vẽ lại;
##   2. sương — FogView vẽ vào SubViewport nhỏ (FOG_SCALE), sương mềm nên không cần nét;
##   3. lớp động — vùng chiêu, mũi nhắm, bóng / vòng chân, hiệu ứng (UnitsView, AimIndicator…) vẽ
##      vào SubViewport trong suốt LAYER_SCALE.
## Trước khi nướng xong, bản đồ gốc vẽ trong lớp động (phủ kín) như bản cũ.

## Điểm ảnh mỗi px thế giới: lớp động (khớp MapBaker), sương.
const LAYER_SCALE: float = 0.5
const FOG_SCALE: float = 0.125
const SHADER: Shader = preload("res://view/three/ground.gdshader")

var layer: SubViewport
var fog_layer: SubViewport
## Vùng phủ so với điểm nhìn (px thế giới).
var rect: Rect2 = Rect2()
var _layer_cam: Camera2D
var _fog_cam: Camera2D
var _material: ShaderMaterial


## Đưa `fog` vào lớp sương, các node 2D khác vào lớp động; `map` nướng xong thì lấy ảnh bản đồ.
func setup(map: MapView, fog: FogView, others: Array[Node]) -> void:
	mesh = PlaneMesh.new()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer = _viewport()
	_layer_cam = _camera(layer, LAYER_SCALE)
	fog_layer = _viewport()
	_fog_cam = _camera(fog_layer, FOG_SCALE)
	fog.reparent(fog_layer, false)
	for n: Node in others:
		n.reparent(layer, false)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("overlay", layer.get_texture())
	_material.set_shader_parameter("fog", fog_layer.get_texture())
	_material.set_shader_parameter("detail", Look3D.detail_texture())
	_material.set_shader_parameter("map_size", map.layout.world_size() * MatchView3D.S)
	material_override = _material
	if map.baker != null:
		map.baker.baked.connect(_use_baked.bind(map))


## Cỡ vùng phủ (px thế giới, so với điểm nhìn) — gọi khi đổi cỡ màn hình.
func fit(area: Rect2) -> void:
	rect = area
	(mesh as PlaneMesh).size = rect.size * MatchView3D.S
	layer.size = Vector2i(ceili(rect.size.x * LAYER_SCALE), ceili(rect.size.y * LAYER_SCALE))
	fog_layer.size = Vector2i(ceili(rect.size.x * FOG_SCALE), ceili(rect.size.y * FOG_SCALE))


## Mỗi khung: theo điểm nhìn `focus` (px thế giới).
func follow(focus: Vector2) -> void:
	var center: Vector2 = focus + rect.get_center()
	_layer_cam.position = center
	_fog_cam.position = center
	position = Vector3(center.x, 0.0, center.y) * MatchView3D.S


## D-155: gộp các ô ảnh đã nướng thành một ảnh có mipmap (đỡ nhòe, đỡ băng thông khi nhìn xiên);
## ô 2D và lớp bản đồ gốc thôi vẽ.
func _use_baked(map: MapView) -> void:
	var tiles: Array[Sprite2D] = map.baker.tiles
	var size: Vector2i = Vector2i((map.layout.world_size() * MapBaker.SCALE).ceil())
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for t: Sprite2D in tiles:
		var part: Image = t.texture.get_image()
		part.convert(Image.FORMAT_RGBA8)
		img.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i((t.position * MapBaker.SCALE).round()))
	img.generate_mipmaps()
	_material.set_shader_parameter("map_tex", ImageTexture.create_from_image(img))
	_material.set_shader_parameter("has_map", true)
	for t: Sprite2D in tiles:
		t.queue_free()
	tiles.clear()


func _viewport() -> SubViewport:
	var vp: SubViewport = SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


func _camera(vp: SubViewport, scale: float) -> Camera2D:
	var cam: Camera2D = Camera2D.new()
	cam.zoom = Vector2.ONE * scale
	vp.add_child(cam)
	return cam
