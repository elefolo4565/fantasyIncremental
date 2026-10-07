class_name TimeWarning
extends Control
## 時間切れが近いことを知らせる、画面の縁の赤い光（ビネット）。
## 親が show_pulse(強さ 0〜1) を毎フレーム呼ぶと、その強さで縁が赤く光る。hide() で消す。触っても操作の邪魔にならない。

## 縁の色と、いちばん強いときの濃さ（見た目だけ）
const EDGE_COLOR := Color(1.0, 0.1, 0.05)
const MAX_ALPHA := 0.55
## 光らないときもうっすら残す濃さ（見た目だけ）
const BASE_ALPHA := 0.15
## 中央の、色を付けない範囲（0〜1、見た目だけ）
const CLEAR_RADIUS := 0.45

var _texture: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.set_offset(0, CLEAR_RADIUS)
	gradient.set_color(0, Color(EDGE_COLOR, 0.0))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(EDGE_COLOR, MAX_ALPHA))
	_texture = GradientTexture2D.new()
	_texture.gradient = gradient
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	# 縦横で伸ばすので、四隅まで届くよう半径を対角の長さにする
	_texture.fill_to = Vector2(0.5 + 0.5 * sqrt(2.0), 0.5)
	_texture.width = 128
	_texture.height = 128
	visible = false


func _draw() -> void:
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)


## 縁を光らせる。strength は 0（うっすら）〜1（いちばん強い）。
func show_pulse(strength: float) -> void:
	visible = true
	modulate.a = lerpf(BASE_ALPHA, MAX_ALPHA, clampf(strength, 0.0, 1.0)) / MAX_ALPHA
