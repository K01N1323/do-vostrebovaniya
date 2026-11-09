extends Node3D
## Instantiate this scene in an isolated SubViewport with own_world_3d = true.

const Packages = preload("res://scripts/presentation/package_registry.gd")
const G = preload("res://scripts/presentation/geometry.gd")

signal detail_selected(detail_id: String)
signal focus_changed(detail_id: String)

var _package_id := "P01"
var _pending_lining := false

@export var input_enabled: bool = true
@export var reduced_motion: bool = false
var _turn: Tween
var _pending_opened: bool = true
var _focus_id := ""
var _focus_tween: Tween
var _overview: Transform3D
var _overview_fov: float
var _dragging := false

@onready var _pivot: Node3D = $Pivot
@onready var _package: Node3D = $Pivot/Package

func _ready() -> void:
	if _package_id != "P01":
		_swap_package()
	_package.set_opened(_pending_opened)
	_package.set_detail_picking(true)
	$Camera3D.current = true
	$Camera3D.look_at(Vector3(0.04, 0.31, -0.07), Vector3.UP)
	if _package_id == "P02":
		$Camera3D.position = Vector3(0.12, 0.95, 1.00)
		$Camera3D.look_at(Vector3(0, 0.10, 0), Vector3.UP)
		$Camera3D.fov = 44
	elif _package_id == "P03":
		_package.set_unlocked(true)
		_package.set_lining_lifted(_pending_lining)
		$Camera3D.position = Vector3(0.04, 0.95, 1.15)
		$Camera3D.look_at(Vector3(0, 0.17, -0.03), Vector3.UP)
		$Camera3D.fov = 45
	elif _package_id == "P04":
		$Camera3D.position = Vector3(0.03, 0.91, 0.89)
		$Camera3D.look_at(Vector3(0, 0.14, 0), Vector3.UP)
		$Camera3D.fov = 44
	elif _package_id != "P01":
		$Camera3D.position = Vector3(0.04, 0.86, 0.62) if _package_id == "P05" else Vector3(0.04, 0.56, 0.47)
		$Camera3D.look_at(Vector3(0, 0.05, 0), Vector3.UP)
		$Camera3D.fov = 43
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

func _swap_package() -> void:
	_pivot.remove_child(_package)
	_package.queue_free()
	_package = Packages.instantiate(_package_id)
	_package.name = "Package"
	_pivot.add_child(_package)

func _views() -> Dictionary:
	return Packages.detail_views(_package_id)

func set_lining_lifted(value: bool) -> void:
	_pending_lining = value
	if is_node_ready() and _package.has_method("set_lining_lifted"):
		_package.set_lining_lifted(value)

func set_opened(value: bool) -> void:
	_pending_opened = value
	if is_node_ready():
		_package.set_opened(value)

func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		_dragging = false

func get_focus_id() -> String:
	return _focus_id

func focus_detail(detail_id: String) -> void:
	if not is_node_ready() or not can_focus_detail(detail_id):
		return
	_dragging = false
	if is_instance_valid(_turn):
		_turn.kill()
	var view: Dictionary = _views()[detail_id]
	var destination := Transform3D(Basis.IDENTITY, view.eye).looking_at(view.at, Vector3.UP)
	_focus_id = detail_id
	_transition_camera(destination, float(view.fov), true)
	focus_changed.emit(_focus_id)

func can_focus_detail(detail_id: String) -> bool:
	return _views().has(detail_id) and (detail_id != "zipper" or _pending_lining)

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
			_pivot.rotation = Vector3.ZERO
		return
	_focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property($Camera3D, "transform", destination, 0.32)
	_focus_tween.tween_property($Camera3D, "fov", field_of_view, 0.32)
	if straighten_item:
		_focus_tween.tween_property(_pivot, "rotation", Vector3.ZERO, 0.32)

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
	if not input_enabled:
		return
	if event is InputEventMouseMotion and _dragging:
		if not (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
			_dragging = false
			return
		_pivot.rotation.y += event.relative.x * 0.009
		_pivot.rotation.x = clampf(_pivot.rotation.x + event.relative.y * 0.006, -0.24, 0.32)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed and _focus_id.is_empty()
		if _dragging and is_instance_valid(_turn):
			_turn.kill()
		get_viewport().set_input_as_handled()
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
		if can_focus_detail(detail_id) or (_package_id == "P03" and detail_id == "lining"):
			detail_selected.emit(detail_id)
			get_viewport().set_input_as_handled()
