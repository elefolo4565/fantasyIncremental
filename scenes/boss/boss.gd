class_name Boss
extends Slime
## ステージのボス（大きなスライムの王）。決まった数の敵を倒すと現れ、倒すとステージクリア。
## いつもプレイヤーを追いかけ、湧き直さない。

const SCALE := 1.9
const KING_COLOR := Color(0.62, 0.42, 1.0)
const CROWN_COLOR := Color(1.0, 0.82, 0.2)
const BOSS_BAR_COLOR := Color(1.0, 0.25, 0.55)
## 王冠に体力バーが重ならないように持ち上げる量
const CROWN_CLEARANCE := 16.0


func radius() -> float:
	return RADIUS * SCALE


func bar_lift() -> float:
	return super() + CROWN_CLEARANCE


func respawns() -> bool:
	return false


func _choose_direction(_delta: float) -> Vector2:
	_chasing = target != null
	return global_position.direction_to(target.global_position) if _chasing else Vector2.ZERO


func _body_color() -> Color:
	return KING_COLOR


func _bar_color() -> Color:
	return BOSS_BAR_COLOR


func _draw_body(flash_amount: float) -> void:
	super(flash_amount)
	# 頭の王冠
	var base_y := -RADIUS * 0.45
	var crown := PackedVector2Array([
		Vector2(-16, base_y), Vector2(-19, base_y - 18), Vector2(-8, base_y - 9), Vector2(0, base_y - 22),
		Vector2(8, base_y - 9), Vector2(19, base_y - 18), Vector2(16, base_y)])
	Toon.polygon(self, crown, CROWN_COLOR.lerp(FLASH_COLOR, flash_amount))
