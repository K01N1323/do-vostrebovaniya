extends Node

signal state_changed(snapshot: Dictionary)
signal command_rejected(reason: String)
signal save_failed(reason: String)

const Reducer = preload("res://scripts/core/state_reducer.gd")
const Saves = preload("res://scripts/core/save_repository.gd")
const Packages = preload("res://scripts/presentation/package_registry.gd")
const Cases = preload("res://scripts/core/case_definitions.gd")
var _state: Dictionary = Reducer.initial_state()
var content: Dictionary = {}
var loose_finds: Dictionary = {}
var old_act: Dictionary = {}
var clerk: Dictionary = {}

var save_path := "user://shift.json"
var preferences_path := "user://preferences.cfg"
var persistence_enabled := not OS.get_cmdline_args().has("--script")
var restoring := false
var _resume_view: Dictionary = {}
var _save_queued := false
var _catalog: Dictionary = {}

var content_errors := PackedStringArray()

func _ready() -> void:
	content_errors = Cases.catalog_errors()
	for id in Cases.ORDER:
		var path := "res://data/" + id + ".json"
		var parsed: Variant = _read_json(path)
		if parsed is Dictionary and _valid_content(parsed, id):
			_catalog[id] = parsed
		else:
			content_errors.append("Проверьте бумаги, реплики и портрет обращения " + id + " (" + path + ").")
		var definition := Cases.get_case(id)
		if not definition.is_empty():
			_check_package_resources(definition.package_id, definition.details)
	content = _catalog.get(_state.case_id, {})
	var finds: Variant = _read_json("res://data/loose_finds.json")
	for id in Cases.LOOSE_FINDS:
		_check_package_resources(id, Cases.LOOSE_FINDS[id])
		var record: Variant = finds.get(id) if finds is Dictionary else null
		if _valid_find(record, id):
			loose_finds[id] = record
		else:
			content_errors.append("Проверьте описание находки " + id + " в loose_finds.json.")
	var act: Variant = _read_json("res://data/old_act.json")
	if _text_record(act):
		old_act = act
	else:
		content_errors.append("Старый акт повреждён (old_act.json).")
	var clerk_record: Variant = _read_json("res://data/clerk.json")
	if _text_record(clerk_record) and _valid_portrait(clerk_record.get("portrait")):
		clerk = clerk_record
	else:
		content_errors.append("Проверьте удостоверение Павла и его фото (clerk.json).")
	for problem in content_errors:
		push_error(problem)

func _check_package_resources(id: String, details: Array) -> void:
	var scene_path: String = Packages.SCENES.get(id, "")
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		content_errors.append("Не найдена модель находки " + id + ".")
	var missing := Packages.missing_details(id, details)
	if not missing.is_empty():
		content_errors.append("Нет ракурса осмотра " + id + ": " + ", ".join(missing))

func _read_json(path: String) -> Variant:
	var parser := JSON.new()
	if not FileAccess.file_exists(path) or parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data

func _valid_find(record: Variant, id: String) -> bool:
	if not record is Dictionary or not record.get("presentation") is Dictionary or not record.get("details") is Dictionary:
		return false
	if not record.get("owner") is String:
		return false
	for key in ["package_title", "number", "overview"]:
		if not record.presentation.get(key) is String:
			return false
	for detail in Cases.LOOSE_FINDS[id]:
		if not _text_record(record.details.get(detail)):
			return false
	return true

func dispatch(command: Dictionary) -> Dictionary:
	if not content_errors.is_empty():
		return {"ok":false, "error":content_errors[0]}
	var result: Dictionary = Reducer.apply_command(_state, command)
	if result.ok:
		var changed: bool = _state != result.state
		if command.type in ["RESTART", "NEXT_CASE"]:
			_resume_view.clear()
		if changed:
			_set_state(result.state)
			_queue_save()
	else:
		command_rejected.emit(result.error)
	return {"ok": result.ok, "error": result.error}

func _set_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	content = _catalog.get(_state.case_id, {})
	state_changed.emit(get_snapshot())

func set_resume_view(view: Dictionary) -> void:
	if _resume_view != view:
		_resume_view = view.duplicate(true)
		_queue_save()

func read_saved_shift() -> Dictionary:
	return Saves.load_shift(save_path) if persistence_enabled else {}

func has_save_files() -> bool:
	return persistence_enabled and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"))

func continue_shift() -> Dictionary:
	var saved := read_saved_shift()
	if saved.is_empty():
		return {}
	restoring = true
	_resume_view = saved.view.duplicate(true)
	_set_state(saved.state)
	restoring = false
	return saved

func leave_shift() -> bool:
	if persistence_enabled and _state.started and not save_progress():
		return false
	_resume_view.clear()
	_set_state(Reducer.initial_state())
	return true

func restart_shift() -> bool:
	var empty := Reducer.initial_state()
	var fresh: Dictionary = Reducer.apply_command(empty, {"type":"START"}).state
	if persistence_enabled and not _write_progress(fresh, {}):
		return false
	_save_queued = false
	_resume_view.clear()
	_set_state(empty)
	_set_state(fresh)
	return true

func read_preferences() -> Dictionary:
	var config := ConfigFile.new()
	if persistence_enabled:
		config.load(preferences_path)
	return {
		"muted": config.get_value("gameplay", "muted", false) == true,
		"reduced_motion": config.get_value("gameplay", "reduced_motion", false) == true,
	}

func save_preferences(muted: bool, reduced_motion: bool) -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("gameplay", "muted", muted)
	config.set_value("gameplay", "reduced_motion", reduced_motion)
	if config.save(preferences_path) != OK:
		save_failed.emit("Настройки действуют в этой смене. Записать их не удалось.")

func save_progress() -> bool:
	_save_queued = false
	if not persistence_enabled or not _state.started:
		return false
	return _write_progress(_state, _resume_view)

func _write_progress(state: Dictionary, view: Dictionary) -> bool:
	var error := Saves.write_shift(save_path, state, view)
	if error != OK:
		save_failed.emit("Не удалось записать смену. Можно продолжать играть. (" + error_string(error) + ")")
	return error == OK

func _queue_save() -> void:
	if persistence_enabled and _state.started and not _save_queued:
		_save_queued = true
		_flush_autosave.call_deferred()

func _flush_autosave() -> void:
	if _save_queued:
		save_progress()

func get_snapshot() -> Dictionary:
	return _state.duplicate(true)

func get_case_content(case_id: String) -> Dictionary:
	return _catalog.get(case_id, {}).duplicate(true)

func _valid_content(value: Dictionary, case_id: String = "nina") -> bool:
	if not Cases.CASES.has(case_id):
		return false
	if case_id == "serov":
		if not value.get("waiting") is String or not value.get("camera_followup") is Dictionary:
			return false
		for outcome in Cases.outcome_ids("gleb"):
			if not value.camera_followup.get(outcome) is String:
				return false
	if case_id == "finale":
		if not value.get("comparison_note") is String or not _text_record(value.get("archive_supplement")) or not value.get("lunch_followup") is Dictionary:
			return false
		for outcome in Cases.outcome_ids("nina"):
			if not value.lunch_followup.get(outcome) is String:
				return false
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
	return _valid_portrait(value.presentation.portrait)

func _valid_portrait(path: Variant) -> bool:
	return path is String and path.begins_with("res://assets/characters/") and ResourceLoader.exists(path, "Texture2D")

func _text_record(value: Variant) -> bool:
	return value is Dictionary and value.get("title") is String and value.get("text") is String
