extends Node
## 効果音。魔王魂の効果音（出どころとクレジットは assets/audio/README.md）を鳴らす。
## オン/オフは Progress.se_on（保存する）。
## 使い方: Sfx.play(&"hit")

## オートロードは素材の取り込みより先に読まれるので、preload ではなく起動後に load する
const SOUNDS := {
	&"boss_break": "res://assets/audio/se/se_boss_break_maoudamashii_battle_explosion05.ogg",
	&"break": "res://assets/audio/se/se_break_maoudamashii_8bit16.ogg",
	&"buy": "res://assets/audio/se/se_buy_maoudamashii_system03.ogg",
	&"clear": "res://assets/audio/se/se_clear_maoudamashii_jingle04.ogg",
	&"click": "res://assets/audio/se/se_click_maoudamashii_system24.ogg",
	&"deny": "res://assets/audio/se/se_deny_maoudamashii_system25.ogg",
	&"hit": "res://assets/audio/se/se_hit_maoudamashii_battle14.ogg",
	&"hurt": "res://assets/audio/se/se_hurt_maoudamashii_battle12.ogg",
	&"pickup": "res://assets/audio/se/se_pickup_maoudamashii_system18.ogg",
	&"ring": "res://assets/audio/se/se_ring_maoudamashii_magic_ice02.ogg",
	&"shot": "res://assets/audio/se/se_shot_maoudamashii_magical19.ogg",
	&"timeup": "res://assets/audio/se/se_timeup_maoudamashii_jingle06.ogg",
}
const VOICES := 12
## 時計の「チッ」という音はファイルを使わずに作る（短く減衰する高い音。見た目と同じく音色だけの定数）
const TICK_RATE := 22050
const TICK_LENGTH := 0.05
const TICK_FREQ := 1800.0
const TICK_DECAY := 90.0
const TICK_GAIN := 0.6

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for _i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for sound: StringName in SOUNDS:
		_streams[sound] = load(SOUNDS[sound])
	_streams[&"tick"] = _make_tick()


func play(sound: StringName, pitch_jitter := 0.0, volume_db := 0.0, pitch := 1.0) -> void:
	if not Progress.se_on:
		return
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		push_warning("効果音がありません: %s" % sound)
		return
	# 音の出ない環境（CI のヘッドレス実行）では鳴らさない。鳴らすと終了時に音が解放されずエラーが出る
	if AudioServer.get_driver_name() == "Dummy":
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	player.volume_db = volume_db
	player.play()


## 時計の音（16bit モノラルの短い音）を作る。
func _make_tick() -> AudioStreamWAV:
	var count := int(TICK_RATE * TICK_LENGTH)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / TICK_RATE
		var sample := sin(TAU * TICK_FREQ * t) * exp(-TICK_DECAY * t) * TICK_GAIN
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = TICK_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _exit_tree() -> void:
	# 終了時に音を持ったままだと「resources still in use at exit」と出るので手放す
	for player in _players:
		player.stop()
		player.stream = null
	_streams.clear()
