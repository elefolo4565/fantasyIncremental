extends CanvasLayer
## 画面が縦長のとき（縦持ちのスマホ）に、横向きにするよう上部に案内を出す。
## 画面の比率はどの端末でも 16:9 の横長に固定しているので、縦持ちでは小さく表示される。

@onready var _panel: PanelContainer = $Panel


func _ready() -> void:
	get_tree().root.size_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var size := DisplayServer.window_get_size()
	_panel.visible = size.x < size.y
