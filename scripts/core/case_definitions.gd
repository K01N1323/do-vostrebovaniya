extends RefCounted
## Rules and stable IDs. Prose and captions live in data/<case>.json.

const ORDER: Array[String] = ["nina", "fedor", "melnikovs", "gleb", "serov", "finale"]
const CASES := {
	"nina": {"package_id": "P01", "owners": ["nina"], "documents": ["identity", "claim"], "recipients": ["nina"], "allow_appropriate": true,
		"details": ["sandwiches", "saucer", "napkin"],
		"topics": ["carrier", "old_room", "lunch"], "topic_requires": {"lunch": "sandwiches"}},
	"fedor": {"package_id": "P02", "owners": ["fedor"], "documents": ["identity", "claim"], "recipients": ["fedor"], "allow_appropriate": true,
		"details": ["corner", "paint", "collar"],
		"topics": ["house", "work", "blue_paint"], "topic_requires": {"blue_paint": "paint"}},
	"melnikovs": {"package_id": "P03", "owners": ["vera", "leonid"], "documents": ["vera_identity", "vera_claim", "leonid_identity", "leonid_claim"],
		"recipients": ["vera", "leonid"], "allow_appropriate": false, "lock_code": "246",
		"details": ["combination", "green_stain", "zipper"], "required_details": ["green_stain", "zipper"], "required_topics": ["lock_code"],
		"topics": ["journey", "lock_code", "parting", "lining_story", "vera_alone", "leonid_alone"], "topic_requires": {"lining_story": "zipper"}},
	"gleb": {"package_id": "P04", "owners": ["orlov"], "documents": ["identity", "claim"], "recipients": ["gleb"], "allow_appropriate": true,
		"details": ["camera_body", "strap", "onions"], "required_details": ["camera_body", "strap", "onions"],
		"topics": ["repair", "work", "contents_probe", "show_contents", "body_mismatch", "film_mismatch"],
		"topic_requires": {"body_mismatch": "camera_body", "film_mismatch": "onions", "show_contents": "onions"}},
	"serov": {"package_id": "P05", "owners": ["serov"], "documents": ["identity", "claim"], "recipients": ["serov"], "allow_appropriate": true,
		"details": ["coat_tag", "coat_pockets", "coat_cuff", "coat_reversed"],
		"required_details": ["coat_tag", "coat_pockets", "coat_cuff", "coat_reversed"],
		"required_topics": ["past", "trip"], "topics": ["coat", "past", "trip", "tag"],
		"topic_requires": {"tag": "coat_tag"}},
	"finale": {"package_id": "P08", "owners": ["pavel"], "documents": ["card"], "recipients": [], "allow_appropriate": false,
		"details": ["shirt", "ticket", "pass", "card"], "required_details": ["shirt", "ticket", "pass", "card"],
		"topics": [], "topic_requires": {}}
}

const ENDINGS: Array[String] = ["serov", "archive", "keep"]

const LOOSE_FINDS := {
	"P06": ["case_interior", "lens_cap"],
	"P07": ["remote_bundle", "battery_bays"],
}

static func get_case(case_id: String) -> Dictionary:
	return CASES.get(case_id, {}).duplicate(true)

static func future_case(current: String, package_id: String) -> String:
	for id in ORDER.slice(ORDER.find(current) + 1):
		if id != "finale" and CASES[id].package_id == package_id:
			return id
	return ""

static func has_next(case_id: String) -> bool:
	var index := ORDER.find(case_id)
	return index >= 0 and index < ORDER.size() - 1

static func initial_package(case_id: String) -> Dictionary:
	var definition := get_case(case_id)
	var item := {"id": definition.package_id, "location": "shelf", "opened": false}
	if definition.has("lock_code"):
		item.unlocked = false
		item.lining_lifted = false
	return item

static func outcome_ids(case_id: String) -> Array[String]:
	if case_id == "finale":
		return ENDINGS.duplicate()
	var definition := get_case(case_id)
	var ids: Array[String] = []
	for recipient in definition.recipients:
		ids.append("issue_" + recipient if definition.recipients.size() > 1 else "issue")
	ids.append("retain")
	if definition.allow_appropriate:
		ids.append("appropriate")
	return ids

static func outcome_key(state: Dictionary) -> String:
	if state.decision == "issue" and get_case(state.case_id).recipients.size() > 1:
		return "issue_" + state.get("recipient", "")
	return state.decision

static func catalog_errors(order: Array = ORDER, cases: Dictionary = CASES) -> PackedStringArray:
	var errors := PackedStringArray()
	if order.is_empty() or not _unique_ids(order) or order.size() != cases.size() or order.back() != "finale":
		errors.append("Порядок обращений содержит повтор или недостижимое событие.")
	var packages := LOOSE_FINDS.keys()
	for id in order:
		if not cases.has(id):
			errors.append("В порядке смены указано неизвестное обращение: " + str(id))
			continue
		var definition: Dictionary = cases[id]
		packages.append(definition.package_id)
		for field in ["owners", "documents", "recipients", "details", "topics"]:
			if not _unique_ids(definition[field]):
				errors.append(str(id) + ": повтор или пустой идентификатор в " + field)
		for field in ["required_topics", "required_details"]:
			var available: Array = definition.topics if field == "required_topics" else definition.details
			for required in definition.get(field, []):
				if required not in available:
					errors.append(str(id) + ": недостижимое условие " + str(required))
		for topic in definition.topic_requires:
			if topic not in definition.topics or definition.topic_requires[topic] not in definition.details:
				errors.append(str(id) + ": неизвестный вопрос или признак " + str(topic))
	if not _unique_ids(packages):
		errors.append("Один номер находки назначен нескольким предметам.")
	return errors

static func _unique_ids(ids: Array) -> bool:
	var seen := {}
	for id in ids:
		if not id is String or id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true
