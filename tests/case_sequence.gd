extends SceneTree

const Rules = preload("res://scripts/core/state_reducer.gd")
const Store = preload("res://scripts/core/game_store.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _apply(state: Dictionary, command: Dictionary) -> Dictionary:
	var before := state.duplicate(true)
	var result: Dictionary = Rules.apply_command(state, command)
	_expect(result.ok, str(command) + ": accepted " + result.error)
	_expect(state == before, "input snapshot is immutable")
	return result.state

func _reject(state: Dictionary, command: Dictionary) -> void:
	var result: Dictionary = Rules.apply_command(state, command)
	_expect(not result.ok and not result.error.is_empty(), str(command) + ": rejected with reason")
	_expect(result.state == state, "rejection keeps history")

func _verify(state: Dictionary, package_id: String, location: String) -> void:
	var packages: Dictionary = Rules.all_packages(state)
	_expect(packages.size() == 7 and packages.has("P01") and packages.has("P02") and packages.has("P03") and packages.has("P04"), "one entry per package")
	_expect(packages[package_id].location == location, package_id + " retains its location")
	packages[package_id].location = "corrupted"
	_expect(Rules.all_packages(state)[package_id].location == location, "derived package view cannot change state")

func _ready_case(state: Dictionary, detail: String) -> Dictionary:
	for command in [{"type":"READ_DOCUMENT","document_id":"identity"}, {"type":"READ_DOCUMENT","document_id":"claim"},
		{"type":"MOVE_PACKAGE","destination":"desk"}, {"type":"OPEN_PACKAGE"}, {"type":"INSPECT_DETAIL","detail_id":detail}]:
		state = _apply(state, command)
	return state

func _run() -> void:
	var locations := {"ISSUE_PACKAGE":"issued", "RETAIN_PACKAGE":"shelf", "APPROPRIATE_PACKAGE":"personal"}
	_reject(Rules.initial_state(), {"type":"NEXT_CASE"})
	for nina_choice in locations:
		for fedor_choice in locations:
			var state := _apply(Rules.initial_state(), {"type":"START"})
			_reject(state, {"type":"NEXT_CASE"})
			state = _ready_case(state, "sandwiches")
			state = _apply(state, {"type":nina_choice, "recipient":"nina"})
			var nina_record := state.duplicate(true)
			nina_record.erase("completed_cases")
			nina_record.erase("loose_finds")
			nina_record.erase("preview_finds")
			nina_record.erase("old_act_read")
			nina_record.erase("card_location")
			state = _apply(state, {"type":"NEXT_CASE"})
			_expect(state.case_id == "fedor" and state.package.id == "P02", "Nina advances to Fedor/P02")
			_expect(state.read_documents.is_empty() and state.inspected_details.is_empty() and state.asked_topics.is_empty(), "Fedor starts without Nina knowledge")
			_expect(state.completed_cases.nina == nina_record, "Nina archive keeps exact facts")
			_expect(not Rules.finished_checking(state), "Nina verification does not carry to Fedor")
			_verify(state, "P01", locations[nina_choice])
			_reject(state, {"type":"NEXT_CASE"})
			_reject(state, {"type":"ASK_TOPIC", "topic_id":"carrier"})
			_reject(state, {"type":"ASK_TOPIC", "topic_id":"blue_paint"})
			_reject(state, {"type":"INSPECT_DETAIL", "detail_id":"corner"})
			_expect(Rules.apply_command(state, {"type":"ISSUE_PACKAGE", "recipient":"fedor"}).ok, "Fedor can receive the package without checking")
			state = _ready_case(state, "corner")
			_reject(state, {"type":"INSPECT_DETAIL", "detail_id":"sandwiches"})
			_reject(state, {"type":"ISSUE_PACKAGE", "recipient":"nina"})
			state = _apply(state, {"type":"INSPECT_DETAIL", "detail_id":"paint"})
			state = _apply(state, {"type":"ASK_TOPIC", "topic_id":"blue_paint"})
			state = _apply(state, {"type":"INSPECT_DETAIL", "detail_id":"collar"})
			if fedor_choice == "RETAIN_PACKAGE":
				state = _apply(state, {"type":"MOVE_PACKAGE", "destination":"shelf"})
				_expect(state.case_status == "active", "thinking on shelf does not resolve Fedor")
			state = _apply(state, {"type":fedor_choice, "recipient":"fedor"})
			_verify(state, "P01", locations[nina_choice])
			_verify(state, "P02", locations[fedor_choice])
			_expect(state.completed_cases.nina == nina_record, "Fedor choice cannot rewrite Nina")
			_reject(state, {"type":"MOVE_PACKAGE", "destination":"desk"})
			var melnikovs := _apply(state, {"type":"NEXT_CASE"})
			_expect(melnikovs.case_id == "melnikovs" and melnikovs.completed_cases.has("fedor"), "Fedor can advance to the shared case")
			_reject(melnikovs, {"type":"NEXT_CASE"})
			var reset := _apply(state, {"type":"RESTART"})
			_expect(reset == Rules.initial_state(), "restart resets the whole shift")
	# Content must switch before emitting the new snapshot, then switch back on restart.
	var store := Node.new()
	store.set_script(Store)
	root.add_child(store)
	var events: Array[String] = []
	store.state_changed.connect(func(snapshot: Dictionary):
		events.append(snapshot.case_id)
		_expect(store.content.presentation.number == ("02" if snapshot.case_id == "fedor" else "01"), "content agrees with emitted snapshot"))
	for command in [{"type":"START"}, {"type":"READ_DOCUMENT","document_id":"identity"}, {"type":"READ_DOCUMENT","document_id":"claim"},
		{"type":"MOVE_PACKAGE","destination":"desk"}, {"type":"OPEN_PACKAGE"}, {"type":"INSPECT_DETAIL","detail_id":"napkin"},
		{"type":"RETAIN_PACKAGE"}, {"type":"NEXT_CASE"}]:
		_expect(store.dispatch(command).ok, "store sequence dispatch")
	_expect(store.content.details.has("collar") and not store.content.details.has("napkin"), "Fedor content has own evidence")
	for key in ["presentation", "topic_labels"]:
		var damaged: Dictionary = store.content.duplicate(true)
		damaged[key] = "bad record"
		_expect(not store._valid_content(damaged, "fedor"), "malformed " + key + " is rejected")
	var missing: Dictionary = store.content.duplicate(true)
	missing.presentation.outcomes.erase("retain")
	_expect(not store._valid_content(missing, "fedor"), "missing outcome caption is rejected")
	var exposed: Dictionary = store.get_snapshot()
	exposed.completed_cases.nina.package.location = "personal"
	_expect(store.get_snapshot().completed_cases.nina.package.location == "shelf", "store isolates nested history")
	_expect(store.dispatch({"type":"RESTART"}).ok and store.content.presentation.number == "01", "restart restores Nina content")
	_expect(events.has("fedor"), "sequence emitted Fedor snapshot")
	store.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d case-sequence checks, nine pairs of decisions." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
