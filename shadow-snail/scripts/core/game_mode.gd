class_name GameMode
extends RefCounted

## Match types selectable in the lobby.

enum Id { DUEL, DUO, FFA }

const LABELS: Dictionary = {
	Id.DUEL: "单挑 1v1",
	Id.DUO: "组队 2v2",
	Id.FFA: "大乱斗",
}

const DESCRIPTIONS: Dictionary = {
	Id.DUEL: "两名玩家，最后一个影子站立者获胜。",
	Id.DUO: "两队各两人，配合踩踏对手影子。",
	Id.FFA: "最多八人，所有人都是目标。",
}

const MIN_PLAYERS: Dictionary = {
	Id.DUEL: 2,
	Id.DUO: 4,
	Id.FFA: 2,
}

const MAX_PLAYERS: Dictionary = {
	Id.DUEL: 2,
	Id.DUO: 4,
	Id.FFA: 8,
}


static func label(mode: Id) -> String:
	return LABELS.get(mode, "未知")


static func description(mode: Id) -> String:
	return DESCRIPTIONS.get(mode, "")


static func min_players(mode: Id) -> int:
	return MIN_PLAYERS.get(mode, 2)


static func max_players(mode: Id) -> int:
	return MAX_PLAYERS.get(mode, 8)


static func all_modes() -> Array:
	return [Id.DUEL, Id.DUO, Id.FFA]
