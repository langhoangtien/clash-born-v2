class_name HexFrog3D
extends Node3D
## D-299: hóa ếch (ST-16) — mô hình ếch 3D (Tripo, assets/models/style/fx/hex_frog.glb) thay ảnh phẳng; không xương,
## nhảy tưng bằng code: bật lên rồi rơi, nhún dẹt khi chạm đất. Chỉ là hình.

const MODEL: String = "res://assets/models/style/fx/hex_frog.glb"
## Ếch cao bằng phần này của hình đơn vị; nhịp nhảy (lần / giây), độ cao nhảy (phần chiều cao ếch) — hằng số hiển thị.
const SIZE: float = 0.45
const HOPS: float = 1.6
const HOP: float = 0.35

var _body: Node3D
var _h: float = 1.0
var _t: float = 0.0


## Ếch cho đơn vị cao `unit_height` (m); null nếu thiếu mô hình.
static func make(unit_height: float) -> HexFrog3D:
	if not ResourceLoader.exists(MODEL):
		return null
	var f: HexFrog3D = HexFrog3D.new()
	f._body = (load(MODEL) as PackedScene).instantiate() as Node3D
	var box: AABB = ModelLibrary.bounds(f._body)
	f._h = unit_height * SIZE
	f._body.scale = Vector3.ONE * (f._h / maxf(0.01, box.size.y))
	f._body.position.y = -box.position.y * f._body.scale.y
	f.add_child(f._body)
	return f


func _process(delta: float) -> void:
	_t += delta * HOPS
	var phase: float = fmod(_t, 1.0)
	var up: float = sin(phase * PI)
	position.y = up * HOP * _h
	var squash: float = 1.0 - 0.18 * (1.0 - smoothstep(0.0, 0.15, phase)) - 0.12 * smoothstep(0.85, 1.0, phase)
	scale = Vector3(2.0 - squash, squash, 2.0 - squash)
