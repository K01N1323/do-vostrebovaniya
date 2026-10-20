extends Node3D
## All views are head turns from the same clerk's eye position.

signal view_changed(view_id: String)

const EYE := Vector3(0, 1.62, 1.25)
const VIEWS := {
	"window": {"target": Vector3(0.02, 1.58, -0.94), "fov": 42.0},
	"desk": {"target": Vector3(-0.28, 1.06, -0.02), "fov": 64.0},
	"shelf": {"target": Vector3(-1.65, 1.65, 0.65), "fov": 64.0},
	"personal": {"target": Vector3(0.88, 0.46, 0.82), "fov": 64.0},
}

@export var reduced_motion: bool = false
@export var look_enabled: bool = false:
	set(value):
		look_enabled = value
		if not value:
			_looking = false
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var current_view: String = "window"
var _transition: Tween
var _looking: bool = false
var _base_rotation := Vector3.ZERO
var _look_offset := Vector2.ZERO

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_camera.position = EYE
	_apply_view(current_view)

func get_camera() -> Camera3D:
	return _camera if is_instance_valid(_camera) else get_node_or_null("Camera3D") as Camera3D

func focus(view_id: String) -> void:
	if not VIEWS.has(view_id):
		return
	current_view = view_id
	_looking = false
	_look_offset = Vector2.ZERO
	if not is_node_ready():
		return
	if is_instance_valid(_transition):
		_transition.kill()
	# No translation tween, no dolly: local/global eye coordinates stay fixed.
	_camera.position = EYE
	var view: Dictionary = VIEWS[view_id]
	var next_transform := Transform3D(Basis.IDENTITY, EYE).looking_at(view["target"], Vector3.UP)
	_base_rotation = next_transform.basis.get_euler()
	if reduced_motion:
		_camera.quaternion = next_transform.basis.get_rotation_quaternion()
		_camera.fov = float(view["fov"])
	else:
		_transition = create_tween().set_parallel(true)
		_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_transition.tween_property(_camera, "quaternion", next_transform.basis.get_rotation_quaternion(), 0.33)
		_transition.tween_property(_camera, "fov", float(view["fov"]), 0.33)
	view_changed.emit(view_id)

func _apply_view(view_id: String) -> void:
	var view: Dictionary = VIEWS[view_id]
	_camera.position = EYE
	_camera.look_at(view["target"], Vector3.UP)
	_camera.fov = float(view["fov"])
	_base_rotation = _camera.rotation

func _input(event: InputEvent) -> void:
	# Releasing over a UI panel must also end the head turn.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		_looking = false

func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_looking = event.pressed
		if _looking and is_instance_valid(_transition):
			_transition.kill()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _looking:
		_look_offset.x = clampf(_look_offset.x - event.relative.y * 0.0022, -0.27, 0.27)
		_look_offset.y = clampf(_look_offset.y - event.relative.x * 0.0022, -0.42, 0.42)
		_camera.rotation = _base_rotation + Vector3(_look_offset.x, _look_offset.y, 0)
		_camera.position = EYE
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
