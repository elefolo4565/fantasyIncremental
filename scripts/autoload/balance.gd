extends Node
## data/balance.csv を読み込み、ゲーム中の調整用の数値を返すオートロード。
## 数値を変えたいときはスクリプトではなく CSV を編集する。

const PATH := "res://data/balance.csv"

var _values: Dictionary = {}


func _init() -> void:
	_load()


func get_float(key: String) -> float:
	if not _values.has(key):
		push_error("balance.csv にキーがありません: %s" % key)
		return 0.0
	return _values[key]


func get_int(key: String) -> int:
	return roundi(get_float(key))


func _load() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("%s を開けません (error %d)" % [PATH, FileAccess.get_open_error()])
		return
	file.get_csv_line()  # 見出し行を読み飛ばす
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2:
			continue
		var key := row[0].strip_edges()
		if key.is_empty() or key.begins_with("#"):
			continue
		_values[key] = row[1].strip_edges().to_float()
