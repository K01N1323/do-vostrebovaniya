extends "res://tests/fedor_input.gd"
## A full shift through three cases using viewport events, including lock typing.

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Melnikov input test needs graphics.")
		quit(1)
		return
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	output_dir = ProjectSettings.globalize_path("res://tools/input-07")
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
	var scenarios := [
		{"nina":"issue","fedor":"retain","recipient":"vera","size":Vector2i(1280,800)},
		{"nina":"retain","fedor":"appropriate","recipient":"leonid","size":Vector2i(1000,700)},
		{"nina":"appropriate","fedor":"issue","recipient":"","size":Vector2i(1440,900)}]
	for scenario in scenarios:
		if scenario.recipient != "vera":
			await _key(KEY_ESCAPE)
			await _click_caption("В главное меню")
		root.size = scenario.size
		await _settle()
		if not await _play_case(scenario.nina) or not await _play_fedor(scenario.fedor) or not await _play_melnikovs(scenario.recipient):
			break
	var manifest := FileAccess.open(output_dir.path_join("manifest.json"),FileAccess.WRITE)
	if manifest:
		manifest.store_string(JSON.stringify({"version":"0.7","checks":checks,"failures":failures,"captures":captures},"\t"))
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d viewport checks through three cases; Vera, Leonid and retention." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _play_melnikovs(recipient: String) -> bool:
	var prior: Dictionary = Rules.all_packages(store.get_snapshot())
	var name_value := recipient if not recipient.is_empty() else "retain"
	await _click_caption("Следующий посетитель")
	_expect(await _wait(func(): return room.visitor_phase == "waiting",3.0), "Melnikovs arrive together")
	_expect(store.get_snapshot().case_id == "melnikovs" and ui._modal_kind == "dialogue", "shared case has its own arrival dialogue")
	_expect(room.find_child("MelnikovsPortrait",true,false).is_visible_in_tree() and not room.find_child("FedorPortrait",true,false).is_visible_in_tree(), "pair portrait replaces Fedor")
	await _capture(name_value + "-pair-arrival")
	await _finish_reply()
	_expect(_find_button(ui,"Почему язычок под тканью?") == null, "hidden detail question stays unavailable")
	await _click_caption("Кто помнит код замка?")
	_expect("lock_code" in store.get_snapshot().asked_topics, "Leonid's code testimony recorded")
	await _capture(name_value + "-code-dialogue")
	await _key(KEY_ESCAPE)
	await _click_caption("Бумаги Веры")
	_expect(store.get_snapshot().read_documents.size() == 2 and "vera_claim" in store.get_snapshot().read_documents and "leonid_claim" not in store.get_snapshot().read_documents, "Vera papers do not silently read Leonid papers")
	await _key(KEY_ESCAPE)
	_expect(_find_button(ui,"Принять решение").disabled, "decision remains unavailable after only Vera documents")
	await _click_caption("Сверить все четыре бумаги")
	_expect(store.get_snapshot().read_documents.size() == 4, "all four shared-case papers are read")
	for id in ["vera_identity","vera_claim","leonid_identity","leonid_claim"]:
		_expect(is_instance_valid(ui.modal.find_child("Paper_" + id,true,false)), "comparison displays " + id)
	await _capture(name_value + "-four-papers")
	await _key(KEY_ESCAPE)
	await _key(KEY_2)
	await _settle()
	var target := room.find_child("Target_P03",true,false) as Node3D
	await _click_world(target.global_position,name_value + "-suitcase-shelf")
	if not _expect(store.get_snapshot().package.location == "desk", "P03 moves from its own shelf slot"):
		return false
	await _settle()
	await _click_world(target.global_position)
	if not _expect(ui._modal_kind == "lock", "locked suitcase asks for code before inspection"):
		return false
	var before: Dictionary = store.get_snapshot()
	await _type_code("123")
	await _click_caption("Открыть замок")
	_expect(store.get_snapshot() == before and ui._modal_kind == "lock", "wrong typed code changes no story state")
	var feedback := ui.modal.find_child("LockFeedback",true,false) as Label
	_expect(not feedback.text.is_empty(), "wrong code feedback is visible in the lock panel")
	await _capture(name_value + "-wrong-code")
	for i in range(3):
		await _key(KEY_BACKSPACE)
	await _type_code("246")
	await _key(KEY_ENTER)
	if not _expect(ui._modal_kind == "inspection" and store.get_snapshot().package.unlocked and store.get_snapshot().package.opened, "typed code and Enter open P03"):
		return false
	var stage: Node3D = ui.get("_inspection")
	await _settle()
	await _capture(name_value + "-suitcase-overview")
	_expect(not stage.can_focus_detail("zipper"), "hidden zipper cannot be inspected before lifting")
	for id in ["combination", "green_stain"]:
		await _click_stage(stage,id)
		_expect(id in store.get_snapshot().inspected_details and stage.get_focus_id() == id, "3D inspection of " + id)
		await _settle()
		await _capture(name_value + "-" + id)
		await _click_caption("Весь чемодан")
		await _settle()
	await _click_stage(stage,"lining")
	_expect(store.get_snapshot().package.lining_lifted and "zipper" not in store.get_snapshot().inspected_details, "3D click lifts lining without automatically inspecting the pull")
	_expect(stage.can_focus_detail("zipper"), "lifting enables hidden detail")
	await _settle()
	await _capture(name_value + "-raised-lining")
	await _click_stage(stage,"zipper")
	_expect("zipper" in store.get_snapshot().inspected_details and stage.get_focus_id() == "zipper", "actual pull under lining can be clicked")
	await _settle()
	await _capture(name_value + "-zipper")
	await _key(KEY_ESCAPE)
	await _click_caption("Вернуть на полку · пока думаю")
	_expect(store.get_snapshot().case_status == "active" and store.get_snapshot().package.location == "shelf" and store.get_snapshot().package.lining_lifted, "returning shared case to shelf does not resolve it")
	await _click_caption("Принять решение")
	_expect(_find_button(ui,"Выдать чемодан Вере Мельниковой").disabled and _find_button(ui,"Выдать чемодан Леониду Мельникову").disabled, "neither claimant can receive a shelf package directly")
	await _click_caption("Пока не решать")
	await _click_caption("Поставить на стол")
	await _click_caption("Осмотреть содержимое")
	_expect(store.get_snapshot().package.lining_lifted and ui.get("_inspection").get_node("Pivot/Package").lining_lifted, "reopening restores the raised lining and evidence")
	await _key(KEY_ESCAPE)
	await _click_caption("Поговорить")
	await _finish_reply()
	await _click_caption("Почему язычок под тканью?")
	_expect("lining_story" in store.get_snapshot().asked_topics, "pull observation unlocks shared memory dialogue")
	await _capture(name_value + "-shared-memory")
	await _key(KEY_ESCAPE)
	await _click_caption("Принять решение")
	await _capture(name_value + "-shared-decision")
	var caption: String = {"vera":"Выдать чемодан Вере Мельниковой","leonid":"Выдать чемодан Леониду Мельникову","":"Завершить обращение · оставить на хранении"}[recipient]
	await _click_caption(caption)
	_expect(store.get_snapshot().recipient == recipient and store.get_snapshot().case_status == "resolved", "chosen recipient recorded: " + name_value)
	_expect(is_instance_valid(_find_button(ui,"Следующий посетитель")), "next case is available after the shared case")
	await _capture(name_value + "-shared-result")
	await _key(KEY_ESCAPE)
	var safe := true
	var until := Time.get_ticks_msec() + 5000
	while (room.visitor_phase != "gone" or room.transfer_active) and Time.get_ticks_msec() < until:
		var hatch: Dictionary = room.get_hatch_state()
		safe = safe and not (hatch.inner_open and hatch.outer_open)
		await process_frame
	_expect(safe and room.visitor_phase == "gone" and not room.transfer_active, "shared case leaves through protected block")
	var final_packages: Dictionary = Rules.all_packages(store.get_snapshot())
	_expect(final_packages.P01 == prior.P01 and final_packages.P02 == prior.P02 and final_packages.size() == 7, "shared decision preserves two previous package outcomes")
	_expect(final_packages.P03.location == ("shelf" if recipient.is_empty() else "issued"), "P03 remains a single package")
	await _key(KEY_2)
	await _settle()
	await _capture(name_value + "-final-shelf")
	return failures.is_empty()

func _type_code(value: String) -> void:
	for character in value:
		for pressed in [true,false]:
			var event := InputEventKey.new()
			event.keycode = character.unicode_at(0)
			event.physical_keycode = event.keycode
			event.unicode = character.unicode_at(0) if pressed else 0
			event.pressed = pressed
			root.push_input(event,true)
			await process_frame
	await process_frame

func _click_stage(stage: Node3D, id: String) -> void:
	var target := stage.find_child("Target_" + id,true,false) as Node3D
	var camera := stage.get_node("Camera3D") as Camera3D
	var container := stage.get_viewport().get_parent() as SubViewportContainer
	await _click_at(container.get_global_transform_with_canvas() * camera.unproject_position(target.global_position))
	if id != "lining" and _find_button(ui, "Отметить наблюдение") != null:
		_expect(stage.get_focus_id() == id, "world click previews " + id)
		await _click_caption("Отметить наблюдение")
