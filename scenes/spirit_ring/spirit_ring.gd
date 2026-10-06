class_name SpiritRing
extends Node2D
## 精霊の輪（ラン限定の強化）。プレイヤーの周りを玉が回り、触れた物の耐久を減らす。
## レベル＝玉の数。レベルはそのランの間だけ続く。

const ORB_COLOR := Color(0.7, 1.0, 0.85)
const ORB_CORE := Color(1, 1, 1)
const TRAIL_COLOR := Color(0.7, 1.0, 0.85, 0.18)

var level := 0:
	set(value):
		level = value
		queue_redraw()

var _angle := 0.0
## 物の instance_id → 次に当たれるまでの残り時間
var _cooldowns: Dictionary = {}


func _physics_process(delta: float) -> void:
	_angle = wrapf(_angle + Balance.get_float("ring_orbit_speed") * delta, 0.0, TAU)
	for id: int in _cooldowns.keys():
		_cooldowns[id] = float(_cooldowns[id]) - delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	queue_redraw()
	if level <= 0:
		return
	var damage := roundi(Balance.get_float("ring_damage") + Stats.effect(&"ring_power", Progress.levels))
	var orb_radius := Balance.get_float("ring_orb_radius")
	for i in level:
		var orb := global_position + _orb_offset(i)
		for node in get_tree().get_nodes_in_group(Breakable.GROUP):
			var target := node as Breakable
			if target == null or not target.is_alive() or _cooldowns.has(target.get_instance_id()):
				continue
			if orb.distance_to(target.global_position) <= orb_radius + target.radius():
				_cooldowns[target.get_instance_id()] = Balance.get_float("ring_hit_cooldown")
				target.take_hit(damage)


func _draw() -> void:
	if level <= 0:
		return
	var orbit := Balance.get_float("ring_orbit_radius")
	var orb_radius := Balance.get_float("ring_orb_radius")
	draw_arc(Vector2.ZERO, orbit, 0.0, TAU, 48, TRAIL_COLOR, 6.0)
	for i in level:
		var at := _orb_offset(i)
		draw_circle(at, orb_radius, ORB_COLOR)
		draw_circle(at, orb_radius * 0.45, ORB_CORE)


func _orb_offset(index: int) -> Vector2:
	var orbit := Balance.get_float("ring_orbit_radius")
	return Vector2.RIGHT.rotated(_angle + TAU * index / maxi(level, 1)) * orbit
