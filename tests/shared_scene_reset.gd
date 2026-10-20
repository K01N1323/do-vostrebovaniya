extends SceneTree
const Rules = preload("res://scripts/core/state_reducer.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _run() -> void:
	var state: Dictionary = Rules.apply_command(Rules.initial_state(),{"type":"START"}).state
	for id in ["nina","fedor"]:
		for command in [{"type":"READ_DOCUMENT","document_id":"identity"},{"type":"READ_DOCUMENT","document_id":"claim"},
			{"type":"MOVE_PACKAGE","destination":"desk"},{"type":"OPEN_PACKAGE"},
			{"type":"INSPECT_DETAIL","detail_id":"napkin" if id == "nina" else "paint"},{"type":"RETAIN_PACKAGE"},{"type":"NEXT_CASE"}]:
			state = Rules.apply_command(state,command).state
	for command in [{"type":"MOVE_PACKAGE","destination":"desk"},{"type":"UNLOCK_PACKAGE","code":"246"},{"type":"OPEN_PACKAGE"},{"type":"LIFT_LINING"}]:
		state = Rules.apply_command(state,command).state
	var before := state.duplicate(true)
	var room: Node3D = load("res://scenes/room/room.tscn").instantiate()
	root.add_child(room)
	room.reduced_motion = true
	room.apply_snapshot(state)
	room.set_view("desk")
	var suitcase: Node3D = room.get("_package_views").P03
	_expect(suitcase.unlocked and suitcase.lining_lifted and suitcase.opened,"fresh room restores the active shared-case flags")
	_expect(room.find_children("Target_P03","StaticBody3D",true,false).size() == 1,"room owns one P03")
	room.apply_snapshot(Rules.initial_state())
	_expect(not suitcase.unlocked and not suitcase.lining_lifted and not suitcase.opened,"restart resets inactive suitcase flags visually")
	_expect(suitcase.get("_numbers")[0].text == "0" and suitcase.get("_numbers")[2].text == "0","restart resets visible combination wheels")
	_expect(suitcase.get_node("Target_P03").collision_layer == 0,"future package cannot be picked in Nina case")
	room.apply_snapshot(state)
	room.set_view("desk")
	_expect(suitcase.unlocked and suitcase.lining_lifted and suitcase.opened,"reapplying snapshot restores flags again")
	_expect(suitcase.get("_numbers")[0].text == "2" and suitcase.get("_numbers")[2].text == "6","restored combination matches unlocked state")
	_expect(state == before,"projection and restart do not mutate snapshot history")
	room.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d shared-case scene reset checks." % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
