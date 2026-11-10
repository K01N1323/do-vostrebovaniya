extends Sprite3D
## Three drawn poses on a common baseline, with movement driven by the room.

var anchor_position := Vector3(0, 0.92, 0.06)
var _elapsed := 0.0
var _utterance := 0.0
var _phase := 0.0
var _at_bus := false

func configure(id: String, fallback: String, at_bus: bool) -> void:
	_at_bus = at_bus
	_phase = float(id.hash() % 17) * 0.43
	var strip_path := "res://assets/characters/performances/" + id + ".png"
	var drawn := ResourceLoader.exists(strip_path, "Texture2D")
	texture = load(strip_path if drawn else fallback)
	hframes = 3 if drawn else 1
	pixel_size = 1.84 / float(texture.get_height())
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if drawn else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	alpha_scissor_threshold = 0.18
	shaded = false
	modulate = Color(0.84, 0.93, 0.93) if drawn else Color(0.66, 0.84, 0.88)

func perform(pose: int, duration: float) -> void:
	frame = clampi(pose, 0, hframes - 1)
	_utterance = duration

func _process(delta: float) -> void:
	var room := get_parent().get_parent()
	if not is_visible_in_tree() or room.reduced_motion:
		position = anchor_position
		rotation.z = 0
		scale.y = 1.0
		return
	_elapsed += delta
	_utterance = maxf(0.0, _utterance - delta)
	var walking: bool = not _at_bus and room.visitor_phase in ["arriving", "leaving"]
	var weight_shift := sin(_elapsed * 1.15 + _phase)
	var breath := sin(_elapsed * 1.70 + _phase)
	var speech := sin(_elapsed * 14.0) * minf(_utterance * 4.0, 1.0)
	scale.y = 1.0 + breath * 0.010 + speech * 0.003
	position = anchor_position + Vector3(weight_shift * 0.009, anchor_position.y * (scale.y - 1.0), 0)
	rotation.z = weight_shift * 0.006 + speech * 0.004
	if walking:
		var step := sin(_elapsed * 10.0)
		position.y += absf(step) * 0.017
		rotation.z += step * 0.010
