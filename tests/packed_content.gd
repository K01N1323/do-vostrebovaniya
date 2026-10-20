extends SceneTree
## Run from the filesystem with --main-pack to check exported scenes and JSON.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _run() -> void:
	var store := root.get_node("GameStore")
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var room: Node3D = main.get_node("Room")
	room.set_reduced_motion(true)
	_expect(ProjectSettings.get_setting("application/config/version") == "0.6.0", "packed version is 0.6.0")
	_expect(store.dispatch({"type":"START"}).ok, "packed shift starts")
	for case_id in ["nina", "fedor"]:
		var detail := "napkin" if case_id == "nina" else "paint"
		_expect(store.get_snapshot().case_id == case_id, "packed sequence selects " + case_id)
		_expect(store.content.dialogues.has("greeting") and store.content.details.has(detail), "packed JSON contains " + case_id)
		_expect(ResourceLoader.exists(store.content.presentation.portrait), "packed portrait exists for " + case_id)
		for command in [{"type":"READ_DOCUMENT","document_id":"identity"}, {"type":"READ_DOCUMENT","document_id":"claim"},
			{"type":"MOVE_PACKAGE","destination":"desk"}, {"type":"OPEN_PACKAGE"}, {"type":"INSPECT_DETAIL","detail_id":detail}]:
			_expect(store.dispatch(command).ok, "packed command " + str(command))
		var stage: Node3D = load("res://scenes/objects/inspection_stage.tscn").instantiate()
		stage.set_item(store.get_snapshot().package.id)
		main.add_child(stage)
		stage.reduced_motion = true
		stage.focus_detail(detail)
		_expect(stage.get_focus_id() == detail, "packed inspection works for " + case_id)
		stage.queue_free()
		_expect(store.dispatch({"type":"RETAIN_PACKAGE"} if case_id == "nina" else {"type":"ISSUE_PACKAGE","recipient":"fedor"}).ok, "packed decision " + case_id)
		var until := Time.get_ticks_msec() + 5000
		while (room.visitor_phase != "gone" or room.transfer_active) and Time.get_ticks_msec() < until:
			await process_frame
		_expect(room.visitor_phase == "gone" and not room.transfer_active, "packed animations finish for " + case_id)
		if case_id == "nina":
			_expect(store.dispatch({"type":"NEXT_CASE"}).ok, "packed transition to Fedor")
	var state: Dictionary = store.get_snapshot()
	_expect(state.completed_cases.nina.package.location == "shelf" and state.package.location == "issued", "packed outcomes keep two independent locations")
	_expect(is_instance_valid(room.find_child("FedorPortrait", true, false)), "packed room instantiates Fedor portrait")
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d exported-content checks." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
