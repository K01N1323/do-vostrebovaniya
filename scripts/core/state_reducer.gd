class_name StateReducer
extends RefCounted

const DOCUMENT_IDS: Array[String] = ["identity", "claim"]
const ITEM_ACTIONS := ["MOVE_PACKAGE", "OPEN_PACKAGE", "UNLOCK_PACKAGE", "LIFT_LINING", "INSPECT_DETAIL"]
const Cases = preload("res://scripts/core/case_definitions.gd")

static func initial_state() -> Dictionary:
	return {
		"version": 1, "started": false, "case_id": "nina", "case_status": "active",
		"package": Cases.initial_package("nina"),
		"read_documents": [], "inspected_details": [], "asked_topics": [],
		"dialogue_id": "greeting", "decision": "", "recipient": "", "completed_cases": {},
		"loose_finds": {
			"P06": {"id": "P06", "location": "shelf", "opened": false, "inspected_details": []},
			"P07": {"id": "P07", "location": "shelf", "opened": false, "inspected_details": []},
		},
		"preview_finds": {}, "old_act_read": false, "card_location": ""
	}

static func apply_command(state: Dictionary, command: Dictionary) -> Dictionary:
	if not command.get("type") is String:
		return _reject(state, "В команде не указано действие.")
	var kind: String = command.type
	if kind == "RESTART":
		return _accept(initial_state())
	if kind == "START":
		if state.started:
			return _reject(state, "Смена уже началась.")
		var started_state: Dictionary = state.duplicate(true)
		started_state.started = true
		return _accept(started_state)
	if not state.started:
		return _reject(state, "Сначала начните смену.")
	if kind == "READ_OLD_ACT":
		var reading := state.duplicate(true)
		reading.old_act_read = true
		return _accept(reading)
	if kind == "CLOSE_SHIFT":
		if state.case_id != "finale" or state.case_status != "resolved" or state.get("shift_closed", false):
			return _reject(state, "Закрыть бюро можно после решения о карточке.")
		var closed := state.duplicate(true)
		closed.shift_closed = true
		return _accept(closed)
	if command.has("package_id"):
		if kind in ITEM_ACTIONS:
			return _apply_auxiliary_find(state, command)
		return _reject(state, "Находка без заявителя доступна только для осмотра и хранения.")
	if kind == "DEFER_GLEB":
		if state.case_id != "gleb" or state.case_status != "active":
			return _reject(state, "Отложить можно только открытое обращение Глеба.")
		var deferred := _case_record(state)
		deferred.package.location = "shelf"
		var advanced := _advance_case(state)
		advanced.deferred_gleb = deferred
		return _accept(advanced)
	if kind == "HEAR_ORLOV" or kind == "RESOLVE_DEFERRED_GLEB":
		return _update_deferred_gleb(state, command)
	if kind == "NEXT_CASE":
		if state.case_status != "resolved":
			return _reject(state, "Сначала завершите текущее обращение.")
		if state.case_id == "serov" and not state.old_act_read:
			return _reject(state, "Прочитайте акт 2014 года в архивной папке.")
		if state.has("deferred_gleb"):
			return _reject(state, "Закройте отложенное обращение по камере.")
		if not Cases.has_next(state.case_id):
			return _reject(state, "Этот фрагмент смены завершён.")
		var advanced := _advance_case(state)
		advanced.completed_cases[state.case_id] = _case_record(state)
		return _accept(advanced)
	if state.case_status != "active":
		return _reject(state, "Обращение уже завершено.")
	var next: Dictionary = state.duplicate(true)
	var definition: Dictionary = Cases.get_case(state.case_id)
	if kind in ITEM_ACTIONS:
		if state.case_id == "finale" and kind == "MOVE_PACKAGE" and state.card_location != "bag":
			return _reject(state, "Сначала верните карточку в сумку или передайте её.")
		var error := _apply_item_action(next.package, next.inspected_details, definition, command, not desk_package_id(state).is_empty())
		return _accept(next) if error.is_empty() else _reject(state, error)
	match kind:
		"READ_DOCUMENT":
			var document: Variant = command.get("document_id")
			if not document is String or document not in definition.documents:
				return _reject(state, "Таких бумаг в обращении нет.")
			if document == "card" and (next.package.location != "desk" or "card" not in next.inspected_details):
				return _reject(state, "Найдите карточку во внутреннем кармане сумки.")
			if document not in next.read_documents:
				next.read_documents.append(document)
		"ASK_TOPIC":
			var topic: Variant = command.get("topic_id")
			if not topic is String or topic not in definition.topics:
				return _reject(state, "Такого вопроса нет.")
			if definition.topic_requires.has(topic) and definition.topic_requires[topic] not in next.inspected_details:
				return _reject(state, "Сначала осмотрите содержимое.")
			if topic not in next.asked_topics:
				next.asked_topics.append(topic)
			next.dialogue_id = topic
		"TAKE_CARD":
			if state.case_id != "finale" or state.card_location != "bag" or not can_decide(state):
				return _reject(state, "Прежде чем взять карточку, осмотрите сумку и сверьте бумаги.")
			next.card_location = "hand"
		"FILE_CARD":
			if state.case_id != "finale" or state.card_location != "hand":
				return _reject(state, "Сначала возьмите карточку.")
			next.card_location = "archive_draft"
		"RETURN_CARD":
			if state.case_id != "finale" or state.card_location not in ["hand", "archive_draft"]:
				return _reject(state, "Карточка уже в сумке.")
			next.card_location = "bag"
		"FINAL_ACTION":
			var ending: Variant = command.get("ending")
			if state.case_id != "finale" or ending not in Cases.ENDINGS or not can_decide(state):
				return _reject(state, "Сверьте акт с карточкой и осмотрите сумку на столе.")
			var required_place := "archive_draft" if ending == "archive" else "hand"
			if state.card_location != required_place:
				return _reject(state, "Сначала возьмите карточку и подготовьте передачу.")
			if ending == "serov" and not serov_waits_for_bus(state):
				return _reject(state, "Серов ещё не ждёт у выхода на посадку.")
			next.card_location = "bag" if ending == "keep" else ending
			next.package.location = "personal" if ending == "keep" else "shelf"
			next.decision = ending
			next.case_status = "resolved"
			next.dialogue_id = "reaction"
		"ISSUE_PACKAGE", "RETAIN_PACKAGE", "APPROPRIATE_PACKAGE":
			if state.case_id == "finale":
				return _reject(state, "Решение по сумке принимается вместе с решением о карточке.")
			if kind == "APPROPRIATE_PACKAGE" and not definition.allow_appropriate:
				return _reject(state, "В этом обращении выберите получателя или хранение.")
			if kind == "ISSUE_PACKAGE":
				if command.get("recipient") not in definition.recipients:
					return _reject(state, "Для выдачи укажите заявителя текущего обращения.")
				var handling: Variant = command.get("handling", "")
				if handling not in ["", "steady", "jolted"] or (handling != "" and state.case_id not in ["nina", "melnikovs"]) or (handling == "jolted" and state.case_id != "nina"):
					return _reject(state, "Неизвестное состояние переноски.")
				if handling != "":
					next.handling = handling
				next.package.location = "issued"
				next.decision = "issue"
				next.recipient = command.recipient
			elif kind == "RETAIN_PACKAGE":
				next.package.location = "shelf"
				next.decision = "retain"
			else:
				next.package.location = "personal"
				next.decision = "appropriate"
			next.case_status = "resolved"
			next.dialogue_id = "reaction"
		_:
			return _reject(state, "Неизвестное действие.")
	return _accept(next)

static func _case_record(state: Dictionary) -> Dictionary:
	var record := state.duplicate(true)
	for key in ["completed_cases", "loose_finds", "preview_finds", "old_act_read", "card_location", "deferred_gleb", "orlov_heard"]:
		record.erase(key)
	return record

static func _advance_case(state: Dictionary) -> Dictionary:
	var advanced := initial_state()
	advanced.started = true
	advanced.completed_cases = state.completed_cases.duplicate(true)
	advanced.loose_finds = state.loose_finds.duplicate(true)
	advanced.preview_finds = state.get("preview_finds", {}).duplicate(true)
	advanced.old_act_read = state.old_act_read
	advanced.case_id = Cases.ORDER[Cases.ORDER.find(state.case_id) + 1]
	advanced.package = Cases.initial_package(advanced.case_id)
	var preview: Dictionary = advanced.preview_finds.get(advanced.package.id, {})
	if not preview.is_empty():
		advanced.preview_finds.erase(preview.id)
		advanced.inspected_details = preview.inspected_details
		preview.erase("inspected_details")
		advanced.package = preview
	if advanced.case_id == "finale":
		advanced.card_location = "bag"
	return advanced

static func _update_deferred_gleb(state: Dictionary, command: Dictionary) -> Dictionary:
	if state.case_id != "serov" or not state.has("deferred_gleb"):
		return _reject(state, "Отложенного обращения по камере нет.")
	var next := state.duplicate(true)
	if command.type == "HEAR_ORLOV":
		next.orlov_heard = true
		return _accept(next)
	if not state.get("orlov_heard", false):
		return _reject(state, "Сначала ответьте на звонок Орлова.")
	var decision: Variant = command.get("decision")
	if decision not in ["issue", "retain", "appropriate"]:
		return _reject(state, "Выберите судьбу камеры.")
	var record: Dictionary = next.deferred_gleb
	record.decision = decision
	record.recipient = "gleb" if decision == "issue" else ""
	record.case_status = "resolved"
	record.dialogue_id = "reaction"
	record.after_orlov_call = true
	record.package.location = {"issue":"issued", "retain":"shelf", "appropriate":"personal"}[decision]
	next.completed_cases.gleb = record
	next.erase("deferred_gleb")
	next.erase("orlov_heard")
	return _accept(next)

static func _apply_item_action(item: Dictionary, inspected: Array, definition: Dictionary, command: Dictionary, desk_occupied: bool) -> String:
	match command.type:
		"MOVE_PACKAGE":
			var destination: Variant = command.get("destination")
			if destination not in ["desk", "shelf"]:
				return "Выберите стол или полку."
			if item.location not in ["desk", "shelf"]:
				return "Вещь уже недоступна."
			if item.location == destination:
				return "Вещь уже на этом месте."
			if destination == "desk" and desk_occupied:
				return "Сначала верните находку со стола на полку."
			item.location = destination
		"OPEN_PACKAGE":
			if item.location != "desk":
				return "Сначала поставьте вещь на стол."
			if item.opened:
				return "Содержимое уже открыто."
			if definition.has("lock_code") and not item.get("unlocked", false):
				return "Сначала откройте кодовый замок."
			item.opened = true
		"UNLOCK_PACKAGE":
			if not definition.has("lock_code") or item.location != "desk":
				return "Кодовый замок доступен у чемодана на столе."
			if item.unlocked:
				return "Замок уже открыт."
			var code: Variant = command.get("code")
			if not code is String or code != definition.lock_code:
				return "Замок не открылся. Проверьте три цифры."
			item.unlocked = true
		"LIFT_LINING":
			if not item.has("lining_lifted") or item.location != "desk" or not item.opened:
				return "Подкладка доступна внутри открытого чемодана на столе."
			if item.lining_lifted:
				return "Подкладка уже приподнята."
			item.lining_lifted = true
		"INSPECT_DETAIL":
			var detail: Variant = command.get("detail_id")
			if not detail is String or detail not in definition.details:
				return "Такого признака нет."
			if item.location != "desk" or not item.opened:
				return "Откройте вещь на столе."
			if detail == "zipper" and not item.get("lining_lifted", false):
				return "Сначала приподнимите подкладку."
			if detail not in inspected:
				inspected.append(detail)
	return ""

static func _apply_auxiliary_find(state: Dictionary, command: Dictionary) -> Dictionary:
	var id: Variant = command.package_id
	if not id is String:
		return _reject(state, "Такой находки нет.")
	var item := auxiliary_item(state, id)
	if item.is_empty():
		return _reject(state, "Эта находка сейчас недоступна для отдельного осмотра.")
	item = item.duplicate(true)
	var loose := Cases.LOOSE_FINDS.has(id)
	var deferred: bool = id == "P04" and state.has("deferred_gleb")
	var definition := {"details":Cases.LOOSE_FINDS[id]} if loose else Cases.get_case("gleb" if deferred else Cases.future_case(state.case_id, id))
	var error := _apply_item_action(item, item.inspected_details, definition, command, not desk_package_id(state).is_empty())
	if not error.is_empty():
		return _reject(state, error)
	var next := state.duplicate(true)
	if loose:
		next.loose_finds[id] = item
	elif deferred:
		next.deferred_gleb.inspected_details = item.inspected_details
		item.erase("inspected_details")
		next.deferred_gleb.package = item
	else:
		if not next.has("preview_finds"):
			next.preview_finds = {}
		next.preview_finds[id] = item
	return _accept(next)

static func auxiliary_item(state: Dictionary, id: String) -> Dictionary:
	if state.loose_finds.has(id):
		return state.loose_finds[id]
	if id == "P04" and state.has("deferred_gleb"):
		var deferred: Dictionary = state.deferred_gleb.package.duplicate(true)
		deferred.inspected_details = state.deferred_gleb.inspected_details.duplicate()
		return deferred
	var future := Cases.future_case(state.case_id, id)
	if future.is_empty():
		return {}
	if state.get("preview_finds", {}).has(id):
		return state.preview_finds[id]
	var item := Cases.initial_package(future)
	item.inspected_details = []
	return item

static func auxiliary_packages(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.loose_finds.duplicate()
	if state.has("deferred_gleb"):
		result.P04 = auxiliary_item(state, "P04")
	for id in Cases.ORDER.slice(Cases.ORDER.find(state.case_id) + 1):
		if id == "finale":
			continue
		var package_id: String = Cases.CASES[id].package_id
		result[package_id] = auxiliary_item(state, package_id)
	return result

static func desk_package_id(state: Dictionary) -> String:
	if state.package.location == "desk":
		return state.package.id
	for item in auxiliary_packages(state).values():
		if item.location == "desk":
			return item.id
	return ""

static func serov_waits_for_bus(state: Dictionary) -> bool:
	return (state.case_id == "serov" and state.case_status == "resolved") or state.completed_cases.has("serov")

static func can_decide(state: Dictionary) -> bool:
	if not state.started or state.case_status != "active":
		return false
	if state.case_id != "finale":
		return true
	return state.old_act_read and state.package.location == "desk" and finished_checking(state)

static func finished_checking(state: Dictionary) -> bool:
	if not state.package.opened or state.inspected_details.is_empty():
		return false
	var definition: Dictionary = Cases.get_case(state.case_id)
	for id in definition.documents:
		if id not in state.read_documents:
			return false
	for id in definition.get("required_details", []):
		if id not in state.inspected_details:
			return false
	for id in definition.get("required_topics", []):
		if state.case_id == "melnikovs" and id == "lock_code" and "leonid_alone" in state.asked_topics:
			continue
		if id not in state.asked_topics:
			return false
	return true

static func all_packages(state: Dictionary) -> Dictionary:
	# Active package and archived cases each own one state. This is a derived view.
	var result: Dictionary = {}
	for id in Cases.ORDER:
		if id != "finale":
			var package_id: String = Cases.get_case(id).package_id
			result[package_id] = Cases.initial_package(id)
	for record in state.get("completed_cases", {}).values():
		result[record.package.id] = record.package.duplicate(true)
	result.merge(auxiliary_packages(state).duplicate(true), true)
	result[state.package.id] = state.package.duplicate(true)
	return result

static func _reject(state: Dictionary, reason: String) -> Dictionary:
	return {"ok": false, "state": state.duplicate(true), "error": reason}

static func _accept(state: Dictionary) -> Dictionary:
	return {"ok": true, "state": state, "error": ""}

static func is_valid_snapshot(state: Dictionary) -> bool:
	if state.get("version") != 1 or state.get("started") != true or not state.get("old_act_read") is bool:
		return false
	if not state.get("case_id") is String or not state.get("completed_cases") is Dictionary or not state.get("loose_finds") is Dictionary:
		return false
	var index := Cases.ORDER.find(state.case_id)
	var deferred: Variant = state.get("deferred_gleb")
	if state.has("deferred_gleb"):
		if state.case_id != "serov" or not deferred is Dictionary or not _valid_case_record(deferred, "gleb"):
			return false
		if deferred.case_status != "active" or not state.get("orlov_heard", false) is bool:
			return false
	elif state.has("orlov_heard"):
		return false
	if index < 0 or state.completed_cases.size() != index - int(deferred != null) or not _valid_case_record(state, state.case_id):
		return false
	for prior in Cases.ORDER.slice(0, index):
		if prior == "gleb" and deferred != null:
			continue
		var record: Variant = state.completed_cases.get(prior)
		if not record is Dictionary or record.get("case_status") != "resolved" or not _valid_case_record(record, prior):
			return false
	if state.loose_finds.size() != Cases.LOOSE_FINDS.size():
		return false
	var desk_items: int = int(state.package.location == "desk")
	if deferred != null:
		desk_items += int(deferred.package.location == "desk")
	for id in Cases.LOOSE_FINDS:
		var item: Variant = state.loose_finds.get(id)
		if not item is Dictionary or item.get("id") != id or item.get("location") not in ["desk", "shelf"] or not item.get("opened") is bool:
			return false
		if not _valid_ids(item.get("inspected_details"), Cases.LOOSE_FINDS[id]) or (not item.opened and not item.inspected_details.is_empty()):
			return false
		desk_items += int(item.location == "desk")
	var previews: Variant = state.get("preview_finds", {})
	if not previews is Dictionary:
		return false
	for id in previews:
		if not id is String:
			return false
		var future := Cases.future_case(state.case_id, id)
		var item: Variant = previews[id]
		if future.is_empty() or not item is Dictionary or item.get("location") not in ["desk", "shelf"]:
			return false
		if not _valid_package_record(item, Cases.CASES[future], item.get("inspected_details")):
			return false
		desk_items += int(item.location == "desk")
	if desk_items > 1:
		return false
	if state.case_id != "finale":
		return state.get("card_location") == "" and not state.has("shift_closed")
	if state.has("shift_closed") and (state.shift_closed != true or state.case_status != "resolved"):
		return false
	if not state.old_act_read:
		return false
	var card: Variant = state.get("card_location")
	if state.case_status == "active":
		return card == "bag" or (card in ["hand", "archive_draft"] and can_decide(state))
	return card == ("bag" if state.decision == "keep" else state.decision)

static func _valid_case_record(record: Dictionary, case_id: String) -> bool:
	var definition := Cases.get_case(case_id)
	if record.get("version") != 1 or record.get("started") != true or record.get("case_id") != case_id:
		return false
	var item: Variant = record.get("package")
	if not _valid_package_record(item, definition, record.get("inspected_details")):
		return false
	if not _valid_ids(record.get("read_documents"), definition.documents) or not _valid_ids(record.get("asked_topics"), definition.topics):
		return false
	for topic in record.asked_topics:
		if definition.topic_requires.has(topic) and definition.topic_requires[topic] not in record.inspected_details:
			return false
	if case_id == "finale" and "card" in record.read_documents and "card" not in record.inspected_details:
		return false
	var status: Variant = record.get("case_status")
	var decision: Variant = record.get("decision")
	var recipient: Variant = record.get("recipient")
	if not decision is String or not recipient is String or status not in ["active", "resolved"]:
		return false
	if record.has("after_orlov_call") and (case_id != "gleb" or status != "resolved" or record.after_orlov_call != true):
		return false
	if record.has("handling") and (case_id not in ["nina", "melnikovs"] or decision != "issue" or record.handling not in ["steady", "jolted"] or (record.handling == "jolted" and case_id != "nina")):
		return false
	if status == "active":
		return decision.is_empty() and recipient.is_empty() and item.get("location") in ["desk", "shelf"] and (record.get("dialogue_id") == "greeting" or record.get("dialogue_id") in record.asked_topics)
	if record.get("dialogue_id") != "reaction":
		return false
	if case_id == "finale":
		return finished_checking(record) and decision in Cases.ENDINGS and recipient.is_empty() and item.get("location") == ("personal" if decision == "keep" else "shelf")
	match decision:
		"issue":
			return recipient in definition.recipients and item.get("location") == "issued"
		"retain":
			return recipient.is_empty() and item.get("location") == "shelf"
		"appropriate":
			return definition.allow_appropriate and recipient.is_empty() and item.get("location") == "personal"
	return false

static func _valid_package_record(item: Variant, definition: Dictionary, inspected: Variant) -> bool:
	if not item is Dictionary or item.get("id") != definition.package_id or not item.get("opened") is bool:
		return false
	if not _valid_ids(inspected, definition.details) or (not item.opened and not inspected.is_empty()):
		return false
	if definition.has("lock_code"):
		if not item.get("unlocked") is bool or not item.get("lining_lifted") is bool:
			return false
		if item.opened and not item.unlocked or item.lining_lifted and not item.opened or "zipper" in inspected and not item.lining_lifted:
			return false
	return true

static func _valid_ids(value: Variant, allowed: Array) -> bool:
	if not value is Array or value.size() > allowed.size():
		return false
	var found := {}
	for id in value:
		if not id is String or id not in allowed or found.has(id):
			return false
		found[id] = true
	return true
