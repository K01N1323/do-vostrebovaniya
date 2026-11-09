extends "res://tests/finale_rules.gd"

const Saves = preload("res://scripts/core/save_repository.gd")

func _run() -> void:
	var path := ProjectSettings.globalize_path("res://tools/shift-test-%s.json" % Time.get_ticks_usec())
	var store := root.get_node("GameStore")
	store.save_path = path
	store.preferences_path = path + ".preferences"
	store.persistence_enabled = true
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var ui: Control = main.get_node("Interface/GameUI")
	var room: Node3D = main.get_node("Room")
	ui.set("_reduced", true)
	ui.set("_muted", true)
	await ui._start_shift()
	_expect(await _autosaved(store, path), "starting the shift creates a real save file")
	ui.open_target("identity")
	_expect(store.get_snapshot().read_documents.is_empty(), "visitor papers stay unavailable during arrival")
	ui.open_target("clerk_identity")
	_expect(is_instance_valid(ui.modal.find_child("IdentityPhoto",true,false)), "Pavel's ID has a photo from the start")
	await create_timer(1.3).timeout
	_expect(ui.get("_modal_kind") == "document" and ui.get("_arrival_dialogue_pending"), "arrival waits for an open document to close")
	ui._close_modal()
	await process_frame
	_expect(ui.get("_modal_kind") == "dialogue" and ui.dialogue_text.text.contains("дальнюю комнату"), "Nina's opening sets up the later discovery")
	ui._close_modal()
	ui._show_document("identity")
	await process_frame
	var saved := Saves.load_shift(path)
	_expect(saved.view.get("id") == "identity" and saved.state.read_documents == ["identity"], "open document and observation autosave together")
	ui._return_to_title()
	await ui._resume_shift()
	_expect(ui.get("_modal_kind") == "document" and ui.modal.find_child("IdentityPhoto",true,false) != null, "resume opens Nina's identity booklet")
	_expect(store.get_snapshot().read_documents == ["identity"] and room.visitor_phase == "waiting", "resume keeps document evidence and settles visitor")
	ui._close_modal()
	_expect(store.dispatch({"type":"MOVE_PACKAGE","destination":"desk"}).ok, "move for checkpoint")
	ui._show_inspection()
	ui._preview_detail("napkin")
	await process_frame
	saved = Saves.load_shift(path)
	_expect(saved.view.get("detail") == "napkin" and saved.state.inspected_details.is_empty(), "unrecorded close-up is saved separately from evidence")
	ui._return_to_title()
	await ui._resume_shift()
	_expect(ui.get("_inspection").get_focus_id() == "napkin" and store.get_snapshot().inspected_details.is_empty(), "resuming a preview does not discover the clue")
	ui._inspect_detail("napkin")
	await process_frame
	saved = Saves.load_shift(path)
	_expect(saved.view.get("kind") == "inspection" and saved.view.get("detail") == "napkin", "focus is stored")
	var checkpoint: Dictionary = store.get_snapshot()
	ui._return_to_title()
	await ui._resume_shift()
	var stage: Node3D = ui.get("_inspection")
	_expect(ui.get("_modal_kind") == "inspection" and stage.get_focus_id() == "napkin", "resume restores close-up")
	_expect(store.get_snapshot() == checkpoint and not room.transfer_active, "restore cannot repeat a package action")
	ui._show_pause()
	_expect(paused and not room.can_process(), "pause freezes the room and bound tweens")
	ui._close_modal()
	_expect(not paused and ui.get("_modal_kind") == "inspection" and stage.get_focus_id() == "napkin", "resuming the pause preserves the open inspection")
	ui._close_modal()
	ui._show_pause()
	ui._save_now()
	_expect(ui.get("_save_message").text == "Смена сохранена.", "manual save reports success")
	var valid_primary := FileAccess.get_file_as_string(path)
	var backup_path := path + ".bak"
	var valid_backup := FileAccess.get_file_as_string(backup_path)
	_expect(not valid_primary.is_empty() and not valid_backup.is_empty(), "replacement preserves earlier backup")
	var damaged: Variant = JSON.parse_string(valid_primary)
	damaged.state.loose_finds.P06.location = "desk"
	_write_fixture(path, JSON.stringify(damaged))
	_expect(Saves.load_shift(path).recovered, "two packages on a desk is rejected and backup is selected")
	_expect(store.save_progress(), "save replaces a damaged primary")
	_expect(FileAccess.get_file_as_string(backup_path) == valid_backup, "a damaged primary never replaces the backup")
	_write_fixture(path, "{")
	_write_fixture(backup_path, JSON.stringify({"format":99}))
	_expect(Saves.load_shift(path).is_empty(), "truncated file and unsupported schema are rejected")
	_expect(store.get_snapshot() == checkpoint, "invalid files do not change live progress")
	var errors: Array[String] = []
	store.save_failed.connect(func(reason: String): errors.append(reason))
	store.save_path = path.path_join("impossible.json")
	_expect(not store.save_progress() and errors.size() == 1, "write failure is reported")
	_expect(store.get_snapshot() == checkpoint, "write failure leaves the shift playable")
	ui._return_to_title()
	_expect(store.get_snapshot() == checkpoint and ui.get("_modal_kind") == "pause" and paused, "failed exit to title keeps the live shift and visible error")
	ui._restart()
	var confirmation: ConfirmationDialog = ui.get("_confirmation")
	_expect(is_instance_valid(confirmation) and store.get_snapshot() == checkpoint, "restart requires confirmation before resetting progress")
	confirmation.canceled.emit()
	_expect(store.get_snapshot() == checkpoint, "canceling restart preserves progress")
	ui._restart()
	confirmation = ui.get("_confirmation")
	confirmation.confirmed.emit()
	_expect(store.get_snapshot() == checkpoint and ui.get("_modal_kind") == "pause", "failed replacement leaves the current shift open")
	ui._set_muted(true)
	ui._set_reduced_motion(true)
	_expect(store.read_preferences() == {"muted":true, "reduced_motion":true}, "settings round-trip in a separate file")
	var case_content: Dictionary = store.get_case_content("nina")
	case_content.presentation.portrait = "res://assets/characters/missing.png"
	_expect(not store._valid_content(case_content, "nina"), "missing portrait is rejected")
	var duplicate_order := ["nina", "nina", "melnikovs", "gleb", "serov", "finale"]
	_expect(not Cases.catalog_errors(duplicate_order).is_empty(), "duplicate and unreachable case IDs are rejected")
	var broken_cases: Dictionary = Cases.CASES.duplicate(true)
	broken_cases.serov.required_topics.append("never_asked")
	_expect(not Cases.catalog_errors(Cases.ORDER, broken_cases).is_empty(), "unreachable required topics are rejected")
	ui._close_modal()
	store.save_path = path
	_check_early_arrival(store, ui, path)
	_check_ending_roundtrip(path)
	main.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".preferences", ".tmp", ".bak.tmp"]:
		var file: String = path + suffix
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	for failure in failures:
		push_error(failure)
	print("%s: %d save, recovery and restoration checks." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _autosaved(store: Node, path: String) -> bool:
	await process_frame
	await process_frame
	var saved := Saves.load_shift(path)
	return not saved.is_empty() and saved.state == store.get_snapshot()

func _write_fixture(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _check_early_arrival(store: Node, ui: Control, path: String) -> void:
	var nina := _apply(Rules.initial_state(), {"type":"START"})
	for command in [
		{"type":"MOVE_PACKAGE", "package_id":"P02", "destination":"desk"},
		{"type":"OPEN_PACKAGE", "package_id":"P02"},
		{"type":"INSPECT_DETAIL", "package_id":"P02", "detail_id":"corner"},
		{"type":"MOVE_PACKAGE", "package_id":"P02", "destination":"shelf"},
	]:
		nina = _apply(nina, command)
	nina = _ready_case(nina, "sandwiches")
	nina = _apply(nina, {"type":"RETAIN_PACKAGE"})
	var fedor := _apply(nina, {"type":"NEXT_CASE"})
	_expect(Saves.write_shift(path, fedor, {}) == OK and not store.continue_shift().is_empty(), "restored early inspection enters Fedor's arrival")
	_expect("corner" in store.get_snapshot().inspected_details and ui._modal_kind == "dialogue", "early evidence does not skip Fedor's greeting")
	ui._close_modal()

func _check_ending_roundtrip(path: String) -> void:
	var state := _before_gleb("RETAIN_PACKAGE", "RETAIN_PACKAGE", "")
	state = _ready_case(state, "camera_body")
	for id in ["strap", "onions"]:
		state = _apply(state, {"type":"INSPECT_DETAIL", "detail_id":id})
	state = _apply(state, {"type":"RETAIN_PACKAGE"})
	state = _apply(state, {"type":"NEXT_CASE"})
	state = _ready_case(state, "coat_tag")
	for detail in ["coat_pockets", "coat_cuff", "coat_reversed"]:
		state = _apply(state, {"type":"INSPECT_DETAIL", "detail_id":detail})
	for topic in ["past", "trip"]:
		state = _apply(state, {"type":"ASK_TOPIC", "topic_id":topic})
	for coat in CHOICES:
		var final := _apply(state, {"type":coat, "recipient":"serov"})
		final = _apply(final, {"type":"READ_OLD_ACT"})
		final = _apply(final, {"type":"NEXT_CASE"})
		final = _apply(final, {"type":"MOVE_PACKAGE","destination":"desk"})
		final = _apply(final, {"type":"OPEN_PACKAGE"})
		for id in Cases.get_case("finale").details:
			final = _apply(final, {"type":"INSPECT_DETAIL","detail_id":id})
		final = _apply(final, {"type":"READ_DOCUMENT","document_id":"card"})
		final = _apply(final, {"type":"TAKE_CARD"})
		_expect(Saves.write_shift(path, final, {}) == OK and Saves.load_shift(path).state == final, "card in hand survives reload")
		var draft := _apply(final, {"type":"FILE_CARD"})
		_expect(Saves.write_shift(path, draft, {"kind":"archive_draft"}) == OK, "unsigned archive draft can be saved")
		var saved_draft := Saves.load_shift(path)
		_expect(saved_draft.state == draft and saved_draft.view.kind == "archive_draft", "unsigned archive draft survives reload")
		for ending in Cases.ENDINGS:
			var outcome := _apply(draft if ending == "archive" else final, {"type":"FINAL_ACTION","ending":ending})
			_expect(Saves.write_shift(path, outcome, {"kind":"ending"}) == OK, "save " + coat + "/" + ending)
			var saved := Saves.load_shift(path)
			_expect(saved.state == outcome and saved.view.kind == "ending", "round trip preserves entire ending " + coat + "/" + ending)
