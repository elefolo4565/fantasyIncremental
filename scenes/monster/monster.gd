class_name Monster
extends Breakable
## 敵（モンスター）。稼ぎの元であり、同時に脅威でもある。種類は data/enemies.csv の1行（def）で決まる。
## 動きは部品（MonsterMove。scenes/monster/moves/）に任せ、ここは移動・画面の端・プレイヤーとの接触・絵を受け持つ。
## 物理の層は enemy（2番）で、プレイヤーと木（world、1番）にだけぶつかる。敵同士はぶつからず重なって通り抜ける。
## enemies.csv の shot 列に弾（data/shots.csv）があれば、動きとは別に MonsterShooter で弾を撃つ。
## 触れると touched_player を出す（ダメージは Run が与える）。壊すと宝石が手に入り、ボスでなければプレイヤーから離れた場所に湧き直す。
## 魔導樹の「黄金スライム」があると、金色になれる種類（golden）は湧くたびに golden_chance の確率で金色になる。

signal touched_player(monster: Monster)
## 撃った弾がプレイヤーに当たった（ダメージは Run が与える）
signal shot_hit(damage: int, from: Vector2)

## 絵は体の半径がこの大きさのときに合わせて焼いてある。体の大きい敵は、その分だけ拡大して描く。
const SPRITE_RADIUS := 34.0
const SHEET_DIRECTIONS := 8
const SHEET_FRAMES := 4
## コマの中で足元が来る位置（render_enemies.gd の FOOT と合わせる）。
const SHEET_FOOT := Vector2(64, 104)
## 絵の1ピクセルを、この体の座標で何単位に描くか。
const SHEET_PIXEL := 1.0
const FOOT_Y := 30.0
## 跳ねる動きの速さ（1秒に何周するか）
const BOUNCE_RATE := 1.3
const EDGE_MARGIN := 40.0
const TOP_MARGIN := 140.0
const SPAWN_TRIES := 30
## 弾を撃つ前の予備動作で足元に出す輪の色（見た目だけ）
const WINDUP_COLOR := Color(1.0, 0.3, 0.2, 0.6)

## 生成する側が add_child の前に入れる
var def: EnemyDef
var target: Node2D
var speed := 0.0
var contact_damage := 1
## ボスは湧き直さない
var is_boss := false
## 湧くたびに金色になる確率（0〜1）
var golden_chance := 0.0
var golden := false

var _move: MonsterMove
var _shooter: MonsterShooter
var _bob := 0.0
var _placed := false
var _facing := Vector2.DOWN


func _ready() -> void:
	_move = MonsterMove.create(def.move)
	_move.monster = self
	var shot_def := Progress.shot(def.shot) if def.shot != &"" else null
	if shot_def != null:
		_shooter = MonsterShooter.new()
		_shooter.monster = self
		_shooter.def = shot_def
	var circle := CircleShape2D.new()
	circle.radius = def.size
	_shape.shape = circle
	super()


func kind() -> StringName:
	return Stats.MONSTER


func radius() -> float:
	return def.size


func respawn_time() -> float:
	return Balance.get_float("slime_respawn_time")


## 大きい敵（ボス）は頭の上の余白もその分だけ広げる。
func head_lift() -> float:
	return radius() + HEAD_GAP * _body_scale()


func respawns() -> bool:
	return not is_boss


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_bob += delta
	velocity = _move.step(delta)
	move_and_slide()
	_update_facing()
	if _shooter != null:
		_shooter.step(delta)
	var area := get_viewport_rect().size
	var clamped := position.clamp(Vector2(EDGE_MARGIN, TOP_MARGIN), area - Vector2(EDGE_MARGIN, EDGE_MARGIN))
	if clamped != position:
		position = clamped
		_move.on_edge()
	queue_redraw()
	if target != null and _move.can_touch() and global_position.distance_to(target.global_position) \
			<= (radius() + Balance.get_float("slime_touch_reach")) * scale.x + _move.touch_bonus():
		touched_player.emit(self)


## 部品が向きを決めていなければ、怒っているときはプレイヤーのほうを、そうでなければ進む向きを向く。止まっているときは向きを変えない。
func _update_facing() -> void:
	var forced := _move.facing()
	if forced != Vector2.ZERO:
		_facing = forced
	elif _move.is_angry() and target != null:
		_facing = global_position.direction_to(target.global_position)
	elif velocity.length_squared() > 1.0:
		_facing = velocity.normalized()


## いま向いている向き（弾の「向いている向きに撃つ」で使う）。
func facing() -> Vector2:
	return _facing


func on_shot_hit(damage: int, from: Vector2) -> void:
	shot_hit.emit(damage, from)


func _body_scale() -> float:
	return radius() / SPRITE_RADIUS


func _sheet() -> Texture2D:
	if golden:
		return def.sheet(&"golden")
	return def.sheet(&"angry") if _move.is_angry() else def.sheet()


func _respawn() -> void:
	if _placed and target != null:
		position = _far_spot()
	_placed = true
	golden = def.golden and randf() < golden_chance
	_move.reset()
	if _shooter != null:
		_shooter.reset()
	super()


## プレイヤーから離れた場所を選ぶ（湧いた瞬間に当たらないように）。
func _far_spot() -> Vector2:
	var area := get_viewport_rect().size
	var best := position
	var best_distance := 0.0
	for _i in SPAWN_TRIES:
		var spot := Vector2(randf_range(EDGE_MARGIN, area.x - EDGE_MARGIN), randf_range(TOP_MARGIN, area.y - EDGE_MARGIN))
		var distance := spot.distance_to(target.global_position)
		if distance > best_distance:
			best = spot
			best_distance = distance
		if distance > Balance.get_float("slime_aggro_range") * 1.5:
			return spot
	return best


func _draw_body(flash_amount: float) -> void:
	_move.draw_under()
	if _shooter != null and _shooter.windup_progress() >= 0.0:
		# 弾を撃つ前の予告: 足元の輪がだんだん縮む
		var k := _shooter.windup_progress()
		draw_arc(Vector2(0, FOOT_Y * 0.4), SPRITE_RADIUS * lerpf(1.8, 1.0, k), 0.0, TAU, 32, WINDUP_COLOR, 5.0)
	Toon.shadow(self, Vector2(0, SPRITE_RADIUS - 4.0), Vector2(SPRITE_RADIUS * 0.95, SPRITE_RADIUS * 0.32))
	# 跳んでいる最中などは絵だけ浮かせる（キャラの大きさの倍率は掛かっているので、高さは割り戻す）
	var lift := _move.lift() / maxf(scale.x, 0.01)
	SpriteSheet.draw(self, _sheet(), _facing, fmod(_bob * BOUNCE_RATE, 1.0), Vector2(0, FOOT_Y - lift),
			SHEET_FOOT, SHEET_PIXEL, SHEET_DIRECTIONS, SHEET_FRAMES, flash_amount, hp_fill())
