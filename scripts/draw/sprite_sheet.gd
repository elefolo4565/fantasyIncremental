class_name SpriteSheet
extends RefCounted
## 3Dモデルを焼いた絵（行が向き、列が動きのコマ）から、向きと動きに合ったコマを切り出して描く道具。
## 絵の作り方は tools/render_enemies/README.md。コマの大きさや足元の位置は焼く側と合わせる。
## fill（0〜1）を渡すと、体の下から fill の高さまでを元の色、それより上を色の抜けた絵で描く（敵の残り体力の表示）。
## 色の抜けた絵は、元の絵から初めて使うときに1回だけ作って覚えておく。

const CELL := 128
## 当たって光るときの色（1より大きい値で明るくする）
const FLASH_TINT := Color(1.9, 1.9, 1.7)
## 色の抜けた絵の明るさ・コントラスト・彩度（1 で元のまま。見た目だけ）
const FADED_BRIGHTNESS := 1.15
const FADED_CONTRAST := 0.85
const FADED_SATURATION := 0.2

## 元の絵 → 色の抜けた絵
static var _faded: Dictionary = {}
## 元の絵 → コマの中で体が写っている上端と下端（ピクセル。Vector2(上, 下)）
static var _body_span: Dictionary = {}


## facing の向きのコマを、足元が foot_at に来るように描く。phase は動きの1周（0〜1）、flash は 0〜1。
## directions が 1 のときは向きを見ない。pixel は絵の1ピクセルをこの座標で何単位に描くか。
static func draw(ci: CanvasItem, sheet: Texture2D, facing: Vector2, phase: float, foot_at: Vector2,
		foot: Vector2, pixel: float, directions: int, frames: int, flash := 0.0, fill := 1.0) -> void:
	var direction := 0
	if directions > 1:
		direction = wrapi(roundi(facing.angle() / (TAU / directions)), 0, directions)
	var frame := wrapi(int(phase * frames), 0, frames)
	var source := Rect2(frame * CELL, direction * CELL, CELL, CELL)
	var at := foot_at - foot * pixel
	var tint := Color.WHITE.lerp(FLASH_TINT, flash)
	if fill >= 1.0:
		ci.draw_texture_rect_region(sheet, Rect2(at, Vector2.ONE * CELL * pixel), source, tint)
		return
	ci.draw_texture_rect_region(_faded_of(sheet), Rect2(at, Vector2.ONE * CELL * pixel), source, tint)
	if fill <= 0.0:
		return
	# 体の下端から fill の高さまでを、元の色の絵で上から重ねる
	var span: Vector2 = _body_span[sheet]
	var cut := floorf(lerpf(span.y, span.x, fill))
	var keep := Rect2(source.position + Vector2(0, cut), Vector2(CELL, CELL - cut))
	ci.draw_texture_rect_region(sheet, Rect2(at + Vector2(0, cut * pixel), keep.size * pixel), keep, tint)


## 色の抜けた絵を返す。初めてのときに作り、体の写っている範囲も一緒に測っておく。
static func _faded_of(sheet: Texture2D) -> Texture2D:
	if _faded.has(sheet):
		return _faded[sheet]
	var image := sheet.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var top := CELL
	var bottom := 0
	for y in range(0, image.get_height(), CELL):
		for x in range(0, image.get_width(), CELL):
			var used := image.get_region(Rect2i(x, y, CELL, CELL)).get_used_rect()
			if used.has_area():
				top = mini(top, used.position.y)
				bottom = maxi(bottom, used.end.y)
	_body_span[sheet] = Vector2(top, bottom) if bottom > top else Vector2(0, CELL)
	image.adjust_bcs(FADED_BRIGHTNESS, FADED_CONTRAST, FADED_SATURATION)
	var faded := ImageTexture.create_from_image(image)
	_faded[sheet] = faded
	return faded
