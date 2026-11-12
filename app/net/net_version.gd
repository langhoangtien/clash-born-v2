class_name NetVersion
extends RefCounted
## NET-10 (D-338): dấu vân tay SIM để bắt tay — mã băm World của trận cố định (SyncCheck) sau TICKS tick, kèm số hiệu
## giao thức. Khác code / nội dung SIM giữa máy khách và máy chủ → khác dấu → không vào phòng (lockstep sẽ lệch).
## Tính một lần (~0,5–1 s trên điện thoại), nhớ lại.

const PROTOCOL: int = 3  ## D-401: probe trước bắt tay, mã phòng 6 chữ số, BUSY (D-345: 2 — điểm "không có" = null)
const TICKS: int = 90

static var _cached: String = ""


static func fingerprint() -> String:
	if _cached == "":
		var s: SyncCheck = SyncCheck.new(TICKS / SimClock.TICKS_PER_SECOND)
		while not s.done():
			s.advance(TICKS)
		var ctx: HashingContext = HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(s.world.state_hash())
		ctx.update(balance_text(s.world.balance).to_utf8_buffer())  # D-344: số cân bằng khác → khác dấu
		ctx.update(content_text(ContentLibrary.load_dir()).to_utf8_buffer())  # D-347: tướng / chiêu / đồ khác → khác dấu
		_cached = "%d-%s" % [PROTOCOL, ctx.finish().hex_encode().left(16)]
	return _cached


## D-344: mọi số trong BalanceSettings (theo tên, thứ tự cố định) — trận 3 giây của SyncCheck không chạm tới hết (vd vàng
## Hạ gục đầu tiên D-340), máy chủ cũ vẫn khớp dấu rồi lệch giữa trận.
static func balance_text(b: BalanceSettings) -> String:
	return resource_text(b)


## D-347: mọi dữ liệu nội dung (tướng, chiêu, hiệu ứng, đồ, đơn vị, trại) theo id — đọc giá trị đã nạp, không đọc file
## (bản xuất APK đổi .tres sang nhị phân, máy chủ chạy mã nguồn: file khác nhau dù nội dung giống).
static func content_text(lib: ContentLibrary) -> String:
	var parts: PackedStringArray = []
	for group: Dictionary in [lib.heroes, lib.abilities, lib.effects, lib.items, lib.units, lib.camps]:
		for id: StringName in _by_text(group.keys()):
			parts.append("%s{%s}" % [id, resource_text(group[id])])
	return "\n".join(parts)


## Giá trị mọi biến script của một resource (theo tên, thứ tự cố định); resource con lồng vào, resource có id chỉ ghi id
## (đã có mục riêng) — không lặp vô tận.
static func resource_text(r: Resource, depth: int = 0) -> String:
	var parts: PackedStringArray = []
	for p: Dictionary in r.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			parts.append("%s=%s" % [p["name"], _value_text(r.get(p["name"]), depth)])
	parts.sort()
	return ";".join(parts)


static func _value_text(v: Variant, depth: int) -> String:
	if v is Resource:
		var id: Variant = (v as Resource).get("id")
		if depth > 0 and id is StringName and id != &"":
			return "@" + String(id)
		return "{" + resource_text(v, depth + 1) + "}" if depth < 8 else "…"
	if v is Array:
		return "[" + ",".join(PackedStringArray((v as Array).map(func(x: Variant) -> String: return _value_text(x, depth)))) + "]"
	if v is Dictionary:
		return "{" + ",".join(PackedStringArray(_by_text((v as Dictionary).keys()).map(func(k: Variant) -> String: return "%s:%s" % [k, _value_text(v[k], depth)]))) + "}"
	return var_to_str(v)


## D-400: xếp tên theo chữ. `Array.sort()` trên StringName so địa chỉ bộ nhớ → thứ tự đổi theo lần chạy / máy, dấu vân
## tay cùng một bản game ra khác nhau (máy khách bị VERSION oan).
static func _by_text(names: Array) -> Array:
	var out: Array = names.duplicate()
	out.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	return out
