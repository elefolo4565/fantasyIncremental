class_name Grass
extends Node2D
## 平原の草地。中にいるあいだはプレイヤーの移動が遅くなり、魔法弾も遅くなって射程を余計に使う。
## 草地どうしは Grass.rate_at() で調べる（グループ Grass.GROUP に入る）。

const GROUP := &"grass"
const BASE_COLOR := Color(0.24, 0.5, 0.16, 0.75)
const TUFT_COLOR := Color(0.2, 0.44, 0.12)
const TIP_COLOR := Color(0.42, 0.7, 0.24)
const TUFTS_PER_AREA := 1.0 / 650.0

## 草地の半径（ピクセル）。生成する側が add_child の前に入れる
var radius := 60.0

var _tufts: Array[Vector2] = []


func _ready() -> void:
	add_to_group(GROUP)
	var count := int(PI * radius * radius * TUFTS_PER_AREA)
	for _i in count:
		var spot := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius * 0.9
		_tufts.append(spot)
	_tufts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)


func contains(point: Vector2) -> bool:
	return global_position.distance_to(point) <= radius


## point が草地の中なら rate を、外なら 1 を返す（速さに掛ける倍率）。
static func rate_at(tree: SceneTree, point: Vector2, rate: float) -> float:
	for node in tree.get_nodes_in_group(GROUP):
		var grass := node as Grass
		if grass != null and grass.contains(point):
			return rate
	return 1.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 4.0, Color(Toon.OUTLINE, 0.35))
	draw_circle(Vector2.ZERO, radius, BASE_COLOR)
	for spot in _tufts:
		draw_line(spot, spot + Vector2(-7, -15), TUFT_COLOR, 4.0)
		draw_line(spot, spot + Vector2(0, -19), TUFT_COLOR, 4.0)
		draw_line(spot, spot + Vector2(7, -15), TUFT_COLOR, 4.0)
		draw_circle(spot + Vector2(0, -19), 2.0, TIP_COLOR)
