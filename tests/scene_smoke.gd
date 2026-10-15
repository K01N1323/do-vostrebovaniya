extends SceneTree

var _checks := 0
var _failures: Array[String] = []
var _main: Node
var _ui: Node
var _room: Node
var _store: Node
var _camera: Node
var _package: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	_expect(scene != null, "main scene loads")
	if scene == null:
		_finish()
		return
	_main = scene.instantiate()
	root.add_child(_main)
	await process_frame
	await physics_frame
	_ui = _main.get_node_or_null("Interface/GameUI")
	_room = _main.get_node_or_null("Room")
	_camera = _main.get_node_or_null("CameraRig")
	_store = root.get_node_or_null("GameStore")
	_expect(is_instance_valid(_ui) and _ui.has_method("_show_comparison"), "GameUI is instantiated")
	_expect(is_instance_valid(_room) and _room.has_method("apply_snapshot"), "Room is instantiated")
	_expect(is_instance_valid(_camera) and _camera.has_method("focus"), "CameraRig is instantiated")
	_expect(is_instance_valid(_store) and _store.has_method("dispatch"), "GameStore autoload is present")
	if not is_instance_valid(_ui) or not _ui.has_method("_show_comparison") or not is_instance_valid(_room) or not _room.has_method("apply_snapshot") or not is_instance_valid(_camera) or not _camera.has_method("focus") or not is_instance_valid(_store):
		_finish()
		return
	_package = _room.get_node_or_null("Package") as Node3D
	_expect(is_instance_valid(_package), "room contains package instance")
	if not is_instance_valid(_package):
		_finish()
		return
	_expect(_room.get("input_enabled") == false, "title screen blocks room picking")
	_expect(_package.visible and _package.position.is_equal_approx(Vector3(-2.3, 1.2, -1.8)), "initial package is visible on shelf")
	_expect(_room.find_children("Target_P01", "StaticBody3D", true, false).size() == 1, "room contains exactly one P01 target")
	var mute := _find_button(_ui, "Играть без звука")
	if is_instance_valid(mute):
		mute.button_pressed = true
	var start := _find_button(_ui, "Начать смену")
	_expect(is_instance_valid(start), "start screen has start button")
	if not is_instance_valid(start):
		_finish()
		return
	start.pressed.emit()
	await process_frame
	_expect(_snapshot().get("started") == true, "start button dispatches START")
	_expect(not is_instance_valid(_ui.get("_start_screen")), "start screen closes")
	_expect(_room.get("input_enabled") == true, "starting enables room picking")
	_test_pause_and_camera()
	for decision in ["issue", "retain", "appropriate"]:
		if decision != "issue":
			_ui.call("_restart")
			await process_frame
			_test_restart_state(decision)
		var prepared: bool = await _prepare_case(decision)
		if not prepared:
			continue
		_ui.call("_show_decision")
		_expect(is_instance_valid(_ui.get("modal")) and _ui.get("_modal_kind") == "decision", decision + ": decision modal opens")
		_expect(_room.get("input_enabled") == false, decision + ": decision modal blocks room")
		var captions := {
			"issue": "Выдать переноску Нине Лукиной",
			"retain": "Завершить обращение · оставить на хранении",
			"appropriate": "Убрать под стол · присвоить переноску",
		}
		var decision_button := _find_button(_ui.get("modal"), captions[decision])
		_expect(is_instance_valid(decision_button) and not decision_button.disabled, decision + ": decision button enabled")
		if not is_instance_valid(decision_button):
			continue
		decision_button.pressed.emit()
		await process_frame
		await physics_frame
		_check_outcome(decision)
		_ui.call("_close_modal")
		_expect(_room.get("input_enabled") == true, decision + ": closing result re-enables room")
	_main.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _snapshot() -> Dictionary:
	return _store.call("get_snapshot")


func _prepare_case(label: String) -> bool:
	_ui.call("_show_comparison")
	await process_frame
	_expect(_snapshot()["read_documents"].size() == 2, label + ": comparison reads both documents")
	_expect(is_instance_valid(_ui.get("modal")), label + ": comparison modal is present")
	_expect(_room.get("input_enabled") == false, label + ": document modal blocks room")
	var previous_view: String = _camera.get("current_view")
	_ui.call("_focus", "personal")
	_expect(_camera.get("current_view") == previous_view, label + ": modal prevents camera navigation")
	_ui.call("_close_modal")
	_expect(not is_instance_valid(_ui.get("modal")), label + ": closing comparison removes modal")
	_expect(_room.get("input_enabled") == true, label + ": closing comparison enables room")
	_ui.call("_move", "desk")
	await process_frame
	await physics_frame
	_expect(_snapshot()["package"]["location"] == "desk", label + ": UI moves package to desk")
	_expect(_package.position.is_equal_approx(Vector3(0, 0.98, -0.35)), label + ": room follows desk state")
	_expect(_camera.get("current_view") == "desk", label + ": move focuses desk")
	var room_camera: Camera3D = _camera.call("get_camera")
	var package_screen := room_camera.unproject_position(_package.global_position + Vector3(0, 0.26, 0))
	_expect(_room.call("_pick", package_screen) == "P01", label + ": room physics ray picks package at desk")
	_ui.call("_show_inspection")
	await process_frame
	await physics_frame
	_expect(_snapshot()["package"]["opened"] == true and _package.get("opened") == true, label + ": inspection opens both state and room package")
	_expect(_ui.get("_modal_kind") == "inspection" and _room.get("input_enabled") == false, label + ": inspection blocks room")
	var inspection: Node = _ui.get("_inspection")
	_expect(is_instance_valid(inspection), label + ": separate inspection stage is instantiated")
	if not is_instance_valid(inspection):
		return false
	var viewport := inspection.get_parent() as SubViewport
	_expect(is_instance_valid(viewport) and viewport.own_world_3d, label + ": inspection has separate 3D world")
	var contents := inspection.get_node_or_null("Pivot/Package/Contents")
	_expect(is_instance_valid(contents), label + ": inspection package contents are built")
	if is_instance_valid(contents):
		_expect(contents.find_children("Sandwich*", "Node3D", false, false).size() == 3, label + ": inspection shows three sandwiches")
	inspection.set("reduced_motion", true)
	var pivot := inspection.get_node_or_null("Pivot") as Node3D
	if is_instance_valid(pivot):
		var angle: float = pivot.rotation.y
		inspection.call("rotate_item", 1.0)
		_expect(not is_equal_approx(angle, pivot.rotation.y), label + ": inspection model rotates")
	inspection.emit_signal("detail_selected", "sandwiches")
	_expect(_snapshot()["inspected_details"].has("sandwiches"), label + ": inspection detail signal records observation")
	_ui.call("_inspect_detail", "napkin")
	_expect(_snapshot()["inspected_details"].has("napkin"), label + ": UI detail button records observation")
	_ui.call("_close_modal")
	_ui.call("_show_conversation")
	var lunch := _find_button(_ui.get("modal"), "Вы приготовили обед на троих?")
	_expect(is_instance_valid(lunch), label + ": observed sandwiches expose lunch question")
	if is_instance_valid(lunch):
		lunch.pressed.emit()
		_expect(_snapshot()["asked_topics"].has("lunch"), label + ": dialogue button dispatches lunch question")
	_ui.call("_close_modal")
	return true


func _check_outcome(decision: String) -> void:
	var snapshot := _snapshot()
	_expect(snapshot["case_status"] == "resolved" and snapshot["decision"] == decision, decision + ": UI commits decision")
	_expect(_ui.get("_modal_kind") == "result" and _room.get("input_enabled") == false, decision + ": result modal blocks room")
	var target := _package.get_node_or_null("Target_P01") as StaticBody3D
	_expect(is_instance_valid(target), decision + ": package picking body exists")
	if decision == "issue":
		_expect(snapshot["package"]["location"] == "issued" and not _package.visible, "issue: issued package disappears from room")
		if is_instance_valid(target):
			_expect(target.collision_layer == 0, "issue: invisible package cannot be picked")
	else:
		var location: String = "shelf" if decision == "retain" else "personal"
		var position := Vector3(-2.3, 1.2, -1.8) if decision == "retain" else Vector3(1.15, 0.3, 0.55)
		_expect(snapshot["package"]["location"] == location and _package.visible, decision + ": retained package remains visible at final location")
		_expect(_package.position.is_equal_approx(position), decision + ": room displays final package position")
		if is_instance_valid(target):
			_expect(target.collision_layer == 1, decision + ": visible package restores room picking body")
	var before := snapshot.duplicate(true)
	var response: Dictionary = _store.call("dispatch", {"type": "ISSUE_PACKAGE", "recipient": "nina"})
	_expect(response.get("ok") == false and _snapshot() == before, decision + ": second issue is rejected through GameStore")


func _test_restart_state(label: String) -> void:
	var state := _snapshot()
	_expect(state["started"] == true and state["case_status"] == "active" and state["decision"] == "", label + ": restart starts fresh active case")
	_expect(state["read_documents"].is_empty() and state["inspected_details"].is_empty() and state["asked_topics"].is_empty(), label + ": restart clears UI knowledge")
	_expect(_package.visible and _package.get("opened") == false, label + ": restart restores closed package")
	_expect(_package.position.is_equal_approx(Vector3(-2.3, 1.2, -1.8)), label + ": restart restores package on shelf")
	_expect(_room.get("input_enabled") == true, label + ": restart restores room input")


func _test_pause_and_camera() -> void:
	_ui.call("_show_pause")
	_expect(is_instance_valid(_ui.get("modal")) and _room.get("input_enabled") == false, "pause blocks room picking")
	var reduced := _find_button(_ui.get("modal"), "Уменьшить движение камеры")
	_expect(is_instance_valid(reduced), "pause exposes reduced motion control")
	if is_instance_valid(reduced):
		reduced.button_pressed = true
		_expect(_camera.get("reduced_motion") == true, "motion preference reaches camera rig")
	_ui.call("_close_modal")
	_expect(_room.get("input_enabled") == true, "closing pause restores room picking")


func _find_button(node: Node, caption: String) -> Button:
	if not is_instance_valid(node):
		return null
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := _find_button(child, caption)
		if is_instance_valid(found):
			return found
	return null


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: %d scene/UI integration checks; three Nina outcomes verified." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: %d failures / %d scene/UI checks" % [_failures.size(), _checks])
		quit(1)
