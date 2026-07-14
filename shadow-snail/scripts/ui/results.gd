extends Control

@onready var _summary: Label = %SummaryLabel
@onready var _results_list: ItemList = %ResultsList


func _ready() -> void:
	var results: Dictionary = SessionState.last_match_results
	var mode: int = results.get("mode", SessionState.lobby_mode)
	_summary.text = "对局结束 — %s" % GameMode.label(mode as GameMode.Id)
	_results_list.clear()
	var ranking: Array = results.get("ranking", [])
	for i in ranking.size():
		var entry: Dictionary = ranking[i]
		_results_list.add_item("第%d名  %s  (%s)" % [
			i + 1,
			entry.get("name", "玩家"),
			entry.get("loadout", ""),
		])
	if ranking.is_empty():
		_results_list.add_item("暂无排名数据（原型对局）。")
