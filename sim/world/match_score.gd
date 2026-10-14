class_name MatchScore
extends RefCounted
## Tỷ số trận (ECO-09): số lần hero đội kia đã chết.


static func team_kills(world: World, team: int) -> int:
	var total: int = 0
	for e: Entity in world.entities:
		if e.kind == Entity.Kind.HERO and e.team != team and e.team != 2:
			total += e.deaths
	return total
