extends "res://tests/serov_rules.gd"
## The choice of what to do with the card is independent of the coat.

func _run() -> void:
	var state := _before_gleb("APPROPRIATE_PACKAGE", "APPROPRIATE_PACKAGE", "leonid")
	_expect(not Rules.all_packages(state).has("P08"), "no P08 before the later arrival")
	state = _ready_case(state, "camera_body")
	for detail in ["strap", "onions"]:
		state = _apply(state, {"type":"INSPECT_DETAIL", "detail_id":detail})
	state = _apply(state, {"type":"APPROPRIATE_PACKAGE"})
	state = _apply(state, {"type":"NEXT_CASE"})
	state = _ready_case(state, "coat_tag")
	for detail in ["coat_pockets", "coat_cuff", "coat_reversed"]:
		state = _apply(state, {"type":"INSPECT_DETAIL", "detail_id":detail})
	for topic in ["past", "trip"]:
		state = _apply(state, {"type":"ASK_TOPIC", "topic_id":topic})
	for choice in CHOICES:
		_check_endings(_apply(state, {"type":choice, "recipient":"serov"}), CHOICES[choice])
	for failure in failures:
		push_error(failure)
	print("%s: %d finale checks across all nine combinations of coat and card outcomes." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check_endings(serov: Dictionary, coat_place: String) -> void:
	_expect(serov.card_location.is_empty() and not Rules.all_packages(serov).has("P08"), "P08 is still absent when the coat is resolved")
	_reject(serov, {"type":"NEXT_CASE"})
	var state := _apply(serov, {"type":"READ_OLD_ACT"})
	state = _apply(state, {"type":"NEXT_CASE"})
	_expect(state.case_id == "finale" and state.card_location == "bag" and Rules.all_packages(state).size() == 8, "the bag brings the only card")
	_expect(state.old_act_read and state.completed_cases.serov.package.location == coat_place and Rules.serov_waits_for_bus(state), "coat and archive history survive Nina's arrival")
	_reject(state, {"type":"READ_DOCUMENT","document_id":"card"})
	_reject(state, {"type":"FINAL_ACTION","ending":"serov"})
	state = _apply(state, {"type":"MOVE_PACKAGE","destination":"desk"})
	state = _apply(state, {"type":"OPEN_PACKAGE"})
	_reject(state, {"type":"READ_DOCUMENT","document_id":"card"})
	state = _apply(state, {"type":"INSPECT_DETAIL","detail_id":"card"})
	state = _apply(state, {"type":"READ_DOCUMENT","document_id":"card"})
	_expect(not Rules.can_decide(state), "only reading the card leaves the bag unchecked")
	for detail in ["shirt", "ticket", "pass"]:
		state = _apply(state, {"type":"INSPECT_DETAIL","detail_id":detail})
	_expect(Rules.can_decide(state), "all three endings are ready")
	_reject(state, {"type":"RETAIN_PACKAGE"})
	_reject(state, {"type":"APPROPRIATE_PACKAGE"})
	_reject(state, {"type":"FINAL_ACTION","ending":"archive"})
	state = _apply(state, {"type":"TAKE_CARD"})
	_expect(state.card_location == "hand" and Rules.is_valid_snapshot(state), "verified card can be held and saved")
	_reject(state, {"type":"MOVE_PACKAGE","destination":"shelf"})
	_reject(state, {"type":"TAKE_CARD"})
	_reject(state, {"type":"FINAL_ACTION","ending":"none"})
	_reject(state, {"type":"FINAL_ACTION","ending":"archive"})
	var draft := _apply(state, {"type":"FILE_CARD"})
	_expect(draft.card_location == "archive_draft" and Rules.is_valid_snapshot(draft), "unsigned archive stage can be saved")
	_reject(draft, {"type":"FINAL_ACTION","ending":"serov"})
	_reject(draft, {"type":"FINAL_ACTION","ending":"keep"})
	_expect(_apply(draft, {"type":"RETURN_CARD"}).card_location == "bag", "the archive draft can be undone")
	_expect(_apply(state, {"type":"RETURN_CARD"}).card_location == "bag", "holding the card can be undone")
	for ending in Cases.ENDINGS:
		var prepared := draft if ending == "archive" else state
		var final := _apply(prepared, {"type":"FINAL_ACTION","ending":ending})
		_expect(final.case_status == "resolved" and final.decision == ending, "selected ending is recorded")
		_expect(final.card_location == ("bag" if ending == "keep" else ending), "the card has one destination")
		_expect(final.package.location == ("personal" if ending == "keep" else "shelf"), "bag remains a separate find")
		_expect(final.completed_cases == state.completed_cases and Rules.all_packages(final).P05.location == coat_place, "the ending preserves the earlier decisions and the coat")
		_expect(not Rules.can_decide(final), "ending closes final decisions")
		_reject(final, {"type":"FINAL_ACTION","ending":"archive"})
		_reject(final, {"type":"NEXT_CASE"})
