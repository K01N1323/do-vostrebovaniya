extends Node3D
## The clerk is inside the cage. Presentation owns movement, never story state.

signal target_clicked(target_id: String)
signal hover_changed(target_id: String)
signal visitor_arrived
signal sound_requested(id: String)
signal handover_finished
signal visitor_departed

const Portrait = preload("res://scripts/presentation/visitor_portrait.gd")
const VisitorActing = preload("res://scripts/presentation/visitor_performance.gd")
const StationShell = preload("res://scripts/presentation/station_shell.gd")
const Packages = preload("res://scripts/presentation/package_registry.gd")
const G = preload("res://scripts/presentation/geometry.gd")
const CRATE_PROBE = preload("res://assets/models/crate_probe.glb")
const Rules = preload("res://scripts/core/state_reducer.gd")
const PACKAGE_POSITIONS := {
	"shelf": Vector3(-1.65, 1.16, 0.65),
	"desk": Vector3(-0.28, 0.94, -0.02),
	"personal": Vector3(0.60, 0.25, 0.65),
	"hatch": Vector3(0.72, 0.94, -0.62),
}
const VISITOR_WAIT := Vector3(0, 0, -0.94)
const VISITOR_FAR := Vector3(-1.7, 0, -5.8)
const BUS_WAIT := Vector3(-0.58, 0, -4.60)
const NINA_ASIDE := Vector3(0.82, 0, -1.55)

@export var input_enabled: bool = true
var visitor_phase: String = "absent"
var transfer_active: bool = false
var reduced_motion: bool = false
var _snapshot: Dictionary = {}
var _has_snapshot: bool = false
var _hovered: String = ""
var _pointer_position := Vector2.ZERO
var _highlights: Dictionary = {}
var _visitor: Node3D
var _visitor_geometry: Node3D
var _active_portrait: Portrait
var _bus_portrait: Portrait
var _visitor_target: StaticBody3D
var _waiting_serov: Node3D
var _waiting_serov_target: StaticBody3D
var _archived_card: Node3D
var _serov_card: MeshInstance3D
var _held_card: Node3D
var _personal_card_target: StaticBody3D
var _visitor_tween: Tween
var _transfer_tween: Tween
var _rotation_tween: Tween
var _inner_door: Node3D
var _outer_door: Node3D
var _inner_open: bool = false
var _outer_open: bool = false
var _face_height: float = 1.60
var _face_depth: float = 0.06
var _view_id: String = "window"
var _dialogue_framing := false
var _package_views: Dictionary = {}
var _paper_titles: Dictionary = {}

@onready var _package: Node3D = $Package

func _ready() -> void:
	if not GameStore.content_errors.is_empty():
		return
	StationShell.build(self)
	_build_shelf()
	_build_desk()
	_build_cage()
	_build_hatch()
	_build_nina()
	_package_views["P01"] = _package
	for id in Packages.SCENES:
		if id == "P01":
			continue
		var view := Packages.instantiate(id)
		add_child(view)
		_package_views[id] = view
	_build_lighting()
	var pending := _snapshot.duplicate(true)
	_snapshot.clear()
	if not pending.is_empty():
		apply_snapshot(pending)
	else:
		_set_visitor_phase("absent")

func apply_snapshot(snapshot: Dictionary, restored: bool = false) -> void:
	if not is_node_ready():
		_snapshot = snapshot.duplicate(true)
		return
	var previous := _snapshot
	var had_previous := _has_snapshot
	var previous_started := bool(previous.get("started", false))
	var started := bool(snapshot.get("started", false))
	var status := str(snapshot.get("case_status", "active"))
	var previous_status := str(previous.get("case_status", "active"))
	var changed_case: bool = had_previous and previous.get("case_id", "nina") != snapshot.case_id
	var previous_package: Dictionary = previous.get("package", {})
	var previous_location := str(previous_package.get("location", "shelf"))
	var package_state: Dictionary = snapshot.get("package", {})
	var location := str(package_state.get("location", "shelf"))
	var restarted := had_previous and ((previous_started and not started) or (previous_status == "resolved" and status == "active" and not changed_case))
	_snapshot = snapshot.duplicate(true)
	_has_snapshot = true
	if restarted or changed_case or not had_previous or restored:
		_cancel_animations()
		set_hovered("")
		_package = _package_views[package_state.id]
		_package.rotation = Vector3.ZERO
		_set_visitor_phase("absent")
		_configure_visitor(snapshot.case_id)
	if restarted or changed_case or not had_previous or restored or previous.has("deferred_gleb") != snapshot.has("deferred_gleb"):
		_render_inactive_packages()
	if not started:
		_cancel_animations()
		_set_visitor_phase("absent")
	elif not had_previous or restored:
		var at_bus: bool = snapshot.case_id == "serov" and Rules.serov_waits_for_bus(snapshot)
		_visitor.position = BUS_WAIT if at_bus else VISITOR_WAIT
		_set_visitor_phase("at_bus" if at_bus else ("gone" if status == "resolved" else "waiting"))
	elif (not previous_started and started) or changed_case:
		_start_arrival()
	if location == "issued" and had_previous and previous_location in ["desk", "shelf"] and not restarted and not changed_case and not restored:
		_start_handover(snapshot.has("handling"))
	elif not transfer_active:
		_package.visible = location != "issued" and not (snapshot.case_id == "finale" and visitor_phase == "arriving")
		if PACKAGE_POSITIONS.has(location):
			_package.position = _package_position(package_state.id, location)
		if restarted or changed_case or not had_previous or location != previous_location:
			_package.rotation_degrees.y = 59.0 if location == "shelf" else (-45.0 if location == "personal" else 0.0)
		_update_package_lid()
		_set_package_picking(_package.visible and (snapshot.case_id != "finale" or snapshot.card_location == "bag"))
	_render_auxiliary_finds()
	_sync_finale_props()
	$WarmDeskLamp.visible = not snapshot.get("shift_closed", false)
	if started and status == "resolved" and had_previous and previous_status != "resolved" and not restored:
		if _snapshot.case_id == "finale":
			_set_visitor_phase("gone")
		else:
			_start_departure()
	if not _package.visible and _hovered == package_state.id:
		set_hovered("")

func _package_position(package_id: String, location: String) -> Vector3:
	if package_id == "P08":
		if location == "shelf":
			return Vector3(-2.14, 0.32, 1.46)
		if location == "personal":
			return Vector3(0.68, 0.57, -0.12)
	if package_id == "P05":
		if location == "shelf":
			return Vector3(-1.14, 0.32, -0.20)
		if location == "personal":
			return Vector3(0.68, 0.25, -0.12)
	if package_id == "P06" and location == "shelf":
		return Vector3(-1.14, 1.16, -0.20)
	if package_id == "P07" and location == "shelf":
		return Vector3(-1.14, 2.06, -0.20)
	if package_id == "P04":
		if location == "shelf":
			return Vector3(-2.14, 1.16, 1.46)
		if location == "personal":
			return Vector3(1.55, 0.25, 0.18)
	if package_id == "P03" and location == "shelf":
		return Vector3(-1.55, 0.32, 0.48)
	if package_id == "P02":
		if location == "shelf":
			return Vector3(-1.65, 2.06, 0.65)
		if location == "personal":
			return Vector3(1.55, 0.25, 1.05)
	return PACKAGE_POSITIONS.get(location, Vector3.ZERO)

func _render_inactive_packages() -> void:
	var packages: Dictionary = Rules.all_packages(_snapshot)
	var auxiliary: Dictionary = Rules.auxiliary_packages(_snapshot)
	for id in _package_views:
		var view: Node3D = _package_views[id]
		if view == _package or auxiliary.has(id):
			continue
		var item: Dictionary = packages.get(id, {})
		if item.is_empty():
			view.hide()
			view.get_node("Target_" + id).collision_layer = 0
			continue
		view.visible = item.location != "issued"
		view.position = _package_position(id, item.location)
		view.rotation_degrees.y = 59 if item.location == "shelf" else -45
		view.set_opened(false)
		if view.has_method("set_unlocked"):
			view.set_unlocked(item.get("unlocked",false))
			view.set_lining_lifted(item.get("lining_lifted",false))
		view.set_highlighted(false)
		var target: StaticBody3D = view.get_node("Target_" + id)
		target.collision_layer = 0

func _render_auxiliary_finds() -> void:
	var auxiliary := Rules.auxiliary_packages(_snapshot)
	for id in auxiliary:
		var item: Dictionary = auxiliary[id]
		var view: Node3D = _package_views[id]
		var on_desk: bool = item.location == "desk"
		view.show()
		view.position = _package_position(id, item.location)
		view.rotation_degrees.y = 0.0 if on_desk else 59.0
		view.set_opened(on_desk and item.opened and _view_id == "desk")
		if view.has_method("set_unlocked"):
			view.set_unlocked(item.unlocked)
			view.set_lining_lifted(item.lining_lifted)
		view.set_highlighted(id == _hovered)
		var target: StaticBody3D = view.get_node("Target_" + id)
		target.collision_layer = 1 if _snapshot.started and not (transfer_active and on_desk) else 0

func _sync_finale_props() -> void:
	var at_bus: bool = _snapshot.started and _snapshot.completed_cases.has("serov")
	_waiting_serov.visible = at_bus
	_waiting_serov_target.collision_layer = 1 if at_bus else 0
	if _snapshot.case_id == "finale" and visitor_phase == "waiting":
		var nina_at_window: bool = _snapshot.card_location == "bag"
		_visitor.position = VISITOR_WAIT if nina_at_window else NINA_ASIDE
		_visitor_target.collision_layer = 1 if nina_at_window else 0
	_package_views.P08.set_card_inside(_snapshot.card_location == "bag")
	_archived_card.visible = _snapshot.card_location in ["archive", "archive_draft"]
	_held_card.visible = _snapshot.card_location == "hand"
	_personal_card_target.collision_layer = 1 if _held_card.visible else 0
	_serov_card.visible = _snapshot.card_location == "serov"
	_show_issued_coat()

func _show_issued_coat() -> void:
	if not is_serov_at_bus() or transfer_active:
		return
	var coat: Dictionary = Rules.all_packages(_snapshot).P05
	if coat.location == "issued":
		var view: Node3D = _package_views.P05
		view.set_opened(false)
		view.rotation_degrees.y = -16.0
		view.position = BUS_WAIT + Vector3(0.40, 0, 0.10)
		view.show()

func is_serov_at_bus() -> bool:
	return visitor_phase == "at_bus" or _waiting_serov.visible

func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		set_hovered("")

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value

func set_view(view_id: String) -> void:
	_view_id = view_id
	_update_package_lid()
	if _has_snapshot:
		_render_auxiliary_finds()

func set_dialogue_framing(active: bool, _paired: bool) -> void:
	_dialogue_framing = active
	_update_package_lid()

func _update_package_lid() -> void:
	if not is_instance_valid(_package) or transfer_active:
		return
	var package_state: Dictionary = _snapshot.get("package", {})
	if package_state.get("id") == "P01" and package_state.get("location") == "desk":
		# Keep the tall carrier handle out of the speaking opening.
		_package.position.x = -0.88 if _dialogue_framing and _view_id == "window" else PACKAGE_POSITIONS.desk.x
	# Opened records knowledge; the lid closes when looking back at the visitor.
	_package.set_opened(bool(package_state.get("opened", false)) and package_state.get("location", "shelf") == "desk" and _view_id == "desk")
	if _package.has_method("set_unlocked"):
		_package.set_unlocked(package_state.get("unlocked", false))
		_package.set_lining_lifted(package_state.get("lining_lifted", false))

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
	var face := Vector3(_active_portrait.anchor_position.x if is_instance_valid(_active_portrait) else 0.0, _face_height, _face_depth)
	return (_visitor.global_position if is_instance_valid(_visitor) else VISITOR_WAIT) + face

func set_hovered(target_id: String) -> void:
	var changed := _hovered != target_id
	_hovered = target_id
	if is_instance_valid(_package):
		_package.set_highlighted(target_id == _snapshot.get("package", {}).get("id", "P01") and _package.visible and not transfer_active)
	if _snapshot.has("loose_finds"):
		for id in Rules.auxiliary_packages(_snapshot):
			_package_views[id].set_highlighted(target_id == id)
	for key in _highlights:
		var mesh: MeshInstance3D = _highlights[key]
		mesh.visible = key == target_id
	if changed:
		hover_changed.emit(target_id)

func _physics_process(_delta: float) -> void:
	if not input_enabled or not is_visible_in_tree():
		return
	var control := get_viewport().gui_get_hovered_control()
	if is_instance_valid(control) and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		if not _hovered.is_empty():
			set_hovered("")
		return
	var next_hovered := _pick(_pointer_position)
	if next_hovered != _hovered:
		set_hovered(next_hovered)

func _input(event: InputEvent) -> void:
	# Hover and clicks use the same viewport-local coordinates, including scaled windows.
	if event is InputEventMouse:
		_pointer_position = event.position

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
	var target: StaticBody3D = _package.get_node_or_null("Target_" + str(_snapshot.get("package", {}).get("id", "P01")))
	if is_instance_valid(target):
		target.collision_layer = 1 if value else 0

func _set_visitor_phase(value: String) -> void:
	visitor_phase = value
	if is_instance_valid(_visitor):
		_visitor.visible = value not in ["absent", "gone"]
	if is_instance_valid(_visitor_target):
		_visitor_target.collision_layer = 1 if value in ["waiting", "at_bus"] else 0
	if value == "at_bus":
		_show_issued_coat()
	if value in ["gone", "at_bus"]:
		visitor_departed.emit()

func _start_arrival() -> void:
	if is_instance_valid(_visitor_tween):
		_visitor_tween.kill()
	_visitor.position = VISITOR_FAR
	_set_visitor_phase("arriving")
	sound_requested.emit("steps")
	_visitor_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_visitor_tween.tween_property(_visitor, "position", VISITOR_WAIT, 0.03 if reduced_motion else 1.15)
	_visitor_tween.tween_callback(func():
		_set_visitor_phase("waiting")
		if _snapshot.case_id == "finale":
			_package.show()
			_set_package_picking(true)
		visitor_arrived.emit())

func _start_departure() -> void:
	if is_instance_valid(_visitor_tween):
		_visitor_tween.kill()
	_visitor.position = VISITOR_WAIT
	_set_visitor_phase("waiting")
	_visitor_tween = create_tween()
	_visitor_tween.tween_interval(2.1)
	_visitor_tween.tween_callback(func(): _set_visitor_phase("leaving"))
	var waits: bool = _snapshot.case_id == "serov" and Rules.serov_waits_for_bus(_snapshot)
	var destination := BUS_WAIT if waits else Vector3(2.0, 0, -5.8)
	_visitor_tween.tween_property(_visitor, "position", destination, 0.03 if reduced_motion else 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_visitor_tween.tween_callback(func(): _set_visitor_phase("at_bus" if waits else "gone"))

func _start_handover(already_inside: bool = false) -> void:
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
	if already_inside:
		_package.position = PACKAGE_POSITIONS["hatch"]
		if _snapshot.package.id == "P03":
			_package.rotation.y = PI / 2.0
	else:
		# A door is open from its first moving frame until it is completely closed.
		_transfer_tween.tween_callback(func():
			_inner_open = true
			sound_requested.emit("latch"))
		_transfer_tween.tween_property(_inner_door, "position:y", 0.83, 0.14 * speed)
		_transfer_tween.tween_property(_package, "position", Vector3(0.72, 0.94, 0.23), 0.28 * speed)
		_transfer_tween.tween_property(_package, "position", PACKAGE_POSITIONS["hatch"], 0.30 * speed)
		_transfer_tween.tween_property(_inner_door, "position:y", 0.0, 0.16 * speed)
		_transfer_tween.tween_callback(func(): _inner_open = false)
	_transfer_tween.tween_callback(func():
		_outer_open = true
		sound_requested.emit("latch"))
	_transfer_tween.tween_property(_outer_door, "position:y", 0.83, 0.16 * speed)
	_transfer_tween.tween_property(_package, "position", Vector3(0.72, 0.94, -1.42), 0.25 * speed)
	_transfer_tween.tween_callback(func(): _package.visible = false)
	_transfer_tween.tween_property(_outer_door, "position:y", 0.0, 0.16 * speed)
	_transfer_tween.tween_callback(func():
		_outer_open = false
		transfer_active = false
		_render_auxiliary_finds()
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
	# A small side bracket gives the grocery bag its own slot, clear of P01/P03.
	G.box(shelf, Vector3(0.68, 0.08, 0.66), Vector3(-0.99, 1.12, 0), wood)
	for x in [-1.26, -0.72]:
		G.rod(shelf, Vector3(x, 0.75, -0.28), Vector3(x, 1.08, 0.24), 0.018, G.worn_material(Color("555b4d"), "metal"))
	G.label(shelf, "П04", Vector3(-0.99, 1.12, 0.35), 20, Color("c8b788"))
	G.box(shelf, Vector3(0.69, 0.08, 0.66), Vector3(-0.99, 0.28, 0), wood)
	G.label(shelf, "П08", Vector3(-0.99, 0.28, 0.35), 20, Color("c8b788"))
	for slot in [[0.28, "П05"], [1.12, "П06"], [2.02, "П07"]]:
		var height: float = slot[0]
		G.box(shelf, Vector3(0.69, 0.08, 0.65), Vector3(0.99, height, 0), wood)
		G.label(shelf, slot[1], Vector3(0.99, height, 0.35), 20, Color("c8b788"))
	for z in [-0.29, 0.29]:
		G.box(shelf, Vector3(0.046, 2.1, 0.046), Vector3(1.31, 1.05, z), wood)
	var crate: Node3D = CRATE_PROBE.instantiate()
	crate.name = "ImportedCrateProbe"
	crate.position = Vector3(-0.46, 0.49, 0)
	crate.scale = Vector3(0.26, 0.35, 0.35)
	shelf.add_child(crate)
	G.label(shelf, "П03", Vector3(0.20, 0.28, 0.412), 20, Color("c8b788"))
	G.label(shelf, "П02", Vector3(0, 2.02, 0.412), 20, Color("c8b788"))
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
	var second_stand := Node3D.new()
	second_stand.name = "SecondPersonalStand"
	second_stand.position = Vector3(1.55, 0, 1.05)
	second_stand.rotation_degrees.y = -45
	add_child(second_stand)
	G.box(second_stand, Vector3(0.96, 0.07, 0.72), Vector3(0, 0.215, 0), dark)
	for x in [-0.44, 0.44]:
		G.box(second_stand, Vector3(0.05, 0.22, 0.66), Vector3(x, 0.11, 0), dark)
	var third_stand := Node3D.new()
	third_stand.name = "ThirdPersonalStand"
	third_stand.position = Vector3(1.55, 0, 0.18)
	third_stand.rotation_degrees.y = -45
	add_child(third_stand)
	G.box(third_stand, Vector3(0.75, 0.07, 0.64), Vector3(0, 0.215, 0), dark)
	for x in [-0.32, 0.32]:
		G.box(third_stand, Vector3(0.05, 0.22, 0.58), Vector3(x, 0.11, 0), dark)
	G.box(self, Vector3(0.73, 0.07, 0.58), Vector3(0.68, 0.215, -0.12), dark).rotation_degrees.y = -45
	for x in [0.39, 0.97]:
		G.box(self, Vector3(0.05, 0.22, 0.45), Vector3(x, 0.11, -0.12), dark)
	G.box(self, Vector3(0.75, 0.048, 0.55), Vector3(0.68, 0.546, -0.12), dark).rotation_degrees.y = -45
	for x in [0.39, 0.97]:
		G.box(self, Vector3(0.043, 0.28, 0.045), Vector3(x, 0.395, -0.12), dark)
	_personal_card_target = G.target(self, "personal_bag", Vector3(0.62, 0.17, 0.49), Vector3(0.68, 0.64, -0.12))
	_personal_card_target.collision_layer = 0
	_add_highlight(self, "personal_bag", Vector3(0.56, 0.004, 0.46), Vector3(0.68, 0.573, -0.12))
	_held_card = Node3D.new()
	_held_card.name = "CardInHand"
	_held_card.position = Vector3(0.20, 1.045, 0.12)
	add_child(_held_card)
	G.box(_held_card, Vector3(0.15, 0.004, 0.10), Vector3.ZERO, G.worn_material(Color("c0a778"), "paper"))
	var held_number := G.label(_held_card, "№ 314", Vector3(0, 0.004, 0), 22, Color("534736"))
	held_number.rotation_degrees.x = -90
	held_number.pixel_size = 0.0014
	_held_card.hide()
	_build_paper("identity", Vector3(-0.69, 0.952, 0.28), -7, "УДОСТОВЕРЕНИЕ", Color("b8b097"))
	_build_paper("claim", Vector3(-0.20, 0.953, 0.32), 6, "ЗАЯВЛЕНИЕ № 01", Color("b4ae94"))
	var badge := Node3D.new()
	badge.name = "ClerkIdentity"
	badge.position = Vector3(0.32, 0.954, 0.28)
	badge.rotation_degrees.y = -10
	add_child(badge)
	G.box(badge, Vector3(0.17, 0.006, 0.11), Vector3.ZERO, G.worn_material(Color("b8b097"), "paper"))
	var badge_name := G.label(badge, "П. ФОМИН", Vector3(0, 0.005, 0), 15, Color("414238"))
	badge_name.rotation_degrees.x = -90
	badge_name.pixel_size = 0.0015
	G.target(badge, "clerk_identity", Vector3(0.18, 0.03, 0.12), Vector3(0, 0.01, 0))
	_add_highlight(badge, "clerk_identity", Vector3(0.18, 0.003, 0.12), Vector3(0, -0.001, 0))
	var archive := Node3D.new()
	archive.name = "ArchiveFolder"
	archive.position = Vector3(-0.83, 0.95, -0.24)
	archive.rotation_degrees.y = -5
	add_child(archive)
	G.box(archive, Vector3(0.28, 0.08, 0.43), Vector3(0, 0.04, 0), G.worn_material(Color("6c6549"), "paper"))
	G.box(archive, Vector3(0.29, 0.015, 0.44), Vector3(0, 0.088, 0), wood)
	var label := G.label(archive, "АРХИВ", Vector3(0, 0.098, 0), 19, Color("c9bd9b"))
	label.rotation_degrees.x = -90
	label.pixel_size = 0.002
	G.target(archive, "archive", Vector3(0.32, 0.14, 0.46), Vector3(0, 0.07, 0))
	_add_highlight(archive, "archive", Vector3(0.32, 0.004, 0.47), Vector3.ZERO)
	_archived_card = Node3D.new()
	_archived_card.name = "ArchivedCard"
	_archived_card.position = Vector3(-0.028, 0.105, 0.067)
	_archived_card.rotation.y = 0.22
	archive.add_child(_archived_card)
	G.box(_archived_card, Vector3(0.19, 0.006, 0.127), Vector3(0.025, 0.003, 0.038), G.worn_material(Color("bcb29a"), "paper"))
	G.box(_archived_card, Vector3(0.124, 0.006, 0.088), Vector3.ZERO, G.worn_material(Color("c0a778"), "paper"))
	var number := G.label(_archived_card, "№ 314", Vector3(0, 0.006, 0), 22, Color("534736"))
	number.rotation_degrees.x = -90
	number.pixel_size = 0.0014
	_archived_card.hide()
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
	_paper_titles[target_id] = text
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
	for x in [-2.45, -2.15, -1.87, -1.57, -1.27, -0.97, -0.67, 0.39, 1.35, 1.65]:
		G.rod(self, Vector3(x, 1.74 if x == 0.39 else 0.94, -0.75), Vector3(x, 2.65, -0.75), 0.017, metal)
	for y in [2.02, 2.60]:
		G.rod(self, Vector3(-2.48, y, -0.75), Vector3(1.69, y, -0.75), 0.027, metal)
	G.rod(self, Vector3(-1.9, 1.20, -0.75), Vector3(-0.67, 1.20, -0.75), 0.014, edge)
	G.rod(self, Vector3(1.33, 1.20, -0.75), Vector3(1.69, 1.20, -0.75), 0.014, edge)
	G.box(self, Vector3(1.45, 0.26, 0.04), Vector3(-0.43, 2.14, -0.70), metal)
	G.label(self, "БЮРО НАХОДОК", Vector3(-0.43, 2.14, -0.668), 25, Color("bbb89b"))
	G.label(self, "ДОКУМЕНТЫ — В ЛОТОК", Vector3(-0.80, 0.77, -0.69), 17, Color("a6af95"))
	# Side cage returns make the clerk's enclosure legible during head turns.
	for z in [-0.4, 0.0, 0.4, 0.8, 1.2, 1.6]:
		G.rod(self, Vector3(-2.45, 0, z), Vector3(-2.45, 2.65, z), 0.016, metal)
	G.rod(self, Vector3(-2.45, 2.05, -0.75), Vector3(-2.45, 2.05, 1.9), 0.025, metal)
	# Weld plates, slotted screws and a timber wear rail break the uniform grid.
	for x in [-1.87, -1.27, -0.67, 0.39, 1.35]:
		G.box(self, Vector3(0.073, 0.14, 0.018), Vector3(x, 2.02, -0.711), edge)
		_screw_z(self, Vector3(x, 1.975, -0.695), 0.008, metal)
		_screw_z(self, Vector3(x, 2.065, -0.695), 0.008, metal)
	for x in [-1.87, -0.97, -0.67, 1.35]:
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
	_waiting_serov = Node3D.new()
	_waiting_serov.name = "SerovAtBus"
	_waiting_serov.position = BUS_WAIT
	add_child(_waiting_serov)
	_bus_portrait = _make_portrait("WaitingPortrait", "serov", GameStore.get_case_content("serov").presentation.portrait, true)
	_waiting_serov.add_child(_bus_portrait)
	_waiting_serov_target = G.target(_waiting_serov, "serov", Vector3(0.75, 1.2, 0.55), Vector3(0, 1.11, 0.05))
	_waiting_serov_target.collision_layer = 0
	_serov_card = G.box(_waiting_serov, Vector3(0.087, 0.062, 0.004), Vector3(0.14, 1.145, 0.069), G.worn_material(Color("bea986"), "paper"), "CardWithSerov")
	_serov_card.rotation.z = -0.12
	_serov_card.hide()
	_waiting_serov.hide()
	_set_visitor_phase("absent")

func _configure_visitor(case_id: String) -> void:
	var presentation: Dictionary = GameStore.get_case_content(case_id).presentation
	if _paper_titles.has("claim"):
		_paper_titles.claim.text = "СЛУЖЕБНЫЕ БУМАГИ" if case_id == "finale" else ("ЗАЯВЛЕНИЯ № " if case_id == "melnikovs" else "ЗАЯВЛЕНИЕ № ") + presentation.number
	if _paper_titles.has("identity"):
		match case_id:
			"finale": _paper_titles.identity.text = "ЖУРНАЛ СМЕНЫ"
			"melnikovs": _paper_titles.identity.text = "ДОКУМЕНТЫ · 2"
			_: _paper_titles.identity.text = "ДОКУМЕНТ" if presentation.get("identity_layout") == "sheet" else "УДОСТОВЕРЕНИЕ"
	var actor := VisitorActing.actor(case_id)
	var portrait_name := actor.capitalize() + "Portrait"
	for child in _visitor.get_children():
		if child is Sprite3D:
			child.visible = str(child.name) == portrait_name
	var portrait := _visitor.get_node_or_null(portrait_name) as Portrait
	if not is_instance_valid(portrait):
		portrait = _make_portrait(portrait_name, actor, presentation.portrait)
		_visitor.add_child(portrait)
	portrait.visible = true
	var anchor := Vector3(-0.16 if case_id == "melnikovs" else -0.20, 0.92, 0.06)
	portrait.scale.x = 0.82 if case_id == "melnikovs" else 1.0
	portrait.anchor_position = anchor
	portrait.position = anchor
	portrait.perform(0, 0.0)
	_active_portrait = portrait
	_visitor_geometry.visible = false
	_visitor_target.set_meta("target_id", case_id)

func _make_portrait(portrait_name: String, id: String, fallback: String, at_bus: bool = false) -> Portrait:
	var portrait := Portrait.new()
	portrait.name = portrait_name
	portrait.configure(id, fallback, at_bus)
	portrait.position = portrait.anchor_position
	return portrait

func set_dialogue_pose(pose: int, duration: float, at_bus: bool) -> void:
	var portrait := _bus_portrait if at_bus and _waiting_serov.visible else _active_portrait
	if is_instance_valid(portrait):
		portrait.perform(pose, duration)

func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	world.name = "BureauEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("172321")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9aa9a3")
	environment.ambient_light_energy = 0.18
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var daylight := DirectionalLight3D.new()
	daylight.name = "StationEveningLight"
	daylight.rotation_degrees = Vector3(-48, -23, 0)
	daylight.light_color = Color("8eb1b6")
	daylight.light_energy = 0.26
	daylight.shadow_enabled = true
	daylight.directional_shadow_max_distance = 15
	add_child(daylight)
	var face_light := OmniLight3D.new()
	face_light.name = "VisitorFluorescent"
	face_light.position = Vector3(-0.25, 2.52, -0.40)
	face_light.light_color = Color("a5c7b6")
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
	hall_light.light_color = Color("82c5bf")
	hall_light.light_energy = 0.48
	hall_light.omni_range = 4.5
	add_child(hall_light)
	var platform_light := OmniLight3D.new()
	platform_light.name = "PlatformSpill"
	platform_light.position = Vector3(-1.6, 2.05, -6.12)
	platform_light.light_color = Color("459b9b")
	platform_light.light_energy = 0.58
	platform_light.omni_range = 2.3
	add_child(platform_light)

func _add_highlight(parent: Node3D, target_id: String, size: Vector3, position: Vector3) -> void:
	var material := G.material(Color("a79a69"))
	material.emission_enabled = true
	material.emission = Color("7f754f")
	material.emission_energy_multiplier = 0.45
	var mesh := G.box(parent, size, position, material)
	mesh.visible = false
	_highlights[target_id] = mesh

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
