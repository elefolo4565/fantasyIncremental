class_name SpriteSheet
extends RefCounted
## 3Dモデルを焼いた絵（行が向き、列が動きのコマ）から、向きと動きに合ったコマを切り出して描く道具。
## 絵の作り方は tools/render_enemies/README.md。コマの大きさや足元の位置は焼く側と合わせる。

const CELL := 128
## 当たって光るときの色（1より大きい値で明るくする）
const FLASH_TINT := Color(1.9, 1.9, 1.7)


## facing の向きのコマを、足元が foot_at に来るように描く。phase は動きの1周（0〜1）、flash は 0〜1。
## directions が 1 のときは向きを見ない。pixel は絵の1ピクセルをこの座標で何単位に描くか。
static func draw(ci: CanvasItem, sheet: Texture2D, facing: Vector2, phase: float, foot_at: Vector2,
		foot: Vector2, pixel: float, directions: int, frames: int, flash := 0.0) -> void:
	var direction := 0
	if directions > 1:
		direction = wrapi(roundi(facing.angle() / (TAU / directions)), 0, directions)
	var frame := wrapi(int(phase * frames), 0, frames)
	var source := Rect2(frame * CELL, direction * CELL, CELL, CELL)
	var at := foot_at - foot * pixel
	ci.draw_texture_rect_region(sheet, Rect2(at, Vector2.ONE * CELL * pixel), source, Color.WHITE.lerp(FLASH_TINT, flash))
