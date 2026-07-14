class_name PlayerSlot
extends RefCounted

var slot_id: int = -1
var peer_id: int = 1
var team: int = TeamInfo.Id.TEAM_A
var pawn: CharacterBody3D
var spawn_position: Vector3 = Vector3.ZERO
var respawn_remaining: float = 0.0
var is_eliminated: bool = false


func is_alive() -> bool:
	return is_instance_valid(pawn) and not is_eliminated and respawn_remaining <= 0.0
