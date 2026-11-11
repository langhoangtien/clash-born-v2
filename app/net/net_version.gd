class_name NetVersion
extends RefCounted
## NET-10 (D-338): dấu vân tay SIM để bắt tay — mã băm World của trận cố định (SyncCheck) sau TICKS tick, kèm số hiệu
## giao thức. Khác code / nội dung SIM giữa máy khách và máy chủ → khác dấu → không vào phòng (lockstep sẽ lệch).
## Tính một lần (~0,5–1 s trên điện thoại), nhớ lại.

const PROTOCOL: int = 2  ## D-345: điểm "không có" = null trên dây
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
		_cached = "%d-%s" % [PROTOCOL, ctx.finish().hex_encode().left(16)]
	return _cached


## D-344: mọi số trong BalanceSettings (theo tên, thứ tự cố định) — trận 3 giây của SyncCheck không chạm tới hết (vd vàng
## Hạ gục đầu tiên D-340), máy chủ cũ vẫn khớp dấu rồi lệch giữa trận.
static func balance_text(b: BalanceSettings) -> String:
	var parts: PackedStringArray = []
	for p: Dictionary in b.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			parts.append("%s=%s" % [p["name"], var_to_str(b.get(p["name"]))])
	parts.sort()
	return ";".join(parts)
