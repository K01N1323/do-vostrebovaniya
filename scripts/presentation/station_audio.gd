extends Node
## Original procedural station sounds. The title menu stays silent.

const SAMPLE_RATE := 22050
const DURATIONS := {"hall": 2.0, "steps": 1.1, "paper": 0.26, "latch": 0.24, "stamp": 0.23, "boarding": 1.40, "phone": 1.15}
const SCORE = preload("res://assets/audio/last-shift.wav")
const VOICES := {
	"nina":1.29, "fedor":0.86, "vera":1.42, "leonid":1.08,
	"gleb":1.16, "serov":0.78, "pavel":1.02, "dispatcher":1.36,
}

var _hall: AudioStreamPlayer
var _music: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _murmurs: Array[AudioStreamWAV] = []
var _effects: Dictionary = {}
var _running := false
var _muted := false
var _paused := false

func _ready() -> void:
	_hall = AudioStreamPlayer.new()
	_hall.volume_db = -34
	_hall.stream = _make_stream("hall")
	add_child(_hall)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -23
	var score := SCORE.duplicate() as AudioStreamWAV
	score.loop_mode = AudioStreamWAV.LOOP_FORWARD
	score.loop_end = int(score.get_length() * score.mix_rate)
	_music.stream = score
	add_child(_music)
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = -16
	add_child(_voice)

func start(muted: bool) -> void:
	_running = true
	set_muted(muted)

func stop() -> void:
	_running = false
	_hall.stop()
	_music.stop()
	_voice.stop()
	for player in _effects.values():
		player.stop()

func set_muted(value: bool) -> void:
	_muted = value
	if _running and not _muted:
		if not _hall.playing:
			_hall.play()
		if not _music.playing:
			_music.play()
		_hall.stream_paused = _paused
		_music.stream_paused = _paused
	else:
		_hall.stop()
		_music.stop()
		_voice.stop()
		for player in _effects.values():
			player.stop()

func set_paused(value: bool) -> void:
	_paused = value
	_hall.stream_paused = value
	_music.stream_paused = value
	_voice.stream_paused = value
	for player in _effects.values():
		player.stream_paused = value

func cue(id: String) -> void:
	if not _running or _muted or _paused or not DURATIONS.has(id) or id == "hall":
		return
	if not _effects.has(id):
		var player := AudioStreamPlayer.new()
		player.volume_db = -23
		player.stream = _make_stream(id)
		add_child(player)
		_effects[id] = player
	_effects[id].play()

func speak(speaker: String, phrase: String) -> void:
	_voice.stop()
	if not _running or _muted or _paused or not VOICES.has(speaker):
		return
	if _murmurs.is_empty():
		for i in 3:
			_murmurs.append(_make_murmur(i))
	_voice.stream = _murmurs[absi(phrase.hash()) % _murmurs.size()]
	_voice.pitch_scale = VOICES[speaker]
	_voice.volume_db = -21 if speaker == "dispatcher" else -16
	_voice.play()

func stop_speech() -> void:
	_voice.stop()

func _make_murmur(pattern: int) -> AudioStreamWAV:
	var syllables: Array = [[0.16, 0.13, 0.19], [0.23, 0.17], [0.13, 0.19, 0.17, 0.13]][pattern]
	var data := PackedByteArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7921 + pattern
	for index in syllables.size():
		var duration: float = syllables[index]
		var count := int(duration * SAMPLE_RATE)
		var offset := data.size()
		data.resize(offset + count * 2)
		var formant: Vector2 = [Vector2(430, 930), Vector2(660, 1280), Vector2(330, 830)][(index + pattern) % 3]
		var phase := 0.0
		for i in count:
			var t := float(i) / SAMPLE_RATE
			var progress := t / duration
			var pitch := 104.0 + 15.0 * sin(PI * progress) - 8.0 * index
			phase = fposmod(phase + pitch / SAMPLE_RATE, 1.0)
			var cycle := phase / pitch
			var resonant := exp(-cycle * 465.0) * (sin(TAU * formant.x * cycle) + 0.35 * sin(TAU * formant.y * cycle))
			var body := 0.22 * sin(TAU * phase) + 0.58 * resonant
			var envelope := smoothstep(0.0, 0.15, progress) * (1.0 - smoothstep(0.68, 1.0, progress))
			var sample := envelope * (body * 0.72 + 0.04 * rng.randf_range(-1.0, 1.0))
			data.encode_s16(offset + i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream

func _make_stream(id: String) -> AudioStreamWAV:
	var count := int(DURATIONS[id] * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 43719
	var air := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)
		air = lerpf(air, white, 0.033)
		var sample := 0.0
		match id:
			"hall":
				var edge := smoothstep(0.0, 0.12, minf(t, 2.0 - t))
				sample = 0.12 * sin(TAU * 50 * t) + 0.035 * sin(TAU * 100 * t) + 0.40 * air * edge
			"steps":
				var step := fposmod(t, 0.36)
				var weight := 0.46 + 0.47 * t
				sample = weight * _pulse(step, 35.0) * (0.49 * sin(TAU * 72 * step) + 0.41 * air + 0.15 * white)
			"paper":
				var envelope := _pulse(t, 21.0) + 0.47 * _pulse(t - 0.09, 34.0)
				sample = envelope * (0.42 * white + 0.34 * air)
			"latch":
				sample = _pulse(t, 32.0) * (0.38 * sin(TAU * 225 * t) + 0.14 * sin(TAU * 613 * t) + 0.25 * white)
			"stamp":
				sample = _pulse(t, 28.0) * (0.62 * sin(TAU * 96 * t) + 0.22 * white)
			"boarding":
				sample = 0.26 * _pulse(t, 4.0) * sin(TAU * 422 * t) + 0.22 * _pulse(t - 0.40, 4.1) * sin(TAU * 335 * t)
			"phone":
				var ring := _pulse(t, 4.5) + _pulse(t - 0.48, 4.5)
				sample = 0.34 * ring * (sin(TAU * 740 * t) + 0.5 * sin(TAU * 1180 * t))
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	if id == "hall":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream

func _pulse(t: float, falloff: float) -> float:
	return 0.0 if t < 0.0 else minf(t * 150.0, 1.0) * exp(-t * falloff)
