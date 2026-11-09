extends "res://tests/serov_input.gd"
## A complete graphical shift for each ending through the public UI.

func _version() -> String:
	return "0.12"

func _play_serov(decision: String) -> bool:
	if not await super._play_serov(decision):
		return false
	await _click_caption("Продолжить смену")
	if not _expect(await _wait(func(): return room.visitor_phase == "waiting", 3.0), "Nina arrives with P08"):
		return false
	_expect(store.get_snapshot().case_id == "finale" and ui._modal_kind == "dialogue", "arrival opens Nina's lines")
	_expect(room.find_child("SerovAtBus",false,false).visible, "Serov remains at the bus after Nina arrives")
	await _capture(decision + "-p08-arrival")
	await _finish_reply()
	var lunch_outcome: String = store.get_snapshot().completed_cases.nina.decision
	_expect(ui.dialogue_text.text == store.content.lunch_followup[lunch_outcome], "Nina's return reflects the earlier lunch decision")
	await _key(KEY_ESCAPE)
	_expect(_find_button(ui,"Сверить карточку и акт").disabled and _find_button(ui,"Вынуть карточку № 314").disabled, "card and final action stay locked before inspection")
	await _click_caption("Поставить на стол")
	await _click_caption("Открыть и осмотреть")
	if not _expect(ui._modal_kind == "inspection", "blue bag can be opened on the desk"):
		return false
	var stage: Node3D = ui.get("_inspection")
	await _settle()
	await _capture(decision + "-p08-overview")
	for id in ["shirt", "ticket", "pass", "card"]:
		await _click_stage(stage,id)
		if not _expect(id in store.get_snapshot().inspected_details and stage.get_focus_id() == id, "P08 physical evidence " + id):
			await _capture(decision + "-p08-failed-" + id)
			return false
		await _settle()
		await _capture(decision + "-p08-" + id)
		await _click_caption("Вся сумка")
		await _settle()
	await _click_caption("Сверить карточку и акт")
	_expect(ui._modal_kind == "comparison" and ui.modal.find_child("Paper_old_act",true,false) != null and ui.modal.find_child("Paper_card",true,false) != null, "both conflicting papers appear together")
	await _capture(decision + "-p08-comparison")
	await _key(KEY_ESCAPE)
	await _click_caption("Вынуть карточку № 314")
	_expect(store.get_snapshot().card_location == "hand" and room.find_child("CardInHand",true,false).visible, "taking the card makes a single held prop visible")
	_expect(room.find_child("Target_P08",true,false).collision_layer == 0, "the bag cannot open a duplicate card while it is held")
	var ending: String = {"issue":"keep", "retain":"serov", "appropriate":"archive"}[decision]
	var label: String = {"serov":"Посмотреть на Серова", "archive":"Посмотреть на архив", "keep":"Посмотреть под стол"}[ending]
	var target_id: String = {"serov":"serov", "archive":"archive", "keep":"personal_bag"}[ending]
	await _click_caption(label)
	await _settle()
	var target := room.find_child("Target_" + target_id,true,false) as Node3D
	var click_position := target.global_position
	if ending == "serov":
		click_position += Vector3(0, 0.42, 0)
	var camera: Camera3D = rig.get_camera()
	var picked: String = room.call("_pick", camera.unproject_position(click_position))
	if not _expect(picked == target_id, "world ray reaches " + target_id + " (picked " + picked + ")"):
		await _capture(ending + "-target-failed")
		return false
	await _click_world(click_position)
	if ending == "archive":
		_expect(store.get_snapshot().card_location == "archive_draft" and ui._modal_kind == "archive_draft", "putting the card into the folder opens an unsigned draft")
		_expect(ui.modal.find_child("Paper_supplement_draft",true,false) != null and not room.find_child("CardInHand",true,false).visible, "the draft and one archive card are visible")
		await _capture("archive-unsigned-supplement")
		await _click_caption("Подписать дополнение")
	var state: Dictionary = store.get_snapshot()
	_expect(ui._modal_kind == "ending" and state.decision == ending and state.card_location == ("bag" if ending == "keep" else ending), "one final destination after the UI decision")
	_expect(state.completed_cases.serov.decision == decision, "final decision preserves the coat result")
	_expect(room.find_child("ArchivedCard",true,false).visible == (ending == "archive"), "the card appears in the archive only in that ending")
	_expect(room.find_child("CardWithSerov",true,false).visible == (ending == "serov"), "Serov receives one visible card only in his ending")
	_expect(not room.find_child("CardInHand",true,false).visible, "no held duplicate remains after committing the ending")
	_expect(room.get("_package_views").P05.visible, "the one coat model remains at its actual destination")
	_expect(_find_button(ui,"Начать новую смену") != null, "ending offers restart")
	await _settle()
	await _capture(ending + "-ending")
	await _click_caption("Осмотреть бюро")
	await _settle()
	await _capture(ending + "-ending-room")
	if ending == "archive":
		var folder := room.find_child("Target_archive",true,false) as Node3D
		await _click_world(folder.global_position)
		_expect(ui._modal_kind == "comparison" and ui.modal.find_child("Paper_supplement",true,false) != null, "signed supplement can be read beside the original records")
		await _capture("archive-signed-supplement")
		await _key(KEY_ESCAPE)
	return failures.is_empty()
