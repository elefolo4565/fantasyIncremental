extends Node
## ゲーム全体の流れ。魔導樹の画面とラン（1ステージ）を切り替える。
## 起動引数に -- --smoke-run を付けると、全強化を最大にして最後のステージを直接始める（CI の動作確認用）。

const TREE_SCENE := preload("res://scenes/upgrade_tree/upgrade_tree.tscn")
const FONT := preload("res://assets/fonts/MPLUSRounded1c-ExtraBold-subset.ttf")
const RUN_SCENE := preload("res://scenes/run/run.tscn")

var _screen: Node


func _ready() -> void:
	# 同梱フォントを全体の既定にする。既定テーマの英字フォント（Open Sans）のままだと、PC では
	# OS の日本語フォントで補われて見えてしまうが、Web では補われず文字化けする。
	ThemeDB.get_default_theme().default_font = FONT
	ThemeDB.fallback_font = FONT
	if OS.get_cmdline_user_args().has("--smoke-run"):
		Progress.enable_smoke_mode()
		_show_run(Progress.stages.size() - 1)
	else:
		_show_tree()


func _show_tree() -> void:
	var tree := TREE_SCENE.instantiate() as UpgradeTree
	tree.start_requested.connect(_show_run)
	Bgm.play(&"tree")
	_switch_to(tree)


func _show_run(stage_index: int) -> void:
	var run := RUN_SCENE.instantiate() as Run
	run.stage_index = stage_index
	run.finished.connect(_show_tree)
	run.retry_requested.connect(_show_run)
	Bgm.play(&"battle")
	_switch_to(run)


func _switch_to(screen: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	add_child(screen)
