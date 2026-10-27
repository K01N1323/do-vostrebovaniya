extends SceneTree

const Rules = preload("res://scripts/core/state_reducer.gd")
const Cases = preload("res://scripts/core/case_definitions.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _apply(state: Dictionary, command: Dictionary) -> Dictionary:
	var before := state.duplicate(true)
	var result: Dictionary = Rules.apply_command(state, command)
	_expect(state == before, "command does not mutate its input")
	_expect(result.get("ok", false), str(command) + " accepted: " + str(result.get("error", "missing result")))
	return result.get("state", before)

func _reject(state: Dictionary, command: Dictionary) -> void:
	var before := state.duplicate(true)
	var result: Dictionary = Rules.apply_command(state, command)
	_expect(result.get("ok", true) == false and not str(result.get("error", "")).is_empty(), str(command) + " rejected")
	_expect(result.get("state", {}) == before and state == before, "rejection keeps all three packages and history")

func _previous(nina: String, fedor: String) -> Dictionary:
	var state := _apply(Rules.initial_state(), {"type":"START"})
	for id in ["nina", "fedor"]:
		for command in [{"type":"READ_DOCUMENT","document_id":"identity"}, {"type":"READ_DOCUMENT","document_id":"claim"},
			{"type":"MOVE_PACKAGE","destination":"desk"}, {"type":"OPEN_PACKAGE"},
			{"type":"INSPECT_DETAIL","detail_id":"napkin" if id == "nina" else "paint"}]:
			state = _apply(state, command)
		state = _apply(state, {"type":nina if id == "nina" else fedor,"recipient":id})
		state = _apply(state, {"type":"NEXT_CASE"})
	return state

func _run() -> void:
	for nina in ["ISSUE_PACKAGE", "RETAIN_PACKAGE", "APPROPRIATE_PACKAGE"]:
		for fedor in ["ISSUE_PACKAGE", "RETAIN_PACKAGE", "APPROPRIATE_PACKAGE"]:
			for recipient in ["vera", "leonid", ""]:
				var state := _previous(nina, fedor)
				var history: Dictionary = state.completed_cases.duplicate(true)
				var packages: Dictionary = Rules.all_packages(state)
				_expect(state.case_id == "melnikovs" and state.package.id == "P03", "third case uses one P03")
				_expect(not state.package.unlocked and not state.package.lining_lifted and state.read_documents.is_empty(), "shared case starts locked and unverified")
				_reject(state, {"type":"READ_DOCUMENT","document_id":"identity"})
				_reject(state, {"type":"UNLOCK_PACKAGE","code":"246"})
				_reject(state, {"type":"LIFT_LINING"})
				state = _apply(state, {"type":"MOVE_PACKAGE","destination":"desk"})
				_reject(state, {"type":"OPEN_PACKAGE"})
				for code in ["000", "24", "2460", 246, null, [2,4,6]]:
					_reject(state, {"type":"UNLOCK_PACKAGE","code":code})
				state = _apply(state, {"type":"UNLOCK_PACKAGE","code":"246"})
				_reject(state, {"type":"UNLOCK_PACKAGE","code":"246"})
				state = _apply(state, {"type":"OPEN_PACKAGE"})
				_reject(state, {"type":"INSPECT_DETAIL","detail_id":"zipper"})
				_reject(state, {"type":"ASK_TOPIC","topic_id":"lining_story"})
				state = _apply(state, {"type":"INSPECT_DETAIL","detail_id":"green_stain"})
				for id in ["vera_identity", "vera_claim"]:
					state = _apply(state, {"type":"READ_DOCUMENT","document_id":id})
				_expect(not Rules.can_decide(state), "one claimant's papers cannot complete verification")
				state = _apply(state, {"type":"LIFT_LINING"})
				_reject(state, {"type":"LIFT_LINING"})
				state = _apply(state, {"type":"INSPECT_DETAIL","detail_id":"zipper"})
				state = _apply(state, {"type":"ASK_TOPIC","topic_id":"lining_story"})
				for id in ["leonid_identity", "leonid_claim"]:
					state = _apply(state, {"type":"READ_DOCUMENT","document_id":id})
				_expect(not Rules.can_decide(state), "guessing the code does not record Leonid's testimony")
				state = _apply(state, {"type":"ASK_TOPIC","topic_id":"lock_code"})
				_expect(Rules.can_decide(state), "both claimants' documents and evidence allow either recipient")
				for foreign in ["nina", "fedor", "melnikovs", "unknown", null, ["vera", "leonid"]]:
					_reject(state, {"type":"ISSUE_PACKAGE","recipient":foreign})
				_reject(state, {"type":"APPROPRIATE_PACKAGE"})
				state = _apply(state, {"type":"MOVE_PACKAGE","destination":"shelf"})
				_expect(state.case_status == "active" and state.package.lining_lifted, "thinking preserves lining knowledge and active status")
				_reject(state, {"type":"ISSUE_PACKAGE","recipient":"vera"})
				_reject(state, {"type":"ISSUE_PACKAGE","recipient":"leonid"})
				if not recipient.is_empty():
					state = _apply(state, {"type":"MOVE_PACKAGE","destination":"desk"})
					state = _apply(state, {"type":"ISSUE_PACKAGE","recipient":recipient})
				else:
					state = _apply(state, {"type":"RETAIN_PACKAGE"})
				_expect(state.recipient == recipient, "selected recipient is stored explicitly")
				_expect(Cases.outcome_key(state) == ("retain" if recipient.is_empty() else "issue_" + recipient), "reaction distinguishes two recipients")
				_expect(state.package.location == ("shelf" if recipient.is_empty() else "issued"), "P03 has exactly one resulting location")
				_expect(state.completed_cases == history, "third decision cannot rewrite first two cases")
				var final_packages: Dictionary = Rules.all_packages(state)
				_expect(final_packages.size() == 4 and final_packages.P01 == packages.P01 and final_packages.P02 == packages.P02, "previous package states are unchanged")
				_reject(state, {"type":"ISSUE_PACKAGE","recipient":"leonid" if recipient == "vera" else "vera"})
				var advanced := _apply(state, {"type":"NEXT_CASE"})
				_expect(advanced.case_id == "gleb" and advanced.completed_cases.melnikovs.recipient == recipient, "Gleb follows and preserves shared recipient")
				_expect(_apply(state, {"type":"RESTART"}) == Rules.initial_state(), "restart clears recipients and all history")
	for failure in failures:
		push_error(failure)
	print("%s: %d Melnikov rules checks, 27 triples of outcomes." % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
