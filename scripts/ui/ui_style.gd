class_name UiStyle
extends RefCounted
## ブロスタ風の UI の見た目（太い縁取り・下に落ちる影・明るい色のボタン）をまとめて付ける。

const OUTLINE := Color(0.09, 0.07, 0.13)
const YELLOW := Color(1.0, 0.8, 0.12)
const GREEN := Color(0.3, 0.85, 0.3)
const BLUE := Color(0.25, 0.5, 1.0)
const PANEL := Color(0.13, 0.17, 0.36)
const DISABLED := Color(0.35, 0.36, 0.42)


static func box(fill: Color, radius := 14, border := 4, shadow := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = OUTLINE
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_offset = Vector2(0, shadow)
	style.shadow_size = 1 if shadow > 0 else 0
	style.set_content_margin_all(10.0)
	return style


## 太い縁取りの文字と、色つきのボタンの見た目を付ける。押すと少し沈む。
static func button(target: Button, fill: Color, font_size := 0) -> void:
	var normal := box(fill)
	var hover := box(fill.lightened(0.12))
	var pressed := box(fill.darkened(0.15), 14, 4, 2)
	pressed.content_margin_top += 4.0
	var off := box(DISABLED)
	target.add_theme_stylebox_override("normal", normal)
	target.add_theme_stylebox_override("hover", hover)
	target.add_theme_stylebox_override("pressed", pressed)
	target.add_theme_stylebox_override("focus", normal)
	target.add_theme_stylebox_override("disabled", off)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		target.add_theme_color_override(state, Color.WHITE)
	target.add_theme_color_override("font_disabled_color", Color(0.75, 0.75, 0.8))
	target.add_theme_color_override("font_outline_color", OUTLINE)
	target.add_theme_constant_override("outline_size", 8)
	if font_size > 0:
		target.add_theme_font_size_override("font_size", font_size)


static func outline_label(target: Label, outline := 8) -> void:
	target.add_theme_color_override("font_outline_color", OUTLINE)
	target.add_theme_constant_override("outline_size", outline)
