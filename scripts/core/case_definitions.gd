extends RefCounted
## Rules and stable IDs. Prose and captions live in data/<case>.json.

const ORDER: Array[String] = ["nina", "fedor", "melnikovs"]
const CASES := {
	"nina": {"package_id": "P01", "documents": ["identity", "claim"], "recipients": ["nina"], "allow_appropriate": true,
		"details": ["sandwiches", "saucer", "napkin"],
		"topics": ["carrier", "old_room", "lunch"], "topic_requires": {"lunch": "sandwiches"}},
	"fedor": {"package_id": "P02", "documents": ["identity", "claim"], "recipients": ["fedor"], "allow_appropriate": true,
		"details": ["corner", "paint", "collar"],
		"topics": ["house", "work", "blue_paint"], "topic_requires": {"blue_paint": "paint"}},
	"melnikovs": {"package_id": "P03", "documents": ["vera_identity", "vera_claim", "leonid_identity", "leonid_claim"],
		"recipients": ["vera", "leonid"], "allow_appropriate": false, "lock_code": "246",
		"details": ["combination", "green_stain", "zipper"], "required_details": ["green_stain", "zipper"], "required_topics": ["lock_code"],
		"topics": ["journey", "lock_code", "parting", "lining_story"], "topic_requires": {"lining_story": "zipper"}}
}

static func get_case(case_id: String) -> Dictionary:
	return CASES.get(case_id, {}).duplicate(true)

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
