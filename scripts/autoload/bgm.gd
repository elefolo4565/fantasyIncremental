extends Node
## 仮の BGM。画面ごとの曲をループで流し、切り替えるときは前の曲を小さくしてから次の曲にする。
## 曲は assets/audio/ の自作ループ（出どころは assets/audio/README.md）。オン/オフは Progress.bgm_on（保存する）。
## Web ではブラウザの決まりで、最初に画面に触れるまで音は出ない。
## 使い方: Bgm.play(&"battle")

## オートロードは素材の取り込みより先に読まれるので、preload ではなく使うときに load する
const TRACKS := {
	&"tree": "res://assets/audio/bgm_tree.ogg",
	&"battle": "res://assets/audio/bgm_battle.ogg",
	&"boss": "res://assets/audio/bgm_boss.ogg",
}
const SILENT_DB := -40.0

var _player: AudioStreamPlayer
var _current := &""
var _fade: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	Progress.changed.connect(_apply_enabled)


func play(track: StringName) -> void:
	if track == _current or not TRACKS.has(track):
		return
	_current = track
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	if _player.playing:
		_fade.tween_property(_player, "volume_db", SILENT_DB, Balance.get_float("bgm_fade_time"))
	_fade.tween_callback(_start.bind(track))


func _start(track: StringName) -> void:
	_player.stream = load(TRACKS[track])
	_player.volume_db = Balance.get_float("bgm_volume_db")
	# 音の出ない環境（CI のヘッドレス実行）では鳴らさない。鳴らすと終了時に曲が解放されずエラーが出る
	if Progress.bgm_on and AudioServer.get_driver_name() != "Dummy":
		_player.play()


func _apply_enabled() -> void:
	if Progress.bgm_on and not _player.playing and _current != &"":
		_start(_current)
	elif not Progress.bgm_on and _player.playing:
		_player.stop()

