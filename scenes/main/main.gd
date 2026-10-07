extends Node
## ゲーム全体の流れ。魔導樹の画面とラン（1ステージ）と、開発用の敵エディタを切り替える。
## 切り替えるときは画面をいったん暗くしてから次の画面を明るく出す（暗いあいだは触れない）。
## 起動引数に -- --smoke-run を付けると、全強化を最大にして最後のステージを直接始める（CI の動作確認用）。
## -- --smoke-stage-editor を付けると、ステージエディタを開いてそこから最初のステージを試遊する（CI の動作確認用）。

const TREE_SCENE := preload("res://scenes/upgrade_tree/upgrade_tree.tscn")
const FONT := preload("res://assets/fonts/MPLUSRounded1c-ExtraBold-subset.ttf")
const RUN_SCENE := preload("res://scenes/run/run.tscn")
const EDITOR_SCENE := preload("res://scenes/enemy_editor/enemy_editor.tscn")
const STAGE_EDITOR_SCENE := preload("res://scenes/stage_editor/stage_editor.tscn")
## CI の動作確認でステージエディタを開いてから試遊を始めるまでの秒数
const SMOKE_EDITOR_WAIT := 1.0

## 画面を切り替えるときに暗くする・明るくする時間（見た目だけ、秒）
const FADE_OUT_TIME := 0.25
const FADE_IN_TIME := 0.3
const CURTAIN_COLOR := Color(0.05, 0.04, 0.1)

## 右下の版表示（見た目だけ）。中身は書き出し時に CI が version.txt に書く（PR 番号と commit）
const VERSION_FILE := "res://version.txt"
const VERSION_FONT_SIZE := 14
const VERSION_COLOR := Color(1, 1, 1, 0.55)
const VERSION_MARGIN := 6.0

var _screen: Node
var _curtain: ColorRect
var _switching := false
## ステージエディタからの試遊で使う強化（StageEditor.TEST_UPGRADES の id）
var _test_upgrades: StringName = &"current"


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
	_add_version_label()
	if OS.get_cmdline_user_args().has("--smoke-run"):
		Progress.enable_smoke_mode()
		_show_run(Progress.stages.size() - 1)
	elif OS.get_cmdline_user_args().has("--smoke-stage-editor"):
		var editor := _show_stage_editor()
		await get_tree().create_timer(SMOKE_EDITOR_WAIT).timeout
		editor.test_play_selected()
	else:
		_show_tree()


## どの版を遊んでいるか分かるよう、画面の右下にいつも小さく出す（触っても反応しない）。
func _add_version_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 99
	add_child(layer)
	var label := Label.new()
	label.text = _read_version()
	label.add_theme_font_size_override("font_size", VERSION_FONT_SIZE)
	label.add_theme_color_override("font_color", VERSION_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, int(VERSION_MARGIN))
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(label)


func _read_version() -> String:
	if not FileAccess.file_exists(VERSION_FILE):
		return "開発版"
	var text := FileAccess.get_file_as_string(VERSION_FILE).strip_edges()
	return text if not text.is_empty() else "開発版"


func _show_tree() -> void:
	var tree := TREE_SCENE.instantiate() as UpgradeTree
	tree.start_requested.connect(_show_run)
	tree.editor_requested.connect(_show_enemy_editor)
	tree.stage_editor_requested.connect(_show_stage_editor)
	Bgm.play(&"tree")
	_switch_to(tree)


## 開発用の敵エディタ。閉じると魔導樹に戻る。
func _show_enemy_editor() -> void:
	var editor := EDITOR_SCENE.instantiate() as EnemyEditor
	editor.closed.connect(_show_tree)
	_switch_to(editor)


## 開発用のステージエディタ。閉じると魔導樹に戻り、試遊を押すとそのステージを遊ぶ。
func _show_stage_editor() -> StageEditor:
	Progress.end_test()
	var editor := STAGE_EDITOR_SCENE.instantiate() as StageEditor
	editor.closed.connect(_show_tree)
	editor.test_requested.connect(_show_test_run)
	Bgm.play(&"tree")
	_switch_to(editor)
	return editor


## ステージエディタからの試遊。終わったら（「戻る」で）ステージエディタに戻る。「もう一度」は同じ条件で遊び直す。
func _show_test_run(stage_index: int, upgrades: StringName) -> void:
	_test_upgrades = upgrades
	Progress.begin_test(upgrades)
	var run := RUN_SCENE.instantiate() as Run
	run.stage_index = stage_index
	run.finished.connect(_show_stage_editor)
	run.retry_requested.connect(func(index: int) -> void: _show_test_run(index, _test_upgrades))
	Bgm.play(&"battle")
	_switch_to(run)


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
