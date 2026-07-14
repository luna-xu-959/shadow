class_name TeamInfo
extends RefCounted

## Two-team mode: everyone casts shadows; cross-team stomps only.

enum Id { TEAM_A = 0, TEAM_B = 1 }


static func casts_sun_shadow(_team: int) -> bool:
	return true


static func can_stomp_team(attacker_team: int, victim_team: int) -> bool:
	return attacker_team != victim_team


static func display_name(team: int) -> String:
	return "Team A" if team == Id.TEAM_A else "Team B"


static func team_tint(team: int) -> Color:
	return Color(0.98, 0.97, 0.94) if team == Id.TEAM_A else Color(0.62, 0.78, 0.98)


static func team_accent(team: int) -> Color:
	return Color(0.95, 0.72, 0.28) if team == Id.TEAM_A else Color(0.45, 0.82, 0.95)
