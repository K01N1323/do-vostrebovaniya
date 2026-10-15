extends SceneTree

const Reducer = preload("res://scripts/core/state_reducer.gd")
const StoreScript = preload("res://scripts/core/game_store.gd")

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_initial_state_and_start()
	_test_bad_commands()
	_test_package_and_knowledge_rules()
	_test_decision_prerequisites()
	_test_issue()
	_test_retain()
	_test_appropriate()
	_test_restart()
	_test_snapshot_independence()
	_test_store_boundary()
	if _failures.is_empty():
		print("PASS: %d checks; Nina state rules verified." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: %d failures / %d checks" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _accept(state: Dictionary, command: Dictionary, label: String) -> Dictionary:
	var before := state.duplicate(true)
	var result: Dictionary = Reducer.apply_command(state, command)
	_expect(state == before, label + ": input state stays unchanged")
	_expect(result.has("ok") and result.has("state") and result.has("error"), label + ": result contract")
	_expect(result.get("ok", false) == true, label + ": command accepted (%s)" % result.get("error", "no error field"))
	_expect(result.get("error") == "", label + ": no error on success")
	_expect(result.get("state") is Dictionary, label + ": output state is Dictionary")
	if result.get("state") is Dictionary:
		return result["state"]
	return before


func _reject(state: Dictionary, command: Dictionary, label: String) -> void:
	var before := state.duplicate(true)
	var result: Dictionary = Reducer.apply_command(state, command)
	_expect(result.get("ok", true) == false, label + ": command rejected")
	_expect(state == before, label + ": input state stays unchanged")
	_expect(result.get("state") == before, label + ": rejection preserves progress")
	_expect(result.get("error") is String and not str(result.get("error", "")).is_empty(), label + ": error explains rejection")


func _started() -> Dictionary:
	return _accept(Reducer.initial_state(), {"type": "START"}, "start case")


func _ready(detail_id: String = "sandwiches") -> Dictionary:
	var state := _started()
	state = _accept(state, {"type": "READ_DOCUMENT", "document_id": "identity"}, "read identity")
	state = _accept(state, {"type": "READ_DOCUMENT", "document_id": "claim"}, "read claim")
	state = _accept(state, {"type": "MOVE_PACKAGE", "destination": "desk"}, "put package on desk")
	state = _accept(state, {"type": "OPEN_PACKAGE"}, "open package")
	return _accept(state, {"type": "INSPECT_DETAIL", "detail_id": detail_id}, "inspect " + detail_id)


func _reject_all_decisions(state: Dictionary, label: String) -> void:
	_reject(state, {"type": "ISSUE_PACKAGE", "recipient": "nina"}, label + ": issue")
	_reject(state, {"type": "RETAIN_PACKAGE"}, label + ": retain")
	_reject(state, {"type": "APPROPRIATE_PACKAGE"}, label + ": appropriate")


func _test_initial_state_and_start() -> void:
	var initial: Dictionary = Reducer.initial_state()
	_expect(initial.get("version") == 1, "initial: schema version")
	_expect(initial.get("started") == false, "initial: title screen before START")
	_expect(initial.get("case_id") == "nina", "initial: Nina case")
	_expect(initial.get("case_status") == "active", "initial: active case")
	_expect(initial.get("package", {}).get("id") == "P01", "initial: package identity")
	_expect(initial.get("package", {}).get("location") == "shelf", "initial: package on shelf")
	_expect(initial.get("package", {}).get("opened") == false, "initial: package closed")
	_expect(initial.get("read_documents") == [], "initial: no papers read")
	_expect(initial.get("inspected_details") == [], "initial: no details seen")
	_expect(initial.get("asked_topics") == [], "initial: no questions asked")
	_expect(initial.get("decision") == "", "initial: no decision")
	for command in [
		{"type": "MOVE_PACKAGE", "destination": "desk"},
		{"type": "OPEN_PACKAGE"},
		{"type": "INSPECT_DETAIL", "detail_id": "sandwiches"},
		{"type": "READ_DOCUMENT", "document_id": "identity"},
		{"type": "ASK_TOPIC", "topic_id": "carrier"},
		{"type": "ISSUE_PACKAGE", "recipient": "nina"},
		{"type": "RETAIN_PACKAGE"},
		{"type": "APPROPRIATE_PACKAGE"},
	]:
		_reject(initial, command, "before START: " + command["type"])
	var state := _accept(initial, {"type": "START"}, "START")
	_expect(state.get("started") == true, "START enters case")


func _test_bad_commands() -> void:
	var state := _started()
	for command in [
		{}, {"type": ""}, {"type": "UNKNOWN"}, {"type": 12}, {"type": null},
		{"type": "MOVE_PACKAGE"}, {"type": "MOVE_PACKAGE", "destination": "issued"},
		{"type": "MOVE_PACKAGE", "destination": "personal"}, {"type": "MOVE_PACKAGE", "destination": []},
		{"type": "READ_DOCUMENT"}, {"type": "READ_DOCUMENT", "document_id": "archive"},
		{"type": "READ_DOCUMENT", "document_id": "../../identity"}, {"type": "READ_DOCUMENT", "document_id": 12},
		{"type": "INSPECT_DETAIL"}, {"type": "INSPECT_DETAIL", "detail_id": "unknown"},
		{"type": "ASK_TOPIC"}, {"type": "ASK_TOPIC", "topic_id": "unknown"},
		{"type": "ASK_TOPIC", "topic_id": 12},
	]:
		_reject(state, command, "malformed or unknown: " + str(command))
	var ready := _ready()
	_reject(ready, {"type": "ISSUE_PACKAGE"}, "issue requires recipient")
	_reject(ready, {"type": "ISSUE_PACKAGE", "recipient": "unknown"}, "issue recipient whitelist")
	_reject(ready, {"type": "INSPECT_DETAIL", "detail_id": "unknown"}, "detail whitelist at desk")
	_reject(ready, {"type": "INSPECT_DETAIL", "detail_id": 12}, "detail identifier must be text")
	_reject(ready, {"type": "READ_DOCUMENT", "document_id": "invented"}, "document whitelist after prerequisites")
	_reject(ready, {"type": "READ_DOCUMENT", "document_id": {}}, "document identifier must be text")


func _test_package_and_knowledge_rules() -> void:
	var state := _started()
	_reject(state, {"type": "OPEN_PACKAGE"}, "cannot open package on shelf")
	_reject(state, {"type": "INSPECT_DETAIL", "detail_id": "sandwiches"}, "cannot inspect on shelf")
	_reject(state, {"type": "ASK_TOPIC", "topic_id": "lunch"}, "lunch requires observed sandwiches")
	state = _accept(state, {"type": "ASK_TOPIC", "topic_id": "carrier"}, "carrier available initially")
	state = _accept(state, {"type": "ASK_TOPIC", "topic_id": "old_room"}, "old room available initially")
	state = _accept(state, {"type": "MOVE_PACKAGE", "destination": "desk"}, "move shelf to desk")
	_expect(state["package"]["location"] == "desk", "desk is sole package location")
	_reject(state, {"type": "INSPECT_DETAIL", "detail_id": "sandwiches"}, "cannot inspect closed package")
	state = _accept(state, {"type": "OPEN_PACKAGE"}, "open at desk")
	state = _accept(state, {"type": "INSPECT_DETAIL", "detail_id": "saucer"}, "saucer inspection")
	_reject(state, {"type": "ASK_TOPIC", "topic_id": "lunch"}, "other detail does not unlock lunch")
	state = _accept(state, {"type": "INSPECT_DETAIL", "detail_id": "napkin"}, "napkin inspection")
	state = _accept(state, {"type": "INSPECT_DETAIL", "detail_id": "sandwiches"}, "sandwich inspection")
	state = _accept(state, {"type": "ASK_TOPIC", "topic_id": "lunch"}, "sandwiches unlock lunch")
	_expect(state["asked_topics"].has("lunch"), "lunch knowledge recorded")
	state = _accept(state, {"type": "MOVE_PACKAGE", "destination": "shelf"}, "move opened package back to shelf")
	_expect(state["package"]["location"] == "shelf", "shelf is sole package location")
	_expect(state["case_status"] == "active" and state["decision"] == "", "moving to shelf does not resolve case")
	_reject(state, {"type": "INSPECT_DETAIL", "detail_id": "napkin"}, "opened package cannot be inspected on shelf")


func _test_decision_prerequisites() -> void:
	var state := _started()
	_reject_all_decisions(state, "no evidence")
	state = _accept(state, {"type": "MOVE_PACKAGE", "destination": "desk"}, "prerequisites: desk")
	state = _accept(state, {"type": "READ_DOCUMENT", "document_id": "identity"}, "prerequisites: identity")
	state = _accept(state, {"type": "READ_DOCUMENT", "document_id": "claim"}, "prerequisites: claim")
	_reject_all_decisions(state, "package unopened")
	state = _accept(state, {"type": "OPEN_PACKAGE"}, "prerequisites: open")
	_reject_all_decisions(state, "no inspected detail")
	for missing_id in ["identity", "claim"]:
		var partial := _started()
		partial = _accept(partial, {"type": "READ_DOCUMENT", "document_id": "claim" if missing_id == "identity" else "identity"}, "one paper read")
		partial = _accept(partial, {"type": "MOVE_PACKAGE", "destination": "desk"}, "missing paper: desk")
		partial = _accept(partial, {"type": "OPEN_PACKAGE"}, "missing paper: open")
		partial = _accept(partial, {"type": "INSPECT_DETAIL", "detail_id": "saucer"}, "missing paper: inspected detail")
		_reject_all_decisions(partial, "missing " + missing_id)
	var shelf := _ready("napkin")
	shelf = _accept(shelf, {"type": "MOVE_PACKAGE", "destination": "shelf"}, "ready package to shelf")
	_expect(shelf["case_status"] == "active", "fully examined package on shelf remains active")
	_reject(shelf, {"type": "ISSUE_PACKAGE", "recipient": "nina"}, "issue requires desk")
	_reject(shelf, {"type": "APPROPRIATE_PACKAGE"}, "appropriation requires desk")


func _check_resolved(state: Dictionary, decision: String, location: String) -> void:
	_expect(state["decision"] == decision, decision + ": decision recorded")
	_expect(state["case_status"] == "resolved", decision + ": case resolved")
	_expect(state["package"]["location"] == location, decision + ": sole final package location")
	for command in [
		{"type": "START"}, {"type": "MOVE_PACKAGE", "destination": "desk"},
		{"type": "OPEN_PACKAGE"}, {"type": "INSPECT_DETAIL", "detail_id": "sandwiches"},
		{"type": "READ_DOCUMENT", "document_id": "identity"}, {"type": "ASK_TOPIC", "topic_id": "carrier"},
		{"type": "ISSUE_PACKAGE", "recipient": "nina"}, {"type": "RETAIN_PACKAGE"}, {"type": "APPROPRIATE_PACKAGE"},
	]:
		_reject(state, command, decision + ": resolved case rejects " + command["type"])


func _test_issue() -> void:
	var state := _ready()
	state = _accept(state, {"type": "ISSUE_PACKAGE", "recipient": "nina"}, "issue to Nina")
	_check_resolved(state, "issue", "issued")


func _test_retain() -> void:
	var state := _ready("saucer")
	state = _accept(state, {"type": "RETAIN_PACKAGE"}, "retain from desk")
	_check_resolved(state, "retain", "shelf")
	var shelf := _ready("napkin")
	shelf = _accept(shelf, {"type": "MOVE_PACKAGE", "destination": "shelf"}, "retain setup on shelf")
	shelf = _accept(shelf, {"type": "RETAIN_PACKAGE"}, "retain from shelf")
	_check_resolved(shelf, "retain", "shelf")


func _test_appropriate() -> void:
	var state := _ready("napkin")
	state = _accept(state, {"type": "APPROPRIATE_PACKAGE"}, "appropriate from desk")
	_check_resolved(state, "appropriate", "personal")


func _test_restart() -> void:
	for decision in ["ISSUE_PACKAGE", "RETAIN_PACKAGE", "APPROPRIATE_PACKAGE"]:
		var state := _ready()
		state = _accept(state, {"type": "ASK_TOPIC", "topic_id": "lunch"}, "restart setup: lunch")
		var command := {"type": decision}
		if decision == "ISSUE_PACKAGE":
			command["recipient"] = "nina"
		state = _accept(state, command, "restart setup: " + decision)
		state = _accept(state, {"type": "RESTART"}, "restart after " + decision)
		_expect(state == Reducer.initial_state(), "RESTART restores complete initial state after " + decision)
		state = _accept(state, {"type": "START"}, "start again after " + decision)
		_expect(state["started"] == true and state["case_status"] == "active", "restarted case can be played")
	var active := _ready()
	active = _accept(active, {"type": "RESTART"}, "restart active case")
	_expect(active == Reducer.initial_state(), "RESTART resets active progress")


func _test_snapshot_independence() -> void:
	var first: Dictionary = Reducer.initial_state()
	var second: Dictionary = Reducer.initial_state()
	first["package"]["location"] = "desk"
	first["read_documents"].append("identity")
	_expect(second["package"]["location"] == "shelf", "initial nested dictionaries are independent")
	_expect(second["read_documents"].is_empty(), "initial arrays are independent")
	var source := _started()
	var result := _accept(source, {"type": "MOVE_PACKAGE", "destination": "desk"}, "independence: move")
	result["package"]["opened"] = true
	result["read_documents"].append("identity")
	result["inspected_details"].append("sandwiches")
	result["asked_topics"].append("lunch")
	_expect(source["package"]["location"] == "shelf" and source["package"]["opened"] == false, "successful state deeply copies package")
	_expect(source["read_documents"].is_empty(), "successful state deeply copies documents")
	_expect(source["inspected_details"].is_empty(), "successful state deeply copies inspected details")
	_expect(source["asked_topics"].is_empty(), "successful state deeply copies asked topics")
	source["package"]["location"] = "personal"
	_expect(result["package"]["location"] == "desk", "mutating earlier snapshot cannot affect later snapshot")


func _test_store_boundary() -> void:
	var store = StoreScript.new()
	root.add_child(store)
	var changes: Array[Dictionary] = []
	var rejections: Array[String] = []
	store.state_changed.connect(func(snapshot: Dictionary) -> void: changes.append(snapshot))
	store.command_rejected.connect(func(reason: String) -> void: rejections.append(reason))
	var response: Dictionary = store.dispatch({"type": "START"})
	_expect(response.get("ok") == true and response.get("error") == "", "GameStore dispatch success contract")
	_expect(changes.size() == 1 and rejections.is_empty(), "GameStore success emits one state change")
	var snapshot: Dictionary = store.get_snapshot()
	snapshot["package"]["location"] = "personal"
	snapshot["read_documents"].append("identity")
	var unchanged: Dictionary = store.get_snapshot()
	_expect(unchanged["package"]["location"] == "shelf", "get_snapshot isolates package mutations")
	_expect(unchanged["read_documents"].is_empty(), "get_snapshot isolates array mutations")
	if changes.size() == 1:
		changes[0]["package"]["opened"] = true
		changes[0]["asked_topics"].append("lunch")
		unchanged = store.get_snapshot()
		_expect(unchanged["package"]["opened"] == false, "state_changed isolates package mutations")
		_expect(unchanged["asked_topics"].is_empty(), "state_changed isolates array mutations")
	response = store.dispatch({"type": "OPEN_PACKAGE"})
	_expect(response.get("ok") == false and response.get("error") is String, "GameStore dispatch rejection contract")
	_expect(changes.size() == 1 and rejections.size() == 1, "GameStore rejection emits no state change")
	_expect(store.get_snapshot() == unchanged, "GameStore rejected action preserves progress")
	_expect(store.content.get("documents", {}).has("identity"), "GameStore loads Nina document content")
	store.free()
