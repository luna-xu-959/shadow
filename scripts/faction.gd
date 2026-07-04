class_name FactionInfo
extends RefCounted

enum Type { HUMAN, GHOST }


static func casts_sun_shadow(faction: int) -> bool:
	return faction == Type.HUMAN


static func can_capture_shadow(attacker_faction: int, caster_faction: int) -> bool:
	return attacker_faction == Type.GHOST and caster_faction == Type.HUMAN


static func display_name(faction: int) -> String:
	return "Human" if faction == Type.HUMAN else "Ghost"
