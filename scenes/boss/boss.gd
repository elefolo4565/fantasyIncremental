class_name Boss
extends Slime
## ステージのボス（大きなスライムの王）。決まった数の敵を倒すと現れ、倒すとステージクリア。
## いつもプレイヤーを追いかけ、湧き直さない。

const SCALE := 1.9
## 王冠をかぶった紫のスライム（いつも怒り顔）。
const BOSS_SHEET := preload("res://assets/sprites/enemies/boss.png")
## 体の色（倒したときの破片の色に使う）
const KING_COLOR := Color(0.62, 0.42, 1.0)
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


func _sheet() -> Texture2D:
	return BOSS_SHEET


func _bar_color() -> Color:
	return BOSS_BAR_COLOR

