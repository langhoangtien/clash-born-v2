class_name MapShape
extends RefCounted
## Một vùng địa hình (rừng, vách, nước): đường bao ngoài và các lỗ bên trong.

var outer: PackedVector2Array = PackedVector2Array()
var holes: Array[PackedVector2Array] = []
