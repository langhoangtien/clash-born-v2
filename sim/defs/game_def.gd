class_name GameDef
extends Resource
## Lớp cha của mọi dữ liệu có id trong content/ (hero, kỹ năng, hiệu ứng, đồ, đơn vị).
## Quy ước cho mọi Def: trường `String` là **biểu thức** (EFF-09) — trừ trường chữ
## hiển thị trong TEXT_FIELDS; tên/id dùng `StringName`.

const TEXT_FIELDS: PackedStringArray = ["display_name", "description"]

@export var id: StringName
@export var display_name: String
## Id hình ảnh tra qua ArtLibrary (ART.md); không chứa đường dẫn file.
@export var art_id: StringName
