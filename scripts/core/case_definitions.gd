extends RefCounted
## Rules and stable IDs. Prose and captions live in data/<case>.json.

const ORDER: Array[String] = ["nina", "fedor"]
const CASES := {
	"nina": {"package_id": "P01", "details": ["sandwiches", "saucer", "napkin"],
		"topics": ["carrier", "old_room", "lunch"], "topic_requires": {"lunch": "sandwiches"}},
	"fedor": {"package_id": "P02", "details": ["corner", "paint", "collar"],
		"topics": ["house", "work", "blue_paint"], "topic_requires": {"blue_paint": "paint"}}
}

static func get_case(case_id: String) -> Dictionary:
	return CASES.get(case_id, {}).duplicate(true)

static func has_next(case_id: String) -> bool:
	var index := ORDER.find(case_id)
	return index >= 0 and index < ORDER.size() - 1
