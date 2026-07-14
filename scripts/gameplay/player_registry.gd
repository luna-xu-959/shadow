class_name PlayerRegistry
extends Node

signal player_registered(slot: PlayerSlot)
signal player_eliminated(slot: PlayerSlot, attacker: PlayerSlot)
signal player_respawned(slot: PlayerSlot)

var _slots: Array[PlayerSlot] = []


func clear() -> void:
	_slots.clear()


func register_pawn(
	pawn: CharacterBody3D,
	team: int,
	slot_id: int = -1,
	peer_id: int = 1
) -> PlayerSlot:
	if slot_id < 0:
		slot_id = _slots.size()
	var slot := PlayerSlot.new()
	slot.slot_id = slot_id
	slot.peer_id = peer_id
	slot.team = team
	slot.pawn = pawn
	slot.spawn_position = pawn.global_position
	slot.is_eliminated = false
	slot.respawn_remaining = 0.0
	if pawn.has_method("set_slot_id"):
		pawn.call("set_slot_id", slot_id)
	if pawn.has_method("set_team"):
		pawn.call("set_team", team)
	_slots.append(slot)
	player_registered.emit(slot)
	return slot


func register_from_group(group: StringName = &"players") -> void:
	clear()
	for node in get_tree().get_nodes_in_group(group):
		if node is CharacterBody3D and node.has_method("get_team"):
			var pawn := node as CharacterBody3D
			var team: int = pawn.call("get_team")
			var slot_id: int = pawn.call("get_slot_id") if pawn.has_method("get_slot_id") else _slots.size()
			var peer_id: int = pawn.get_multiplayer_authority()
			register_pawn(pawn, team, slot_id, peer_id)


func get_slot(slot_id: int) -> PlayerSlot:
	for slot in _slots:
		if slot.slot_id == slot_id:
			return slot
	return null


func get_slot_for_pawn(pawn: Node) -> PlayerSlot:
	for slot in _slots:
		if slot.pawn == pawn:
			return slot
	return null


func get_pawn(slot_id: int) -> CharacterBody3D:
	var slot := get_slot(slot_id)
	return slot.pawn if slot else null


func get_all_pawns() -> Array[CharacterBody3D]:
	var pawns: Array[CharacterBody3D] = []
	for slot in _slots:
		if is_instance_valid(slot.pawn):
			pawns.append(slot.pawn)
	return pawns


func get_alive_pawns() -> Array[CharacterBody3D]:
	var pawns: Array[CharacterBody3D] = []
	for slot in _slots:
		if slot.is_alive():
			pawns.append(slot.pawn)
	return pawns


func get_enemies_of(pawn: Node) -> Array[CharacterBody3D]:
	var source := get_slot_for_pawn(pawn)
	if source == null:
		return []
	var enemies: Array[CharacterBody3D] = []
	for slot in _slots:
		if slot.is_alive() and slot.team != source.team and is_instance_valid(slot.pawn):
			enemies.append(slot.pawn)
	return enemies


func count_team(team: int) -> int:
	var count := 0
	for slot in _slots:
		if slot.team == team:
			count += 1
	return count


func pick_team_for_join() -> int:
	if count_team(TeamInfo.Id.TEAM_A) <= count_team(TeamInfo.Id.TEAM_B):
		return TeamInfo.Id.TEAM_A
	return TeamInfo.Id.TEAM_B


func find_nearest_enemy(from_pawn: Node) -> CharacterBody3D:
	var from_3d := from_pawn as Node3D
	if from_3d == null:
		return null
	var enemies := get_enemies_of(from_pawn)
	if enemies.is_empty():
		return null
	var best: CharacterBody3D = null
	var best_dist: float = INF
	for enemy in enemies:
		var dist: float = from_3d.global_position.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func eliminate_player(victim: Node, attacker: Node) -> void:
	var victim_slot := get_slot_for_pawn(victim)
	if victim_slot == null or victim_slot.is_eliminated:
		return
	var attacker_slot := get_slot_for_pawn(attacker)
	victim_slot.is_eliminated = true
	victim_slot.respawn_remaining = SessionConfig.RESPAWN_SECONDS
	if is_instance_valid(victim) and victim.has_method("eliminate"):
		victim.call("eliminate")
	player_eliminated.emit(victim_slot, attacker_slot)


func tick_respawns(delta: float, authority: bool) -> void:
	if not authority:
		return
	for slot in _slots:
		if slot.respawn_remaining <= 0.0:
			continue
		slot.respawn_remaining = maxf(0.0, slot.respawn_remaining - delta)
		if slot.respawn_remaining <= 0.0:
			_respawn_slot(slot)


func _respawn_slot(slot: PlayerSlot) -> void:
	if not is_instance_valid(slot.pawn):
		return
	slot.is_eliminated = false
	slot.respawn_remaining = 0.0
	if slot.pawn.has_method("respawn_at"):
		slot.pawn.call("respawn_at", slot.spawn_position)
	player_respawned.emit(slot)


func count_alive_team(team: int) -> int:
	var count := 0
	for slot in _slots:
		if slot.team == team and slot.is_alive():
			count += 1
	return count


func count_respawning_team(team: int) -> int:
	var count := 0
	for slot in _slots:
		if slot.team == team and slot.respawn_remaining > 0.0:
			count += 1
	return count


func get_respawn_label(pawn: Node) -> String:
	var slot := get_slot_for_pawn(pawn)
	if slot == null or slot.respawn_remaining <= 0.0:
		return ""
	return "respawn %.0fs" % slot.respawn_remaining
