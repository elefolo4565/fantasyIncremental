class_name Player
extends CharacterBody2D
## プレイヤー。スティックかキーボードで動き、近くの壊せる物へ魔法弾を自動で撃つ。
## 魔導樹の Twin Bolt で1度に撃つ数が増え、Focus で数発ごとに強い1発になる。

const BOLT_SCENE := preload("res://scenes/bolt/bolt.tscn")
const RADIUS := 20.0
const COLOR := Color(0.95, 0.85, 0.4)

var stick: VirtualStick

var _fire_cooldown := 0.0
var _shot_count := 0


func _physics_process(delta: float) -> void:
	velocity = _read_move_input() * Balance.get_float("player_speed")
	move_and_slide()
	var area := get_viewport_rect().size
	global_position = global_position.clamp(Vector2(RADIUS, RADIUS), area - Vector2(RADIUS, RADIUS))

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		var bolt_count := 1 + roundi(Stats.effect(&"twin", Progress.levels))
		var targets := _find_targets(bolt_count)
		if not targets.is_empty():
			_fire_volley(targets, bolt_count)
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


## 射程内の壊せる物を近い順に最大 count 個返す。
func _find_targets(count: int) -> Array[Breakable]:
	var in_range: Array[Breakable] = []
	var fire_range := Balance.get_float("fire_range")
	for node in get_tree().get_nodes_in_group(Breakable.GROUP):
		var candidate := node as Breakable
		if candidate != null and global_position.distance_to(candidate.global_position) < fire_range:
			in_range.append(candidate)
	in_range.sort_custom(func(a: Breakable, b: Breakable) -> bool:
		return global_position.distance_squared_to(a.global_position) \
				< global_position.distance_squared_to(b.global_position))
	return in_range.slice(0, count)


## 狙える相手が足りない分は、一番近い相手の左右にずらして撃つ。
func _fire_volley(targets: Array[Breakable], bolt_count: int) -> void:
	var spread := deg_to_rad(Balance.get_float("twin_spread"))
	var focus_every := maxi(Balance.get_int("focus_every"), 1)
	var has_focus := Stats.effect(&"focus", Progress.levels) > 0.0
	for i in bolt_count:
		var dir := global_position.direction_to(targets[mini(i, targets.size() - 1)].global_position)
		if i >= targets.size():
			var extra := i - targets.size() + 1
			dir = dir.rotated(spread * ceilf(extra / 2.0) * (1.0 if extra % 2 == 1 else -1.0))
		_shot_count += 1
		var bolt := BOLT_SCENE.instantiate() as Bolt
		bolt.direction = dir
		bolt.focused = has_focus and _shot_count % focus_every == 0
		get_parent().add_child(bolt)
		bolt.global_position = global_position
