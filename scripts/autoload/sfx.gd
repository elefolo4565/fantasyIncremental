extends Node
## 仮の効果音。起動時に簡単な波形を合成して鳴らす（本番の素材が決まったら差し替える）。
## 使い方: Sfx.play(&"hit")

const MIX_RATE := 22050
const VOICES := 12

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for _i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	# [開始周波数, 終了周波数, 長さ(秒)] を並べた音符の列と、波形・ノイズの混ぜ具合
	_streams[&"hit"] = _synth([[1100.0, 620.0, 0.045]], 0.6, 0.15, 0.35)
	_streams[&"break"] = _synth([[220.0, 70.0, 0.2]], 0.3, 0.7, 0.6)
	_streams[&"buy"] = _synth([[523.0, 523.0, 0.07], [659.0, 659.0, 0.07], [784.0, 784.0, 0.07], [1047.0, 1047.0, 0.16]], 0.2, 0.0, 0.5)
	_streams[&"deny"] = _synth([[160.0, 120.0, 0.14]], 1.0, 0.1, 0.35)
	_streams[&"clear"] = _synth([[392.0, 392.0, 0.09], [523.0, 523.0, 0.09], [659.0, 659.0, 0.09], [784.0, 784.0, 0.09], [1047.0, 1047.0, 0.3]], 0.25, 0.0, 0.5)
	_streams[&"timeup"] = _synth([[440.0, 440.0, 0.12], [330.0, 330.0, 0.12], [220.0, 200.0, 0.25]], 0.4, 0.0, 0.45)
	_streams[&"ring"] = _synth([[600.0, 1800.0, 0.28]], 0.0, 0.05, 0.45)
	_streams[&"click"] = _synth([[700.0, 700.0, 0.03]], 0.5, 0.0, 0.3)


func play(sound: StringName, pitch_jitter := 0.0, volume_db := 0.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		push_warning("効果音がありません: %s" % sound)
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.volume_db = volume_db
	player.play()


## notes の各音符を順につなげた 16bit モノラルの音を作る。
## square_mix: 矩形波の混ぜ具合（0 で正弦波）、noise_mix: ノイズの混ぜ具合、volume: 音量（0〜1）
func _synth(notes: Array, square_mix: float, noise_mix: float, volume: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var phase := 0.0
	for note: Array in notes:
		var from: float = note[0]
		var to: float = note[1]
		var length: float = note[2]
		var count := int(length * MIX_RATE)
		var start := data.size()
		data.resize(start + count * 2)
		for i in count:
			var t := float(i) / count
			phase = fmod(phase + lerpf(from, to, t) / MIX_RATE, 1.0)
			var sine := sin(phase * TAU)
			var square := 1.0 if phase < 0.5 else -1.0
			var tone := lerpf(sine, square, square_mix)
			var sample := lerpf(tone, randf_range(-1.0, 1.0), noise_mix)
			var envelope := minf(t * 20.0, 1.0) * pow(1.0 - t, 1.5)
			data.encode_s16(start + i * 2, int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
