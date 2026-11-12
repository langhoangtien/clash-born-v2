class_name SimSource
extends RefCounted
## NET-10 (D-403): mã băm MÃ NGUỒN SIM cho dấu vân tay. APK không còn file .gd nguyên văn (Godot xuất script thành token
## nhị phân) nên không tính lúc chạy được: mã băm tính từ mã nguồn rồi ghi vào FILE (được đóng gói cả APK lẫn máy chủ);
## test `test_NET_10_sim_source_file_is_current` đỏ khi FILE cũ → chạy lại `tools/vps/sim_source.gd`. Băm: mọi file
## .gd / .tres / .json trong ROOTS + FILES theo đường dẫn tăng dần, bỏ \r (máy Windows checkout CRLF vẫn ra cùng số).

const FILE: String = "res://app/net/sim_source.json"
const ROOTS: Array[String] = ["res://sim", "res://content", "res://data/maps"]
const FILES: Array[String] = ["res://app/net/net_codec.gd"]
const EXTS: Array[String] = ["gd", "tres", "json"]


## Tính từ mã nguồn (máy dev / test — không dùng trong APK).
static func compute() -> String:
	var paths: Array[String] = FILES.duplicate()
	for r: String in ROOTS:
		_walk(r, paths)
	paths.sort()
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for p: String in paths:
		ctx.update((p + "\n").to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_string(p).replace("\r", "").to_utf8_buffer())
	return ctx.finish().hex_encode().left(16)


## Số đã ghi (APK, máy chủ — mọi nơi tính dấu vân tay).
static func recorded() -> String:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return String(d.get("hash", "")) if d is Dictionary else ""


static func _walk(dir: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() in EXTS:
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(d), out)
