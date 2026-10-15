extends Node3D
## The clerk is inside the cage. Presentation owns movement, never story state.

signal target_clicked(target_id: String)
signal visitor_arrived
signal handover_finished

const G = preload("res://scripts/presentation/geometry.gd")
const CRATE_PROBE = preload("res://assets/models/crate_probe.glb")
const PACKAGE_POSITIONS := {
	"shelf": Vector3(-1.65, 1.16, 0.65),
	"desk": Vector3(-0.28, 0.94, -0.02),
	"personal": Vector3(0.60, 0.25, 0.65),
	"hatch": Vector3(0.72, 0.94, -0.62),
}
const VISITOR_WAIT := Vector3(0, 0, -0.94)
const VISITOR_FAR := Vector3(-1.7, 0, -5.8)

@export var input_enabled: bool = true
var visitor_phase: String = "absent"
var transfer_active: bool = false
var reduced_motion: bool = false
var _snapshot: Dictionary = {}
var _has_snapshot: bool = false
var _hovered: String = ""
var _highlights: Dictionary = {}
var _visitor: Node3D
var _visitor_geometry: Node3D
var _visitor_target: StaticBody3D
var _visitor_tween: Tween
var _transfer_tween: Tween
var _rotation_tween: Tween
var _inner_door: Node3D
var _outer_door: Node3D
var _inner_open: bool = false
var _outer_open: bool = false
var _face_height: float = 1.56
var _face_depth: float = 0.17
var _view_id: String = "window"

@onready var _package: Node3D = $Package

func _ready() -> void:
	_build_room()
	_build_shelf()
	_build_desk()
	_build_cage()
	_build_hatch()
	_build_nina()
	_build_lighting()
	var pending := _snapshot.duplicate(true)
	_snapshot.clear()
	if not pending.is_empty():
		apply_snapshot(pending)
	else:
		_set_visitor_phase("absent")

func apply_snapshot(snapshot: Dictionary) -> void:
	if not is_node_ready():
		_snapshot = snapshot.duplicate(true)
		return
	var previous := _snapshot
	var had_previous := _has_snapshot
	var previous_started := bool(previous.get("started", false))
	var started := bool(snapshot.get("started", false))
	var status := str(snapshot.get("case_status", "active"))
	var previous_status := str(previous.get("case_status", "active"))
	var previous_package: Dictionary = previous.get("package", {})
	var previous_location := str(previous_package.get("location", "shelf"))
	var package_state: Dictionary = snapshot.get("package", {})
	var location := str(package_state.get("location", "shelf"))
	var restarted := had_previous and ((previous_started and not started) or (previous_status == "resolved" and status == "active"))
	_snapshot = snapshot.duplicate(true)
	_has_snapshot = true
	if restarted:
		_cancel_animations()
		_package.rotation = Vector3.ZERO
		_set_visitor_phase("absent")
	if not started:
		_cancel_animations()
		_set_visitor_phase("absent")
	elif not had_previous:
		_visitor.position = VISITOR_WAIT
		_set_visitor_phase("gone" if status == "resolved" else "waiting")
	elif not previous_started and started:
		_start_arrival()
	if location == "issued" and had_previous and previous_location == "desk" and not restarted:
		_start_handover()
	elif not transfer_active:
		_package.visible = location != "issued"
		if PACKAGE_POSITIONS.has(location):
			_package.position = PACKAGE_POSITIONS[location]
		if restarted or not had_previous or location != previous_location:
			_package.rotation_degrees.y = 59.0 if location == "shelf" else (-45.0 if location == "personal" else 0.0)
		_update_package_lid()
		_set_package_picking(_package.visible)
	if started and status == "resolved" and had_previous and previous_status != "resolved":
		_start_departure()
	if not _package.visible and _hovered == "P01":
		set_hovered("")

func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		set_hovered("")

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value

func set_view(view_id: String) -> void:
	_view_id = view_id
	_update_package_lid()

func _update_package_lid() -> void:
	if not is_instance_valid(_package) or transfer_active:
		return
	var package_state: Dictionary = _snapshot.get("package", {})
	# Opened records knowledge; the lid closes when looking back at the visitor.
	_package.set_opened(bool(package_state.get("opened", false)) and package_state.get("location", "shelf") == "desk" and _view_id == "desk")

func rotate_package(direction: float) -> void:
	if transfer_active or not is_instance_valid(_package) or not _package.visible:
		return
	if is_instance_valid(_rotation_tween):
		_rotation_tween.kill()
	var next_angle := _package.rotation.y + direction * PI / 6.0
	if reduced_motion:
		_package.rotation.y = next_angle
	else:
		_rotation_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_rotation_tween.tween_property(_package, "rotation:y", next_angle, 0.16)

func get_hatch_state() -> Dictionary:
	return {"inner_open": _inner_open, "outer_open": _outer_open}

func get_visitor_focus_position() -> Vector3:
	return _visitor.global_position + Vector3(0, _face_height, _face_depth) if is_instance_valid(_visitor) else VISITOR_WAIT + Vector3(0, _face_height, _face_depth)

func set_hovered(target_id: String) -> void:
	_hovered = target_id
	if is_instance_valid(_package):
		_package.set_highlighted(target_id == "P01" and _package.visible and not transfer_active)
	for key in _highlights:
		var mesh: MeshInstance3D = _highlights[key]
		mesh.visible = key == target_id

func _physics_process(_delta: float) -> void:
	if not input_enabled or not is_visible_in_tree():
		return
	var control := get_viewport().gui_get_hovered_control()
	if is_instance_valid(control) and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		if not _hovered.is_empty():
			set_hovered("")
		return
	var next_hovered := _pick(get_viewport().get_mouse_position())
	if next_hovered != _hovered:
		set_hovered(next_hovered)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target_id := _pick(event.position)
		if not target_id.is_empty():
			target_clicked.emit(target_id)
			get_viewport().set_input_as_handled()

func _pick(screen_position: Vector2) -> String:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return ""
	var origin := camera.project_ray_origin(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_position) * 20.0, 1)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return ""
	var collider: Object = result["collider"]
	return str(collider.get_meta("target_id", ""))

func _set_package_picking(value: bool) -> void:
	var target: StaticBody3D = _package.get_node_or_null("Target_P01")
	if is_instance_valid(target):
		target.collision_layer = 1 if value else 0

func _set_visitor_phase(value: String) -> void:
	visitor_phase = value
	if is_instance_valid(_visitor):
		_visitor.visible = value not in ["absent", "gone"]
	if is_instance_valid(_visitor_target):
		_visitor_target.collision_layer = 1 if value == "waiting" else 0

func _start_arrival() -> void:
	if is_instance_valid(_visitor_tween):
		_visitor_tween.kill()
	_visitor.position = VISITOR_FAR
	_set_visitor_phase("arriving")
	_visitor_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_visitor_tween.tween_property(_visitor, "position", VISITOR_WAIT, 0.03 if reduced_motion else 1.15)
	_visitor_tween.tween_callback(func():
		_set_visitor_phase("waiting")
		visitor_arrived.emit())

func _start_departure() -> void:
	if is_instance_valid(_visitor_tween):
		_visitor_tween.kill()
	_visitor.position = VISITOR_WAIT
	_set_visitor_phase("waiting")
	_visitor_tween = create_tween()
	_visitor_tween.tween_interval(2.1)
	_visitor_tween.tween_callback(func(): _set_visitor_phase("leaving"))
	_visitor_tween.tween_property(_visitor, "position", Vector3(2.0, 0, -5.8), 0.03 if reduced_motion else 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_visitor_tween.tween_callback(func(): _set_visitor_phase("gone"))

func _start_handover() -> void:
	if transfer_active:
		return
	if is_instance_valid(_rotation_tween):
		_rotation_tween.kill()
	transfer_active = true
	_set_package_picking(false)
	_package.visible = true
	_package.set_opened(false)
	_package.rotation = Vector3.ZERO
	_close_hatch_now()
	_transfer_tween = create_tween()
	var speed := 0.06 if reduced_motion else 1.0
	# A door is open from its first moving frame until it is completely closed.
	_transfer_tween.tween_callback(func(): _inner_open = true)
	_transfer_tween.tween_property(_inner_door, "position:y", 0.83, 0.14 * speed)
	_transfer_tween.tween_property(_package, "position", Vector3(0.72, 0.94, 0.23), 0.28 * speed)
	_transfer_tween.tween_property(_package, "position", PACKAGE_POSITIONS["hatch"], 0.30 * speed)
	_transfer_tween.tween_property(_inner_door, "position:y", 0.0, 0.16 * speed)
	_transfer_tween.tween_callback(func(): _inner_open = false)
	_transfer_tween.tween_callback(func(): _outer_open = true)
	_transfer_tween.tween_property(_outer_door, "position:y", 0.83, 0.16 * speed)
	_transfer_tween.tween_property(_package, "position", Vector3(0.72, 0.94, -1.42), 0.25 * speed)
	_transfer_tween.tween_callback(func(): _package.visible = false)
	_transfer_tween.tween_property(_outer_door, "position:y", 0.0, 0.16 * speed)
	_transfer_tween.tween_callback(func():
		_outer_open = false
		transfer_active = false
		handover_finished.emit())

func _close_hatch_now() -> void:
	_inner_open = false
	_outer_open = false
	if is_instance_valid(_inner_door):
		_inner_door.position.y = 0
	if is_instance_valid(_outer_door):
		_outer_door.position.y = 0

func _cancel_animations() -> void:
	for tween in [_visitor_tween, _transfer_tween, _rotation_tween]:
		if is_instance_valid(tween):
			tween.kill()
	transfer_active = false
	_close_hatch_now()

func _build_room() -> void:
	var wall := G.worn_material(Color("99917f"), "plaster")
	var lower := G.worn_material(Color("6d746b"), "tile")
	var trim := G.worn_material(Color("464b43"), "metal", 0.86, 0.3)
	var floor := G.worn_material(Color("57564b"), "tile")
	G.box(self, Vector3(7.0, 0.12, 10.0), Vector3(0, -0.06, -2.0), floor)
	var grout := G.material(Color("363a32"))
	for z in range(21):
		G.box(self, Vector3(6.95, 0.003, 0.009), Vector3(0, 0.002, -6.8 + z * 0.48), grout)
	for x in range(15):
		G.box(self, Vector3(0.009, 0.003, 9.85), Vector3(-3.45 + x * 0.48, 0.002, -1.86), grout)
	G.box(self, Vector3(2.8, 0.009, 2.2), Vector3(-0.65, 0.009, 0.85), G.worn_material(Color("49483a"), "leather"))
	G.box(self, Vector3(7.0, 3.3, 0.2), Vector3(0, 1.65, -6.8), wall)
	for x in [-3.5, 2.4]:
		G.box(self, Vector3(0.16, 3.3, 9.8), Vector3(x, 1.65, -2.0), wall)
		G.box(self, Vector3(0.025, 1.12, 9.8), Vector3(x + (0.09 if x < 0 else -0.09), 0.56, -2.0), lower)
		G.box(self, Vector3(0.045, 0.09, 9.8), Vector3(x + (0.11 if x < 0 else -0.11), 0.06, -2.0), trim)
		G.box(self, Vector3(0.04, 0.045, 9.8), Vector3(x + (0.11 if x < 0 else -0.11), 1.15, -2.0), trim)
		for height in [0.28, 0.56, 0.84]:
			G.box(self, Vector3(0.005, 0.008, 9.7), Vector3(x + (0.108 if x < 0 else -0.108), height, -2.0), grout)
	G.box(self, Vector3(7.0, 1.12, 0.025), Vector3(0, 0.56, -6.68), lower)
	G.box(self, Vector3(7.0, 0.045, 0.04), Vector3(0, 1.16, -6.66), trim)
	G.box(self, Vector3(7.0, 0.10, 0.05), Vector3(0, 0.06, -6.64), trim)
	# A real ceiling, cornice and service conduits keep the hall enclosed.
	G.box(self, Vector3(7.0, 0.14, 10.0), Vector3(0, 3.15, -2.0), G.worn_material(Color("888878"), "plaster"))
	for x in [-3.37, 2.27]:
		G.box(self, Vector3(0.12, 0.13, 9.8), Vector3(x, 3.01, -2.0), G.worn_material(Color("73776b"), "plaster"))
	for z in [-5.7, -3.2, 0.1, 2.6]:
		G.box(self, Vector3(5.8, 0.025, 0.035), Vector3(-0.5, 3.06, z), trim)
	G.rod(self, Vector3(2.24, 2.91, -6.6), Vector3(2.24, 2.91, 2.5), 0.018, trim)
	G.rod(self, Vector3(2.24, 2.91, -2.9), Vector3(2.24, 0.3, -2.9), 0.018, trim)
	G.box(self, Vector3(0.11, 0.18, 0.16), Vector3(2.23, 1.65, -2.9), trim)
	_build_station_door()
	_build_hall_window()
	_build_notices()
	_build_bench()
	_build_ceiling_fixture(Vector3(-0.6, 3.0, -3.4), true)
	_build_ceiling_fixture(Vector3(0.7, 3.0, -5.9), false)
	# Small irregular moisture stains belong to the low wall, away from the face.
	var damp := G.worn_material(Color("565b50"), "rust")
	_add_wall_stain(self, Vector3(-2.9, 0.18, -6.65), Vector2(0.75, 0.38), damp)
	_add_wall_stain(self, Vector3(1.94, 0.17, -6.65), Vector2(0.54, 0.25), damp)
	_build_clock()
	G.label(self, "А В Т О В О К З А Л", Vector3(0.1, 2.76, -6.62), 27, Color("b0ac94"))

func _build_clock() -> void:
	var clock := Node3D.new()
	clock.position = Vector3(-0.56, 2.26, -6.60)
	add_child(clock)
	var rim := G.cylinder(clock, 0.20, 0.04, Vector3.ZERO, G.worn_material(Color("555949"), "metal", 0.7, 0.4))
	rim.rotation_degrees.x = 90
	var dial := G.cylinder(clock, 0.176, 0.01, Vector3(0, 0, 0.025), G.worn_material(Color("b7b69b"), "paper"))
	dial.rotation_degrees.x = 90
	var ink := G.material(Color("2c3b30"))
	G.rod(clock, Vector3(0, 0, 0.036), Vector3(-0.09, 0.04, 0.036), 0.007, ink)
	G.rod(clock, Vector3(0, 0, 0.038), Vector3(0.05, 0.13, 0.038), 0.005, ink)
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		G.sphere(clock, 0.006, Vector3(sin(angle) * 0.15, cos(angle) * 0.15, 0.037), ink)

func _build_shelf() -> void:
	var wood := G.worn_material(Color("665845"), "wood")
	var shelf := Node3D.new()
	shelf.name = "EmployeeShelf"
	shelf.position = Vector3(-1.65, 0, 0.65)
	# Open front faces the employee, on the secure side of the cage.
	shelf.rotation_degrees.y = 59
	add_child(shelf)
	G.box(shelf, Vector3(1.35, 2.35, 0.06), Vector3(0, 1.20, -0.35), wood)
	for x in [-0.67, 0.67]:
		G.box(shelf, Vector3(0.06, 2.4, 0.75), Vector3(x, 1.20, 0), wood)
	for height in [0.28, 1.12, 2.02, 2.36]:
		G.box(shelf, Vector3(1.4, 0.08, 0.75), Vector3(0, height, 0), wood)
		G.box(shelf, Vector3(1.4, 0.07, 0.025), Vector3(0, height, 0.39), G.worn_material(Color("77725a"), "wood"))
	var crate: Node3D = CRATE_PROBE.instantiate()
	crate.name = "ImportedCrateProbe"
	crate.position = Vector3(-0.30, 0.55, 0)
	crate.scale = Vector3(0.50, 0.45, 0.5)
	shelf.add_child(crate)
	G.box(shelf, Vector3(0.45, 0.35, 0.47), Vector3(0.29, 0.50, 0), G.worn_material(Color("77755e"), "paper"))
	G.box(shelf, Vector3(0.70, 0.22, 0.50), Vector3(-0.18, 2.17, 0), G.worn_material(Color("716a4d"), "paper"))
	var folders := [Color("6b6552"), Color("82735b"), Color("626d67")]
	for i in range(5):
		var folder := G.box(shelf, Vector3(0.065, 0.27 + (i % 2) * 0.04, 0.35), Vector3(0.32 + i * 0.067, 2.21, -0.02), G.worn_material(folders[i % 3], "paper"))
		folder.rotation_degrees.z = -3 + i
		G.box(shelf, Vector3(0.045, 0.05, 0.004), Vector3(0.32 + i * 0.067, 2.27, 0.158), G.worn_material(Color("b4aa91"), "paper"))
	G.label(shelf, "ХРАНЕНИЕ", Vector3(0, 2.48, 0.38), 27, Color("c0b592"))
	G.label(shelf, "П01", Vector3(0, 1.12, 0.412), 20, Color("c8b788"))
	_package.rotation_degrees.y = 59

func _build_desk() -> void:
	var wood := G.worn_material(Color("69543d"), "wood")
	var dark := G.worn_material(Color("423d32"), "wood")
	G.box(self, Vector3(1.65, 0.09, 0.94), Vector3(-0.35, 0.895, -0.02), wood)
	G.box(self, Vector3(1.36, 0.008, 0.74), Vector3(-0.35, 0.944, -0.02), G.worn_material(Color("454b3e"), "leather"))
	G.box(self, Vector3(1.67, 0.045, 0.028), Vector3(-0.35, 0.892, 0.462), G.worn_material(Color("847154"), "wood"))
	for x in [-1.1, 0.39]:
		G.box(self, Vector3(0.08, 0.86, 0.08), Vector3(x, 0.43, -0.36), dark)
		G.box(self, Vector3(0.08, 0.86, 0.08), Vector3(x, 0.43, 0.36), dark)
	G.box(self, Vector3(0.39, 0.73, 0.71), Vector3(-0.98, 0.49, -0.06), dark)
	var drawer_metal := G.worn_material(Color("77766a"), "metal", 0.75, 0.4)
	for y in [0.29, 0.53, 0.77]:
		G.box(self, Vector3(0.34, 0.21, 0.027), Vector3(-0.98, y, 0.31), wood)
		G.rod(self, Vector3(-1.05, y + 0.015, 0.34), Vector3(-0.91, y + 0.015, 0.34), 0.009, drawer_metal)
	# Under the forward edge: visible only when the clerk looks down and right.
	G.box(self, Vector3(0.99, 0.07, 0.77), Vector3(0.60, 0.215, 0.65), dark)
	for x in [0.15, 1.04]:
		G.box(self, Vector3(0.06, 0.22, 0.71), Vector3(x, 0.11, 0.65), dark)
	_build_paper("identity", Vector3(-0.69, 0.952, 0.28), -7, "УДОСТОВЕРЕНИЕ", Color("b8b097"))
	_build_paper("claim", Vector3(-0.20, 0.953, 0.32), 6, "ЗАЯВЛЕНИЕ № 01", Color("b4ae94"))
	var archive := Node3D.new()
	archive.name = "ArchiveFolder"
	archive.position = Vector3(-0.99, 0.95, -0.13)
	archive.rotation_degrees.y = -5
	add_child(archive)
	G.box(archive, Vector3(0.28, 0.08, 0.43), Vector3(0, 0.04, 0), G.worn_material(Color("6c6549"), "paper"))
	G.box(archive, Vector3(0.29, 0.015, 0.44), Vector3(0, 0.088, 0), wood)
	var label := G.label(archive, "АРХИВ", Vector3(0, 0.098, 0), 19, Color("c9bd9b"))
	label.rotation_degrees.x = -90
	label.pixel_size = 0.002
	G.target(archive, "archive", Vector3(0.32, 0.14, 0.46), Vector3(0, 0.07, 0))
	_add_highlight(archive, "archive", Vector3(0.32, 0.004, 0.47), Vector3.ZERO)
	_build_lamp()
	_build_clerk_details()

func _build_paper(target_id: String, position: Vector3, angle: float, title: String, color: Color) -> void:
	var paper := Node3D.new()
	paper.position = position
	paper.rotation_degrees.y = angle
	add_child(paper)
	G.box(paper, Vector3(0.37, 0.007, 0.24), Vector3.ZERO, G.worn_material(color, "paper"))
	var ink := G.material(Color("57624f"))
	for line_index in range(5):
		G.box(paper, Vector3(0.24 if line_index % 2 == 0 else 0.18, 0.001, 0.003), Vector3(0.01, 0.005, -0.02 + line_index * 0.019), ink)
	var text := G.label(paper, title, Vector3(0, 0.007, -0.078), 13, Color("3a493a"))
	text.rotation_degrees.x = -90
	text.pixel_size = 0.0016
	G.target(paper, target_id, Vector3(0.41, 0.03, 0.28), Vector3(0, 0.01, 0))
	_add_highlight(paper, target_id, Vector3(0.41, 0.003, 0.28), Vector3(0, -0.001, 0))

func _build_cage() -> void:
	var metal := G.worn_material(Color("49514b"), "metal", 0.88, 0.35)
	var edge := G.worn_material(Color("797a6d"), "metal", 0.83, 0.4)
	var timber := G.worn_material(Color("6a5941"), "wood")
	G.box(self, Vector3(4.16, 0.86, 0.12), Vector3(-0.40, 0.43, -0.77), metal)
	G.box(self, Vector3(4.22, 0.09, 0.43), Vector3(-0.40, 0.895, -0.76), timber)
	# The face occupies the speaking opening. Bars remain prominent at its sides.
	for x in [-2.45, -2.15, -1.87, -1.57, -1.27, -0.97, -0.67, -0.39, 0.39, 1.35, 1.65]:
		G.rod(self, Vector3(x, 1.74 if x == 0.39 else 0.94, -0.75), Vector3(x, 2.65, -0.75), 0.017, metal)
	for y in [2.02, 2.60]:
		G.rod(self, Vector3(-2.48, y, -0.75), Vector3(1.69, y, -0.75), 0.027, metal)
	G.rod(self, Vector3(-1.9, 1.20, -0.75), Vector3(-0.40, 1.20, -0.75), 0.014, edge)
	G.rod(self, Vector3(1.33, 1.20, -0.75), Vector3(1.69, 1.20, -0.75), 0.014, edge)
	G.box(self, Vector3(1.45, 0.26, 0.04), Vector3(-0.43, 2.14, -0.70), metal)
	G.label(self, "БЮРО НАХОДОК", Vector3(-0.43, 2.14, -0.668), 25, Color("bbb89b"))
	G.label(self, "ДОКУМЕНТЫ — В ЛОТОК", Vector3(-0.80, 0.77, -0.69), 17, Color("a6af95"))
	# Side cage returns make the clerk's enclosure legible during head turns.
	for z in [-0.4, 0.0, 0.4, 0.8, 1.2, 1.6]:
		G.rod(self, Vector3(-2.45, 0, z), Vector3(-2.45, 2.65, z), 0.016, metal)
	G.rod(self, Vector3(-2.45, 2.05, -0.75), Vector3(-2.45, 2.05, 1.9), 0.025, metal)
	# Weld plates, slotted screws and a timber wear rail break the uniform grid.
	for x in [-1.87, -1.27, -0.67, -0.39, 0.39, 1.35]:
		G.box(self, Vector3(0.073, 0.14, 0.018), Vector3(x, 2.02, -0.711), edge)
		_screw_z(self, Vector3(x, 1.975, -0.695), 0.008, metal)
		_screw_z(self, Vector3(x, 2.065, -0.695), 0.008, metal)
	for x in [-1.87, -0.97, -0.39, 1.35]:
		G.box(self, Vector3(0.12, 0.035, 0.13), Vector3(x, 0.961, -0.75), edge)
	G.box(self, Vector3(1.41, 0.045, 0.055), Vector3(-1.19, 0.963, -0.51), timber)
	G.box(self, Vector3(0.39, 0.135, 0.018), Vector3(-1.16, 0.69, -0.687), G.worn_material(Color("b7b09a"), "metal"))
	G.label(self, "ОКНО № 1", Vector3(-1.16, 0.69, -0.674), 18, Color("42483e"))

func _build_hatch() -> void:
	var frame := G.worn_material(Color("6b7069"), "metal", 0.86, 0.4)
	var dark := G.worn_material(Color("3f4641"), "metal", 0.9, 0.35)
	var hatch := Node3D.new()
	hatch.name = "SecureTransferHatch"
	hatch.position = PACKAGE_POSITIONS["hatch"]
	add_child(hatch)
	G.box(hatch, Vector3(1.08, 0.06, 0.88), Vector3(0, -0.03, 0), frame)
	G.box(hatch, Vector3(1.08, 0.07, 0.88), Vector3(0, 0.76, 0), dark)
	for x in [-0.53, 0.53]:
		G.box(hatch, Vector3(0.045, 0.77, 0.88), Vector3(x, 0.365, 0), frame)
		for z in [-0.44, 0.44]:
			G.box(hatch, Vector3(0.065, 1.10, 0.065), Vector3(x, 0.55, z), dark)
	_inner_door = _make_hatch_door(hatch, "InnerDoor", 0.44, frame)
	_outer_door = _make_hatch_door(hatch, "OuterDoor", -0.44, frame)
	G.label(hatch, "ПЕРЕДАТОЧНЫЙ ШЛЮЗ", Vector3(0, 0.83, 0.49), 16, Color("bbb59d"))
	G.label(hatch, "1", Vector3(-0.42, 0.34, 0.49), 22, Color("d1c39a"))
	for x in [-0.50, 0.50]:
		for y in [0.11, 0.65, 0.95]:
			_screw_z(hatch, Vector3(x, y, 0.478), 0.008, dark)
		G.box(hatch, Vector3(0.025, 1.08, 0.027), Vector3(x * 0.90, 0.54, 0.485), dark)

func _make_hatch_door(parent: Node3D, object_name: String, z: float, material: Material) -> Node3D:
	var door := Node3D.new()
	door.name = object_name
	parent.add_child(door)
	for y in [0.04, 0.71]:
		G.box(door, Vector3(1.0, 0.045, 0.04), Vector3(0, y, z), material)
	for x in [-0.48, 0.48]:
		G.box(door, Vector3(0.045, 0.71, 0.04), Vector3(x, 0.37, z), material)
	for i in range(1, 8):
		G.rod(door, Vector3(-0.48 + i * 0.12, 0.06, z), Vector3(-0.48 + i * 0.12, 0.69, z), 0.009, material)
	G.rod(door, Vector3(-0.46, 0.36, z), Vector3(0.46, 0.36, z), 0.009, material)
	return door

func _build_lamp() -> void:
	var brass := G.worn_material(Color("81755c"), "metal", 0.72, 0.5)
	var green := G.worn_material(Color("555b47"), "metal", 0.79, 0.3)
	var base := Vector3(-1.14, 0.98, -0.42)
	G.cylinder(self, 0.11, 0.035, base, brass)
	G.rod(self, base, base + Vector3(0.02, 0.40, -0.02), 0.013, brass)
	G.rod(self, base + Vector3(0.02, 0.40, -0.02), base + Vector3(0.24, 0.47, 0.02), 0.013, brass)
	G.cylinder(self, 0.17, 0.13, base + Vector3(0.24, 0.46, 0.02), green, 0.08)
	var glow := G.material(Color("d4b473"))
	glow.emission_enabled = true
	glow.emission = Color("d7ad64")
	glow.emission_energy_multiplier = 0.65
	G.cylinder(self, 0.145, 0.006, base + Vector3(0.24, 0.392, 0.02), glow)
	var lamp := SpotLight3D.new()
	lamp.name = "WarmDeskLamp"
	lamp.position = base + Vector3(0.24, 0.33, 0.02)
	lamp.light_color = Color("e4c99b")
	lamp.light_energy = 1.65
	lamp.spot_range = 2.1
	lamp.spot_angle = 55
	lamp.spot_attenuation = 1.2
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.look_at(Vector3(-0.42, 0.94, 0.25), Vector3.UP)
	# The cable goes down the rear of the desk, away from the transfer path.
	var cord := G.material(Color("292e28"))
	G.rod(self, base + Vector3(-0.06, -0.01, -0.03), Vector3(-1.23, 0.79, -0.48), 0.004, cord)
	G.rod(self, Vector3(-1.23, 0.79, -0.48), Vector3(-1.23, 0.10, -0.48), 0.004, cord)
	G.rod(self, Vector3(-1.23, 0.10, -0.48), Vector3(-1.49, 0.035, 0.0), 0.004, cord)

func _build_nina() -> void:
	_visitor = Node3D.new()
	_visitor.name = "Nina"
	_visitor.position = VISITOR_WAIT
	add_child(_visitor)
	_visitor_geometry = Node3D.new()
	_visitor_geometry.name = "FallbackFigure"
	_visitor.add_child(_visitor_geometry)
	var nina := _visitor_geometry
	var coat := G.worn_material(Color("655e4c"), "cloth")
	var skirt := G.worn_material(Color("414c40"), "cloth")
	var skin := G.worn_material(Color("a99a7e"), "skin")
	var hair := G.worn_material(Color("747569"), "cloth")
	var eye := G.material(Color("2f3a2e"))
	G.cylinder(nina, 0.23, 0.61, Vector3(0, 0.99, 0), coat, 0.19)
	G.cylinder(nina, 0.245, 0.40, Vector3(0, 0.52, 0), skirt, 0.19)
	for x in [-0.12, 0.12]:
		G.cylinder(nina, 0.05, 0.28, Vector3(x, 0.20, 0), skirt)
		G.box(nina, Vector3(0.14, 0.08, 0.23), Vector3(x, 0.04, 0.035), eye)
	G.cylinder(nina, 0.06, 0.10, Vector3(0, 1.33, 0), skin)
	G.sphere(nina, 0.19, Vector3(0, 1.55, 0), hair, Vector3(0.9, 1.2, 0.85))
	G.sphere(nina, 0.16, Vector3(0, 1.54, 0.05), skin, Vector3(0.89, 1.12, 0.86))
	G.sphere(nina, 0.09, Vector3(0.05, 1.58, -0.15), hair)
	G.sphere(nina, 0.145, Vector3(-0.03, 1.67, 0.025), hair, Vector3(1.0, 0.42, 1.0))
	for x in [-0.052, 0.052]:
		G.sphere(nina, 0.013, Vector3(x, 1.57, 0.183), eye, Vector3(0.8, 0.45, 0.45))
	G.sphere(nina, 0.023, Vector3(0, 1.525, 0.19), skin, Vector3(0.58, 0.9, 0.7))
	G.rod(nina, Vector3(-0.03, 1.478, 0.168), Vector3(0.03, 1.48, 0.168), 0.003, eye)
	var scarf := G.worn_material(Color("858670"), "cloth")
	G.sphere(nina, 0.10, Vector3(0, 1.32, 0.03), scarf, Vector3(1.5, 0.40, 1.1))
	G.box(nina, Vector3(0.09, 0.27, 0.02), Vector3(-0.06, 1.13, 0.21), scarf)
	for side in [-1.0, 1.0]:
		G.rod(nina, Vector3(side * 0.2, 1.19, 0), Vector3(side * 0.27, 0.94, 0.14), 0.065, coat)
		G.rod(nina, Vector3(side * 0.27, 0.94, 0.14), Vector3(side * 0.17, 1.0, 0.42), 0.055, coat)
		G.sphere(nina, 0.055, Vector3(side * 0.17, 1.0, 0.42), skin, Vector3(0.8, 0.45, 1.0))
	_visitor_target = G.target(_visitor, "nina", Vector3(0.75, 1.2, 0.55), Vector3(0, 1.11, 0.05))
	_load_nina_image_if_available()
	_set_visitor_phase("absent")

func _load_nina_image_if_available() -> void:
	var path := "res://assets/characters/nina-v2.png"
	if not ResourceLoader.exists(path):
		return
	var texture := load(path) as Texture2D
	if texture == null:
		return
	var sprite := Sprite3D.new()
	sprite.set_script(preload("res://scripts/presentation/visitor_portrait.gd"))
	sprite.name = "NinaPortrait"
	sprite.texture = texture
	sprite.pixel_size = 1.84 / float(texture.get_height())
	sprite.position = Vector3(0, 0.92, 0.06)
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.05
	sprite.no_depth_test = false
	# The painted shadows belong to the portrait; avoid illuminating them twice.
	sprite.shaded = false
	sprite.modulate = Color(0.66, 0.84, 0.88)
	_visitor.add_child(sprite)
	_visitor_geometry.visible = false
	_face_height = 1.600
	_face_depth = 0.06

func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	world.name = "BureauEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1f2523")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("999a96")
	environment.ambient_light_energy = 0.16
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var daylight := DirectionalLight3D.new()
	daylight.name = "StationEveningLight"
	daylight.rotation_degrees = Vector3(-48, -23, 0)
	daylight.light_color = Color("abb2b8")
	daylight.light_energy = 0.30
	daylight.shadow_enabled = true
	daylight.directional_shadow_max_distance = 15
	add_child(daylight)
	var face_light := OmniLight3D.new()
	face_light.name = "VisitorFluorescent"
	face_light.position = Vector3(-0.25, 2.52, -0.40)
	face_light.light_color = Color("c5c9c5")
	face_light.light_energy = 0.35
	face_light.omni_range = 3.2
	add_child(face_light)
	var shelf_light := OmniLight3D.new()
	shelf_light.name = "ClerkFill"
	shelf_light.position = Vector3(-0.7, 2.35, 0.9)
	shelf_light.light_color = Color("b5b2a0")
	shelf_light.light_energy = 0.48
	shelf_light.omni_range = 2.8
	add_child(shelf_light)
	var hall_light := OmniLight3D.new()
	hall_light.name = "ColdWaitingHallLight"
	hall_light.position = Vector3(-0.6, 2.72, -3.4)
	hall_light.light_color = Color("b4c1c6")
	hall_light.light_energy = 0.32
	hall_light.omni_range = 4.5
	add_child(hall_light)

func _add_highlight(parent: Node3D, target_id: String, size: Vector3, position: Vector3) -> void:
	var material := G.material(Color("a79a69"))
	material.emission_enabled = true
	material.emission = Color("7f754f")
	material.emission_energy_multiplier = 0.45
	var mesh := G.box(parent, size, position, material)
	mesh.visible = false
	_highlights[target_id] = mesh

func _build_station_door() -> void:
	var frame := G.worn_material(Color("69624f"), "wood")
	var paint := G.worn_material(Color("6d7165"), "paint")
	var metal := G.worn_material(Color("73746a"), "metal", 0.82, 0.4)
	G.box(self, Vector3(1.08, 2.28, 0.03), Vector3(-1.7, 1.14, -6.65), G.material(Color("252c27")))
	for x in [-2.29, -1.11]:
		G.box(self, Vector3(0.11, 2.42, 0.17), Vector3(x, 1.21, -6.59), frame)
	G.box(self, Vector3(1.29, 0.12, 0.17), Vector3(-1.7, 2.39, -6.59), frame)
	G.box(self, Vector3(1.13, 0.045, 0.32), Vector3(-1.7, 0.027, -6.48), metal)
	var wing := Node3D.new()
	wing.name = "HalfOpenStationDoor"
	wing.position = Vector3(-2.23, 0, -6.57)
	wing.rotation_degrees.y = -61
	add_child(wing)
	G.box(wing, Vector3(1.03, 2.23, 0.075), Vector3(0.515, 1.15, 0), paint)
	G.box(wing, Vector3(0.81, 0.87, 0.025), Vector3(0.515, 1.59, 0.05), frame)
	G.box(wing, Vector3(0.70, 0.76, 0.015), Vector3(0.515, 1.59, 0.069), G.worn_material(Color("59645d"), "tile"))
	G.box(wing, Vector3(0.91, 0.27, 0.02), Vector3(0.515, 0.24, 0.049), metal)
	G.box(wing, Vector3(0.07, 0.17, 0.018), Vector3(0.88, 1.08, 0.055), metal)
	G.rod(wing, Vector3(0.88, 1.11, 0.09), Vector3(0.77, 1.11, 0.09), 0.014, metal)
	G.label(self, "ПЛАТФОРМЫ  1—4", Vector3(-1.7, 2.60, -6.55), 23, Color("aca995"))
	# A second, shut employee door gives the secure side a believable entrance.
	var employee := Node3D.new()
	employee.position = Vector3(-3.39, 0, 1.65)
	employee.rotation_degrees.y = 90
	add_child(employee)
	G.box(employee, Vector3(0.91, 2.16, 0.055), Vector3(0, 1.08, 0), G.worn_material(Color("555447"), "wood"))
	for x in [-0.50, 0.50]:
		G.box(employee, Vector3(0.09, 2.30, 0.11), Vector3(x, 1.15, 0.02), frame)
	G.box(employee, Vector3(1.09, 0.10, 0.11), Vector3(0, 2.25, 0.02), frame)
	G.box(employee, Vector3(0.16, 0.15, 0.025), Vector3(0.32, 1.04, 0.045), metal)
	G.rod(employee, Vector3(0.34, 1.07, 0.075), Vector3(0.22, 1.07, 0.075), 0.014, metal)
	G.label(employee, "СЛУЖЕБНОЕ", Vector3(0, 1.72, 0.042), 17, Color("c0b59a"))

func _build_hall_window() -> void:
	var window := Node3D.new()
	window.name = "StationWindowAndRadiator"
	window.position = Vector3(2.29, 0, -4.3)
	window.rotation_degrees.y = -90
	add_child(window)
	var wood := G.worn_material(Color("777669"), "wood")
	var glass := G.worn_material(Color("657174"), "tile", 0.57)
	G.box(window, Vector3(1.65, 1.45, 0.07), Vector3(0, 1.96, 0), G.material(Color("363f3c")))
	for x in [-0.81, 0.0, 0.81]:
		G.box(window, Vector3(0.065, 1.45, 0.10), Vector3(x, 1.96, 0.035), wood)
	for x in [-0.40, 0.40]:
		G.box(window, Vector3(0.72, 1.28, 0.025), Vector3(x, 1.96, 0.025), glass)
	for y in [1.26, 2.66]:
		G.box(window, Vector3(1.72, 0.07, 0.13), Vector3(0, y, 0.04), wood)
	G.box(window, Vector3(1.88, 0.065, 0.31), Vector3(0, 1.23, 0.13), G.worn_material(Color("8d8d7c"), "plaster"))
	var radiator := G.worn_material(Color("7e8277"), "metal", 0.9, 0.25)
	for i in range(11):
		var x := -0.66 + i * 0.132
		G.rod(window, Vector3(x, 0.31, 0.11), Vector3(x, 0.91, 0.11), 0.041, radiator)
	for y in [0.38, 0.84]:
		G.rod(window, Vector3(-0.77, y, 0.11), Vector3(0.78, y, 0.11), 0.025, radiator)
	G.rod(window, Vector3(0.83, 0.35, 0.11), Vector3(0.83, 0.13, 0.11), 0.018, radiator)
	G.cylinder(window, 0.038, 0.035, Vector3(0.83, 0.33, 0.11), G.material(Color("4d5147")))

func _build_notices() -> void:
	var board := Node3D.new()
	board.name = "DustyStationNoticeBoard"
	board.position = Vector3(0.96, 1.73, -6.64)
	add_child(board)
	G.box(board, Vector3(1.63, 1.34, 0.07), Vector3.ZERO, G.worn_material(Color("4b493b"), "wood"))
	G.box(board, Vector3(1.49, 1.20, 0.02), Vector3(0, 0, 0.046), G.worn_material(Color("706955"), "cloth"))
	_wall_notice(board, Vector3(-0.32, 0.12, 0.065), Vector2(0.63, 0.88), "РАСПИСАНИЕ", "06:20   ПРИГОРОД\n08:10   СЕВЕРНЫЙ\n12:40   РЕЧНОЙ\n18:15   ПРИГОРОД\n22:40   ПОСЛЕДНИЙ", -2.0)
	_wall_notice(board, Vector3(0.40, 0.25, 0.068), Vector2(0.53, 0.55), "ОБЪЯВЛЕНИЕ", "БИЛЕТЫ\nСОХРАНЯТЬ\nДО КОНЦА ПОЕЗДКИ", 2.5)
	_wall_notice(board, Vector3(0.37, -0.36, 0.071), Vector2(0.48, 0.31), "ЗАБЫТЫЕ ВЕЩИ", "СПРАВА ОТ КАССЫ", -4.0)
	# Older notices leave pale rectangles and torn paper below the board.
	var old_paste := G.worn_material(Color("aaa08a"), "paper")
	G.box(self, Vector3(0.29, 0.48, 0.006), Vector3(-0.52, 1.53, -6.686), old_paste)
	G.box(self, Vector3(0.23, 0.09, 0.008), Vector3(-0.49, 1.18, -6.679), old_paste)
	var phone := Node3D.new()
	phone.position = Vector3(2.29, 1.73, -2.6)
	phone.rotation_degrees.y = -90
	add_child(phone)
	_wall_notice(phone, Vector3.ZERO, Vector2(0.54, 0.68), "СПРАВОЧНАЯ", "ПРИ УТЕРЕ БАГАЖА\nОБРАТИТЕСЬ К\nСМОТРИТЕЛЮ\n\nЧАСЫ РАБОТЫ\n08:00 — 23:00", -1.0)

func _wall_notice(parent: Node3D, position: Vector3, size: Vector2, title: String, text: String, angle: float) -> void:
	var notice := Node3D.new()
	notice.position = position
	notice.rotation_degrees.z = angle
	parent.add_child(notice)
	G.box(notice, Vector3(size.x, size.y, 0.007), Vector3.ZERO, G.worn_material(Color("c6baa0"), "paper"))
	var header := G.label(notice, title, Vector3(0, size.y * 0.35, 0.007), 19, Color("4b5144"))
	header.pixel_size = 0.00175
	var body := G.label(notice, text, Vector3(0, -size.y * 0.05, 0.008), 14, Color("555a4b"))
	body.pixel_size = 0.00155
	var nail := G.material(Color("777466"))
	G.sphere(notice, 0.006, Vector3(-size.x * 0.40, size.y * 0.42, 0.01), nail)
	G.sphere(notice, 0.006, Vector3(size.x * 0.40, size.y * 0.42, 0.01), nail)

func _build_bench() -> void:
	var bench := Node3D.new()
	bench.name = "WaitingHallBench"
	bench.position = Vector3(0.87, 0, -5.42)
	add_child(bench)
	var wood := G.worn_material(Color("6e6045"), "wood")
	var steel := G.worn_material(Color("424a40"), "metal", 0.87, 0.45)
	for x in [-0.61, 0.61]:
		G.rod(bench, Vector3(x, 0.04, 0.16), Vector3(x, 0.43, 0.11), 0.022, steel)
		G.rod(bench, Vector3(x, 0.04, -0.18), Vector3(x, 0.96, -0.25), 0.022, steel)
		G.rod(bench, Vector3(x, 0.39, -0.20), Vector3(x, 0.39, 0.20), 0.023, steel)
	for z in [-0.15, 0.0, 0.15]:
		G.box(bench, Vector3(1.63, 0.035, 0.12), Vector3(0, 0.45, z), wood)
	for y in [0.64, 0.79, 0.94]:
		G.box(bench, Vector3(1.63, 0.12, 0.035), Vector3(0, y, -0.25), wood)
	G.box(bench, Vector3(0.24, 0.015, 0.17), Vector3(0.45, 0.48, 0.02), G.worn_material(Color("b3aa92"), "paper"))

func _build_ceiling_fixture(position: Vector3, working: bool) -> void:
	var fixture := Node3D.new()
	fixture.name = "FluorescentFixture"
	fixture.position = position
	add_child(fixture)
	var enamel := G.worn_material(Color("83877b"), "metal", 0.8, 0.3)
	G.box(fixture, Vector3(1.38, 0.085, 0.29), Vector3.ZERO, enamel)
	G.box(fixture, Vector3(1.24, 0.025, 0.22), Vector3(0, -0.054, 0), G.material(Color("4c554b")))
	var tube := G.material(Color("abb4a2") if working else Color("72786c"))
	if working:
		tube.emission_enabled = true
		tube.emission = Color("b1c0ae")
		tube.emission_energy_multiplier = 0.35
	for z in [-0.065, 0.065]:
		var light_mesh := G.cylinder(fixture, 0.018, 1.13, Vector3(0, -0.077, z), tube)
		light_mesh.rotation_degrees.z = 90
		for x in [-0.58, 0.58]:
			G.box(fixture, Vector3(0.045, 0.065, 0.05), Vector3(x, -0.059, z), enamel)

func _add_wall_stain(parent: Node3D, position: Vector3, size: Vector2, material: Material) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.48, -0.09, 0), Vector3(0.34, -0.04, 0), Vector3(0.25, 0.33, 0), Vector3(0.09, 0.12, 0), Vector3(-0.11, 0.50, 0), Vector3(-0.23, 0.18, 0), Vector3(-0.47, 0.22, 0)]
	for i in range(1, points.size() - 1):
		for point in [points[0], points[i], points[i + 1]]:
			builder.add_vertex(Vector3(point.x * size.x, point.y * size.y, 0))
	builder.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = builder.commit()
	mesh.material_override = material
	mesh.position = position
	parent.add_child(mesh)

func _build_clerk_details() -> void:
	var enamel := G.worn_material(Color("b0aa91"), "metal", 0.75, 0.12)
	G.cylinder(self, 0.053, 0.12, Vector3(-1.045, 1.01, 0.24), enamel)
	G.cylinder(self, 0.045, 0.004, Vector3(-1.045, 1.072, 0.24), G.material(Color("3a3429")))
	var handle := G.worn_material(Color("7c7d6c"), "metal", 0.79, 0.2)
	G.rod(self, Vector3(-1.09, 1.04, 0.24), Vector3(-1.14, 1.04, 0.24), 0.008, handle)
	G.rod(self, Vector3(-1.14, 1.04, 0.24), Vector3(-1.14, 0.99, 0.24), 0.008, handle)
	G.rod(self, Vector3(-1.14, 0.99, 0.24), Vector3(-1.09, 0.99, 0.24), 0.008, handle)
	var stamp_wood := G.worn_material(Color("66513b"), "wood")
	G.box(self, Vector3(0.13, 0.026, 0.085), Vector3(-0.99, 0.967, 0.414), G.material(Color("353b31")))
	G.cylinder(self, 0.025, 0.075, Vector3(-0.99, 1.016, 0.414), stamp_wood)
	G.sphere(self, 0.033, Vector3(-0.99, 1.06, 0.414), stamp_wood, Vector3(1, 0.65, 1))
	var pencil := G.worn_material(Color("b1975e"), "wood")
	G.rod(self, Vector3(-0.85, 0.956, 0.444), Vector3(-0.63, 0.956, 0.427), 0.004, pencil)
	G.rod(self, Vector3(-0.86, 0.957, 0.423), Vector3(-0.68, 0.957, 0.437), 0.004, G.material(Color("626955")))
	G.rod(self, Vector3(-0.63, 0.956, 0.427), Vector3(-0.615, 0.956, 0.426), 0.002, G.material(Color("30362d")))
	# A bundle of used receipt forms lies under the date stamp.
	for i in range(5):
		var sheet := G.box(self, Vector3(0.21, 0.0015, 0.12), Vector3(-1.0, 0.951 + i * 0.0018, 0.40), G.worn_material(Color("afa58a"), "paper"))
		sheet.rotation_degrees.y = -3 + i
	var cloth := G.box(self, Vector3(0.16, 0.28, 0.012), Vector3(-1.14, 0.63, 0.19), G.worn_material(Color("787364"), "cloth"))
	cloth.rotation_degrees.z = -5
	# Receipt spike and a narrow writing pad sit behind the archive folder.
	G.cylinder(self, 0.055, 0.012, Vector3(-1.0, 0.958, -0.42), handle)
	G.rod(self, Vector3(-1.0, 0.967, -0.42), Vector3(-1.0, 1.13, -0.42), 0.0024, handle)
	for i in range(3):
		var receipt := G.box(self, Vector3(0.10, 0.001, 0.065), Vector3(-1.0, 1.0 + i * 0.008, -0.42), G.worn_material(Color("bab097"), "paper"))
		receipt.rotation_degrees.y = -11 + i * 9

func _screw_z(parent: Node3D, position: Vector3, radius: float, material: Material) -> void:
	var screw := G.cylinder(parent, radius, 0.006, position, material)
	screw.rotation_degrees.x = 90
	var slot := G.box(parent, Vector3(radius * 1.2, radius * 0.22, 0.001), position + Vector3(0, 0, 0.004), G.material(Color("30362f")))
	slot.rotation_degrees.z = 24
