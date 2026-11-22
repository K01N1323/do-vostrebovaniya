extends "res://tests/melnikov_rules.gd"
## Fourth-case verification cannot decide ownership or overwrite earlier choices.

func _before_gleb(nina: String, fedor: String, recipient: String) -> Dictionary:
	var state := _previous(nina, fedor)
	for id in Cases.get_case("melnikovs").documents:
		state = _apply(state, {"type":"READ_DOCUMENT", "document_id":id})
	for command in [{"type":"ASK_TOPIC","topic_id":"lock_code"}, {"type":"MOVE_PACKAGE","destination":"desk"},
		{"type":"UNLOCK_PACKAGE","code":"246"}, {"type":"OPEN_PACKAGE"},
		{"type":"INSPECT_DETAIL","detail_id":"green_stain"}, {"type":"LIFT_LINING"},
		{"type":"INSPECT_DETAIL","detail_id":"zipper"}]:
		state = _apply(state, command)
	state = _apply(state, {"type":"RETAIN_PACKAGE"} if recipient.is_empty() else {"type":"ISSUE_PACKAGE","recipient":recipient})
	return _apply(state, {"type":"NEXT_CASE"})

func _run() -> void:
	var locations := {"ISSUE_PACKAGE":"issued", "RETAIN_PACKAGE":"shelf", "APPROPRIATE_PACKAGE":"personal"}
	for nina in locations:
		for fedor in locations:
			for recipient in ["vera", "leonid", ""]:
				var initial := _before_gleb(nina, fedor, recipient)
				var history: Dictionary = initial.completed_cases.duplicate(true)
				var packages: Dictionary = Rules.all_packages(initial)
				_expect(initial.case_id == "gleb" and initial.package.id == "P04" and history.size() == 3, "fourth case follows all three histories")
				_expect(initial.read_documents.is_empty() and initial.inspected_details.is_empty() and initial.asked_topics.is_empty(), "new claimant has no inherited verification")
				_expect(history.melnikovs.recipient == recipient, "shared suitcase recipient survives Gleb arrival")
				_reject(initial, {"type":"ASK_TOPIC", "topic_id":"body_mismatch"})
				_reject(initial, {"type":"ASK_TOPIC", "topic_id":"film_mismatch"})
				_reject(initial, {"type":"UNLOCK_PACKAGE", "code":"246"})
				_reject(initial, {"type":"READ_DOCUMENT", "document_id":"vera_claim"})
				for choice in locations:
					var state := initial.duplicate(true)
					for command in [{"type":"ASK_TOPIC","topic_id":"repair"}, {"type":"READ_DOCUMENT","document_id":"identity"},
						{"type":"READ_DOCUMENT","document_id":"claim"}, {"type":"MOVE_PACKAGE","destination":"desk"},
						{"type":"OPEN_PACKAGE"}]:
						state = _apply(state, command)
					_expect(not Rules.finished_checking(state), "a genuine ID and matching name do not replace physical inspection")
					state = _apply(state, {"type":"INSPECT_DETAIL","detail_id":"camera_body"})
					state = _apply(state, {"type":"ASK_TOPIC","topic_id":"body_mismatch"})
					state = _apply(state, {"type":"INSPECT_DETAIL","detail_id":"strap"})
					_expect(not Rules.finished_checking(state), "camera alone does not finish inspection of the whole claim")
					_expect(Rules.apply_command(state, {"type":choice, "recipient":"gleb"}).ok, "incomplete check still permits a deliberate choice")
					state = _apply(state, {"type":"INSPECT_DETAIL","detail_id":"onions"})
					state = _apply(state, {"type":"ASK_TOPIC","topic_id":"film_mismatch"})
					_expect(Rules.finished_checking(state), "contradictory evidence permits an explicit decision without a moral lock")
					_reject(state, {"type":"ISSUE_PACKAGE","recipient":"leonid"})
					state = _apply(state, {"type":"MOVE_PACKAGE","destination":"shelf"})
					_expect(state.case_status == "active" and state.inspected_details.size() == 3, "thinking preserves all three observations")
					state = _apply(state, {"type":choice, "recipient":"gleb"})
					_expect(state.package.location == locations[choice] and state.case_status == "resolved", "P04 has one outcome for " + choice)
					_expect(state.recipient == ("gleb" if choice == "ISSUE_PACKAGE" else ""), "recipient is claimant, not a rewritten owner")
					_expect(state.completed_cases == history, "fourth choice keeps all earlier stories byte-for-byte")
					var final: Dictionary = Rules.all_packages(state)
					_expect(final.size() == 7 and final.P01 == packages.P01 and final.P02 == packages.P02 and final.P03 == packages.P03, "four independent package locations survive all 81 routes")
					_reject(state, {"type":"ISSUE_PACKAGE","recipient":"gleb"})
					var serov := _apply(state, {"type":"NEXT_CASE"})
					_expect(serov.case_id == "serov" and serov.completed_cases.gleb.package == final.P04, "Serov follows Gleb with the exact bag outcome")
					_expect(_apply(state, {"type":"RESTART"}) == Rules.initial_state(), "restart clears the four-case shift")
	for failure in failures:
		push_error(failure)
	print("%s: %d Gleb rules checks, 81 combinations of four-case outcomes." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
