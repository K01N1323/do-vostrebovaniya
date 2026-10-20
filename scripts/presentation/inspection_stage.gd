extends Node3D
## Instantiate this scene in an isolated SubViewport with own_world_3d = true.

const G = preload("res://scripts/presentation/geometry.gd")

signal detail_selected(detail_id: String)
signal focus_changed(detail_id: String)

const DETAIL_VIEWS := {
	"sandwiches": {"eye": Vector3(0.10, 0.76, 0.70), "at": Vector3(0.04, 0.17, -0.01), "fov": 35.0},
	"saucer": {"eye": Vector3(0.31, 0.46, 0.57), "at": Vector3(0.19, 0.135, 0.18), "fov": 35.0},
	"napkin": {"eye": Vector3(-0.37, 0.33, 0.43), "at": Vector3(-0.29, 0.10, 0.18), "fov": 36.0}
}
const BRICK_VIEWS := {
	"corner": {"eye": Vector3(-0.49, 0.40, 0.48), "at": Vector3(-0.21, 0.13, 0.09), "fov": 35.0},
	"paint": {"eye": Vector3(0.07, 0.78, 0.45), "at": Vector3(0.025, 0.23, -0.005), "fov": 32.0},
	"collar": {"eye": Vector3(0.43, 0.40, 0.48), "at": Vector3(0.28, 0.058, 0.16), "fov": 29.0}
}
var _package_id := "P01"

@export var input_enabled: bool = true
@export var reduced_motion: bool = false
var _turn: Tween
var _pending_opened: bool = true
var _focus_id := ""
var _focus_tween: Tween
var _overview: Transform3D
var _overview_fov: float

@onready var _pivot: Node3D = $Pivot
@onready var _package: Node3D = $Pivot/Package

func _ready() -> void:
	if _package_id == "P02":
		_swap_brick()
	_package.set_opened(_pending_opened)
	_package.set_detail_picking(true)
	$Camera3D.current = true
	$Camera3D.look_at(Vector3(0.04, 0.31, -0.07), Vector3.UP)
	if _package_id == "P02":
		$Camera3D.position = Vector3(0.12, 0.95, 1.00)
		$Camera3D.look_at(Vector3(0, 0.10, 0), Vector3.UP)
		$Camera3D.fov = 44
	_overview = $Camera3D.transform
	_overview_fov = $Camera3D.fov
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("1d211f")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b3b7b1")
	settings.ambient_light_energy = 0.30
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	G.cylinder(self, 0.58, 0.018, Vector3(0, -0.016, 0), G.worn_material(Color("343832"), "plastic", 0.96))

func set_item(package_id: String = "P01") -> void:
	# Configure before adding to the viewport so the package is built only once.
	_package_id = package_id
	set_opened(true)

func _swap_brick() -> void:
	_pivot.remove_child(_package)
	_package.queue_free()
	_package = preload("res://scenes/objects/brick_package.tscn").instantiate()
	_package.name = "Package"
	_pivot.add_child(_package)

func _views() -> Dictionary:
	return BRICK_VIEWS if _package_id == "P02" else DETAIL_VIEWS

func set_opened(value: bool) -> void:
	_pending_opened = value
	if is_node_ready():
		_package.set_opened(value)

func set_input_enabled(value: bool) -> void:
	input_enabled = value

func get_focus_id() -> String:
	return _focus_id

func focus_detail(detail_id: String) -> void:
	if not is_node_ready() or not _views().has(detail_id):
		return
	if is_instance_valid(_turn):
		_turn.kill()
	var view: Dictionary = _views()[detail_id]
	var destination := Transform3D(Basis.IDENTITY, view.eye).looking_at(view.at, Vector3.UP)
	_focus_id = detail_id
	_transition_camera(destination, float(view.fov), true)
	focus_changed.emit(_focus_id)

func reset_focus() -> void:
	if not is_node_ready():
		return
	_focus_id = ""
	_transition_camera(_overview, _overview_fov, false)
	focus_changed.emit(_focus_id)

func _transition_camera(destination: Transform3D, field_of_view: float, straighten_item: bool) -> void:
	if is_instance_valid(_focus_tween):
		_focus_tween.kill()
	if reduced_motion:
		$Camera3D.transform = destination
		$Camera3D.fov = field_of_view
		if straighten_item:
			_pivot.rotation.y = 0.0
		return
	_focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property($Camera3D, "transform", destination, 0.32)
	_focus_tween.tween_property($Camera3D, "fov", field_of_view, 0.32)
	if straighten_item:
		_focus_tween.tween_property(_pivot, "rotation:y", 0.0, 0.32)

func rotate_item(direction: float) -> void:
	if not is_node_ready():
		return
	# Rotation is always made from the overview; close-ups remain framed on their target.
	if not _focus_id.is_empty():
		reset_focus()
	if is_instance_valid(_turn):
		_turn.kill()
	var angle := _pivot.rotation.y + direction * PI / 6.0
	if reduced_motion:
		_pivot.rotation.y = angle
	else:
		_turn = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_turn.tween_property(_pivot, "rotation:y", angle, 0.18)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var camera: Camera3D = $Camera3D
	var origin := camera.project_ray_origin(event.position)
	var finish := origin + camera.project_ray_normal(event.position) * 10.0
	var query := PhysicsRayQueryParameters3D.create(origin, finish, 2)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var collider: Object = result["collider"]
		var detail_id := str(collider.get_meta("target_id", ""))
		if _views().has(detail_id):
			detail_selected.emit(detail_id)
			get_viewport().set_input_as_handled()
