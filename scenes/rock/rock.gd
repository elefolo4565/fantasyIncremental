class_name Rock
extends Breakable
## 壊せる岩。壊すと石が手に入り、しばらくすると元に戻る。

const RADIUS := 36.0
const COLOR := Color(0.58, 0.52, 0.46)
const SHADE_COLOR := Color(0.46, 0.41, 0.36)


func kind() -> StringName:
	return Stats.ROCK


func radius() -> float:
	return RADIUS


func respawn_time() -> float:
	return Balance.get_float("rock_respawn_time")


func _draw_body(flash_amount: float) -> void:
	draw_circle(Vector2(0, 4), RADIUS, SHADE_COLOR.lerp(FLASH_COLOR, flash_amount))
	draw_circle(Vector2(0, -2), RADIUS - 4.0, COLOR.lerp(FLASH_COLOR, flash_amount))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, OUTLINE_COLOR, 3.0)
