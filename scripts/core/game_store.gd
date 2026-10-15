extends Node

signal state_changed(snapshot: Dictionary)
signal command_rejected(reason: String)

const Reducer = preload("res://scripts/core/state_reducer.gd")
var _state: Dictionary = Reducer.initial_state()
var content: Dictionary = {}

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/nina.json"))
	if parsed is Dictionary and _valid_content(parsed):
		content = parsed
	else:
		push_error("Контент первого обращения повреждён.")

func dispatch(command: Dictionary) -> Dictionary:
	var result: Dictionary = Reducer.apply_command(_state, command)
	if result.ok:
		_state = result.state.duplicate(true)
		state_changed.emit(get_snapshot())
	else:
		command_rejected.emit(result.error)
	return {"ok": result.ok, "error": result.error}

func get_snapshot() -> Dictionary:
	return _state.duplicate(true)

func _valid_content(value: Dictionary) -> bool:
	for group in ["documents", "details", "dialogues", "reactions"]:
		if not value.get(group) is Dictionary:
			return false
	for id in Reducer.DOCUMENT_IDS:
		if not _text_record(value.documents.get(id)):
			return false
	for id in Reducer.DETAIL_IDS:
		if not _text_record(value.details.get(id)):
			return false
	for id in ["greeting", "carrier", "old_room", "lunch"]:
		if not value.dialogues.get(id) is String:
			return false
	for id in ["issue", "retain", "appropriate"]:
		if not value.reactions.get(id) is String:
			return false
	return true

func _text_record(value: Variant) -> bool:
	return value is Dictionary and value.get("title") is String and value.get("text") is String
