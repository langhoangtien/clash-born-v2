class_name MatchSlot
extends RefCounted
## MATCH-01: một ô của trận — tướng, người hay bot điều khiển, độ khó bot.

var team: int = 0
var index: int = 0
var hero_id: StringName
var is_bot: bool = true
var difficulty: BotState.Difficulty = BotState.Difficulty.NORMAL
