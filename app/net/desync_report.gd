class_name DesyncReport
extends RefCounted
## NET-20 (D-402): báo cáo lệch trận online (kiểu `sync`, như D-336) — máy chủ báo `desync` thì máy này gửi mã phòng, tick
## lệch, chuỗi mã băm đã gửi và mã băm từng đơn vị lúc gửi; đọc lại qua /api/reports/<S-…> để tìm đơn vị lệch đầu tiên.


static func build(lock: LockstepClient, room_code: String) -> Dictionary:
	var units: Dictionary = {}
	for e: Entity in lock.world.entities:
		units[str(e.id)] = lock.world.entity_digest(e).hex_encode()
	var hashes: Dictionary = {}
	for t: int in lock.hashes:
		hashes[str(t)] = lock.hashes[t]
	var meta: Dictionary = {"online": true, "room": room_code, "desync_tick": lock.desync_tick, "tick": lock.world.tick,
		"version": Updater.current_name(), "fingerprint": NetVersion.fingerprint(), "device": OS.get_model_name(),
		"os": OS.get_name() + " " + OS.get_version(), "arch": Engine.get_architecture_name()}
	return {"summary": "Lệch trận online · phòng %s · tick %d · %s · %s" % [room_code, lock.desync_tick, meta["version"],
		meta["device"]], "data": {"meta": meta, "hashes": hashes, "units": units}}
