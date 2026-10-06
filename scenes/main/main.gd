extends Node
## ゲーム全体の流れ。魔導樹の画面とラン（1ステージ）を切り替える。
## 起動引数に -- --smoke-run を付けると、全強化を最大にして最後のステージを直接始める（CI の動作確認用）。

const TREE_SCENE := preload("res://scenes/upgrade_tree/upgrade_tree.tscn")
const RUN_SCENE := preload("res://scenes/run/run.tscn")

var _screen: Node


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--smoke-run"):
		Progress.enable_smoke_mode()
		_show_run(Progress.stages.size() - 1)
	else:
		_show_tree()


func _show_tree() -> void:
	var tree := TREE_SCENE.instantiate() as UpgradeTree
	tree.start_requested.connect(_show_run)
	_switch_to(tree)


func _show_run(stage_index: int) -> void:
	var run := RUN_SCENE.instantiate() as Run
	run.stage_index = stage_index
	run.finished.connect(_show_tree)
	_switch_to(run)


func _switch_to(screen: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	add_child(screen)
