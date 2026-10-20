extends "res://tests/input_workflow.gd"
## Reuses the same viewport input helpers, then plays the complete second case.

const Rules = preload("res://scripts/core/state_reducer.gd")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Fedor input test needs graphics.")
		quit(1)
		return
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	output_dir = ProjectSettings.globalize_path("res://tools/input-06")
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
			root.size = Vector2i(1000, 700) if decision == "retain" else Vector2i(1440, 900)
			await _settle()
		if not await _play_case(decision):
			break
		if not await _play_fedor(decision):
			break
	var manifest := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if manifest:
		manifest.store_string(JSON.stringify({"version":"0.6", "checks":checks, "failures":failures, "captures":captures}, "\t"))
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d viewport checks through Nina and Fedor; three outcomes each." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _play_fedor(decision: String) -> bool:
	var nina: Dictionary = store.get_snapshot()
	await _click_caption("Следующий посетитель")
	_expect(store.get_snapshot().case_id == "fedor", "next button advances to Fedor")
	_expect(await _wait(func(): return room.visitor_phase == "waiting", 3.0), "Fedor arrives")
	_expect(ui._modal_kind == "dialogue", "Fedor arrival opens his conversation")
	_expect(room.find_child("FedorPortrait", true, false).is_visible_in_tree(), "Fedor has his own portrait")
	_expect(not room.find_child("NinaPortrait", true, false).is_visible_in_tree(), "Nina is no longer at the window")
	await _capture(decision + "-fedor-arrival")
	await _finish_reply()
	_expect(_find_button(ui, "Откуда синяя полоса?") == null, "paint question hidden before inspection")
	await _click_caption("Вы его строили?")
	_expect("work" in store.get_snapshot().asked_topics, "Fedor work dialogue recorded")
	await _key(KEY_ESCAPE)
	await _click_caption("Сравнить обе бумаги")
	_expect(ui._modal_kind == "comparison" and store.get_snapshot().read_documents.size() == 2, "both Fedor documents are readable")
	await _capture(decision + "-fedor-papers")
	await _key(KEY_ESCAPE)
	await _key(KEY_2)
	await _settle()
	var target := room.find_child("Target_P02", true, false) as Node3D
	var shelf_point: Vector2 = rig.get_camera().unproject_position(target.global_position)
	_expect(shelf_point.y > root.get_visible_rect().size.y * 0.14, "P02 is below the HUD, visibly inside the shelf view")
	await _click_world(target.global_position, decision + "-fedor-shelf")
	if not _expect(store.get_snapshot().package.location == "desk", "P02 moves from upper shelf to desk by 3D click"):
		return false
	await _settle()
	await _click_world(target.global_position)
	if not _expect(ui._modal_kind == "inspection", "P02 opens his own inspection stage"):
		return false
	var stage: Node3D = ui.get("_inspection")
	await _settle()
	await _capture(decision + "-fedor-overview")
	for id in ["corner", "paint", "collar"]:
		var detail := stage.find_child("Target_" + id, true, false) as Node3D
		var camera := stage.get_node("Camera3D") as Camera3D
		var container := stage.get_viewport().get_parent() as SubViewportContainer
		var point := container.get_global_transform_with_canvas() * camera.unproject_position(detail.global_position)
		await _click_at(point)
		_expect(id in store.get_snapshot().inspected_details and stage.get_focus_id() == id, "3D click inspects Fedor detail: " + id)
		await _settle()
		await _capture(decision + "-fedor-" + id)
		await _click_caption("Весь свёрток")
		await _settle()
	await _key(KEY_ESCAPE)
	await _key(KEY_1)
	await _settle()
	await _click_world(room.get_visitor_focus_position())
	await _finish_reply()
	await _click_caption("Откуда синяя полоса?")
	_expect("blue_paint" in store.get_snapshot().asked_topics, "inspection unlocks Fedor paint dialogue")
	await _key(KEY_ESCAPE)
	# Returning to shelf is not a decision, and collected evidence persists.
	await _click_caption("Вернуть на полку · пока думаю")
	_expect(store.get_snapshot().case_status == "active" and store.get_snapshot().inspected_details.size() == 3, "Fedor remains active while thinking")
	if decision != "retain":
		await _click_caption("Поставить на стол")
	await _click_caption("Принять решение")
	var captions := {"issue":"Выдать свёрток Фёдору Аргунову", "retain":"Завершить обращение · оставить на хранении", "appropriate":"Убрать под стол · присвоить свёрток"}
	await _click_caption(captions[decision])
	_expect(store.get_snapshot().decision == decision and store.get_snapshot().case_status == "resolved", "Fedor outcome " + decision)
	_expect(_find_button(ui, "Следующий посетитель") == null, "no transition to unimplemented visitor")
	await _capture(decision + "-fedor-result")
	await _key(KEY_ESCAPE)
	_expect(await _wait(func(): return room.visitor_phase == "gone" and not room.transfer_active, 5.0), "Fedor departure and handover complete")
	var packages := Rules.all_packages(store.get_snapshot())
	_expect(packages.P01 == nina.package, "Fedor outcome preserves Nina package state")
	var nina_view := room.get_node("Package") as Node3D
	_expect(nina_view.visible == (nina.package.location != "issued"), "Nina physical package still matches prior outcome")
	_expect(nina_view.get_node("Target_P01").collision_layer == 0, "previous package cannot act on the new case")
	var hatch: Dictionary = room.get_hatch_state()
	_expect(not hatch.inner_open and not hatch.outer_open, "handover closes both doors")
	for entry in [[KEY_2,"shelf"], [KEY_4,"personal"]]:
		await _key(entry[0])
		await _settle()
		await _capture(decision + "-two-packages-" + entry[1])
	return failures.is_empty()

func _finish_reply() -> void:
	for i in range(12):
		if _find_button(ui, "Далее") == null:
			return
		await _click_caption("Далее")

func _capture(id: String) -> void:
	if id.ends_with("-outcome") and store.get_snapshot().case_id == "nina":
		var next := _find_button(ui, "Следующий посетитель")
		_expect(is_instance_valid(next) and next.disabled, "next visitor locked while Nina is leaving")
		if is_instance_valid(next):
			await _click_at(next.get_global_rect().get_center())
			_expect(store.get_snapshot().case_id == "nina", "disabled next button cannot interrupt departure")
	await super._capture(id)
