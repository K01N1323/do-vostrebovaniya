extends SceneTree
## Iteration 0.2: observable presentation invariants and state/UI integration.

var _checks := 0
var _failures: Array[String] = []
var _main: Node
var _ui: Node
var _room: Node
var _store: Node
var _rig: Node3D
var _camera: Camera3D
var _package: Node3D
var _positions: Dictionary = {}
var _eye := Vector3.ZERO
var _handover_count := 0
var _door_overlap := false
var _eye_moved := false


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
	await _frames()
	_ui = _main.get_node_or_null("Interface/GameUI")
	_room = _main.get_node_or_null("Room")
	_rig = _main.get_node_or_null("CameraRig") as Node3D
	_store = root.get_node_or_null("GameStore")
	if not _required_nodes():
		_finish()
		return
	_camera = _rig.call("get_camera")
	_package = _room.get_node_or_null("Package") as Node3D
	_positions = _room.get_script().get_script_constant_map().get("PACKAGE_POSITIONS", {})
	var eye_value: Variant = _rig.get_script().get_script_constant_map().get("EYE")
	_expect(eye_value is Vector3, "camera exposes fixed EYE")
	_expect(_positions.has("shelf") and _positions.has("desk") and _positions.has("personal") and _positions.has("hatch"), "room exposes all package positions")
	if eye_value is Vector3:
		_eye = eye_value
	else:
		_finish()
		return
	_expect(is_instance_valid(_package) and is_instance_valid(_camera), "package and camera instances exist")
	if not is_instance_valid(_package) or not is_instance_valid(_camera) or not _positions.has("shelf"):
		_finish()
		return
	_room.connect("handover_finished", func() -> void: _handover_count += 1)
	_expect(_room.get("visitor_phase") == "absent", "visitor absent in title screen")
	_expect(_room.get("input_enabled") == false, "title screen blocks room picking")
	_expect(_package.visible and _package.position.is_equal_approx(_positions["shelf"]), "package starts on current shelf position")
	_expect(_room.find_children("Target_P01", "StaticBody3D", true, false).size() == 1, "room has exactly one P01 target")
	var mute := _find_button(_ui, "Играть без звука")
	if is_instance_valid(mute):
		mute.button_pressed = true
	var start := _find_button(_ui, "Начать смену")
	_expect(is_instance_valid(start), "menu exposes start button")
	if not is_instance_valid(start):
		_finish()
		return
	start.pressed.emit()
	var started: bool = await _wait_until(func() -> bool: return _snapshot().get("started", false), 1.2)
	_expect(started, "start button completes preparation and dispatches START")
	_expect(_room.get("visitor_phase") == "arriving", "START begins visitor arrival")
	var arrived: bool = await _wait_until(func() -> bool: return _room.get("visitor_phase") == "waiting", 2.0)
	_expect(arrived, "visitor arrives and waits at window")
	await _frames()
	_expect(not is_instance_valid(_ui.get("_start_screen")), "preparation screen closes")
	_expect(_ui.get("_modal_kind") == "briefing" and not _room.get("input_enabled"), "briefing opens before greeting and blocks background clicks")
	_ui.call("_close_modal")
	await _frames()
	_expect(_ui.get("_modal_kind") == "dialogue", "visitor arrival opens compact greeting")
	await _test_conversation("arrival greeting", true)
	await _test_visitor_audio_and_idle()
	await _test_fixed_eye()
	_test_pause_and_motion()
	for decision in ["issue", "retain", "appropriate"]:
		if decision != "issue":
			_ui.call("_restart")
			await _frames()
			_test_restart_state(decision)
			arrived = await _wait_until(func() -> bool: return _room.get("visitor_phase") == "waiting", 2.0)
			_expect(arrived, decision + ": restarted visitor arrives")
			_ui.call("_close_modal")
		var prepared: bool = await _prepare_case(decision)
		if not prepared:
			continue
		_ui.call("_show_decision")
		await _frames()
		_expect(_ui.get("_modal_kind") == "decision", decision + ": decision panel opens")
		_check_panel(decision + " decision", true)
		var captions := {"issue": "Выдать переноску Нине Лукиной", "retain": "Завершить обращение · оставить на хранении", "appropriate": "Убрать под стол · присвоить переноску"}
		var button := _find_button(_ui.get("modal"), captions[decision])
		_expect(is_instance_valid(button) and not button.disabled, decision + ": decision button enabled")
		if not is_instance_valid(button):
			continue
		var begin_ms := Time.get_ticks_msec()
		var before_count := _handover_count
		button.pressed.emit()
		if decision == "issue":
			var hatch: Control = _ui.find_child("HatchStage", true, false)
			_expect(is_instance_valid(hatch), "the room opens a manual transfer before issuing")
			hatch.nudge(1.0)
			var cleared: bool = await _wait_until(hatch.ready_to_deliver, 2.4)
			_expect(cleared and hatch.jolted, "a hard push jolts the saucer and still reaches the receiver")
			var sign := _find_button(_ui.get("modal"), "Подписать и передать")
			sign.pressed.emit()
			begin_ms = Time.get_ticks_msec()
			_expect(_snapshot().get("handling") == "jolted", "rough transfer is recorded")
		_expect(_snapshot()["case_status"] == "resolved" and _snapshot()["decision"] == decision, decision + ": logical outcome is immediate")
		await _frames()
		_expect(_ui.get("_modal_kind") == "result", decision + ": compact reaction opens")
		_check_panel(decision + " reaction", false)
		await _observe(0.4)
		if decision == "issue":
			_check_face_uncovered(decision + " reaction")
		_expect(_room.get("visitor_phase") == "waiting", decision + ": visitor remains for reaction")
		if decision == "issue":
			_expect(_rig.get("current_view") == "window", "issue keeps view on protected handover")
			_expect(_room.get("transfer_active") == true, "issue begins presentation transfer")
			var finished: bool = await _wait_until(func() -> bool: return not _room.get("transfer_active"), 2.05)
			_expect(finished and Time.get_ticks_msec() - begin_ms <= 2050, "protected handover completes within two seconds")
			_expect(_handover_count == before_count + 1, "handover_finished emitted exactly once")
			var hatch: Dictionary = _room.call("get_hatch_state")
			_expect(not hatch.get("inner_open", true) and not hatch.get("outer_open", true), "handover ends with both doors closed")
			await _test_repeated_and_loaded_issued()
		_check_outcome(decision)
		var logical_after_decision := _snapshot().duplicate(true)
		var gone: bool = await _wait_until(func() -> bool: return _room.get("visitor_phase") == "gone", 4.0)
		_expect(gone, decision + ": visitor leaves after reaction")
		_expect(_snapshot() == logical_after_decision, decision + ": visitor timing does not change history")
		_ui.call("_close_modal")
	await _test_restart_cancels_animations()
	await _test_return_to_title()
	_expect(not _door_overlap, "inner and outer hatch doors never overlap in observed frames")
	_expect(not _eye_moved, "camera remains at EYE throughout all observed frames")
	_main.queue_free()
	await process_frame
	_finish()


func _test_return_to_title() -> void:
	_ui.call("_show_hint", "Сообщение из прежней смены")
	_ui.call("_show_pause")
	var back := _find_button(_ui.get("modal"), "В главное меню")
	_expect(is_instance_valid(back), "pause exposes return to title")
	if not is_instance_valid(back):
		return
	back.pressed.emit()
	await _frames()
	_expect(not _snapshot()["started"], "return to title resets logical shift")
	_expect(is_instance_valid(_ui.get("_start_screen")), "title recreated")
	_expect(not _ui.get("_hud").visible, "title hides gameplay HUD")
	_expect(_ui.get("hint").text.begins_with("ПКМ"), "return to title resets hints from the old shift")
	_expect(_room.get("visitor_phase") == "absent", "title removes visitor")
	_expect(not _room.get("input_enabled") and not _rig.get("look_enabled"), "title blocks room and head controls")
	_expect(not _ui.get("_sound").get("_running"), "title stops shift audio")
	var begin := _find_button(_ui.get("_start_screen"), "Начать смену")
	_expect(is_instance_valid(begin), "return title exposes fresh START")
	if is_instance_valid(begin):
		begin.pressed.emit()
		var started_again: bool = await _wait_until(func() -> bool: return _snapshot()["started"] and not is_instance_valid(_ui.get("_start_screen")), 1.5)
		_expect(started_again, "starting again after title works")

func _required_nodes() -> bool:
	var valid := true
	for item in [[_ui, "_show_comparison", "UI"], [_room, "get_hatch_state", "Room hatch API"], [_room, "get_visitor_focus_position", "Room visitor API"], [_rig, "get_camera", "CameraRig"], [_store, "dispatch", "GameStore"]]:
		var present: bool = is_instance_valid(item[0]) and item[0].has_method(item[1])
		_expect(present, item[2] + " is available")
		valid = valid and present
	return valid


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _snapshot() -> Dictionary:
	return _store.call("get_snapshot")


func _frames(count: int = 2) -> void:
	for _i in range(count):
		await process_frame
		_collect_invariants()


func _wait_until(condition: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		_collect_invariants()
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _observe(seconds: float) -> void:
	await _wait_until(func() -> bool: return false, seconds)


func _collect_invariants() -> void:
	if is_instance_valid(_camera) and is_instance_valid(_rig):
		if not _camera.global_position.is_equal_approx(_rig.to_global(_eye)):
			_eye_moved = true
	if is_instance_valid(_room) and _room.has_method("get_hatch_state"):
		var hatch: Dictionary = _room.call("get_hatch_state")
		if hatch.get("inner_open", false) and hatch.get("outer_open", false):
			_door_overlap = true


func _test_fixed_eye() -> void:
	_ui.call("_close_modal")
	_rig.set("reduced_motion", false)
	for view in ["window", "shelf", "desk", "personal", "window"]:
		_ui.call("_focus", view)
		await _observe(0.75)
		_expect(_rig.get("current_view") == view, "fixed viewpoint selects " + view)
		_expect(_camera.position.is_equal_approx(_eye), "local EYE unchanged at " + view)
	var original: Transform3D = _camera.transform
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_RIGHT
	down.pressed = true
	_rig.call("_unhandled_input", down)
	var movement := InputEventMouseMotion.new()
	movement.relative = Vector2(180, 100)
	_rig.call("_unhandled_input", movement)
	down.pressed = false
	_rig.call("_unhandled_input", down)
	_expect(_camera.position.is_equal_approx(_eye), "head turning keeps fixed EYE")
	_expect(not _camera.transform.basis.is_equal_approx(original.basis), "right mouse changes head orientation")
	_ui.call("_focus", "window")
	await _observe(0.75)


func _test_pause_and_motion() -> void:
	_ui.call("_show_pause")
	_expect(_room.get("input_enabled") == false, "pause blocks room picking")
	var reduced := _find_button(_ui.get("modal"), "Уменьшить движение камеры")
	_expect(is_instance_valid(reduced), "pause exposes reduced motion preference")
	if is_instance_valid(reduced):
		reduced.button_pressed = true
		_expect(_rig.get("reduced_motion") == true, "motion preference reaches camera")
		reduced.button_pressed = false
	_ui.call("_close_modal")
	_room.call("set_reduced_motion", false)
	_expect(_room.get("input_enabled") == true and _rig.get("look_enabled") == true, "closing pause restores interaction")


func _prepare_case(label: String) -> bool:
	var package_before: Dictionary = _snapshot()["package"].duplicate(true)
	_ui.call("_show_document", "identity")
	await _frames(3)
	_expect(_ui.get("_modal_kind") == "document", label + ": single identity document opens")
	_check_panel(label + " identity", true)
	if ResourceLoader.exists("res://assets/characters/nina-v1.png"):
		var photo := _ui.get("modal").find_child("IdentityPhoto", true, false) as TextureRect
		_expect(is_instance_valid(photo) and photo.texture != null and photo.size.x > 0 and photo.size.y > 0, label + ": identity contains a visible photo")
	_expect(_snapshot()["package"] == package_before, label + ": identity reading leaves package unchanged")
	_ui.call("_close_modal")
	await _frames()
	_ui.call("_show_comparison")
	await _frames(3)
	_expect(_snapshot()["read_documents"].size() == 2, label + ": comparison reads both documents")
	_expect(_snapshot()["package"] == package_before, label + ": reading papers does not move package")
	_check_panel(label + " documents", true)
	var previous_view: String = _rig.get("current_view")
	_ui.call("_focus", "personal")
	_expect(_rig.get("current_view") == previous_view, label + ": documents block camera navigation")
	_ui.call("_close_modal")
	_expect(_room.get("input_enabled") == true and _rig.get("look_enabled") == true, label + ": closing documents restores interaction")
	_ui.call("_move", "desk")
	await _frames()
	await physics_frame
	_expect(_snapshot()["package"]["location"] == "desk" and _package.position.is_equal_approx(_positions["desk"]), label + ": package moves to current desk position")
	_ui.call("_show_inspection")
	await _frames(3)
	_expect(_snapshot()["package"]["opened"] == true and _package.get("opened") == true, label + ": inspection opens package at desk")
	_check_panel(label + " inspection", true)
	var inspection: Node = _ui.get("_inspection")
	_expect(is_instance_valid(inspection), label + ": inspection stage exists")
	if not is_instance_valid(inspection):
		return false
	var viewport := inspection.get_parent() as SubViewport
	_expect(is_instance_valid(viewport) and viewport.own_world_3d, label + ": inspection uses separate 3D world")
	var contents := inspection.get_node_or_null("Pivot/Package/Contents")
	_expect(is_instance_valid(contents) and contents.find_children("Sandwich*", "Node3D", false, false).size() == 3, label + ": three inspection sandwiches")
	inspection.set("reduced_motion", true)
	var pivot := inspection.get_node_or_null("Pivot") as Node3D
	if is_instance_valid(pivot):
		var angle: float = pivot.rotation.y
		inspection.call("rotate_item", 1.0)
		_expect(not is_equal_approx(angle, pivot.rotation.y), label + ": inspection rotates")
	inspection.emit_signal("detail_selected", "sandwiches")
	_expect(inspection.get_focus_id() == "sandwiches" and not _snapshot()["inspected_details"].has("sandwiches"), label + ": detail signal previews without recording")
	_ui.call("_record_focused_detail")
	_expect(_snapshot()["inspected_details"].has("sandwiches"), label + ": marking the preview records knowledge")
	_ui.call("_inspect_detail", "napkin")
	_expect(_snapshot()["inspected_details"].has("napkin"), label + ": detail action records napkin")
	_ui.call("_close_modal")
	var logical_before := _snapshot().duplicate(true)
	_room.call("rotate_package", 0.3)
	_expect(_snapshot() == logical_before, label + ": visual package rotation does not alter history")
	_ui.call("_move", "shelf")
	await _frames()
	_expect(_snapshot()["package"]["opened"] == true and _package.get("opened") == false, label + ": shelf package is visually closed without losing knowledge")
	_ui.call("_move", "desk")
	await _frames()
	_expect(_package.get("opened") == true, label + ": returning to desk restores open appearance")
	_ui.call("_show_conversation")
	_expect(_rig.get("current_view") == "window", label + ": talking turns from desk to visitor")
	_expect(not _package.get("opened"), label + ": carrier lid closes below visitor")
	_expect(_snapshot()["package"]["opened"] == true, label + ": closing the visual lid preserves inspection history")
	await _observe(0.75)
	await _frames(3)
	_check_panel(label + " conversation", false)
	_check_face_uncovered(label + " conversation")
	await _finish_speech_chunks()
	var lunch := _find_button(_ui.get("modal"), "Вы приготовили обед на троих?")
	_expect(is_instance_valid(lunch), label + ": sandwiches expose lunch question")
	if is_instance_valid(lunch):
		lunch.pressed.emit()
		_expect(_snapshot()["asked_topics"].has("lunch"), label + ": lunch button records topic")
		_expect(not _package.get("opened"), label + ": dialogue updates do not reopen foreground lid")
	_ui.call("_close_modal")
	return true


func _test_conversation(label: String, expect_chunks: bool) -> void:
	await _frames(3)
	_check_panel(label, false)
	_check_face_uncovered(label)
	var speech := _ui.find_child("SpeechText", true, false) as RichTextLabel
	_expect(is_instance_valid(speech) and not speech.text.is_empty(), label + ": speech text is visible")
	var next := _find_button(_ui.get("modal"), "Далее")
	if expect_chunks:
		_expect(is_instance_valid(next), label + ": long greeting exposes next chunk")
	if is_instance_valid(next) and is_instance_valid(speech):
		var portrait := _room.find_child("NinaPortrait", true, false) as Sprite3D
		var pose := portrait.frame
		var old_text: String = speech.text
		var package_before: Dictionary = _snapshot()["package"].duplicate(true)
		next.pressed.emit()
		await _frames()
		_expect(speech.text != old_text, label + ": next displays another speech chunk")
		_expect(portrait.hframes == 3 and portrait.frame != pose, label + ": next selects the drawn pose for the current line")
		_expect(_snapshot()["package"] == package_before, label + ": speech progress leaves package unchanged")
	_ui.call("_close_modal")

func _test_visitor_audio_and_idle() -> void:
	var portrait := _room.find_child("NinaPortrait", true, false) as Sprite3D
	var before := portrait.position
	await create_timer(0.18).timeout
	_expect(portrait.frame == 0 and not portrait.position.is_equal_approx(before), "waiting visitor returns to neutral and shifts weight")
	var sound: Node = _ui.get("_sound")
	var music: AudioStreamPlayer = sound.get("_music")
	var voice: AudioStreamPlayer = sound.get("_voice")
	_expect(not music.playing, "mute keeps music silent")
	_ui.call("_set_muted", false)
	_ui.call("_show_conversation")
	_expect(music.playing and music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music loops through the shift")
	_expect(voice.playing, "a line plays the visitor's murmur")
	_ui.call("_show_pause")
	_expect(music.stream_paused and voice.stream_paused, "pause suspends music and voice")
	_ui.call("_close_modal")
	_expect(not music.stream_paused and not voice.stream_paused, "resume restores music and the current voice")
	_ui.call("_close_modal")
	_expect(not voice.playing and music.playing, "closing dialogue stops just the murmur")
	_ui.call("_set_muted", true)
	_expect(not music.playing, "mute stops music during the shift")


func _check_panel(label: String, blocked: bool) -> void:
	var panel := _ui.get("modal") as Control
	_expect(is_instance_valid(panel), label + ": ContentPanel exists")
	if not is_instance_valid(panel):
		return
	var rect: Rect2 = panel.get_global_rect()
	var viewport_rect := root.get_visible_rect()
	_expect(rect.size.x > 0 and rect.size.y > 0, label + ": panel has positive dimensions " + str(rect))
	_expect(viewport_rect.grow(2).encloses(rect), label + ": panel remains inside viewport " + str(rect))
	_expect(rect.size.x < viewport_rect.size.x * 0.95 and rect.size.y < viewport_rect.size.y * 0.95, label + ": panel does not fill screen")
	_expect(_room.get("input_enabled") == (not blocked), label + ": room blocking matches panel kind")
	_expect(_rig.get("look_enabled") == (not blocked), label + ": head-look blocking matches panel kind")
	for control in _ui.find_children("*", "ColorRect", true, false):
		var overlay := control as ColorRect
		if not is_instance_valid(overlay) or not overlay.is_visible_in_tree():
			continue
		var overlay_rect: Rect2 = overlay.get_global_rect()
		if overlay_rect.size.x >= viewport_rect.size.x * 0.95 and overlay_rect.size.y >= viewport_rect.size.y * 0.95:
			_expect(overlay.color.a * overlay.modulate.a <= 0.15, label + ": no opaque full-screen scrim")


func _check_face_uncovered(label: String) -> void:
	var panel := _ui.get("modal") as Control
	if not is_instance_valid(panel):
		return
	var focus: Vector3 = _room.call("get_visitor_focus_position")
	var screen := _camera.unproject_position(focus)
	_expect(not _camera.is_position_behind(focus), label + ": visitor face is in front of camera")
	_expect(root.get_visible_rect().has_point(screen), label + ": visitor face is inside viewport")
	_expect(not panel.get_global_rect().has_point(screen), label + ": speech panel leaves face uncovered")


func _finish_speech_chunks() -> void:
	for _i in range(12):
		var next := _find_button(_ui.get("modal"), "Далее")
		if not is_instance_valid(next):
			return
		next.pressed.emit()
		await _frames()
	_expect(false, "speech chunks eventually expose topic choices")


func _check_outcome(decision: String) -> void:
	var state := _snapshot()
	var target := _package.get_node_or_null("Target_P01") as StaticBody3D
	_expect(is_instance_valid(target), decision + ": P01 collider exists")
	if decision == "issue":
		_expect(state["package"]["location"] == "issued" and not _package.visible, "issued package disappears after handover")
		if is_instance_valid(target):
			_expect(target.collision_layer == 0, "issued package cannot be picked")
	else:
		var location: String = "shelf" if decision == "retain" else "personal"
		_expect(state["package"]["location"] == location and _package.visible, decision + ": final package visible")
		_expect(_package.position.is_equal_approx(_positions[location]), decision + ": final package uses room coordinates")
		_expect(_package.get("opened") == false, decision + ": stored package is visually closed")
	var before := state.duplicate(true)
	var response: Dictionary = _store.call("dispatch", {"type": "ISSUE_PACKAGE", "recipient": "nina"})
	_expect(response.get("ok") == false and _snapshot() == before, decision + ": double issue remains rejected")


func _test_repeated_and_loaded_issued() -> void:
	var issued := _snapshot()
	var count_before := _handover_count
	for _i in range(3):
		_room.call("apply_snapshot", issued)
	await _observe(0.2)
	_expect(_room.get("transfer_active") == false and _handover_count == count_before, "repeated issued snapshots do not repeat handover")
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	var fresh: Node = load("res://scenes/room/room.tscn").instantiate()
	viewport.add_child(fresh)
	fresh.call("apply_snapshot", issued)
	await _frames()
	var fresh_package := fresh.get_node("Package") as Node3D
	_expect(fresh.get("transfer_active") == false and not fresh_package.visible, "first loaded issued snapshot hides package without transfer")
	viewport.queue_free()
	await _frames()


func _test_restart_state(label: String) -> void:
	var state := _snapshot()
	_expect(state["started"] == true and state["case_status"] == "active" and state["decision"] == "", label + ": UI restart starts active case")
	_expect(state["read_documents"].is_empty() and state["inspected_details"].is_empty() and state["asked_topics"].is_empty(), label + ": restart clears knowledge")
	_expect(_package.visible and _package.get("opened") == false and _package.position.is_equal_approx(_positions["shelf"]), label + ": restart restores closed shelf package")
	_expect(_room.get("transfer_active") == false, label + ": restart has no old transfer")


func _test_restart_cancels_animations() -> void:
	_ui.call("_restart")
	await _wait_until(func() -> bool: return _room.get("visitor_phase") == "waiting", 2.0)
	_ui.call("_close_modal")
	for command in [{"type": "READ_DOCUMENT", "document_id": "identity"}, {"type": "READ_DOCUMENT", "document_id": "claim"}, {"type": "MOVE_PACKAGE", "destination": "desk"}, {"type": "OPEN_PACKAGE"}, {"type": "INSPECT_DETAIL", "detail_id": "sandwiches"}]:
		_store.call("dispatch", command)
	_ui.call("_decide", "ISSUE_PACKAGE")
	await _observe(0.2)
	_expect(_room.get("transfer_active") == true, "cancellation test begins during active handover")
	var before_count := _handover_count
	_ui.call("_close_modal")
	_store.call("dispatch", {"type": "RESTART"})
	await _frames()
	_expect(_room.get("transfer_active") == false and _room.get("visitor_phase") == "absent", "RESTART cancels transfer and visitor movement")
	_expect(_package.visible and _package.get("opened") == false and _package.position.is_equal_approx(_positions["shelf"]), "cancelled transfer restores closed shelf package")
	await _observe(2.3)
	_expect(_handover_count == before_count and _room.get("visitor_phase") == "absent", "cancelled callbacks never finish or move the visitor later")
	_expect(_snapshot()["started"] == false and _snapshot()["decision"] == "", "cancelled animation cannot mutate reset history")
	_store.call("dispatch", {"type": "START"})
	await _frames()
	_expect(_room.get("visitor_phase") == "arriving", "new START begins a new arrival")
	_store.call("dispatch", {"type": "RESTART"})
	await _observe(1.4)
	_expect(_room.get("visitor_phase") == "absent", "RESTART also cancels arrival tween")


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
		print("PASS: %d iteration 0.2 scene/UI checks; fixed EYE, compact UI, visitors and protected handover verified." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: %d failures / %d iteration 0.2 checks" % [_failures.size(), _checks])
		quit(1)
