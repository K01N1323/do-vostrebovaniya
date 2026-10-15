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
const VISITOR_WAIT := Vector3(0, 0, -1.25)
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
	var wall := G.worn_material(Color("56645a"), "plaster")
	var lower := G.worn_material(Color("354d43"), "paint")
	var trim := G.worn_material(Color("29372e"), "metal", 0.8, 0.4)
	var floor := G.worn_material(Color("39392f"), "wood")
	G.box(self, Vector3(7.0, 0.12, 10.0), Vector3(0, -0.06, -2.0), floor)
	for z in range(20):
		G.box(self, Vector3(7.0, 0.004, 0.012), Vector3(0, 0.004, -6.8 + z * 0.5), trim)
	G.box(self, Vector3(7.0, 3.3, 0.2), Vector3(0, 1.65, -6.8), wall)
	for x in [-3.5, 2.4]:
		G.box(self, Vector3(0.16, 3.3, 9.8), Vector3(x, 1.65, -2.0), wall)
		G.box(self, Vector3(0.025, 1.12, 9.8), Vector3(x + (0.09 if x < 0 else -0.09), 0.56, -2.0), lower)
	G.box(self, Vector3(7.0, 1.12, 0.025), Vector3(0, 0.56, -6.68), lower)
	G.box(self, Vector3(7.0, 0.07, 0.04), Vector3(0, 1.16, -6.66), trim)
	# A dark station corridor lets the visitor visibly approach the bureau.
	G.box(self, Vector3(1.05, 2.3, 0.025), Vector3(-1.7, 1.15, -6.66), G.material(Color("1b2722")))
	for x in [-2.27, -1.13]:
		G.box(self, Vector3(0.08, 2.4, 0.08), Vector3(x, 1.2, -6.59), trim)
	G.label(self, "ЗАЛ ОЖИДАНИЯ", Vector3(-1.7, 2.56, -6.60), 27, Color("a5ae93"))
	G.box(self, Vector3(1.55, 0.48, 0.43), Vector3(1.1, 0.38, -5.4), G.worn_material(Color("4f4c39"), "wood"))
	G.box(self, Vector3(1.55, 0.38, 0.06), Vector3(1.1, 0.82, -5.6), lower)
	_build_clock()
	G.label(self, "А В Т О В О К З А Л", Vector3(0.4, 2.74, -6.62), 28, Color("a8b09a"))
	G.label(self, "ПОСЛЕДНИЙ РЕЙС  22:40", Vector3(0.4, 2.40, -6.62), 19, Color("919c87"))

func _build_clock() -> void:
	var clock := Node3D.new()
	clock.position = Vector3(-0.75, 2.44, -2.9)
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
	var wood := G.worn_material(Color("4e4b37"), "wood")
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
	G.label(shelf, "ХРАНЕНИЕ", Vector3(0, 2.48, 0.38), 27, Color("c0b592"))
	G.label(shelf, "П01", Vector3(0, 1.12, 0.412), 20, Color("c8b788"))
	_package.rotation_degrees.y = 59

func _build_desk() -> void:
	var wood := G.worn_material(Color("554b34"), "wood")
	var dark := G.worn_material(Color("333c2e"), "wood")
	G.box(self, Vector3(1.65, 0.09, 0.94), Vector3(-0.35, 0.895, -0.02), wood)
	G.box(self, Vector3(1.36, 0.008, 0.74), Vector3(-0.35, 0.944, -0.02), G.worn_material(Color("2d493b"), "paint"))
	for x in [-1.1, 0.39]:
		G.box(self, Vector3(0.08, 0.86, 0.08), Vector3(x, 0.43, -0.36), dark)
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
	G.cylinder(self, 0.053, 0.12, Vector3(0.27, 1.01, 0.31), G.worn_material(Color("8a9a87"), "metal", 0.6, 0.1))
	G.cylinder(self, 0.044, 0.004, Vector3(0.27, 1.072, 0.31), G.material(Color("3f3929")))

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
	var metal := G.worn_material(Color("35483d"), "metal", 0.79, 0.5)
	var edge := G.worn_material(Color("737760"), "metal", 0.7, 0.45)
	var timber := G.worn_material(Color("575039"), "wood")
	G.box(self, Vector3(4.16, 0.86, 0.12), Vector3(-0.40, 0.43, -0.77), metal)
	G.box(self, Vector3(4.22, 0.09, 0.43), Vector3(-0.40, 0.895, -0.76), timber)
	# The face occupies the speaking opening. Bars remain prominent at its sides.
	for x in [-2.45, -2.15, -1.87, -1.57, -1.27, -0.97, -0.67, -0.39, 0.39, 1.35, 1.65]:
		G.rod(self, Vector3(x, 1.74 if x == 0.39 else 0.94, -0.75), Vector3(x, 2.65, -0.75), 0.017, metal)
	for y in [2.02, 2.60]:
		G.rod(self, Vector3(-2.48, y, -0.75), Vector3(1.69, y, -0.75), 0.027, metal)
	G.rod(self, Vector3(-1.9, 1.20, -0.75), Vector3(-0.40, 1.20, -0.75), 0.014, edge)
	G.rod(self, Vector3(1.33, 1.20, -0.75), Vector3(1.69, 1.20, -0.75), 0.014, edge)
	G.box(self, Vector3(1.45, 0.26, 0.04), Vector3(-0.43, 2.36, -0.70), metal)
	G.label(self, "БЮРО НАХОДОК", Vector3(-0.43, 2.36, -0.668), 29, Color("bbb89b"))
	G.label(self, "ДОКУМЕНТЫ — В ЛОТОК", Vector3(-0.80, 0.77, -0.69), 17, Color("a6af95"))
	# Side cage returns make the clerk's enclosure legible during head turns.
	for z in [-0.4, 0.0, 0.4, 0.8, 1.2, 1.6]:
		G.rod(self, Vector3(-2.45, 0, z), Vector3(-2.45, 2.65, z), 0.016, metal)
	G.rod(self, Vector3(-2.45, 2.05, -0.75), Vector3(-2.45, 2.05, 1.9), 0.025, metal)

func _build_hatch() -> void:
	var frame := G.worn_material(Color("596151"), "metal", 0.76, 0.55)
	var dark := G.worn_material(Color("303d32"), "metal", 0.85, 0.45)
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
	G.label(hatch, "ПЕРЕДАТОЧНЫЙ ШЛЮЗ", Vector3(0, 0.83, 0.49), 18, Color("c6bd9c"))
	G.label(hatch, "1", Vector3(-0.42, 0.34, 0.49), 22, Color("d1c39a"))

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
	var brass := G.worn_material(Color("747149"), "metal", 0.55, 0.6)
	var green := G.worn_material(Color("3c543e"), "metal", 0.58, 0.35)
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
	var lamp := OmniLight3D.new()
	lamp.name = "WarmDeskLamp"
	lamp.position = base + Vector3(0.24, 0.33, 0.02)
	lamp.light_color = Color("e6be75")
	lamp.light_energy = 0.95
	lamp.omni_range = 2.7
	lamp.shadow_enabled = true
	add_child(lamp)

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
	var path := "res://assets/characters/nina-v1.png"
	if not ResourceLoader.exists(path):
		return
	var texture := load(path) as Texture2D
	if texture == null:
		return
	var sprite := Sprite3D.new()
	sprite.name = "NinaPortrait"
	sprite.texture = texture
	sprite.pixel_size = 1.72 / float(texture.get_height())
	sprite.position = Vector3(0, 0.86, 0.06)
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.05
	sprite.no_depth_test = false
	sprite.shaded = true
	_visitor.add_child(sprite)
	_visitor_geometry.visible = false
	_face_height = 1.72 * (1.0 - 0.116)
	_face_depth = 0.06

func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	world.name = "BureauEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("17251e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("909d84")
	environment.ambient_light_energy = 0.31
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var daylight := DirectionalLight3D.new()
	daylight.name = "StationEveningLight"
	daylight.rotation_degrees = Vector3(-48, -23, 0)
	daylight.light_color = Color("9eafa1")
	daylight.light_energy = 0.50
	daylight.shadow_enabled = true
	daylight.directional_shadow_max_distance = 15
	add_child(daylight)
	var face_light := OmniLight3D.new()
	face_light.name = "VisitorFluorescent"
	face_light.position = Vector3(-0.1, 2.5, -1.9)
	face_light.light_color = Color("bfc4a1")
	face_light.light_energy = 1.15
	face_light.omni_range = 4.5
	add_child(face_light)
	var shelf_light := OmniLight3D.new()
	shelf_light.name = "ClerkFill"
	shelf_light.position = Vector3(-0.7, 2.35, 0.9)
	shelf_light.light_color = Color("a1af8c")
	shelf_light.light_energy = 0.65
	shelf_light.omni_range = 3.1
	add_child(shelf_light)
	var fixture := G.worn_material(Color("9b9f85"), "metal")
	G.box(self, Vector3(1.2, 0.06, 0.18), Vector3(-0.1, 2.72, -1.9), fixture)

func _add_highlight(parent: Node3D, target_id: String, size: Vector3, position: Vector3) -> void:
	var material := G.material(Color("a79a69"))
	material.emission_enabled = true
	material.emission = Color("7f754f")
	material.emission_energy_multiplier = 0.45
	var mesh := G.box(parent, size, position, material)
	mesh.visible = false
	_highlights[target_id] = mesh
