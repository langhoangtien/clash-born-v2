class_name MatchRecord
extends RefCounted
## ST.1 (D-331): biên bản trận cho Clashborn Stats — dữ liệu thuần đọc từ World + MatchConfig lúc trận xong. Game gửi
## lên máy chủ (`POST /api/match`); máy chủ trận online (M9) dùng lại. Không có thông tin cá nhân (tên máy, IP…).
## Lịch sử mua lấy từ nhật ký lệnh (CMD-04: lệnh BUY chỉ được ghi khi đã qua kiểm tra — mua thật).

const SCHEMA: int = 1


static func of(world: World, config: MatchConfig, version: String) -> Dictionary:
	var heroes: Array[Entity] = []
	for e: Entity in world.entities:  # theo id = theo thứ tự ô (MATCH-01)
		if e.kind == Entity.Kind.HERO and e.hero_def != null:
			heroes.append(e)
	var players: Array[Dictionary] = []
	for i: int in heroes.size():
		var slot: MatchSlot = config.slots[i] if i < config.slots.size() else null
		players.append(_player(world, heroes[i], slot))
	return {"schema": SCHEMA, "version": version, "mode": "%dv%d" % [config.team_size, config.team_size],
		"kind": kind_of(config), "duration_s": world.tick * SimClock.TICK_SECONDS, "winner": world.winner,
		"seed": config.seed, "practice": config.practice, "players": players}


## ST (D-331): pvp = cả hai đội có người; pvb = có người nhưng không đủ hai đội; bvb = toàn bot.
static func kind_of(config: MatchConfig) -> String:
	var humans: Array[bool] = [false, false]
	for s: MatchSlot in config.slots:
		if not s.is_bot:
			humans[clampi(s.team, 0, 1)] = true
	if humans[0] and humans[1]:
		return "pvp"
	return "pvb" if humans[0] or humans[1] else "bvb"


static func _player(world: World, e: Entity, slot: MatchSlot) -> Dictionary:
	var items: Array[String] = []
	for it: ItemInstance in e.items:
		if it != null:
			items.append(String(it.def.id))
	var buys: Array = []
	for c: Command in world.command_log:
		if c.type == Command.Type.BUY and c.entity_id == e.id:
			buys.append([c.tick * SimClock.TICK_SECONDS, String(c.item_id)])
	return {"hero": String(e.hero_def.id), "team": e.team, "slot": slot.index if slot != null else 0,
		"bot": e.bot != null, "won": world.winner == e.team, "kills": e.kills, "deaths": e.deaths, "assists": e.assists,
		"level": e.stats.level(), "gold": e.gold, "last_hits": e.last_hits, "items": items, "buys": buys}
