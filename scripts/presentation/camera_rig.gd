extends Node3D
## Fixed viewpoints retain context while avoiding free movement and motion sickness.

signal view_changed(view_id: String)

@export var reduced_motion: bool = false

const VIEWS := {
	"window": {"position": Vector3(3.35, 2.30, 4.65), "target": Vector3(0.95, 1.12, -1.40), "fov": 51.0},
	"shelf": {"position": Vector3(-0.30, 2.10, 1.30), "target": Vector3(-1.64, 1.45, -2.10), "fov": 44.0},
	"desk": {"position": Vector3(1.35, 2.75, 2.35), "target": Vector3(0.52, 1.10, -0.66), "fov": 45.0},
	"personal": {"position": Vector3(2.60, 0.90, 2.40), "target": Vector3(1.47, 0.48, 0.24), "fov": 41.0},
}

var current_view: String = "window"
var _transition: Tween

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_apply_view("window")

func get_camera() -> Camera3D:
	return _camera if is_instance_valid(_camera) else get_node_or_null("Camera3D") as Camera3D

func focus(view_id: String) -> void:
	if not VIEWS.has(view_id):
		return
	current_view = view_id
	if not is_node_ready():
		return
	if is_instance_valid(_transition):
		_transition.kill()
	var view: Dictionary = VIEWS[view_id]
	var next_position: Vector3 = view["position"]
	var next_transform := Transform3D(Basis.IDENTITY, next_position).looking_at(view["target"], Vector3.UP)
	if reduced_motion:
		_camera.transform = next_transform
		_camera.fov = float(view["fov"])
	else:
		_transition = create_tween().set_parallel(true)
		_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_transition.tween_property(_camera, "position", next_position, 0.65)
		_transition.tween_property(_camera, "quaternion", next_transform.basis.get_rotation_quaternion(), 0.65)
		_transition.tween_property(_camera, "fov", float(view["fov"]), 0.65)
	view_changed.emit(view_id)

func _apply_view(view_id: String) -> void:
	var view: Dictionary = VIEWS[view_id]
	_camera.position = view["position"]
	_camera.look_at(view["target"], Vector3.UP)
	_camera.fov = float(view["fov"])
