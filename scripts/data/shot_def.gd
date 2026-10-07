class_name ShotDef
extends RefCounted
## 敵の弾の撃ち方1つ分の定義（data/shots.csv の1行）。敵は enemies.csv の shot 列でこれを選ぶ。
## kind（弾の種類）: bullet 弾丸 / arrow 矢じり / wave ウェーブ / bomb 爆弾 / laser レーザー
## aim（狙い）: player プレイヤーを狙う / fixed 決まった向き（direction）/ facing 敵が向いている向き
## pattern（撃ち方）: fan 扇状に同時 / ring 全方位に同時 / burst 同じ向きに続けて / spiral 向きを回しながら続けて

var id: StringName
var name := ""
var kind: StringName
var aim: StringName
var pattern: StringName
## 1回に撃つ数
var count := 1
## 扇の広がり（度）。ring は使わない（いつも全方位）。spiral は1回ぶんで回る角度
var spread := 0.0
## aim が fixed のときの向き（度。0 が右、90 が下）
var direction := 90.0
## 撃ってから次に撃ち始めるまでの間（秒）
var interval := 2.0
## burst・spiral で1発ずつ撃つ間（秒）
var burst_gap := 0.1
## 撃つ前の予備動作（秒）。このあいだ敵の足元に予告の輪が出る（レーザーは予告の線）
var windup := 0.4
## 弾の速さ（ピクセル/秒）
var speed := 200.0
## 弾の半径（ピクセル）。爆弾は爆発の半径、レーザーは光線の太さの半分
var size := 8.0
## 届く距離（ピクセル）。弾はここで消え、レーザーはこの長さ、爆弾はこれより遠くへは投げない
var reach := 600.0
var damage := 1
## プレイヤーがこの距離より近いときだけ撃つ（ピクセル。0 ならいつも）
var start_range := 0.0
var color := Color.WHITE
var memo := ""


static func from_row(row: Dictionary) -> ShotDef:
	var def := ShotDef.new()
	def.id = StringName(row.get("id", ""))
	def.name = row.get("name", "")
	def.kind = StringName(row.get("kind", "bullet"))
	def.aim = StringName(row.get("aim", "player"))
	def.pattern = StringName(row.get("pattern", "fan"))
	def.count = maxi(String(row.get("count", "1")).to_int(), 1)
	def.spread = String(row.get("spread", "0")).to_float()
	def.direction = String(row.get("direction", "90")).to_float()
	def.interval = maxf(String(row.get("interval", "2")).to_float(), 0.1)
	def.burst_gap = maxf(String(row.get("burst_gap", "0.1")).to_float(), 0.0)
	def.windup = maxf(String(row.get("windup", "0.4")).to_float(), 0.0)
	def.speed = String(row.get("speed", "200")).to_float()
	def.size = maxf(String(row.get("size", "8")).to_float(), 1.0)
	def.reach = maxf(String(row.get("reach", "600")).to_float(), 10.0)
	def.damage = String(row.get("damage", "1")).to_int()
	def.start_range = String(row.get("start_range", "0")).to_float()
	def.color = EnemyDef._parse_color(row.get("color", ""), Color.WHITE)
	def.memo = row.get("memo", "")
	return def


## shots.csv の1行に戻す（敵エディタが書き出すとき）。
func to_row() -> Dictionary:
	return {
		"id": String(id), "name": name, "kind": String(kind), "aim": String(aim), "pattern": String(pattern),
		"count": str(count), "spread": EnemyDef._num(spread), "direction": EnemyDef._num(direction),
		"interval": EnemyDef._num(interval), "burst_gap": EnemyDef._num(burst_gap), "windup": EnemyDef._num(windup),
		"speed": EnemyDef._num(speed), "size": EnemyDef._num(size), "reach": EnemyDef._num(reach),
		"damage": str(damage), "start_range": EnemyDef._num(start_range), "color": color.to_html(false), "memo": memo,
	}


func copy() -> ShotDef:
	return ShotDef.from_row(to_row())


## 1回ぶんの弾の向き（ラジアン）を、撃つ順に並べて返す。base は狙いの向き、turn は spiral の回り具合。
func angles(base: float, turn: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	match pattern:
		&"ring":
			for i in count:
				result.append(base + TAU * i / count)
		&"spiral":
			for i in count:
				result.append(base + turn + deg_to_rad(spread) * i / count)
		&"burst":
			for i in count:
				result.append(base)
		_:
			for i in count:
				var t := 0.0 if count == 1 else float(i) / (count - 1) - 0.5
				result.append(base + deg_to_rad(spread) * t)
	return result


## 1発ずつ間を空けて撃つ撃ち方か（そうでなければ同時に撃つ）。
func is_sequential() -> bool:
	return pattern == &"burst" or pattern == &"spiral"
