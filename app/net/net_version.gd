class_name NetVersion
extends RefCounted
## NET-10 (D-338): dấu vân tay SIM để bắt tay — mã băm World của trận cố định (SyncCheck) sau TICKS tick, kèm số hiệu
## giao thức. Khác code / nội dung SIM giữa máy khách và máy chủ → khác dấu → không vào phòng (lockstep sẽ lệch).
## Tính một lần (~0,5–1 s trên điện thoại), nhớ lại.

const PROTOCOL: int = 1
const TICKS: int = 90

static var _cached: String = ""


static func fingerprint() -> String:
	if _cached == "":
		var s: SyncCheck = SyncCheck.new(TICKS / SimClock.TICKS_PER_SECOND)
		while not s.done():
			s.advance(TICKS)
		_cached = "%d-%s" % [PROTOCOL, s.world.state_hash().hex_encode().left(16)]
	return _cached
