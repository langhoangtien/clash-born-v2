class_name MatchConfig
extends RefCounted
## MATCH-01..05 (D-328): cấu hình một trận — số ô mỗi đội, các ô (đội 0 ô 0…n−1 rồi đội 1), seed.
## Offline (màn chọn tướng) và online (máy chủ) dùng chung; MatchSetup.spawn_heroes dựng hero theo nó.

const MAX_TEAM_SIZE: int = 5  ## MATCH-01

var team_size: int = 1
var seed: int = 1
var slots: Array[MatchSlot] = []


## `heroes` theo thứ tự ô; `humans` = chỉ số ô do người điều khiển, còn lại là bot độ khó `difficulty`.
static func make(size: int, heroes: Array[StringName], humans: Array, difficulty: BotState.Difficulty, seed_value: int) -> MatchConfig:
	var c: MatchConfig = MatchConfig.new()
	c.team_size = size
	c.seed = seed_value
	for i: int in heroes.size():
		var s: MatchSlot = MatchSlot.new()
		s.team = i / maxi(size, 1)
		s.index = i % maxi(size, 1)
		s.hero_id = heroes[i]
		s.is_bot = not humans.has(i)
		s.difficulty = difficulty
		c.slots.append(s)
	return c


## 1v1: người cầm `hero`, bot cầm `foe`.
static func duel(hero: StringName, foe: StringName, difficulty: BotState.Difficulty = BotState.Difficulty.NORMAL, seed_value: int = 1) -> MatchConfig:
	return make(1, [hero, foe] as Array[StringName], [0], difficulty, seed_value)


## "" khi dùng được; không thì lý do (MATCH-01 TEAM_SIZE / SLOT_COUNT, MATCH-02 UNKNOWN_HERO / DUPLICATE_HERO).
func validate(library: ContentLibrary) -> String:
	if team_size < 1 or team_size > MAX_TEAM_SIZE:
		return "TEAM_SIZE"
	if slots.size() != 2 * team_size:
		return "SLOT_COUNT"
	var seen: Dictionary[StringName, bool] = {}
	for s: MatchSlot in slots:
		if not library.heroes.has(s.hero_id):
			return "UNKNOWN_HERO"
		if seen.has(s.hero_id):
			return "DUPLICATE_HERO"
		seen[s.hero_id] = true
	return ""
