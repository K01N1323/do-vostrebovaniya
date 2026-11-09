extends "res://tests/gleb_input.gd"
## Exercise all three coat outcomes after four complete routes of normal input.

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Serov input test needs graphics.")
		quit(1)
		return
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	output_dir = ProjectSettings.globalize_path("res://tools/input-" + _version().replace(".", ""))
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	ui = main.get_node("Interface/GameUI")
	room = main.get_node("Room")
	rig = main.get_node("CameraRig")
	store = root.get_node("GameStore")
	store.command_rejected.connect(func(reason: String): print("Rejected during input: ", reason))
	root.notify_mouse_entered()
	await _settle()
	await _click_caption("Играть без звука")
	var routes := [
		{"nina":"issue","fedor":"retain","recipient":"vera","gleb":"issue","serov":"issue","size":Vector2i(1280,800)},
		{"nina":"retain","fedor":"appropriate","recipient":"leonid","gleb":"retain","serov":"retain","size":Vector2i(1000,700)},
		{"nina":"appropriate","fedor":"issue","recipient":"","gleb":"appropriate","serov":"appropriate","size":Vector2i(1440,900)},
	]
	for route in routes:
		if route.serov != "issue":
			await _key(KEY_ESCAPE)
			await _click_caption("В главное меню")
		root.size = route.size
		await _settle()
		print("INPUT " + _version() + ": route " + route.serov)
		if not await _play_case(route.nina) or not await _play_fedor(route.fedor) or not await _play_melnikovs(route.recipient) or not await _play_gleb(route.gleb) or not await _play_serov(route.serov):
			break
	var manifest := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	if manifest:
		manifest.store_string(JSON.stringify({"version":_version(),"checks":checks,"failures":failures,"captures":captures},"	"))
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d viewport checks through the shift." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _version() -> String:
	return "0.9"

func _play_serov(decision: String) -> bool:
	var previous := Rules.all_packages(store.get_snapshot())
	await _click_caption("Следующий посетитель")
	if not _expect(await _wait(func(): return room.visitor_phase == "waiting", 3.0), "Serov arrives after Gleb"):
		return false
	_expect(store.get_snapshot().case_id == "serov" and ui._modal_kind == "dialogue", "Serov has his own arrival")
	var camera_outcome: String = store.get_snapshot().completed_cases.gleb.decision
	_expect(ui.dialogue_text.text == store.content.camera_followup[camera_outcome], "Orlov's call reflects what happened to the camera")
	await _capture(decision + "-serov-arrival")
	await _finish_reply()
	_expect(ui.dialogue_text.text.contains("помнит"), "Pavel recognizes Serov and remembers the act")
	await _click_caption("Вспомнить дело о сумке")
	await _finish_reply()
	await _click_caption("Куда вы едете?")
	await _finish_reply()
	await _key(KEY_ESCAPE)
	_expect("past" in store.get_snapshot().asked_topics and "trip" in store.get_snapshot().asked_topics, "two story topics heard before the decision")
	await _click_caption("Сравнить обе бумаги")
	await _capture(decision + "-serov-papers")
	await _key(KEY_ESCAPE)
	await _key(KEY_3)
	await _settle()
	var archive := room.find_child("Target_archive",true,false) as Node3D
	await _click_world(archive.global_position)
	_expect(store.get_snapshot().old_act_read and ui.modal.find_child("Paper_old_act",true,false) != null, "the 2014 archive act opens from the desk")
	await _capture(decision + "-old-act")
	await _key(KEY_ESCAPE)
	if decision == "issue":
		for id in ["P06", "P07"]:
			if not await _play_loose_find(id):
				return false
	await _click_caption("Поставить на стол")
	await _click_caption("Открыть и осмотреть")
	if not _expect(ui._modal_kind == "inspection", "coat has a physical inspection scene"):
		return false
	var stage: Node3D = ui.get("_inspection")
	await _settle()
	var model := stage.find_child("OpenFind",true,false)
	_expect(model.find_children("Pocket*", "Node3D", false, false).size() == 13, "the coat has thirteen visible pockets")
	await _capture(decision + "-serov-overview")
	for id in ["coat_tag", "coat_pockets", "coat_cuff", "coat_reversed"]:
		await _click_stage(stage, id)
		if not _expect(id in store.get_snapshot().inspected_details and stage.get_focus_id() == id, "physical click on " + id):
			await _capture(decision + "-failed-" + id)
			return false
		await _settle()
		await _capture(decision + "-" + id)
		await _click_caption("Всё пальто")
		await _settle()
	await _key(KEY_ESCAPE)
	await _click_caption("Принять решение")
	var captions := {"issue":"Выдать пальто Семёну Серову", "retain":"Завершить обращение · оставить на хранении", "appropriate":"Убрать под стол · присвоить пальто"}
	await _settle()
	await _click_caption(captions[decision])
	var state: Dictionary = store.get_snapshot()
	_expect(state.decision == decision and state.case_status == "resolved", "coat outcome is " + decision)
	await _key(KEY_ESCAPE)
	_expect(await _wait(func(): return room.visitor_phase == "at_bus" and not room.transfer_active, 5.0), "Serov goes to the bus after " + decision)
	await _click_caption("Поговорить с Серовым у рейса")
	_expect(rig.current_view == "bus" and ui._modal_kind == "dialogue", "bus talk is available after " + decision)
	await _settle()
	await _capture(decision + "-serov-bus")
	await _key(KEY_ESCAPE)
	var serov := room.find_child("Target_nina",true,false) as Node3D
	await _click_world(serov.global_position + Vector3(0, 0.48, 0))
	_expect(ui._modal_kind == "dialogue", "Serov can also be clicked at the bus")
	await _key(KEY_ESCAPE)
	var final := Rules.all_packages(state)
	for id in ["P01", "P02", "P03", "P04"]:
		_expect(final[id] == previous[id], "coat leaves " + id + " untouched")
	_expect(final.P05.location == {"issue":"issued","retain":"shelf","appropriate":"personal"}[decision], "the coat has one destination")
	return failures.is_empty()

func _play_loose_find(id: String) -> bool:
	await _key(KEY_2)
	await _settle()
	var target := room.find_child("Target_" + id,true,false) as Node3D
	await _click_world(target.global_position)
	if not _expect(store.get_snapshot().loose_finds[id].location == "desk", id + " moves from its own shelf"):
		return false
	await _settle()
	await _click_world(target.global_position)
	if not _expect(ui._modal_kind == "inspection", id + " has a separate inspection"):
		return false
	var stage: Node3D = ui.get("_inspection")
	await _settle()
	var package := stage.find_child("OpenFind",true,false)
	if id == "P06":
		_expect(package.find_children("RubberLensCap","MeshInstance3D",true,false).size() == 1, "empty case contains one cap")
	else:
		_expect(package.find_children("Remote*","Node3D",false,false).size() == 5 and package.find_children("EmptyBatteryBay","MeshInstance3D",true,false).size() == 5, "five distinct remotes with five empty bays")
	for detail in store.loose_finds[id].details:
		await _click_stage(stage, detail)
		_expect(detail in store.get_snapshot().loose_finds[id].inspected_details and stage.get_focus_id() == detail, "physical click inspects " + detail)
		await _settle()
		await _capture(id + "-" + detail)
		await _click_caption(store.loose_finds[id].presentation.overview)
		await _settle()
	await _click_caption("Вернуть находку на полку")
	_expect(store.get_snapshot().loose_finds[id].location == "shelf", id + " is back on its shelf")
	return failures.is_empty()
