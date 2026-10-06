extends Node
## data/balance.csv を読み込み、ゲーム中の調整用の数値を返すオートロード。
## 数値を変えたいときはスクリプトではなく CSV を編集する。
## 表形式の CSV（stages.csv など）は load_table() で1行ずつの辞書として読める。

const PATH := "res://data/balance.csv"

var _values: Dictionary = {}


func _init() -> void:
	for row in load_table(PATH):
		var key: String = row.get("key", "")
		if key.is_empty() or key.begins_with("#"):
			continue
		_values[key] = String(row.get("value", "0")).to_float()


func has(key: String) -> bool:
	return _values.has(key)


func get_float(key: String) -> float:
	if not _values.has(key):
		push_error("balance.csv にキーがありません: %s" % key)
		return 0.0
	return _values[key]


func get_int(key: String) -> int:
	return roundi(get_float(key))


## 1行目を見出しとして CSV を読み、各行を「見出し → 文字列」の辞書にして返す。
func load_table(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("%s を開けません (error %d)" % [path, FileAccess.get_open_error()])
		return rows
	var header := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 2 or line[0].strip_edges().is_empty():
			continue
		var row: Dictionary = {}
		for i in mini(header.size(), line.size()):
			row[header[i].strip_edges()] = line[i].strip_edges()
		rows.append(row)
	return rows
