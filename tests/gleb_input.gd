extends "res://tests/melnikov_input.gd"
## Four-case routes through real GUI/3D viewport events, not UI handlers.

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Gleb input test needs graphics.")
		quit(1)
		return
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	output_dir = ProjectSettings.globalize_path("res://tools/input-08")
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
		{"nina":"issue","fedor":"retain","recipient":"vera","gleb":"issue","size":Vector2i(1280,800)},
		{"nina":"retain","fedor":"appropriate","recipient":"leonid","gleb":"retain","size":Vector2i(1000,700)},
		{"nina":"appropriate","fedor":"issue","recipient":"","gleb":"appropriate","size":Vector2i(1440,900)}]
	for scenario in scenarios:
		if scenario.gleb != "issue":
			await _key(KEY_ESCAPE)
			await _click_caption("В главное меню")
		root.size = scenario.size
		await _settle()
		print("INPUT 0.8: route " + scenario.gleb)
		if not await _play_case(scenario.nina) or not await _play_fedor(scenario.fedor) or not await _play_melnikovs(scenario.recipient) or not await _play_gleb(scenario.gleb):
			break
	var manifest := FileAccess.open(output_dir.path_join("manifest.json"),FileAccess.WRITE)
	if manifest:
		manifest.store_string(JSON.stringify({"version":"0.8","checks":checks,"failures":failures,"captures":captures},"\t"))
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d viewport checks through four cases and all three Gleb outcomes." % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _play_gleb(decision: String) -> bool:
	var prior: Dictionary = Rules.all_packages(store.get_snapshot())
	var history: Dictionary = store.get_snapshot().completed_cases.duplicate(true)
	await _click_caption("Следующий посетитель")
	_expect(await _wait(func(): return room.visitor_phase == "waiting",3.0), "Gleb arrives after the shared case")
	_expect(store.get_snapshot().case_id == "gleb" and ui._modal_kind == "dialogue", "Gleb has his own arrival dialogue")
	_expect(room.find_child("GlebPortrait",true,false).is_visible_in_tree() and not room.find_child("MelnikovsPortrait",true,false).is_visible_in_tree(), "Gleb replaces both claimants at the window")
	_expect(ui.dialogue_text.text.contains("Нина") and ui.dialogue_text.text.contains("Спасибо"), "Nina's real gratitude introduces the repair independently of the camera")
	await _capture(decision + "-gleb-arrival")
	await _finish_reply()
	_expect(_find_button(ui,"Вы сказали: чёрный корпус?") == null and _find_button(ui,"Где плёнка из заявления?") == null, "contradiction questions wait for their observations")
	await _click_caption("Что было с лампой Нины?")
	_expect("repair" in store.get_snapshot().asked_topics, "repair conversation is available without implying ownership")
	await _capture(decision + "-gleb-repair")
	await _key(KEY_ESCAPE)
	await _click_caption("Сравнить обе бумаги")
	_expect(store.get_snapshot().read_documents.size() == 2, "two genuine-name papers are read separately from evidence")
	_expect(is_instance_valid(ui.modal.find_child("Paper_identity",true,false)) and is_instance_valid(ui.modal.find_child("Paper_claim",true,false)), "Gleb papers appear side by side")
	for id in ["identity", "claim"]:
		var paper: Node = ui.modal.find_child("Paper_" + id,true,false)
		var text := paper.find_children("*","RichTextLabel",true,false)[0] as RichTextLabel
		_expect(text.size.y >= 135 and text.get_visible_line_count() >= 5, "paper exposes name and identifying description without scrolling: " + id)
	await _capture(decision + "-gleb-papers")
	await _key(KEY_ESCAPE)
	_expect(_find_button(ui,"Принять решение").disabled, "papers alone cannot bypass inspecting the bag")
	await _key(KEY_2)
	await _settle()
	var target := room.find_child("Target_P04",true,false) as Node3D
	await _click_world(target.global_position,decision + "-gleb-shelf")
	if not _expect(store.get_snapshot().package.location == "desk", "P04 moves from its own shelf bracket by 3D click"):
		return false
	await _settle()
	await _click_world(target.global_position)
	if not _expect(ui._modal_kind == "inspection", "grocery bag opens its own inspection scene"):
		return false
	var stage: Node3D = ui.get("_inspection")
	await _settle()
	await _capture(decision + "-gleb-overview")
	for id in ["camera_body","strap","onions"]:
		await _click_stage(stage,id)
		if not _expect(id in store.get_snapshot().inspected_details and stage.get_focus_id() == id, "physical click inspects Gleb evidence: " + id):
			await _capture(decision + "-gleb-" + id + "-failed")
			return false
		await _settle()
		await _capture(decision + "-gleb-" + id)
		await _click_caption("Вся сумка")
		await _settle()
	await _key(KEY_ESCAPE)
	await _click_caption("Поговорить")
	await _finish_reply()
	await _click_caption("Вы сказали: чёрный корпус?")
	_expect("body_mismatch" in store.get_snapshot().asked_topics, "observed body unlocks the color discrepancy")
	await _capture(decision + "-gleb-body-reply")
	await _finish_reply()
	await _click_caption("Где плёнка из заявления?")
	_expect("film_mismatch" in store.get_snapshot().asked_topics, "onions unlock the missing-film discrepancy")
	await _capture(decision + "-gleb-film-reply")
	await _key(KEY_ESCAPE)
	await _click_caption("Вернуть на полку · пока думаю")
	_expect(store.get_snapshot().case_status == "active" and store.get_snapshot().inspected_details.size() == 3, "shelf move preserves active status and evidence")
	await _click_caption("Принять решение")
	_expect(_find_button(ui,"Выдать сумку Глебу Корнееву").disabled and _find_button(ui,"Убрать под стол · присвоить сумку").disabled, "bag cannot be issued or taken directly from shelf")
	await _click_caption("Пока не решать")
	if decision != "retain":
		await _click_caption("Поставить на стол")
	await _click_caption("Принять решение")
	await _settle()
	await _capture(decision + "-gleb-decision")
	var captions := {"issue":"Выдать сумку Глебу Корнееву", "retain":"Завершить обращение · оставить на хранении", "appropriate":"Убрать под стол · присвоить сумку"}
	await _click_caption(captions[decision])
	_expect(store.get_snapshot().decision == decision and store.get_snapshot().case_status == "resolved", "Gleb outcome " + decision + " remains a deliberate possible action")
	var next := _find_button(ui,"Следующий посетитель")
	_expect(is_instance_valid(next) and next.disabled, "Serov waits for Gleb to depart")
	await _capture(decision + "-gleb-result")
	await _key(KEY_ESCAPE)
	var safe := true
	var until := Time.get_ticks_msec() + 5000
	while (room.visitor_phase != "gone" or room.transfer_active) and Time.get_ticks_msec() < until:
		var hatch: Dictionary = room.get_hatch_state()
		safe = safe and not (hatch.inner_open and hatch.outer_open)
		await process_frame
	_expect(safe and room.visitor_phase == "gone" and not room.transfer_active, "Gleb departs and transfer doors never open together")
	var final: Dictionary = Rules.all_packages(store.get_snapshot())
	_expect(final.size() == 7 and final.P01 == prior.P01 and final.P02 == prior.P02 and final.P03 == prior.P03, "Gleb outcome preserves all three earlier package locations")
	_expect(store.get_snapshot().completed_cases.nina == history.nina and store.get_snapshot().completed_cases.fedor == history.fedor, "Gleb never changes archived earlier stories")
	_expect(final.P04.location == {"issue":"issued","retain":"shelf","appropriate":"personal"}[decision], "one bag has one physical destination")
	await _key(KEY_2 if decision == "retain" else (KEY_4 if decision == "appropriate" else KEY_1))
	await _settle()
	await _capture(decision + "-gleb-final-place")
	return failures.is_empty()
