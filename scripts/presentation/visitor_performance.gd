extends RefCounted
## Poses describe the on-screen listener as well as the current speaker.

const SPEAKERS := {
	"Нина":"nina", "Нина, из зала":"nina", "Фёдор":"fedor",
	"Вера":"vera", "Леонид":"leonid", "Глеб":"gleb", "Серов":"serov",
	"Павел":"pavel", "Дежурная, по телефону":"dispatcher",
}
const NAMES := {
	"nina":"Нина", "fedor":"Фёдор", "vera":"Вера", "leonid":"Леонид",
	"gleb":"Глеб", "serov":"Серов", "pavel":"Павел", "dispatcher":"Дежурная",
}
const POSES := {
	"nina":{"greeting":[0,1], "lunch":[1], "carrier":[1], "old_room":[2], "issue":[1], "retain":[2], "appropriate":[2]},
	"fedor":{"greeting":[0,1], "house":[1], "work":[1,2], "blue_paint":[2], "issue":[2], "retain":[0], "appropriate":[1]},
	"gleb":{"greeting":[1,1,0,2], "repair":[1], "work":[1,2], "body_mismatch":[2], "film_mismatch":[2], "issue":[1], "retain":[2], "appropriate":[2]},
	"serov":{"greeting":[0], "past":[1], "coat":[0], "tag":[1], "trip":[2], "waiting":[2], "issue":[2], "retain":[0], "appropriate":[1]},
	"finale":{"greeting":[0,1,2]},
}

static func actor(case_id: String) -> String:
	return "nina" if case_id == "finale" else case_id

static func speaker(line: String, case_id: String) -> String:
	if line.begins_with("Павел узнаёт "):
		return ""
	return SPEAKERS.get(line.get_slice(":", 0), actor(case_id))

static func pose(case_id: String, dialogue: String, index: int, voice: String) -> int:
	if case_id == "melnikovs":
		if dialogue == "parting" and index == 0:
			return 2
		return 1 if voice == "vera" else 0
	var cues: Array = POSES.get(case_id, {}).get(dialogue, [0])
	return cues[mini(index, cues.size() - 1)]
