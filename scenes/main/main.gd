extends Node2D
## 試作用のステージ。プレイヤーと岩を置き、壊した岩の素材を数える。

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ROCK_SCENE := preload("res://scenes/rock/rock.tscn")
const EDGE_MARGIN := 80.0
const MIN_GAP := 130.0

var _material := 0

@onready var _stick: VirtualStick = $HUD/VirtualStick
@onready var _material_label: Label = $HUD/MaterialLabel


func _ready() -> void:
	var area := get_viewport_rect().size
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = area * 0.5
	player.stick = _stick
	add_child(player)

	var taken: Array[Vector2] = [player.position]
	for _i in Balance.get_int("rock_count"):
		var rock := ROCK_SCENE.instantiate() as Rock
		rock.position = _find_free_spot(area, taken)
		taken.append(rock.position)
		rock.broken.connect(_on_rock_broken)
		add_child(rock)
	_update_hud()


func _find_free_spot(area: Vector2, taken: Array[Vector2]) -> Vector2:
	var spot := Vector2.ZERO
	for _attempt in 40:
		spot = Vector2(
			randf_range(EDGE_MARGIN, area.x - EDGE_MARGIN),
			randf_range(EDGE_MARGIN, area.y - EDGE_MARGIN))
		var ok := true
		for other in taken:
			if spot.distance_to(other) < MIN_GAP:
				ok = false
				break
		if ok:
			return spot
	return spot


func _on_rock_broken(_rock: Rock) -> void:
	_material += Balance.get_int("rock_material")
	_update_hud()


func _update_hud() -> void:
	_material_label.text = "Material: %d" % _material
