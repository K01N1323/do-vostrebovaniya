extends SceneTree
## Run from the filesystem with --main-pack to check exported scenes and JSON.

const Cases = preload("res://scripts/core/case_definitions.gd")

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
	_expect(ProjectSettings.get_setting("application/config/version") == "0.14.0", "packed version is 0.14.0")
	_expect(store.dispatch({"type":"START"}).ok, "packed shift starts")
	for case_id in Cases.ORDER:
		if case_id == "finale":
			break
		var detail: String = {"nina":"napkin","fedor":"paint","melnikovs":"zipper","gleb":"onions","serov":"coat_pockets"}[case_id]
		_expect(store.get_snapshot().case_id == case_id, "packed sequence selects " + case_id)
		_expect(store.content.dialogues.has("greeting") and store.content.details.has(detail), "packed JSON contains " + case_id)
		_expect(ResourceLoader.exists(store.content.presentation.portrait), "packed portrait exists for " + case_id)
		var portrait := room.find_child(case_id.capitalize() + "Portrait", true, false) as Sprite3D
		_expect(is_instance_valid(portrait) and portrait.hframes == 3, "packed room renders three poses for " + case_id)
		for id in Cases.get_case(case_id).documents:
			if id.ends_with("identity"):
				_expect(ResourceLoader.exists(store.content.documents[id].portrait), "packed identity photograph " + id)
			_expect(store.dispatch({"type":"READ_DOCUMENT","document_id":id}).ok,"packed paper " + id)
		_expect(store.dispatch({"type":"MOVE_PACKAGE","destination":"desk"}).ok,"packed move " + case_id)
		if case_id == "melnikovs":
			_expect(store.dispatch({"type":"ASK_TOPIC","topic_id":"lock_code"}).ok,"packed testimony")
			_expect(store.dispatch({"type":"UNLOCK_PACKAGE","code":"246"}).ok,"packed combination lock")
		_expect(store.dispatch({"type":"OPEN_PACKAGE"}).ok,"packed opening " + case_id)
		if case_id == "melnikovs":
			_expect(store.dispatch({"type":"INSPECT_DETAIL","detail_id":"green_stain"}).ok,"packed stain")
			_expect(store.dispatch({"type":"LIFT_LINING"}).ok,"packed lining")
		_expect(store.dispatch({"type":"INSPECT_DETAIL","detail_id":detail}).ok,"packed evidence " + case_id)
		for id in Cases.get_case(case_id).get("required_details", []):
			if id != "zipper" and id != "green_stain" and id != detail:
				_expect(store.dispatch({"type":"INSPECT_DETAIL","detail_id":id}).ok,"packed evidence " + id)
		if case_id == "serov":
			for id in ["past", "trip"]:
				_expect(store.dispatch({"type":"ASK_TOPIC","topic_id":id}).ok,"packed conversation " + id)
		var stage: Node3D = load("res://scenes/objects/inspection_stage.tscn").instantiate()
		stage.set_item(store.get_snapshot().package.id)
		stage.set_lining_lifted(store.get_snapshot().package.get("lining_lifted",false))
		main.add_child(stage)
		stage.reduced_motion = true
		stage.focus_detail(detail)
		_expect(stage.get_focus_id() == detail, "packed inspection works for " + case_id)
		stage.queue_free()
		var command: Dictionary = {"type":"RETAIN_PACKAGE"} if case_id == "nina" else {"type":"ISSUE_PACKAGE","recipient":"leonid" if case_id == "melnikovs" else case_id}
		_expect(store.dispatch(command).ok,"packed decision " + case_id)
		var until := Time.get_ticks_msec() + 5000
		var phase := "at_bus" if case_id == "serov" else "gone"
		while (room.visitor_phase != phase or room.transfer_active) and Time.get_ticks_msec() < until:
			await process_frame
		_expect(room.visitor_phase == phase and not room.transfer_active, "packed animations finish for " + case_id)
		if case_id != "serov":
			_expect(store.dispatch({"type":"NEXT_CASE"}).ok, "packed next case")
	var state: Dictionary = store.get_snapshot()
	_expect(state.completed_cases.nina.package.location == "shelf" and state.completed_cases.fedor.package.location == "issued" and state.completed_cases.gleb.package.location == "issued" and state.package.location == "issued", "packed outcomes keep five independent package states")
	_expect(is_instance_valid(room.find_child("MelnikovsPortrait", true, false)), "packed room instantiates paired portrait")
	_expect(state.completed_cases.melnikovs.recipient == "leonid" and state.completed_cases.gleb.recipient == "gleb" and state.recipient == "serov", "packed recipient history preserves Leonid and Gleb")
	_expect(is_instance_valid(room.find_child("GlebPortrait", true, false)), "packed room instantiates Gleb portrait")
	_expect(room.get("_package_views").size() == 8 and not room.get("_package_views").P08.visible, "eighth package remains hidden before arrival")
	_expect(is_instance_valid(room.find_child("SerovPortrait", true, false)), "packed room instantiates Serov portrait")
	_expect(store.old_act.text.contains("2014"), "packed archive act is included")
	for id in Cases.LOOSE_FINDS:
		_expect(store.loose_finds[id].details.size() == 2, "packed find has two details: " + id)
		_expect(store.dispatch({"type":"MOVE_PACKAGE", "package_id":id, "destination":"desk"}).ok, "packed find moves: " + id)
		_expect(store.dispatch({"type":"OPEN_PACKAGE", "package_id":id}).ok, "packed find opens: " + id)
		_expect(store.dispatch({"type":"MOVE_PACKAGE", "package_id":id, "destination":"shelf"}).ok, "packed find returns: " + id)
	_expect(store.dispatch({"type":"READ_OLD_ACT"}).ok, "packed act can be read")
	_expect(store.dispatch({"type":"NEXT_CASE"}).ok and not room.get("_package_views").P08.visible, "packed bag waits for Nina")
	var arrival_deadline := Time.get_ticks_msec() + 3000
	while room.visitor_phase != "waiting" and Time.get_ticks_msec() < arrival_deadline:
		await process_frame
	_expect(room.visitor_phase == "waiting" and room.get("_package_views").P08.visible, "packed final bag arrives with Nina")
	for command in [{"type":"MOVE_PACKAGE","destination":"desk"}, {"type":"OPEN_PACKAGE"}]:
		_expect(store.dispatch(command).ok, "packed final bag " + command.type)
	var final_stage: Node3D = load("res://scenes/objects/inspection_stage.tscn").instantiate()
	final_stage.set_item("P08")
	main.add_child(final_stage)
	for id in Cases.get_case("finale").details:
		_expect(store.dispatch({"type":"INSPECT_DETAIL", "detail_id":id}).ok, "packed P08 evidence " + id)
		final_stage.focus_detail(id)
		_expect(final_stage.get_focus_id() == id, "packed P08 close-up " + id)
	_expect(store.dispatch({"type":"READ_DOCUMENT","document_id":"card"}).ok, "packed card is readable")
	_expect(store.dispatch({"type":"TAKE_CARD"}).ok and room.find_child("CardInHand",true,false).visible, "packed card can be held")
	_expect(store.dispatch({"type":"FILE_CARD"}).ok and room.find_child("ArchivedCard",true,false).visible, "packed card can be filed as a draft")
	_expect(store.dispatch({"type":"FINAL_ACTION","ending":"archive"}).ok and room.find_child("ArchivedCard",true,false).visible, "packed card can be archived")
	_expect(store.get_snapshot().card_location == "archive", "packed ending stores the single card destination")
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d exported-content checks." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
