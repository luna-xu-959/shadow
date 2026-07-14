class_name FactionInfo
extends RefCounted

## Backward-compatible alias for legacy scenes. Prefer TeamInfo.

enum Type { HUMAN = TeamInfo.Id.TEAM_A, GHOST = TeamInfo.Id.TEAM_B }


static func casts_sun_shadow(_faction: int) -> bool:
	return TeamInfo.casts_sun_shadow(_faction)


static func can_capture_shadow(attacker_faction: int, caster_faction: int) -> bool:
	return TeamInfo.can_stomp_team(attacker_faction, caster_faction)


static func display_name(faction: int) -> String:
	return TeamInfo.display_name(faction)
