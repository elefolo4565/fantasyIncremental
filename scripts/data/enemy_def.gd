class_name EnemyDef
extends RefCounted
## 敵1種類分の定義（data/enemies.csv の1行）。
## 耐久・宝石・速さはステージの基準（stages.csv の enemy_* か boss_*）に、ここの倍率を掛けて決まる。
## 絵は assets/sprites/enemies/<id>.png（ふだん）・<id>_angry.png（怒っているとき）・<id>_golden.png（金色）。
## 焼き方は tools/render_enemies/README.md。

const SPRITE_DIR := "res://assets/sprites/enemies/"
const FALLBACK_SHEET := "res://assets/sprites/enemies/slime.png"

var id: StringName
var name := ""
## 動きの部品の名前（MonsterMove.create に渡す）
var move: StringName
## 体の半径（当たり判定。ピクセル、キャラの大きさの倍率を掛ける前）
var size := 34.0
var hp_rate := 1.0
var gem_rate := 1.0
var speed_rate := 1.0
var contact_damage := 1
## 魔導樹の「黄金スライム」で金色になるか
var golden := false
## 焼くときの仮モデルの形（tools/render_enemies/placeholder_monster.gd）
var model: StringName
## 体の色（倒したときの破片の色にも使う）
var color := Color.WHITE
var angry_color := Color.WHITE
var memo := ""

var _sheets: Dictionary = {}


static func from_row(row: Dictionary) -> EnemyDef:
	var def := EnemyDef.new()
	def.id = StringName(row.get("id", ""))
	def.name = row.get("name", "")
	def.move = StringName(row.get("move", ""))
	def.size = maxf(String(row.get("size", "34")).to_float(), 1.0)
	def.hp_rate = String(row.get("hp_rate", "1")).to_float()
	def.gem_rate = String(row.get("gem_rate", "1")).to_float()
	def.speed_rate = String(row.get("speed_rate", "1")).to_float()
	def.contact_damage = String(row.get("contact_damage", "1")).to_int()
	def.golden = String(row.get("golden", "0")).to_int() != 0
	def.model = StringName(row.get("model", "slime"))
	def.color = _parse_color(row.get("color", ""), Color.WHITE)
	def.angry_color = _parse_color(row.get("angry_color", ""), def.color)
	def.memo = row.get("memo", "")
	return def


## enemies.csv の1行に戻す（敵エディタが書き出すとき）。
func to_row() -> Dictionary:
	return {
		"id": String(id), "name": name, "move": String(move), "size": _num(size),
		"hp_rate": _num(hp_rate), "gem_rate": _num(gem_rate), "speed_rate": _num(speed_rate),
		"contact_damage": str(contact_damage), "golden": "1" if golden else "0", "model": String(model),
		"color": color.to_html(false), "angry_color": angry_color.to_html(false), "memo": memo,
	}


func copy() -> EnemyDef:
	return EnemyDef.from_row(to_row())


## 小数の末尾の 0 を落とした書き方（1.50 → 1.5、2.0 → 2）。
static func _num(value: float) -> String:
	var text := "%.2f" % value
	return text.rstrip("0").rstrip(".")


## "4dc7ff" のような16進の色。書かれていない・読めないときは fallback。
static func _parse_color(text: String, fallback: Color) -> Color:
	return Color.html(text) if Color.html_is_valid(text) else fallback


## ステージの基準の耐久に倍率を掛けたもの（1以上）。
func hp_from(base: int) -> int:
	return maxi(roundi(base * hp_rate), 1)


func gem_from(base: int) -> int:
	return maxi(roundi(base * gem_rate), 0)


func speed_from(base: float) -> float:
	return base * speed_rate


## variant は &""（ふだん）・&"angry"・&"golden"。その絵がなければふだんの絵を返す。
func sheet(variant: StringName = &"") -> Texture2D:
	if _sheets.has(variant):
		return _sheets[variant]
	var path := SPRITE_DIR + String(id) + ("_" + String(variant) if variant != &"" else "") + ".png"
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif variant != &"":
		texture = sheet()
	else:
		# まだ焼いていない新しい敵（敵エディタで足したばかりなど）は、スライムの絵で代わりに見せる
		push_warning("敵の絵 %s がまだありません（tools/render_enemies で焼く）。スライムの絵で代わりに出します" % path)
		texture = load(FALLBACK_SHEET) as Texture2D
	_sheets[variant] = texture
	return texture
