extends Node3D
## Instantiate this scene in an isolated SubViewport with own_world_3d = true.

signal detail_selected(detail_id: String)

@export var input_enabled: bool = true
@export var reduced_motion: bool = false
var _turn: Tween
var _pending_opened: bool = true

@onready var _pivot: Node3D = $Pivot
@onready var _package: Node3D = $Pivot/Package

func _ready() -> void:
	_package.set_opened(_pending_opened)
	_package.set_detail_picking(true)
	$Camera3D.current = true
	$Camera3D.look_at(Vector3(0.12, 0.35, 0), Vector3.UP)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("141e18")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b3c3bb")
	settings.ambient_light_energy = 0.39
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)

func set_item(_package_id: String = "P01") -> void:
	set_opened(true)

func set_opened(value: bool) -> void:
	_pending_opened = value
	if is_node_ready():
		_package.set_opened(value)

func set_input_enabled(value: bool) -> void:
	input_enabled = value

func rotate_item(direction: float) -> void:
	if not is_node_ready():
		return
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
		if detail_id in ["sandwiches", "saucer", "napkin"]:
			detail_selected.emit(detail_id)
			get_viewport().set_input_as_handled()
