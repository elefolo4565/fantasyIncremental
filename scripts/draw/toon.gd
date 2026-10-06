class_name Toon
extends RefCounted
## ブロスタ風の絵を _draw() で描くための道具。太い黒っぽい縁取り・足元の影・ハイライトをまとめて描く。
## 見た目だけの定数なのでここに置く（ゲームの数値は data/ に置く）。

const OUTLINE := Color(0.09, 0.07, 0.13)
const OUTLINE_WIDTH := 4.0
const SHADOW := Color(0, 0, 0, 0.3)
const HIGHLIGHT := Color(1, 1, 1, 0.55)
const SEGMENTS := 28


static func ellipse_points(center: Vector2, size: Vector2, segments := SEGMENTS) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	return points


## 足元の楕円の影。
static func shadow(ci: CanvasItem, center: Vector2, size: Vector2) -> void:
	ci.draw_colored_polygon(ellipse_points(center, size), SHADOW)


## 縁取りつきの楕円。縁の分だけ大きい楕円を先に塗って、その上に本体を塗る。
static func blob(ci: CanvasItem, center: Vector2, size: Vector2, fill: Color, outline := OUTLINE_WIDTH) -> void:
	if outline > 0.0:
		ci.draw_colored_polygon(ellipse_points(center, size + Vector2.ONE * outline), OUTLINE)
	ci.draw_colored_polygon(ellipse_points(center, size), fill)


## 下側に濃い影、左上に光のある、立体っぽい楕円（縁取りつき）。
static func shaded_blob(ci: CanvasItem, center: Vector2, size: Vector2, fill: Color, outline := OUTLINE_WIDTH) -> void:
	blob(ci, center, size, fill.darkened(0.3), outline)
	ci.draw_colored_polygon(ellipse_points(center - Vector2(0, size.y * 0.12), size * Vector2(0.92, 0.84)), fill)
	highlight(ci, center + Vector2(-size.x * 0.38, -size.y * 0.42), size * 0.24)


static func highlight(ci: CanvasItem, center: Vector2, size: Vector2) -> void:
	ci.draw_colored_polygon(ellipse_points(center, size, 16), HIGHLIGHT)


## 縁取りつきの多角形。縁は太い線で描く。
static func polygon(ci: CanvasItem, points: PackedVector2Array, fill: Color, outline := OUTLINE_WIDTH) -> void:
	if outline > 0.0:
		var closed := points.duplicate()
		closed.append(points[0])
		ci.draw_polyline(closed, OUTLINE, outline * 2.0, true)
		for point in points:
			ci.draw_circle(point, outline, OUTLINE)
	ci.draw_colored_polygon(points, fill)


## 白目と黒目。look の向きに黒目を寄せる。
static func eye(ci: CanvasItem, center: Vector2, radius: float, look: Vector2) -> void:
	ci.draw_circle(center, radius + 2.5, OUTLINE)
	ci.draw_circle(center, radius, Color.WHITE)
	ci.draw_circle(center + look.limit_length(1.0) * radius * 0.4, radius * 0.55, OUTLINE)


## 太い縁取りの文字（中央揃え）。
static func label(ci: CanvasItem, at: Vector2, text: String, size: int, color: Color, width := 120.0) -> void:
	var font := ThemeDB.fallback_font
	var pos := at - Vector2(width * 0.5, 0)
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 9, OUTLINE)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)
