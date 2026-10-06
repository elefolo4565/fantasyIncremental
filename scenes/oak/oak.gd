class_name Oak
extends Breakable
## 森の木。壊すと木材が手に入る。しばらく叩かずにいると耐久が少しずつ戻る（魔導樹の Withering で止まる）。

const RADIUS := 40.0
const CANOPY_CENTER := Vector2(0, -8)
const CANOPY_RADIUS := 34.0
const TRUNK_COLOR := Color(0.45, 0.3, 0.18)
const LEAF_COLOR := Color(0.2, 0.5, 0.22)
const LEAF_LIGHT := Color(0.32, 0.64, 0.3)
const REGEN_COLOR := Color(0.6, 1.0, 0.6)

var _since_hit := 0.0
var _regen_timer := 0.0


func kind() -> StringName:
	return Stats.OAK


func radius() -> float:
	return RADIUS


func respawn_time() -> float:
	return Balance.get_float("oak_respawn_time")


func _process(delta: float) -> void:
	super(delta)
	if hp <= 0 or hp >= max_hp or Stats.effect(&"withering", Progress.levels) > 0.0:
		return
	_since_hit += delta
	if _since_hit < Balance.get_float("oak_regen_delay"):
		return
	_regen_timer += delta
	var interval := maxf(Balance.get_float("oak_regen_interval"), 0.05)
	if _regen_timer >= interval:
		_regen_timer -= interval
		hp = mini(hp + 1, max_hp)
		queue_redraw()


func _on_hit() -> void:
	_since_hit = 0.0
	_regen_timer = 0.0


func _draw_body(flash_amount: float) -> void:
	draw_rect(Rect2(-8, 12, 16, 28), TRUNK_COLOR.lerp(FLASH_COLOR, flash_amount))
	draw_circle(CANOPY_CENTER, CANOPY_RADIUS, LEAF_COLOR.lerp(FLASH_COLOR, flash_amount))
	draw_circle(CANOPY_CENTER + Vector2(-9, -9), CANOPY_RADIUS * 0.5, LEAF_LIGHT.lerp(FLASH_COLOR, flash_amount))
	var outline := OUTLINE_COLOR
	if hp < max_hp and _since_hit >= Balance.get_float("oak_regen_delay") \
			and Stats.effect(&"withering", Progress.levels) <= 0.0:
		outline = REGEN_COLOR
	draw_arc(CANOPY_CENTER, CANOPY_RADIUS, 0.0, TAU, 32, outline, 3.0)
