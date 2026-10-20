extends Node

signal state_changed(snapshot: Dictionary)
signal command_rejected(reason: String)

const Reducer = preload("res://scripts/core/state_reducer.gd")
const Cases = preload("res://scripts/core/case_definitions.gd")
var _state: Dictionary = Reducer.initial_state()
var content: Dictionary = {}
var _catalog: Dictionary = {}

func _ready() -> void:
	for id in Cases.ORDER:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + id + ".json"))
		if parsed is Dictionary and _valid_content(parsed, id):
			_catalog[id] = parsed
		else:
			push_error("Контент обращения повреждён: " + id)
	content = _catalog.get(_state.case_id, {})

func dispatch(command: Dictionary) -> Dictionary:
	var result: Dictionary = Reducer.apply_command(_state, command)
	if result.ok:
		_state = result.state.duplicate(true)
		content = _catalog.get(_state.case_id, {})
		state_changed.emit(get_snapshot())
	else:
		command_rejected.emit(result.error)
	return {"ok": result.ok, "error": result.error}

func get_snapshot() -> Dictionary:
	return _state.duplicate(true)

func get_case_content(case_id: String) -> Dictionary:
	return _catalog.get(case_id, {}).duplicate(true)

func _valid_content(value: Dictionary, case_id: String = "nina") -> bool:
	var definition: Dictionary = Cases.get_case(case_id)
	for group in ["documents", "document_labels", "details", "dialogues", "reactions", "presentation", "topic_labels"]:
		if not value.get(group) is Dictionary:
			return false
	for id in definition.documents:
		if not _text_record(value.documents.get(id)):
			return false
		if not value.get("document_labels", {}).get(id) is String:
			return false
	for id in definition.details:
		if not _text_record(value.details.get(id)):
			return false
	for id in ["greeting"] + definition.topics:
		if not value.dialogues.get(id) is String:
			return false
	for id in Cases.outcome_ids(case_id):
		if not value.reactions.get(id) is String:
			return false
	if not value.presentation.get("outcomes") is Dictionary:
		return false
	if not value.presentation.get("recipient_captions") is Dictionary:
		return false
	for id in Cases.outcome_ids(case_id):
		if not value.presentation.outcomes.get(id) is String:
			return false
	for key in ["name", "first_name", "talk_hint", "number", "package_title", "item_accusative", "item_nominative", "overview", "issue_caption", "appropriate_caption", "document_header", "identity_seal", "portrait"]:
		if not value.get("presentation", {}).get(key) is String:
			return false
	for id in definition.topics:
		if not value.get("topic_labels", {}).get(id) is String:
			return false
	for recipient in definition.recipients:
		if not value.presentation.get("recipient_captions", {}).get(recipient) is String:
			return false
	return true

func _text_record(value: Variant) -> bool:
	return value is Dictionary and value.get("title") is String and value.get("text") is String
