extends SceneTree
## Run separately with graphics after the orchestrator releases the active Godot window.

var main: Node
var ui: Control
var room: Node
var store: Node
var failures: Array[String] = []
var output_dir: String
var frames: Array[Dictionary] = []
var art_sources: Dictionary = {"character": "", "material_pngs": [], "shaders": []}
var _seen_materials: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual preview requires a graphics window; no rendered pass is possible in headless mode.")
		quit(1)
		return
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	output_dir = ProjectSettings.globalize_path("res://tools/preview-04")
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	ui = main.get_node("Interface/GameUI")
	room = main.get_node("Room")
	store = root.get_node("GameStore")
	_check_art_sources()
	await _frame("01-title", 0.2)
	var mute := _find(ui, "Играть без звука")
	if is_instance_valid(mute):
		mute.button_pressed = true
	await _click(_find(ui, "Начать смену"))
	await _frame("02-preparing", 0.02)
	_check(await _wait_until(func() -> bool: return store.get_snapshot().started, 1.5), "START completes after visible preparation")
	await _frame("03-arrival", 0.1)
	_check(await _wait_until(func() -> bool: return room.visitor_phase == "waiting", 2.0), "Nina reaches window")
	await _frame("04-greeting", 0.12)
	_check(ui._modal_kind == "dialogue", "Arrival opens compact conversation")
	var next := _find(ui.modal, "Далее")
	_check(is_instance_valid(next), "Greeting has next chunk")
	if is_instance_valid(next):
		await _click(next)
		await _frame("05-greeting-next", 0.1)
	ui._close_modal()
	await _frame("06-workplace", 0.1)
	await _composition_frames()
	ui._show_document("identity")
	await _frame("06b-identity", 0.15)
	_check(ui._modal_kind == "document", "Single identity paper opens")
	if ResourceLoader.exists("res://assets/characters/nina-v2.png"):
		_check(is_instance_valid(ui.modal.find_child("IdentityPhoto", true, false)), "Identity paper includes Nina photo")
	ui._close_modal()
	await _click(_find(ui, "Сравнить обе бумаги"))
	await _frame("07-documents", 0.15)
	_check(ui._modal_kind == "comparison" and store.get_snapshot().read_documents.size() == 2, "Comparison shows and records both papers")
	ui._close_modal()
	await _click(_find(ui, "Поставить на стол"))
	await _frame("08-desk", 0.45)
	await _click(_find(ui, "Открыть и осмотреть"))
	await _frame("09-inspection", 0.15)
	_check(ui._modal_kind == "inspection", "Inspection panel opens")
	await _inspection_focus_frames()
	ui._close_modal()
	ui._show_conversation()
	await _frame("11-lunch-conversation", 0.45)
	_check(main.get_node("CameraRig").current_view == "window" and not room.get_node("Package").opened, "Conversation faces Nina with carrier lid closed")
	await _finish_speech_chunks()
	await _click(_find(ui.modal, "Вы приготовили обед на троих?"))
	await _frame("12-lunch-reply", 0.1)
	ui._close_modal()
	await _click(_find(ui, "Принять решение"))
	await _frame("13-decision", 0.1)
	await _click(_find(ui.modal, "Выдать переноску Нине Лукиной"))
	_check(store.get_snapshot().decision == "issue", "Issue decision is immediate")
	_check(await _wait_until(func() -> bool: return room.get_hatch_state().inner_open, 0.4), "Handover opens inner door")
	await _frame("14-handover-inner", 0.08)
	_check(await _wait_until(func() -> bool: return room.get_hatch_state().outer_open, 1.5), "Handover opens outer door later")
	await _frame("15-handover-outer", 0.04)
	_check(await _wait_until(func() -> bool: return not room.transfer_active, 1.0), "Handover finishes")
	await _frame("16-reaction", 0.03)
	_check(await _wait_until(func() -> bool: return room.visitor_phase == "leaving", 1.0), "Visitor starts leaving after reaction")
	await _frame("17-leaving", 0.3)
	_check(await _wait_until(func() -> bool: return room.visitor_phase == "gone", 2.0), "Visitor leaves")
	ui._close_modal()
	await _frame("18-gone", 0.05)
	for decision in ["retain", "appropriate"]:
		ui._restart()
		_check(await _wait_until(func() -> bool: return room.visitor_phase == "waiting", 2.0), decision + ": visitor returns on restart")
		ui._close_modal()
		for command in [{"type":"READ_DOCUMENT","document_id":"identity"},{"type":"READ_DOCUMENT","document_id":"claim"},{"type":"MOVE_PACKAGE","destination":"desk"},{"type":"OPEN_PACKAGE"},{"type":"INSPECT_DETAIL","detail_id":"sandwiches"}]:
			store.dispatch(command)
		ui._show_decision()
		var caption: String = "Завершить обращение · оставить на хранении" if decision == "retain" else "Убрать под стол · присвоить переноску"
		await _click(_find(ui.modal, caption))
		await _frame("19-" + decision + "-reaction", 0.4)
		_check(store.get_snapshot().decision == decision, "Decision button " + decision)
		ui._close_modal()
		ui._focus("shelf" if decision == "retain" else "personal")
		await _frame("20-" + decision + "-package", 0.45)
	_check(frames.size() == 30, "All 27 baseline frames and three inspection focus/reset frames were saved")
	var manifest := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if manifest:
		manifest.store_string(JSON.stringify({"iteration": "0.4", "baseline_frames": 23, "composition_frames": 4, "inspection_extra_frames": 3, "art_sources": art_sources, "frames": frames, "failures": failures}, "\t"))
	if failures.is_empty():
		print("PASS: %d iteration 0.4 rendered previews and UI workflow checks. Inspect PNGs for visual quality." % frames.size())
	else:
		for message in failures:
			push_error(message)
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _frame(id: String, delay: float = 0.1) -> void:
	await create_timer(delay).timeout
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var rendered := root.get_texture().get_image()
	_check(rendered != null and not rendered.is_empty(), id + ": rendered image exists")
	if rendered == null or rendered.is_empty():
		return
	var status := rendered.save_png(output_dir.path_join(id + ".png"))
	_check(status == OK, id + ": PNG saved")
	var camera: Camera3D = main.get_node("CameraRig").get_camera()
	var state: Dictionary = store.get_snapshot()
	var inspection: Variant = ui.get("_inspection")
	var focus_id := ""
	var inspection_camera: Dictionary = {}
	if is_instance_valid(inspection) and inspection.is_inside_tree() and inspection.has_method("get_focus_id"):
		focus_id = str(inspection.call("get_focus_id"))
		var detail_camera := inspection.get_node_or_null("Camera3D") as Camera3D
		if is_instance_valid(detail_camera):
			inspection_camera = {"transform": str(detail_camera.transform), "fov": detail_camera.fov}
	frames.append({"id": id, "view": main.get_node("CameraRig").current_view, "visitor_phase": room.visitor_phase, "transfer_active": room.transfer_active, "hatch": room.get_hatch_state(), "eye": str(camera.global_position), "package_location": state.package.location, "package_opened": state.package.opened, "decision": state.decision, "modal_kind": ui._modal_kind, "inspection_focus": focus_id, "inspection_camera": inspection_camera})


func _inspection_focus_frames() -> void:
	var stage: Node = ui.get("_inspection")
	var has_api: bool = is_instance_valid(stage) and stage.has_method("focus_detail") and stage.has_method("reset_focus") and stage.has_method("get_focus_id")
	_check(has_api, "Inspection close-up API is available")
	if not has_api:
		return
	var camera := stage.get_node_or_null("Camera3D") as Camera3D
	_check(is_instance_valid(camera), "Inspection camera is available")
	if not is_instance_valid(camera):
		return
	var overview: Transform3D = camera.transform
	var overview_fov: float = camera.fov
	_check(stage.call("get_focus_id") == "", "Inspection starts with the entire carrier")
	for detail in [["sandwiches", "Три бутерброда", "10-detail"], ["saucer", "Край блюдца", "10b-saucer-close"], ["napkin", "Голубая заплата", "10c-napkin-close"]]:
		await _click(_find(ui.modal, detail[1]))
		await _frame(detail[2], 0.45)
		_check(stage.call("get_focus_id") == detail[0], "Detail button focuses " + detail[0])
		_check(detail[0] in store.get_snapshot().inspected_details, "Detail button records " + detail[0])
		_check(not camera.transform.is_equal_approx(overview) or not is_equal_approx(camera.fov, overview_fov), "Detail camera differs from overview for " + detail[0])
	await _click(_find(ui.modal, "Вся переноска"))
	await _frame("10d-inspection-reset", 0.45)
	_check(stage.call("get_focus_id") == "", "Reset button restores entire carrier focus")
	_check(camera.transform.is_equal_approx(overview) and is_equal_approx(camera.fov, overview_fov), "Reset button restores overview camera and FOV")


func _composition_frames() -> void:
	ui._close_modal()
	var before: Dictionary = store.get_snapshot().duplicate(true)
	var action_panel := ui.get("_action_panel") as Control
	var actions_were_visible: bool = is_instance_valid(action_panel) and action_panel.visible
	for view in ["window", "shelf"]:
		ui._focus(view)
		if is_instance_valid(action_panel):
			action_panel.hide()
		await _frame("composition-01-window" if view == "window" else "composition-02-shelf", 0.45)
	var response: Dictionary = store.dispatch({"type": "MOVE_PACKAGE", "destination": "desk"})
	_check(response.get("ok", false), "Composition setup moves closed carrier to desk")
	ui._focus("desk")
	if is_instance_valid(action_panel):
		action_panel.hide()
	await _frame("composition-03-desk-closed", 0.45)
	_check(store.get_snapshot().package.opened == false and not room.get_node("Package").opened, "Desk composition keeps carrier closed")
	ui._focus("personal")
	if is_instance_valid(action_panel):
		action_panel.hide()
	await _frame("composition-04-personal", 0.45)
	store.dispatch({"type": "MOVE_PACKAGE", "destination": "shelf"})
	ui._focus("window")
	await create_timer(0.4).timeout
	if is_instance_valid(action_panel):
		action_panel.visible = actions_were_visible
	_check(store.get_snapshot() == before, "Composition captures restore workflow state")


func _check_art_sources() -> void:
	var portrait := room.find_child("NinaPortrait", true, false) as Sprite3D
	_check(is_instance_valid(portrait) and portrait.texture != null, "Nina uses a loaded portrait texture")
	if is_instance_valid(portrait) and portrait.texture != null:
		art_sources["character"] = portrait.texture.resource_path
		_check(portrait.texture.resource_path == "res://assets/characters/nina-v2.png", "Room uses Nina v2 rather than the old portrait")
	for node in room.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			_record_material(mesh_instance.get_active_material(surface), true)
	_check(not art_sources["material_pngs"].is_empty(), "Room materials actually reference PNG textures")
	for node in main.find_children("*", "CanvasItem", true, false):
		var canvas_item := node as CanvasItem
		_record_material(canvas_item.material, false)


func _record_material(material: Material, is_world: bool) -> void:
	if material == null or _seen_materials.has(material.get_instance_id()):
		return
	_seen_materials[material.get_instance_id()] = true
	if material is ShaderMaterial and material.shader != null:
		var shader_path: String = material.shader.resource_path
		if not shader_path.is_empty() and shader_path not in art_sources["shaders"]:
			art_sources["shaders"].append(shader_path)
	if not is_world:
		return
	for property in material.get_property_list():
		if property.get("type") != TYPE_OBJECT:
			continue
		var value: Variant = material.get(property["name"])
		if value is Texture2D:
			var path: String = value.resource_path
			if path.to_lower().ends_with(".png") and path not in art_sources["material_pngs"]:
				art_sources["material_pngs"].append(path)


func _wait_until(condition: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _click(button: Button) -> void:
	if not is_instance_valid(button):
		failures.append("Required UI button missing")
		return
	_check(not button.disabled, "Required UI button enabled: " + button.text)
	await process_frame
	button.pressed.emit()
	await process_frame


func _finish_speech_chunks() -> void:
	for _i in range(12):
		var next := _find(ui.modal, "Далее")
		if not is_instance_valid(next):
			return
		await _click(next)
	failures.append("Speech chunks did not end")


func _find(node: Node, caption: String) -> Button:
	if not is_instance_valid(node):
		return null
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var result := _find(child, caption)
		if result:
			return result
	return null


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
