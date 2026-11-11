class_name RoomLobby
extends RefCounted
## NET-07..09 (D-338, M9.5): một phòng chờ ở máy chủ — mã phòng, chủ phòng, ai ở đội nào cầm tướng nào; bắt đầu thì dựng
## MatchConfig (người ở ô đầu mỗi đội theo thứ tự vào phòng, ô trống bot độ khó Thường, tướng ngẫu nhiên còn lại, seed máy
## chủ chọn). Chỉ logic — máy chủ phòng (server/room_server.gd) nối với mạng.

const CODE_CHARS: String = "0123456789"  ## D-345: chỉ số — nhập nhanh bằng bàn phím số
const CODE_LEN: int = 5
const MAX_TEAM_SIZE: int = 3  ## NET-07: 6 tướng, không trùng (MATCH-02)

var code: String
var team_size: int = 3
var host: int = -1
var members: Array[int] = []                 ## theo thứ tự vào phòng
var info: Dictionary[int, Dictionary] = {}   ## mã → {account, name, team, hero}
var started: bool = false


static func new_code(rng: RandomNumberGenerator) -> String:
	var s: String = ""
	for i: int in CODE_LEN:
		s += CODE_CHARS[rng.randi_range(0, CODE_CHARS.length() - 1)]
	return s


func _init(room_code: String, size: int) -> void:
	code = room_code
	team_size = clampi(size, 1, MAX_TEAM_SIZE)


## "" khi vào được; không thì lý do (STARTED, FULL, ALREADY).
func join(peer: int, account: int, name: String) -> String:
	if started:
		return "STARTED"
	if members.size() >= 2 * team_size:
		return "FULL"
	for m: int in members:
		if int(info[m]["account"]) == account:
			return "ALREADY"
	var team: int = 0 if _count(0) <= _count(1) else 1
	members.append(peer)
	info[peer] = {"account": account, "name": name, "team": team, "hero": ""}
	if host < 0:
		host = peer
	return ""


func leave(peer: int) -> void:
	members.erase(peer)
	info.erase(peer)
	if host == peer:
		host = members[0] if not members.is_empty() else -1


func empty() -> bool:
	return members.is_empty()


func choose_team(peer: int, team: int) -> String:
	if not info.has(peer) or team < 0 or team > 1:
		return "BAD"
	if int(info[peer]["team"]) != team and _count(team) >= team_size:
		return "TEAM_FULL"
	info[peer]["team"] = team
	return ""


func pick(peer: int, hero: StringName, heroes: Array[StringName]) -> String:
	if not info.has(peer) or not heroes.has(hero):
		return "UNKNOWN_HERO"
	for m: int in members:
		if m != peer and StringName(info[m]["hero"]) == hero:
			return "HERO_TAKEN"
	info[peer]["hero"] = String(hero)
	return ""


## Chủ phòng đổi số người mỗi đội (không nhỏ hơn số người đang ở một đội).
func set_size(peer: int, size: int) -> String:
	if peer != host:
		return "NOT_HOST"
	if size < 1 or size > MAX_TEAM_SIZE or size < maxi(_count(0), _count(1)):
		return "BAD_SIZE"
	team_size = size
	return ""


func can_start(peer: int) -> String:
	if peer != host:
		return "NOT_HOST"
	for m: int in members:
		if String(info[m]["hero"]) == "":
			return "NOT_READY"
	return ""


## {config, seats: {mã → chỉ số ô trong config.slots}} — người theo thứ tự vào phòng ở ô đầu mỗi đội.
func build(heroes: Array[StringName], rng: RandomNumberGenerator) -> Dictionary:
	var free: Array[StringName] = heroes.filter(func(h: StringName) -> bool:
		return not members.any(func(m: int) -> bool: return StringName(info[m]["hero"]) == h))
	var picks: Array[StringName] = []
	var humans: Array[int] = []
	var seats: Dictionary = {}
	for team: int in 2:
		var mine: Array[int] = members.filter(func(m: int) -> bool: return int(info[m]["team"]) == team)
		for k: int in team_size:
			var slot: int = team * team_size + k
			if k < mine.size():
				picks.append(StringName(info[mine[k]]["hero"]))
				humans.append(slot)
				seats[mine[k]] = slot
			else:
				picks.append(free.pop_at(rng.randi_range(0, free.size() - 1)))
	started = true
	return {"config": MatchConfig.make(team_size, picks, humans, BotState.Difficulty.NORMAL, rng.randi() & 0x7fffffff),
		"seats": seats}


func state() -> Dictionary:
	return {"code": code, "size": team_size, "host": host, "started": started, "members": members.map(func(m: int) -> Dictionary:
		return {"id": m, "name": info[m]["name"], "team": info[m]["team"], "hero": info[m]["hero"]})}


func _count(team: int) -> int:
	return members.filter(func(m: int) -> bool: return int(info[m]["team"]) == team).size()
