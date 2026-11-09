extends "res://tests/gleb_rules.gd"
## Check each coat outcome against all 81 possible earlier histories.

const CHOICES := {"ISSUE_PACKAGE":"issued", "RETAIN_PACKAGE":"shelf", "APPROPRIATE_PACKAGE":"personal"}

func _run() -> void:
	_check_loose_finds()
	_check_future_finds()
	for nina in CHOICES:
		for fedor in CHOICES:
			for melnikov in ["vera", "leonid", ""]:
				for gleb in CHOICES:
					var state := _before_gleb(nina, fedor, melnikov)
					state = _ready_case(state, "camera_body")
					for id in ["strap", "onions"]:
						state = _apply(state, {"type":"INSPECT_DETAIL", "detail_id":id})
					state = _apply(state, {"type":gleb, "recipient":"gleb"})
					state = _apply(state, {"type":"NEXT_CASE"})
					_check_coat(state)
	for failure in failures:
		push_error(failure)
	print("%s: %d Serov and loose-find checks across 243 complete shifts." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check_future_finds() -> void:
	var state := _apply(Rules.initial_state(), {"type":"START"})
	_expect(Rules.auxiliary_packages(state).keys().size() == 6, "all seven early finds are accessible")
	_reject(state, {"type":"MOVE_PACKAGE", "package_id":"P08", "destination":"desk"})
	state = _apply(state, {"type":"MOVE_PACKAGE", "package_id":"P03", "destination":"desk"})
	_reject(state, {"type":"MOVE_PACKAGE", "package_id":"P02", "destination":"desk"})
	_reject(state, {"type":"OPEN_PACKAGE", "package_id":"P03"})
	state = _apply(state, {"type":"UNLOCK_PACKAGE", "package_id":"P03", "code":"246"})
	state = _apply(state, {"type":"OPEN_PACKAGE", "package_id":"P03"})
	_reject(state, {"type":"INSPECT_DETAIL", "package_id":"P03", "detail_id":"zipper"})
	state = _apply(state, {"type":"LIFT_LINING", "package_id":"P03"})
	state = _apply(state, {"type":"INSPECT_DETAIL", "package_id":"P03", "detail_id":"zipper"})
	_expect(state.inspected_details.is_empty() and Rules.is_valid_snapshot(state), "early observations belong only to the previewed find")
	state = _apply(state, {"type":"MOVE_PACKAGE", "package_id":"P03", "destination":"shelf"})
	for detail in ["napkin", "paint"]:
		state = _ready_case(state, detail)
		_reject(state, {"type":"RETAIN_PACKAGE", "package_id":"P03"})
		state = _apply(state, {"type":"RETAIN_PACKAGE"})
		state = _apply(state, {"type":"NEXT_CASE"})
	_expect(state.package.id == "P03" and state.package.lining_lifted and state.inspected_details == ["zipper"], "early lock and evidence carry into the correct claim")
	_expect(not state.preview_finds.has("P03") and not Rules.can_decide(state), "preview becomes one active item and cannot skip the claim")
	_expect(Rules.is_valid_snapshot(state), "promoted state remains valid for saves")

func _ready_case(state: Dictionary, detail: String) -> Dictionary:
	for command in [{"type":"READ_DOCUMENT", "document_id":"identity"}, {"type":"READ_DOCUMENT", "document_id":"claim"},
		{"type":"MOVE_PACKAGE", "destination":"desk"}, {"type":"OPEN_PACKAGE"}, {"type":"INSPECT_DETAIL", "detail_id":detail}]:
		state = _apply(state, command)
	return state

func _check_coat(state: Dictionary) -> void:
	_expect(state.case_id == "serov" and state.package.id == "P05", "Serov follows Gleb")
	_expect(not Rules.serov_waits_for_bus(state), "Serov begins at the window")
	_reject(state, {"type":"ASK_TOPIC", "topic_id":"tag"})
	var history: Dictionary = state.completed_cases.duplicate(true)
	var packages := Rules.all_packages(state)
	state = _ready_case(state, "coat_tag")
	state = _apply(state, {"type":"ASK_TOPIC", "topic_id":"tag"})
	_expect(not Rules.can_decide(state), "a label alone does not establish ownership")
	for id in ["coat_pockets", "coat_cuff", "coat_reversed"]:
		state = _apply(state, {"type":"INSPECT_DETAIL", "detail_id":id})
	_expect(not Rules.can_decide(state), "the past and trip remain unheard")
	for id in ["past", "trip"]:
		state = _apply(state, {"type":"ASK_TOPIC", "topic_id":id})
	_expect(Rules.can_decide(state), "verified coat is ready for all decisions")
	_reject(state, {"type":"ISSUE_PACKAGE", "recipient":"gleb"})
	for choice in CHOICES:
		var resolved := _apply(state, {"type":choice, "recipient":"serov"})
		_expect(resolved.package.location == CHOICES[choice] and Rules.serov_waits_for_bus(resolved), "Serov catches the same bus after " + choice)
		_expect(resolved.completed_cases == history, "coat outcome keeps all previous records")
		var final := Rules.all_packages(resolved)
		for id in ["P01", "P02", "P03", "P04", "P06", "P07"]:
			_expect(final[id] == packages[id], "coat outcome preserves " + id)
		_reject(resolved, {"type":"ISSUE_PACKAGE", "recipient":"serov"})
		_reject(resolved, {"type":"NEXT_CASE"})
		_expect(_apply(resolved, {"type":"RESTART"}) == Rules.initial_state(), "restart clears Serov and the five cases")

func _check_loose_finds() -> void:
	var state := _apply(Rules.initial_state(), {"type":"START"})
	for id in Cases.LOOSE_FINDS:
		_reject(state, {"type":"OPEN_PACKAGE", "package_id":id})
		state = _apply(state, {"type":"MOVE_PACKAGE", "package_id":id, "destination":"desk"})
		_expect(Rules.desk_package_id(state) == id, "only " + id + " is on the desk")
		_reject(state, {"type":"MOVE_PACKAGE", "destination":"desk"})
		_reject(state, {"type":"MOVE_PACKAGE", "package_id":id, "destination":"personal"})
		_reject(state, {"type":"ISSUE_PACKAGE", "recipient":"nina", "package_id":id})
		state = _apply(state, {"type":"OPEN_PACKAGE", "package_id":id})
		_reject(state, {"type":"INSPECT_DETAIL", "package_id":id, "detail_id":"sandwiches"})
		for detail in Cases.LOOSE_FINDS[id]:
			state = _apply(state, {"type":"INSPECT_DETAIL", "package_id":id, "detail_id":detail})
		state = _apply(state, {"type":"MOVE_PACKAGE", "package_id":id, "destination":"shelf"})
		_expect(state.loose_finds[id].inspected_details == Cases.LOOSE_FINDS[id], "observations survive storage")
	_expect(state.inspected_details.is_empty(), "loose finds do not produce claim evidence")
	state = _apply(state, {"type":"READ_OLD_ACT"})
	state = _ready_case(state, "sandwiches")
	_reject(state, {"type":"MOVE_PACKAGE", "package_id":"P06", "destination":"desk"})
	state = _apply(state, {"type":"RETAIN_PACKAGE"})
	var loose: Dictionary = state.loose_finds.duplicate(true)
	state = _apply(state, {"type":"NEXT_CASE"})
	_expect(state.old_act_read and state.loose_finds == loose, "change of visitor preserves archive and independent finds")
