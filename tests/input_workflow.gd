extends SceneTree
## Sends normal input through the root viewport, never calls game handlers.
## Requires a rendered window. It does not control the OS cursor or other apps.

var main: Node
var ui: Control
var room: Node3D
var store: Node
var rig: Node3D
var failures: Array[String] = []
var checks := 0
var output_dir := ""
var captures: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Input workflow requires a graphics window.")
		quit(1)
		return
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	output_dir = ProjectSettings.globalize_path("res://tools/input-05")
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	ui = main.get_node("Interface/GameUI")
	room = main.get_node("Room")
	rig = main.get_node("CameraRig")
	store = root.get_node("GameStore")
	root.notify_mouse_entered()
	await _settle()
	await _click_caption("Играть без звука")
	for decision in ["issue", "retain", "appropriate"]:
		if decision != "issue":
			await _key(KEY_ESCAPE)
			await _click_caption("В главное меню")
			_expect(not store.get_snapshot().started, decision + ": title starts a fresh case")
			root.size = Vector2i(1000, 700) if decision == "retain" else Vector2i(1440, 900)
			await _settle()
		if not await _play_case(decision):
			break
	await _capture("final")
	var manifest := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if manifest:
		manifest.store_string(JSON.stringify({"version": "0.5", "checks": checks, "failures": failures, "captures": captures}, "\t"))
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d viewport mouse/keyboard checks; all three outcomes." % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d input workflow errors / %d checks" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _play_case(decision: String) -> bool:
	await _click_caption("Начать смену")
	if not await _wait(func(): return store.get_snapshot().started and room.visitor_phase == "waiting", 4.0):
		_expect(false, decision + ": mouse starts shift and visitor arrives; state=%s phase=%s" % [store.get_snapshot(), room.visitor_phase])
		await _capture(decision + "-start-failed")
		return false
	_expect(ui._modal_kind == "dialogue", decision + ": arrival conversation is visible")
	await _key(KEY_ESCAPE)
	await _key(KEY_3)
	await _settle()
	_expect(rig.current_view == "desk", "3 selects desk through keyboard input")
	await _test_head_look()
	await _key(KEY_3)
	await _settle()
	var identity := room.find_child("Target_identity", true, false) as Node3D
	if not is_instance_valid(identity):
		_expect(false, "identity has a physical interaction target")
		return false
	await _click_world(identity.global_position)
	if not _expect(ui._modal_kind == "document", decision + ": paper opens from 3D click"):
		return false
	var before: Dictionary = store.get_snapshot()
	var old_view: String = rig.current_view
	await _key(KEY_F1)
	if not _expect(not ui.get("_action_panel").visible, "F1 cannot reveal actions over a document"):
		await _capture(decision + "-modal-actions-failed")
		return false
	var actions_button := _find_button(ui, "Действия · F1")
	_expect(actions_button.disabled, "actions button is disabled over a document")
	await _click_at(actions_button.get_global_rect().get_center())
	_expect(not ui.get("_action_panel").visible, "disabled actions button cannot bypass document modal")
	_expect(not ui.interaction_hint.visible, "document hides world interaction prompt")
	await _key(KEY_2)
	await _click_at(Vector2(1100, 170))
	_expect(rig.current_view == old_view and store.get_snapshot() == before, "document blocks navigation and underlying world clicks")
	await _key(KEY_ESCAPE)
	_expect(not is_instance_valid(ui.modal), "Escape closes document")
	await _click_caption("Сравнить обе бумаги")
	_expect(ui._modal_kind == "comparison" and store.get_snapshot().read_documents.size() == 2, "mouse comparison records both documents")
	await _capture(decision + "-papers")
	await _key(KEY_ESCAPE)
	await _key(KEY_2)
	await _settle()
	var package_target := room.get_node("Package/Target_P01") as Node3D
	await _click_world(package_target.global_position, decision + "-shelf-hover")
	if not _expect(store.get_snapshot().package.location == "desk", decision + ": shelf package moves by 3D click"):
		return false
	await _settle()
	await _click_world(package_target.global_position)
	if not _expect(ui._modal_kind == "inspection", decision + ": desk package opens inspection by 3D click"):
		return false
	var stage: Node3D = ui.get("_inspection")
	await _key(KEY_F1)
	_expect(not ui.get("_action_panel").visible, "F1 cannot reveal actions over inspection")
	var detail_camera := stage.get_node("Camera3D") as Camera3D
	var container := stage.get_viewport().get_parent() as SubViewportContainer
	var detail := stage.find_child("Target_napkin", true, false) as Node3D
	await _settle()
	var pivot := stage.get_node("Pivot") as Node3D
	var point := container.get_global_rect().get_center()
	for drag_button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var mask := MOUSE_BUTTON_MASK_LEFT if drag_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
		for pressed in [true, false]:
			var drag := InputEventMouseButton.new()
			drag.button_index = drag_button
			drag.button_mask = mask if pressed else 0
			drag.pressed = pressed
			drag.position = point
			drag.global_position = point
			root.push_input(drag, true)
			if pressed:
				var motion := InputEventMouseMotion.new()
				motion.position = point + Vector2(72, 24)
				motion.global_position = motion.position
				motion.relative = Vector2(72, 24)
				motion.button_mask = mask
				root.push_input(motion, true)
			await process_frame
		_expect(not is_zero_approx(pivot.rotation.y) and stage.get_focus_id().is_empty(), "held mouse rotates without selecting a clue")
		pivot.rotation = Vector3.ZERO
		await physics_frame
	var unzoomed := detail_camera.fov
	await _wheel_at(point, MOUSE_BUTTON_WHEEL_UP)
	_expect(stage.get_zoom_step() == 1 and detail_camera.fov < unzoomed, "wheel magnifies the entire item")
	await _click_caption("−")
	_expect(stage.get_zoom_step() == 0 and is_equal_approx(detail_camera.fov, unzoomed), "zoom-out button restores the default scale")
	await physics_frame
	var local_point := detail_camera.unproject_position(detail.global_position)
	var root_point := container.get_global_transform_with_canvas() * local_point
	await _click_at(root_point)
	if not _expect("napkin" not in store.get_snapshot().inspected_details and stage.get_focus_id() == "napkin", "SubViewport click focuses the patch without recording it"):
		await _capture(decision + "-inspection-failed")
		return false
	_expect(_find_button(ui, "Голубая заплата") == null, "the clue label is unavailable before recording")
	await _click_caption("+")
	_expect(stage.get_zoom_step() == 1 and stage.get_focus_id() == "napkin", "zoom also works in a close-up")
	await _click_caption("Отметить наблюдение")
	_expect("napkin" in store.get_snapshot().inspected_details, "recording the focused patch stores its evidence")
	await _capture(decision + "-close-up")
	await _click_caption("Вся переноска")
	await _settle()
	_expect(stage.get_focus_id() == "" and stage.get_zoom_step() == 0, "overview restores the default framing")
	await _click_caption("Следующий ракурс")
	await _settle()
	_expect(stage.get_focus_id() == "sandwiches" and "sandwiches" not in store.get_snapshot().inspected_details, "alternate view focuses sandwiches without recording")
	await _click_caption("Отметить наблюдение")
	_expect("sandwiches" in store.get_snapshot().inspected_details, "alternate view can be recorded")
	await _key(KEY_ESCAPE)
	_expect(not is_instance_valid(ui.modal), "Escape closes inspection")
	if decision == "issue":
		await _key(KEY_1)
		await _settle()
		await _click_world(room.get_visitor_focus_position())
		if not _expect(ui._modal_kind == "dialogue", "clicking visitor opens conversation"):
			return false
		for _i in range(12):
			if _find_button(ui, "Далее") == null:
				break
			await _click_caption("Далее")
		await _settle()
		await _click_caption("Вы приготовили обед на троих?")
		_expect("lunch" in store.get_snapshot().asked_topics, "conversation question is recorded through mouse input")
		await _capture("issue-lunch-conversation")
		await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	_expect(ui._modal_kind == "pause", "Escape opens pause")
	await _key(KEY_F1)
	_expect(not ui.get("_action_panel").visible, "F1 cannot reveal actions while paused")
	var was_reduced: bool = rig.reduced_motion
	await _click_caption("Уменьшить движение камеры")
	_expect(rig.reduced_motion != was_reduced, "mouse toggles reduced motion preference")
	await _click_caption("Продолжить")
	await _key(KEY_1)
	_expect(rig.current_view == "window", "1 restores visitor view")
	await _key(KEY_F1)
	var panel: Control = ui.get("_action_panel")
	_expect(not panel.visible, "F1 hides actions")
	await _key(KEY_F1)
	_expect(panel.visible, "F1 restores actions")
	await _click_caption("Принять решение")
	var caption: String = {"issue": "Выдать переноску Нине Лукиной", "retain": "Завершить обращение · оставить на хранении", "appropriate": "Убрать под стол · присвоить переноску"}[decision]
	await _click_caption(caption)
	if not _expect(store.get_snapshot().decision == decision, decision + ": mouse confirms chosen outcome"):
		return false
	var location: String = {"issue": "issued", "retain": "shelf", "appropriate": "personal"}[decision]
	_expect(store.get_snapshot().package.location == location, decision + ": package exists at the correct single location")
	await _capture(decision + "-outcome")
	await _key(KEY_ESCAPE)
	_expect(await _wait(func(): return room.visitor_phase == "gone" and not room.transfer_active, 5.0), decision + ": visitor and handover finish")
	return failures.is_empty()


func _click_caption(caption: String) -> void:
	var button := _find_button(ui, caption)
	if not _expect(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled, "clickable control: " + caption):
		return
	var point := button.get_global_rect().get_center()
	var ancestor: Node = button.get_parent()
	var clipped_by := ""
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().has_point(point):
			clipped_by = str(ancestor.name) + " " + str(ancestor.get_global_rect())
			break
		ancestor = ancestor.get_parent()
	if not _expect(clipped_by.is_empty(), "button is inside ancestor clip: " + caption + " at " + str(point) + " clipped by " + clipped_by):
		return
	_expect(root.get_visible_rect().has_point(point), "button is inside viewport: " + caption)
	await _click_at(point)


func _click_world(position: Vector3, capture_id: String = "") -> void:
	var camera: Camera3D = rig.get_camera()
	_expect(not camera.is_position_behind(position), "world target is in front of camera")
	var point := camera.unproject_position(position)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	await physics_frame
	await process_frame
	var explained := await _wait(func(): return ui.interaction_hint.visible and ui.interaction_hint.text.begins_with("ЛКМ"), 0.6)
	_expect(explained,
		"world hover explains available mouse action; event=%s local_pointer=%s target=%s ray=%s control=%s" % [point, room.get("_pointer_position"), room.get("_hovered"), room.call("_pick", point), root.gui_get_hovered_control()])
	if not capture_id.is_empty():
		await _capture(capture_id)
	await _click_at(point)


func _click_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = position
		event.global_position = position
		root.push_input(event, true)
		await process_frame
	await process_frame


func _wheel_at(position: Vector2, direction: MouseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = direction
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event, true)
		await process_frame


func _test_head_look() -> void:
	var camera: Camera3D = rig.get_camera()
	var before := camera.transform
	var point := root.get_visible_rect().size * Vector2(0.5, 0.25)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.button_mask = MOUSE_BUTTON_MASK_RIGHT
	down.pressed = true
	down.position = point
	root.push_input(down, true)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = Vector2(90, 30)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	root.push_input(motion, true)
	await process_frame
	_expect(not camera.transform.basis.is_equal_approx(before.basis), "holding right mouse turns head through input pipeline")
	_expect(camera.position.is_equal_approx(before.origin), "head turning keeps the clerk's viewpoint fixed")
	var pause_button := _find_button(ui, "Пауза · Esc")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.pressed = false
	up.position = pause_button.get_global_rect().get_center()
	root.push_input(up, true)
	await process_frame
	var released := camera.transform
	root.push_input(motion, true)
	await process_frame
	_expect(camera.transform.is_equal_approx(released), "release over UI stops head turning")


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await process_frame


func _settle() -> void:
	await create_timer(0.4).timeout
	await physics_frame
	await process_frame


func _wait(condition: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _capture(id: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty():
		_expect(image.save_png(output_dir.path_join(id + ".png")) == OK, "capture saved: " + id)
	captures.append({"id": id, "window_size": str(root.size), "viewport_size": str(root.get_visible_rect().size), "state": store.get_snapshot(), "modal": ui._modal_kind})


func _find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var button := _find_button(child, caption)
		if button != null:
			return button
	return null


func _expect(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok
