class_name MonsterMove
extends RefCounted
## 敵の動きの部品の基底。Monster が毎フレーム step を呼び、返った速度で動く。
## 新しい動きは、これを継承したスクリプトをこのフォルダに置き、create に名前を足す。
## 敵ごとにどの部品を使うかは data/enemies.csv の move 列で決める。部品の数値は data/balance.csv に置く。

var monster: Monster


static func create(id: StringName) -> MonsterMove:
	match id:
		&"wander_chase":
			return WanderChaseMove.new()
		&"dash":
			return DashMove.new()
		&"chase":
			return ChaseMove.new()
		&"keep_away":
			return KeepAwayMove.new()
		&"zigzag":
			return ZigzagMove.new()
		&"orbit":
			return OrbitMove.new()
		&"jump":
			return JumpMove.new()
		&"flee":
			return FleeMove.new()
	push_error("敵の動き %s がありません（scenes/monster/moves/monster_move.gd の create）" % id)
	return WanderChaseMove.new()


## 湧いたとき（湧き直したときも）に呼ばれる。
func reset() -> void:
	pass


## この先1フレームの速度（ピクセル/秒）を返す。
func step(_delta: float) -> Vector2:
	return Vector2.ZERO


## 怒り顔の絵にするか。
func is_angry() -> bool:
	return false


## 向く方向。Vector2.ZERO なら Monster の決まり（怒っているときはプレイヤー、ほかは進む向き）に任せる。
func facing() -> Vector2:
	return Vector2.ZERO


## プレイヤーに触れて当たりになるか（跳んでいる最中などは false）。
func can_touch() -> bool:
	return true


## 当たりの届く距離に足す長さ（ピクセル。着地の衝撃など）。
func touch_bonus() -> float:
	return 0.0


## 体の絵を浮かせる高さ（ピクセル。跳んでいる最中など。見た目だけで、影と当たりは地面のまま）。
func lift() -> float:
	return 0.0


## 画面の端にぶつかったときに呼ばれる。
func on_edge() -> void:
	pass


## 体の絵より下に描くもの（予告の線など）。monster の座標で描く。
func draw_under() -> void:
	pass


## プレイヤーまでの距離。プレイヤーがいなければとても大きな値。
func distance_to_target() -> float:
	if monster.target == null:
		return INF
	return monster.global_position.distance_to(monster.target.global_position)


func direction_to_target() -> Vector2:
	if monster.target == null:
		return Vector2.ZERO
	return monster.global_position.direction_to(monster.target.global_position)
