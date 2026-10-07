class_name ChaseMove
extends MonsterMove
## いつもプレイヤーを追いかける（ボス向け）。速さは slime_chase_multiplier 倍。いつも怒り顔。


func step(_delta: float) -> Vector2:
	return direction_to_target() * monster.speed * Balance.get_float("slime_chase_multiplier")


func is_angry() -> bool:
	return monster.target != null
