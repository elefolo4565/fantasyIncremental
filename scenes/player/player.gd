class_name Player
extends CharacterBody2D
## プレイヤー。スティックかキーボードで動き、近くの壊せる物へ魔法弾を自動で撃つ。

const BOLT_SCENE := preload("res://scenes/bolt/bolt.tscn")
const RADIUS := 20.0
const COLOR := Color(0.95, 0.85, 0.4)

var stick: VirtualStick

var _fire_cooldown := 0.0


func _physics_process(delta: float) -> void:
	velocity = _read_move_input() * Balance.get_float("player_speed")
	move_and_slide()
	var area := get_viewport_rect().size
	global_position = global_position.clamp(Vector2(RADIUS, RADIUS), area - Vector2(RADIUS, RADIUS))

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		var target := _find_target()
		if target != null:
			_fire_at(target)
			_fire_cooldown = Balance.get_float("fire_interval")


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, COLOR)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(0.3, 0.2, 0.1), 3.0)


func _read_move_input() -> Vector2:
	if stick != null and stick.value != Vector2.ZERO:
		return stick.value
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		dir = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	return dir.limit_length(1.0)


func _find_target() -> Node2D:
	var best: Node2D = null
	var best_distance := Balance.get_float("fire_range")
	for node in get_tree().get_nodes_in_group(Rock.GROUP):
		var candidate := node as Node2D
		if candidate == null:
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _fire_at(target: Node2D) -> void:
	var bolt := BOLT_SCENE.instantiate() as Bolt
	bolt.direction = global_position.direction_to(target.global_position)
	get_parent().add_child(bolt)
	bolt.global_position = global_position
