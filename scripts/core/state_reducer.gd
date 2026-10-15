class_name StateReducer
extends RefCounted

const DOCUMENT_IDS: Array[String] = ["identity", "claim"]
const DETAIL_IDS: Array[String] = ["sandwiches", "saucer", "napkin"]
const TOPIC_IDS: Array[String] = ["carrier", "old_room", "lunch"]

static func initial_state() -> Dictionary:
	return {
		"version": 1, "started": false, "case_id": "nina", "case_status": "active",
		"package": {"id": "P01", "location": "shelf", "opened": false},
		"read_documents": [], "inspected_details": [], "asked_topics": [],
		"dialogue_id": "greeting", "decision": ""
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
	if state.case_status != "active":
		return _reject(state, "Обращение уже завершено.")
	var next: Dictionary = state.duplicate(true)
	match kind:
		"MOVE_PACKAGE":
			var destination: Variant = command.get("destination")
			if destination not in ["desk", "shelf"]:
				return _reject(state, "Выберите стол или полку.")
			if next.package.location not in ["desk", "shelf"]:
				return _reject(state, "Переноска уже недоступна.")
			if next.package.location == destination:
				return _reject(state, "Переноска уже на этом месте.")
			next.package.location = destination
		"OPEN_PACKAGE":
			if next.package.location != "desk":
				return _reject(state, "Сначала поставьте переноску на стол.")
			if next.package.opened:
				return _reject(state, "Переноска уже открыта.")
			next.package.opened = true
		"INSPECT_DETAIL":
			var detail: Variant = command.get("detail_id")
			if not detail is String or detail not in DETAIL_IDS:
				return _reject(state, "Такого признака нет.")
			if next.package.location != "desk" or not next.package.opened:
				return _reject(state, "Откройте переноску на столе.")
			if detail not in next.inspected_details:
				next.inspected_details.append(detail)
		"READ_DOCUMENT":
			var document: Variant = command.get("document_id")
			if not document is String or document not in DOCUMENT_IDS:
				return _reject(state, "Таких бумаг в обращении нет.")
			if document not in next.read_documents:
				next.read_documents.append(document)
		"ASK_TOPIC":
			var topic: Variant = command.get("topic_id")
			if not topic is String or topic not in TOPIC_IDS:
				return _reject(state, "Такого вопроса нет.")
			if topic == "lunch" and "sandwiches" not in next.inspected_details:
				return _reject(state, "Сначала осмотрите содержимое.")
			if topic not in next.asked_topics:
				next.asked_topics.append(topic)
			next.dialogue_id = topic
		"ISSUE_PACKAGE", "RETAIN_PACKAGE", "APPROPRIATE_PACKAGE":
			if not can_decide(state):
				return _reject(state, "Прочтите обе бумаги и осмотрите содержимое переноски.")
			if kind != "RETAIN_PACKAGE" and next.package.location != "desk":
				return _reject(state, "Сначала поставьте переноску на стол.")
			if kind == "ISSUE_PACKAGE":
				if command.get("recipient") != "nina":
					return _reject(state, "Для выдачи укажите Нину Лукину.")
				next.package.location = "issued"
				next.decision = "issue"
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

static func can_decide(state: Dictionary) -> bool:
	return state.started and state.case_status == "active" \
		and "identity" in state.read_documents and "claim" in state.read_documents \
		and state.package.opened and not state.inspected_details.is_empty()

static func _reject(state: Dictionary, reason: String) -> Dictionary:
	return {"ok": false, "state": state.duplicate(true), "error": reason}

static func _accept(state: Dictionary) -> Dictionary:
	return {"ok": true, "state": state, "error": ""}
