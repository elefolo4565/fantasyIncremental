class_name SkillIcon
extends RefCounted
## 魔導樹のノードに出すアイコンを描く。upgrades.csv の icon 列の名前で選ぶ。
## assets/icons/<名前>.png があればその絵を使い、なければ _draw() の図形で仮のアイコンを描く。

const FILL := Color(1, 1, 1)
const LINE := Toon.OUTLINE
const ICON_DIR := "res://assets/icons/%s.png"

static var _textures: Dictionary = {}


## center を中心に、半径 radius の円に収まるアイコンを描く。tint で全体の色を掛ける（覚えられないノードは暗くする）。
static func draw(ci: CanvasItem, icon: StringName, center: Vector2, radius: float, tint := Color.WHITE) -> void:
	var texture := _texture(icon)
	if texture != null:
		ci.draw_texture_rect(texture, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, tint)
		return
	var pen := _Pen.new(ci, center, radius, FILL * tint)
	match icon:
		&"bolt":
			pen.poly([Vector2(0.15, -0.95), Vector2(-0.55, 0.15), Vector2(-0.05, 0.15), Vector2(-0.2, 0.95),
					Vector2(0.55, -0.2), Vector2(0.05, -0.2), Vector2(0.3, -0.95)])
		&"fast":
			pen.line([Vector2(-0.8, -0.6), Vector2(-0.2, 0.0), Vector2(-0.8, 0.6)])
			pen.line([Vector2(0.0, -0.6), Vector2(0.6, 0.0), Vector2(0.0, 0.6)])
		&"crack":
			pen.line([Vector2(-0.2, -0.9), Vector2(0.15, -0.35), Vector2(-0.2, 0.05), Vector2(0.25, 0.45), Vector2(-0.05, 0.9)])
			pen.line([Vector2(0.15, -0.35), Vector2(0.55, -0.45)])
		&"twin":
			pen.dot(Vector2(-0.38, 0.15), 0.38)
			pen.dot(Vector2(0.38, -0.15), 0.38)
		&"burst":
			pen.poly(_star(8, 0.95, 0.42))
		&"eye":
			pen.poly([Vector2(-0.95, 0.0), Vector2(-0.5, -0.45), Vector2(0.0, -0.58), Vector2(0.5, -0.45),
					Vector2(0.95, 0.0), Vector2(0.5, 0.45), Vector2(0.0, 0.58), Vector2(-0.5, 0.45)])
			pen.dot(Vector2.ZERO, 0.3, LINE)
		&"target":
			pen.ring(Vector2.ZERO, 0.8)
			pen.dot(Vector2.ZERO, 0.32)
		&"sword":
			pen.line([Vector2(-0.6, 0.6), Vector2(0.75, -0.75)])
			pen.line([Vector2(-0.6, 0.05), Vector2(-0.05, 0.6)])
			pen.line([Vector2(-0.6, 0.6), Vector2(-0.85, 0.85)])
		&"pierce":
			pen.line([Vector2(0.0, -0.9), Vector2(0.0, 0.9)])
			pen.line([Vector2(-0.9, 0.0), Vector2(0.75, 0.0)])
			pen.line([Vector2(0.35, -0.38), Vector2(0.8, 0.0), Vector2(0.35, 0.38)])
		&"wave":
			pen.dot(Vector2(-0.55, 0.0), 0.22)
			pen.arc(Vector2(-0.55, 0.0), 0.65, -0.9, 0.9)
			pen.arc(Vector2(-0.55, 0.0), 1.15, -0.75, 0.75)
		&"focus":
			pen.ring(Vector2.ZERO, 0.6)
			for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				pen.line([direction * 0.45, direction * 0.95])
		&"bounce":
			pen.line([Vector2(-0.85, -0.6), Vector2(0.0, 0.55), Vector2(0.75, -0.55)])
			pen.line([Vector2(0.3, -0.5), Vector2(0.75, -0.55), Vector2(0.75, -0.1)])
		&"sprout":
			pen.line([Vector2(0.0, 0.9), Vector2(0.0, -0.1)])
			pen.poly(_leaf(Vector2(0.0, -0.1), Vector2(-0.85, -0.6)))
			pen.poly(_leaf(Vector2(0.0, -0.1), Vector2(0.85, -0.75)))
		&"hourglass":
			pen.poly([Vector2(-0.6, -0.85), Vector2(0.6, -0.85), Vector2(0.08, 0.0), Vector2(0.6, 0.85),
					Vector2(-0.6, 0.85), Vector2(-0.08, 0.0)])
		&"sun":
			for i in 8:
				var direction := Vector2.UP.rotated(TAU * i / 8.0)
				pen.line([direction * 0.62, direction * 0.92])
			pen.dot(Vector2.ZERO, 0.42)
		&"boot":
			pen.line([Vector2(-0.95, -0.2), Vector2(-0.6, -0.2)])
			pen.line([Vector2(-0.95, 0.25), Vector2(-0.6, 0.25)])
			pen.poly([Vector2(-0.35, -0.9), Vector2(0.3, -0.9), Vector2(0.3, 0.1), Vector2(0.75, 0.25),
					Vector2(0.9, 0.5), Vector2(0.85, 0.8), Vector2(-0.35, 0.8)])
			pen.line([Vector2(-0.35, -0.55), Vector2(0.3, -0.55)], LINE)
		&"drop":
			pen.poly([Vector2(0.0, -0.95), Vector2(0.45, -0.2), Vector2(0.62, 0.25), Vector2(0.45, 0.68),
					Vector2(0.0, 0.88), Vector2(-0.45, 0.68), Vector2(-0.62, 0.25), Vector2(-0.45, -0.2)])
		&"shield":
			pen.poly([Vector2(-0.75, -0.75), Vector2(0.0, -0.95), Vector2(0.75, -0.75), Vector2(0.65, 0.2),
					Vector2(0.0, 0.95), Vector2(-0.65, 0.2)])
		&"flame":
			pen.poly([Vector2(0.0, -0.95), Vector2(0.35, -0.35), Vector2(0.65, 0.15), Vector2(0.5, 0.7),
					Vector2(0.0, 0.92), Vector2(-0.5, 0.7), Vector2(-0.65, 0.15), Vector2(-0.3, -0.15),
					Vector2(-0.12, 0.2)])
		&"heart":
			pen.poly(_heart())
		&"gem":
			pen.poly([Vector2(-0.8, -0.3), Vector2(-0.4, -0.8), Vector2(0.4, -0.8), Vector2(0.8, -0.3), Vector2(0.0, 0.9)])
		&"magnet":
			pen.thick([Vector2(-0.55, -0.8), Vector2(-0.55, 0.1), Vector2(-0.35, 0.55), Vector2(0.0, 0.7),
					Vector2(0.35, 0.55), Vector2(0.55, 0.1), Vector2(0.55, -0.8)], 0.34)
		&"axe":
			pen.line([Vector2(-0.7, 0.85), Vector2(0.3, -0.6)])
			pen.poly([Vector2(-0.05, -0.75), Vector2(0.2, -0.95), Vector2(0.65, -0.85), Vector2(0.95, -0.4),
					Vector2(0.9, 0.05), Vector2(0.55, -0.15), Vector2(0.25, -0.35)])
		&"crown":
			pen.poly([Vector2(-0.85, 0.65), Vector2(-0.85, -0.55), Vector2(-0.4, -0.05), Vector2(0.0, -0.75),
					Vector2(0.4, -0.05), Vector2(0.85, -0.55), Vector2(0.85, 0.65)])
		&"swirl":
			var points: Array[Vector2] = []
			for i in 24:
				var t := float(i) / 23.0
				points.append(Vector2.RIGHT.rotated(t * TAU * 1.6) * lerpf(0.08, 0.85, t))
			pen.line(points)
		&"leaf":
			pen.poly(_leaf(Vector2(-0.75, 0.75), Vector2(0.8, -0.8)))
			pen.line([Vector2(-0.75, 0.75), Vector2(0.3, -0.3)], LINE)
		&"slime":
			pen.poly([Vector2(-0.9, 0.7), Vector2(-0.8, 0.0), Vector2(-0.45, -0.55), Vector2(0.0, -0.75),
					Vector2(0.45, -0.55), Vector2(0.8, 0.0), Vector2(0.9, 0.7)])
			pen.dot(Vector2(-0.3, 0.05), 0.12, LINE)
			pen.dot(Vector2(0.3, 0.05), 0.12, LINE)
		&"bag":
			pen.poly([Vector2(-0.3, -0.75), Vector2(0.3, -0.75), Vector2(0.15, -0.45), Vector2(0.75, 0.15),
					Vector2(0.7, 0.85), Vector2(-0.7, 0.85), Vector2(-0.75, 0.15), Vector2(-0.15, -0.45)])
		&"chain":
			pen.ring(Vector2(-0.35, 0.3), 0.45)
			pen.ring(Vector2(0.35, -0.3), 0.45)
		_:
			pen.dot(Vector2.ZERO, 0.5)


static func _texture(icon: StringName) -> Texture2D:
	if not _textures.has(icon):
		var path := ICON_DIR % icon
		_textures[icon] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[icon]


static func _star(points: int, outer: float, inner: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in points * 2:
		var radius := outer if i % 2 == 0 else inner
		result.append(Vector2.UP.rotated(PI * i / points) * radius)
	return result


## from から to へ向かう、両側がふくらんだ葉の形。
static func _leaf(from: Vector2, to: Vector2) -> Array[Vector2]:
	var side := (to - from).orthogonal() * 0.28
	var result: Array[Vector2] = []
	for i in 9:
		var t := float(i) / 8.0
		result.append(from.lerp(to, t) + side * sin(t * PI))
	for i in range(7, 0, -1):
		var t := float(i) / 8.0
		result.append(from.lerp(to, t) - side * sin(t * PI))
	return result


static func _heart() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		result.append(Vector2(x, -y) / 17.0)
	return result


## 単位円（-1〜1）の座標で、縁取りつきの図形を描く道具。
class _Pen:
	const OUTLINE_RATE := 0.16
	const STROKE_RATE := 0.2

	var ci: CanvasItem
	var center: Vector2
	var scale: float
	var fill: Color

	func _init(target: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
		ci = target
		center = at
		scale = radius
		fill = color

	func _map(points: Array) -> PackedVector2Array:
		var result := PackedVector2Array()
		for point: Vector2 in points:
			result.append(center + point * scale)
		return result

	func poly(points: Array) -> void:
		var mapped := _map(points)
		ci.draw_colored_polygon(mapped, fill)
		mapped.append(mapped[0])
		ci.draw_polyline(mapped, LINE, scale * OUTLINE_RATE * 0.6, true)

	func line(points: Array, color := Color(0, 0, 0, 0)) -> void:
		thick(points, STROKE_RATE, color)

	func thick(points: Array, width: float, color := Color(0, 0, 0, 0)) -> void:
		var mapped := _map(points)
		ci.draw_polyline(mapped, LINE, scale * (width + OUTLINE_RATE), true)
		ci.draw_polyline(mapped, fill if color.a == 0.0 else color, scale * width, true)

	func dot(at: Vector2, radius: float, color := Color(0, 0, 0, 0)) -> void:
		var position := center + at * scale
		if color.a == 0.0:
			ci.draw_circle(position, scale * (radius + OUTLINE_RATE * 0.5), LINE)
		ci.draw_circle(position, scale * radius, fill if color.a == 0.0 else color)

	func ring(at: Vector2, radius: float) -> void:
		arc(at, radius, 0.0, TAU)

	func arc(at: Vector2, radius: float, from: float, to: float) -> void:
		var position := center + at * scale
		ci.draw_arc(position, scale * radius, from, to, 32, LINE, scale * (STROKE_RATE + OUTLINE_RATE), true)
		ci.draw_arc(position, scale * radius, from, to, 32, fill, scale * STROKE_RATE, true)
