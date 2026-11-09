extends Node
## Original procedural station sounds. The title menu stays silent.

const SAMPLE_RATE := 22050
const DURATIONS := {"hall": 2.0, "steps": 1.1, "paper": 0.26, "latch": 0.24, "stamp": 0.23, "boarding": 1.40}

var _hall: AudioStreamPlayer
var _effects: Dictionary = {}
var _running := false
var _muted := false
var _paused := false

func _ready() -> void:
	_hall = AudioStreamPlayer.new()
	_hall.volume_db = -34
	_hall.stream = _make_stream("hall")
	add_child(_hall)

func start(muted: bool) -> void:
	_running = true
	set_muted(muted)

func stop() -> void:
	_running = false
	_hall.stop()
	for player in _effects.values():
		player.stop()

func set_muted(value: bool) -> void:
	_muted = value
	if _running and not _muted:
		if not _hall.playing:
			_hall.play()
		_hall.stream_paused = _paused
	else:
		_hall.stop()
		for player in _effects.values():
			player.stop()

func set_paused(value: bool) -> void:
	_paused = value
	_hall.stream_paused = value
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
