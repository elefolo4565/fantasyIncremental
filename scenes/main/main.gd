extends Node
## ゲーム全体の流れ。魔導樹の画面とラン（1ステージ）を切り替える。
## 切り替えるときは画面をいったん暗くしてから次の画面を明るく出す（暗いあいだは触れない）。
## 起動引数に -- --smoke-run を付けると、全強化を最大にして最後のステージを直接始める（CI の動作確認用）。

const TREE_SCENE := preload("res://scenes/upgrade_tree/upgrade_tree.tscn")
const FONT := preload("res://assets/fonts/MPLUSRounded1c-ExtraBold-subset.ttf")
const RUN_SCENE := preload("res://scenes/run/run.tscn")

## 画面を切り替えるときに暗くする・明るくする時間（見た目だけ、秒）
const FADE_OUT_TIME := 0.25
const FADE_IN_TIME := 0.3
const CURTAIN_COLOR := Color(0.05, 0.04, 0.1)

var _screen: Node
var _curtain: ColorRect
var _switching := false


func _ready() -> void:
	# 同梱フォントを全体の既定にする。既定テーマの英字フォント（Open Sans）のままだと、PC では
	# OS の日本語フォントで補われて見えてしまうが、Web では補われず文字化けする。
	ThemeDB.get_default_theme().default_font = FONT
	ThemeDB.fallback_font = FONT
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_curtain = ColorRect.new()
	_curtain.color = CURTAIN_COLOR
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_curtain)
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
	if _switching:
		screen.free()
		return
	_switching = true
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	if _screen != null:
		var out := create_tween()
		out.tween_property(_curtain, "modulate:a", 1.0, FADE_OUT_TIME)
		await out.finished
		_screen.queue_free()
	_screen = screen
	add_child(screen)
	_curtain.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_property(_curtain, "modulate:a", 0.0, FADE_IN_TIME)
	await fade.finished
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_switching = false
