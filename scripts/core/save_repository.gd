extends RefCounted
## A save is a versioned shift plus the last open paper or inspection panel.

const Rules = preload("res://scripts/core/state_reducer.gd")
const Cases = preload("res://scripts/core/case_definitions.gd")
const FORMAT := 1

static func load_shift(path: String) -> Dictionary:
	var primary := _read(path)
	if not primary.is_empty():
		return primary
	var backup := _read(path + ".bak")
	if not backup.is_empty():
		backup.recovered = true
	return backup

static func write_shift(path: String, state: Dictionary, view: Dictionary) -> Error:
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return error
	var previous := _read(absolute)
	if not previous.is_empty() and previous.state == state and previous.view == view:
		return OK
	var temporary := absolute + ".tmp.%s" % OS.get_process_id()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"format":FORMAT, "state":state, "view":view}))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return error
	if not previous.is_empty():
		var backup_temporary := temporary + ".bak"
		error = DirAccess.copy_absolute(absolute, backup_temporary)
		if error == OK:
			error = DirAccess.rename_absolute(backup_temporary, absolute + ".bak")
		if error != OK:
			DirAccess.remove_absolute(temporary)
			DirAccess.remove_absolute(backup_temporary)
			return error
	error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		DirAccess.remove_absolute(temporary)
	return error

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 262144:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var record: Variant = parser.data
	if not record is Dictionary or record.get("format") != FORMAT:
		return {}
	var state: Variant = record.get("state")
	if not state is Dictionary or not Rules.is_valid_snapshot(state):
		return {}
	state.version = int(state.version)
	if not state.has("preview_finds"):
		state.preview_finds = {}
	for case_record in state.completed_cases.values():
		case_record.version = int(case_record.version)
	var view: Variant = record.get("view")
	return {"state":state, "view":view if view is Dictionary and _valid_view(view, state) else {}, "recovered":false}

static func _valid_view(view: Dictionary, state: Dictionary) -> bool:
	var id: Variant = view.get("id", "")
	if not id is String:
		return false
	match view.get("kind", ""):
		"document":
			return id == "clerk_identity" or id == "old_act" and state.old_act_read or state.case_status == "active" and id in state.read_documents
		"comparison":
			if state.case_status != "active":
				return false
			if state.case_id == "finale":
				return id == "card" and "card" in state.read_documents
			if state.case_id == "melnikovs" and id in ["vera", "leonid"]:
				return id + "_identity" in state.read_documents and id + "_claim" in state.read_documents
			return id.is_empty() and state.read_documents.size() == Cases.get_case(state.case_id).documents.size()
		"inspection":
			if id == "P08" and state.card_location != "bag":
				return false
			var item: Dictionary = state.package if id == state.package.id else Rules.auxiliary_item(state, id)
			if item.is_empty() or item.location != "desk" or not item.opened:
				return false
			var zoom: Variant = view.get("zoom_step", 0)
			if not (zoom is int or zoom is float) or zoom < 0 or zoom > 6 or zoom != floorf(zoom):
				return false
			var detail: Variant = view.get("detail", "")
			var details: Array = Cases.LOOSE_FINDS.get(id, Cases.get_case(state.case_id if id == state.package.id else Cases.future_case(state.case_id, id)).get("details", []))
			return detail is String and (detail.is_empty() or detail in details and (detail != "zipper" or item.get("lining_lifted", false)))
		"archive_draft":
			return state.case_id == "finale" and state.card_location == "archive_draft"
		"ending":
			return state.case_id == "finale" and state.case_status == "resolved"
	return view.is_empty()
