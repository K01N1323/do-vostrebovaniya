extends Control

signal focus_requested(view_id: String)
signal modal_changed(blocked: bool)
signal motion_changed(reduced: bool)
signal dialogue_pose_changed(pose: int, duration: float, at_bus: bool)
signal dialogue_framing_changed(active: bool, paired: bool)

const Cases = preload("res://scripts/core/case_definitions.gd")
const Rules = preload("res://scripts/core/state_reducer.gd")
const VisitorActing = preload("res://scripts/presentation/visitor_performance.gd")
const StationAudio = preload("res://scripts/presentation/station_audio.gd")
const Paper = preload("res://scripts/ui/paper_sheet.gd")
const HatchStage = preload("res://scripts/presentation/hatch_stage.gd")
const INK := Color("272c27")
const LIGHT := Color("e1dac5")
const MUTED := Color("a5aa98")
const GOLD := Color("bdad78")
const DARK := Color(0.035,0.043,0.037,0.91)
const CONTROL_HINT := "ПКМ — повернуть голову   ·   Мышь — выбрать   ·   F1 — действия"

var snapshot: Dictionary = {}
var sidebar: VBoxContainer
var dialogue_text: RichTextLabel
var objective: Label
var hint: Label
var interaction_hint: Label
var modal: Control
var modal_body: VBoxContainer
var _modal_kind: String = ""
var _view: String = "window"
var _sound := StationAudio.new()
var _muted := false
var _reduced := false
var _inspection: Node3D
var _inspection_find_id := ""
var _serov_at_bus := false
var _detail_buttons: Dictionary = {}
var _lining_button: Button
var _card_button: Button
var _record_observation: Button
var _observation_text: RichTextLabel
var _inspection_zone := -1
var _inspection_caption: Label
var _inspection_overview: Button
var _inspection_turns: Array[Button] = []
var _zoom_out: Button
var _zoom_in: Button
var _zoom_caption: Label
var _start_screen: Control
var _action_panel: PanelContainer
var _actions_button: Button
var _journal_button: Button
var _hovered_target := ""
var _hud: Control
var _brand: Label
var _task_panel: PanelContainer
var _task_detail: Label
var _task_button: Button
var _task_action := Callable()
var _footer: PanelContainer
var _menu_status: Label
var _save_message: Label
var _pause_return: Dictionary = {}
var _confirmation: ConfirmationDialog
var _booting := false
var _visitor_ready := false
var _arrival_dialogue_pending := false
var _can_advance := false
var _speech_parts: Array[String] = []
var _speech_index := 0
var _speech_choices: VBoxContainer
var _speech_heading: Label
var _speech_prefix := 0
var _speech_at_bus := false
var _speech_arrival := false
var _typewriter_font: SystemFont
var _heading_font: SystemFont

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var preferences: Dictionary = GameStore.read_preferences()
	_muted = preferences.muted
	_reduced = preferences.reduced_motion
	_build_theme()
	_build_shell()
	GameStore.command_rejected.connect(_show_hint)
	GameStore.save_failed.connect(_show_save_error)
	add_child(_sound)
	_start_screen = _make_start_screen()
	_hud.hide()

func _build_theme() -> void:
	_typewriter_font = SystemFont.new()
	_typewriter_font.font_names = PackedStringArray(["Courier New", "Courier", "monospace"])
	_heading_font = SystemFont.new()
	_heading_font.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	var skin := Theme.new()
	skin.default_font_size = 19
	skin.set_color("font_color", "Label", LIGHT)
	skin.set_color("default_color", "RichTextLabel", LIGHT)
	skin.set_constant("line_separation", "RichTextLabel", 5)
	for property in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
		skin.set_color(property,"Button",LIGHT)
	skin.set_color("font_disabled_color", "Button", Color("6f786a"))
	skin.set_stylebox("normal","Button",_style(Color(0.07,0.085,0.07,0.65),Color(0.52,0.54,0.45,0.40)))
	skin.set_stylebox("hover","Button",_style(Color("30372b"),GOLD))
	skin.set_stylebox("pressed","Button",_style(Color("474b38"),GOLD))
	skin.set_stylebox("disabled","Button",_style(Color("1e2722"),Color("3d483b")))
	skin.set_stylebox("focus","Button",_style(Color(0,0,0,0),GOLD,2))
	skin.set_constant("separation","VBoxContainer",9)
	skin.set_constant("separation","HBoxContainer",9)
	theme = skin

func _build_shell() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_brand = _label(_hud,"БЮРО НАХОДОК",18,GOLD)
	_brand.position = Vector2(26,22)
	_brand.add_theme_font_override("font",_typewriter_font)
	_task_panel = _panel(_hud, DARK)
	_task_panel.name = "ShiftTask"
	_task_panel.position = Vector2(26, 54)
	_task_panel.size.x = 417
	_task_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var task := VBoxContainer.new()
	task.add_theme_constant_override("separation", 6)
	var task_margin := _margin(task, 13, 10)
	task_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_panel.add_child(task_margin)
	task.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective = _label(task, "", 19, GOLD)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_detail = _label(task, "", 16, LIGHT)
	_task_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_button = _button(task, "", _run_task)
	_task_button.add_theme_font_size_override("font_size", 16)
	_task_button.name = "ShiftTaskAction"
	_task_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var pause := _button(_hud,"Пауза · Esc",_show_pause)
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left = -176
	pause.offset_right = -24
	pause.offset_top = 20
	pause.offset_bottom = 58
	_journal_button = _button(_hud,"Журнал",_show_journal)
	_journal_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_journal_button.offset_left = -286
	_journal_button.offset_right = -185
	_journal_button.offset_top = 20
	_journal_button.offset_bottom = 58
	var actions := _button(_hud,"Действия · F1",_toggle_actions)
	_actions_button = actions
	actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	actions.offset_left = -176
	actions.offset_right = -24
	actions.offset_top = 65
	actions.offset_bottom = 103
	_action_panel = _panel(_hud,DARK)
	_action_panel.anchor_left = 1
	_action_panel.anchor_right = 1
	_action_panel.offset_left = -282
	_action_panel.offset_right = -24
	_action_panel.offset_top = 124
	_action_panel.offset_bottom = 510
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_action_panel.add_child(_margin(scroll,12,12))
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sidebar)
	_footer = _panel(_hud,Color(0.02,0.025,0.02,0.52))
	_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_top = -62
	var nav := HBoxContainer.new()
	_footer.add_child(_margin(nav,18,7))
	for entry in [["window","1 · Посетитель"],["shelf","2 · Полки"],["desk","3 · Стол"],["personal","4 · Под столом"]]:
		var id: String = entry[0]
		var button := _button(nav,entry[1],func(): _focus(id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",16)
	hint = _label(_hud,CONTROL_HINT,15,LIGHT)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 26
	hint.offset_top = -92
	hint.offset_right = 1160
	hint.offset_bottom = -66
	hint.add_theme_color_override("font_shadow_color",Color("111b15"))
	hint.add_theme_constant_override("shadow_offset_x",1)
	hint.add_theme_constant_override("shadow_offset_y",1)
	interaction_hint = _label(_hud,"",16,GOLD)
	interaction_hint.name = "InteractionHint"
	interaction_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	interaction_hint.offset_left = 26
	interaction_hint.offset_top = -122
	interaction_hint.offset_right = 1160
	interaction_hint.offset_bottom = -96
	interaction_hint.add_theme_color_override("font_shadow_color",Color("111b15"))
	interaction_hint.add_theme_constant_override("shadow_offset_x",1)
	interaction_hint.add_theme_constant_override("shadow_offset_y",1)
	interaction_hint.hide()

func render(state: Dictionary) -> void:
	if not state.started:
		_show_hint(CONTROL_HINT)
	if not state.started or snapshot.get("case_id", "nina") != state.case_id:
		_visitor_ready = false
		_arrival_dialogue_pending = false
		_can_advance = false
		_hovered_target = ""
	snapshot = state
	_refresh_interaction_hint()
	if not is_instance_valid(sidebar):
		return
	_render_task()
	_clear(sidebar)
	_action_panel.offset_bottom = minf(720, size.y - 110)
	_label(sidebar,"КОНЕЦ СМЕНЫ" if state.case_id == "finale" else "ОБРАЩЕНИЕ " + _p().number,13,GOLD)
	var case_name := _label(sidebar,_p().name,21)
	case_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if state.case_status == "resolved":
		var outcomes: Dictionary = _p().outcomes
		_text(sidebar,outcomes.get(Cases.outcome_key(state),""),17)
		if state.case_id == "finale":
			_button(sidebar,"Итоги смены",_show_ending)
		else:
			_add_next_button(sidebar)
		if state.case_id in ["serov", "finale"]:
			_add_bus_button(sidebar)
		_button(sidebar,"Начать заново",_restart)
		_add_find_actions()
		return
	if not _visitor_ready or _arrival_dialogue_pending:
		_add_find_actions()
		return
	if state.case_id == "finale" and state.card_location != "bag":
		_render_card_actions()
		return
	var decision := _action(sidebar,"Вынуть карточку № 314" if state.case_id == "finale" else "Принять решение",_show_decision)
	decision.disabled = not Rules.can_decide(state)
	decision.tooltip_text = "Проверка помогает принять решение." if state.case_id != "finale" else "Осмотрите сумку и сверьте бумаги."
	if state.case_id == "gleb":
		_action(sidebar,"Отложить камеру · принять следующего",_defer_camera)
		if "claim" in state.read_documents and not state.inspected_details.is_empty():
			_action(sidebar,"Сопоставить улики",_show_camera_comparison)
	if state.case_id == "finale":
		var papers := _action(sidebar,"Сверить карточку и акт",_show_final_papers)
		papers.disabled = state.package.location != "desk" or "card" not in state.inspected_details
		_add_bus_button(sidebar)
	elif snapshot.case_id == "melnikovs":
		for person in ["vera", "leonid"]:
			var owner_id: String = person
			var documents: Array = [owner_id + "_identity", owner_id + "_claim"]
			var checked: bool = documents[0] in state.read_documents and documents[1] in state.read_documents
			_action(sidebar,("Бумаги Веры" if owner_id == "vera" else "Бумаги Леонида") + (" ✓" if checked else ""),func(): _show_comparison(documents))
		_action(sidebar,"Сверить все четыре бумаги",_show_comparison)
		_action(sidebar,"Открыть одну бумагу",_show_document_selection)
	else:
		for id in Cases.get_case(snapshot.case_id).documents:
			var document_id: String = id
			_action(sidebar,GameStore.content.document_labels[id]+(" ✓" if id in state.read_documents else ""),func(): _show_document(document_id))
		_action(sidebar,"Сравнить обе бумаги",_show_comparison)
	_rule(sidebar)
	if state.package.location == "shelf":
		_action(sidebar,"Поставить на стол",func(): _move("desk"))
	elif state.package.location == "desk":
		_action(sidebar,"Осмотреть содержимое" if state.package.opened else "Открыть и осмотреть",_show_inspection)
		_action(sidebar,"Вернуть на полку · пока думаю",func(): _move("shelf"))
	_action(sidebar,"Поговорить",_show_conversation)
	_add_find_actions()

func _add_find_actions() -> void:
	_rule(sidebar)
	if snapshot.has("deferred_gleb"):
		_action(sidebar,"Дело Глеба · камера" if snapshot.get("orlov_heard", false) else "Телефон · ответить Орлову",_show_deferred_camera)
	_action(sidebar,"Удостоверение Павла",_show_clerk_id)
	if snapshot.case_id == "serov":
		_action(sidebar,"Акт 2014 года" + (" ✓" if snapshot.old_act_read else ""),_show_old_act)
		if snapshot.case_status == "resolved":
			_action(sidebar,"Подойти к архиву",_walk_to_archive)
			var walk := _action(sidebar,"Подойти к выходу на посадку",_walk_to_platform)
			walk.name = "WalkToPlatform"
			walk.disabled = not _serov_at_bus
	_label(sidebar,"ДРУГИЕ НАХОДКИ",13,GOLD)
	var auxiliary := Rules.auxiliary_packages(snapshot)
	for id in auxiliary:
		var find_id: String = id
		var item: Dictionary = auxiliary[id]
		var title: String = _find_content(id).presentation.package_title
		_action(sidebar,title + (" · на столе" if item.location == "desk" else ""),func(): open_target(find_id))
		if item.location == "desk":
			_action(sidebar,"Вернуть на полку · П" + id.substr(1),func(): _move_find(find_id, "shelf"))

func _move_find(id: String, destination: String) -> void:
	_close_modal()
	if GameStore.dispatch({"type":"MOVE_PACKAGE", "package_id":id, "destination":destination}).ok:
		_focus("desk" if destination == "desk" else "shelf")
		_show_hint("П" + id.substr(1) + (" на столе. Нажмите для осмотра." if destination == "desk" else " возвращён на полку."))

func _show_clerk_id() -> void:
	play_cue("paper")
	_begin_modal(GameStore.clerk.title, "document")
	_document(modal_body, GameStore.clerk, "clerk_identity")
	_button(modal_body, "Вернуться к столу", _close_modal)
	GameStore.set_resume_view({"kind":"document", "id":"clerk_identity"})

func _show_old_act() -> void:
	if snapshot.case_id == "finale" and snapshot.card_location == "archive":
		_show_archived_documents()
		return
	if not GameStore.dispatch({"type":"READ_OLD_ACT"}).ok:
		return
	play_cue("paper")
	_begin_modal(GameStore.old_act.title, "document")
	_document(modal_body, GameStore.old_act, "old_act")
	if snapshot.case_id not in ["serov", "finale"]:
		_text(modal_body, "Павел: Подпись моя.", 17, GOLD)
	elif snapshot.case_id == "serov" and "past" not in snapshot.asked_topics:
		_text(modal_body, "Павел помнит, что принял сумку у Серова. После этого акта Серова осудили. Он провёл три года в заключении.", 17, GOLD)
	_button(modal_body,"Вернуться к столу",_close_modal)
	GameStore.set_resume_view({"kind":"document", "id":"old_act"})

func _show_archived_documents() -> void:
	play_cue("paper")
	_begin_modal("Архив · дело № 314", "comparison")
	modal.position = Vector2(36, 118)
	modal.size = Vector2(1368, 695)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_body.add_child(row)
	_document(row, GameStore.old_act, "old_act")
	_document(row, GameStore.content.documents.card, "card")
	_document(row, _supplement_record(true), "supplement")
	_button(modal_body, "Вернуться к столу", _close_modal)
	GameStore.set_resume_view({"kind":"document", "id":"old_act"})

func _add_bus_button(parent: Node) -> void:
	var talk := _action(parent,"Поговорить с Серовым у рейса",_show_waiting_serov)
	talk.name = "TalkAtBus"
	talk.disabled = not _serov_at_bus

func set_serov_at_bus(value: bool) -> void:
	_serov_at_bus = value
	for button in find_children("TalkAtBus", "Button", true, false):
		button.disabled = not value
	for button in find_children("WalkToPlatform", "Button", true, false):
		button.disabled = not value

func _show_waiting_serov() -> void:
	if not _serov_at_bus:
		return
	_close_modal()
	if _view != "walk_platform":
		_focus("bus")
	_begin_modal("У выхода на посадку", "dialogue")
	_speech_at_bus = true
	var line: String = GameStore.get_case_content("serov").waiting
	_text(modal_body, line, 21)
	_layout_dialogue(155)
	_dialogue_button(modal_body,"К работе",_close_modal)
	_speak_line(line, "serov", "waiting", 0)

func _walk_to_archive() -> void:
	_close_modal()
	_focus("walk_archive")
	play_cue("steps")
	_show_hint("Архивная папка перед вами. Нажмите на неё, чтобы прочитать акт.")

func _walk_to_platform() -> void:
	_close_modal()
	_focus("walk_platform")
	play_cue("steps")
	_show_hint("Серов ждёт рейс. Нажмите на него, чтобы поговорить.")

func _render_task() -> void:
	var state := snapshot
	if not state.get("started", false):
		_set_task("Открытие смены")
		return
	if state.case_status == "resolved":
		if state.case_id == "finale":
			_set_task("Смена завершена", "", "Посмотреть итоги", _show_ending)
		elif state.has("deferred_gleb"):
			_set_task("Камера ждёт решения", "Прежде чем закрывать смену, вернитесь к отложенному делу.", "Разобрать дело Глеба", _show_deferred_camera)
		elif state.case_id == "serov" and not state.old_act_read:
			if _view == "walk_archive":
				_set_task("Архивная папка", "Здесь подшит акт 2014 года.", "Открыть акт", _show_old_act)
			else:
				_set_task("Старое дело", "В архивной папке лежит акт 2014 года.", "Подойти к архиву", _walk_to_archive)
		elif _can_advance:
			_set_task("Обращение закрыто", "", "Продолжить к следующему обращению", _next_case)
		else:
			_set_task("Обращение закрыто", "Дождитесь, пока посетитель освободит окно.")
		return
	if not _visitor_ready or _arrival_dialogue_pending:
		_set_task("Окно бюро", "Посетитель подходит к стойке.", "Посмотреть на окно", func(): _focus("window"))
		return
	if state.has("deferred_gleb") and not state.get("orlov_heard", false):
		_set_task("Звонок о камере", "Орлов на линии. Пока он ждёт, можно продолжить с пальто Серова через «Действия».", "Снять трубку", _show_deferred_camera)
		return
	if state.case_id == "finale":
		if state.card_location == "hand":
			_set_task("Карточка у вас", "Нажмите на Серова у рейса, папку архива или место под столом. Ракурсы доступны в «Действиях».")
			return
		if state.card_location == "archive_draft":
			_set_task("Дополнение к акту", "Чтобы завершить смену, подпишите документ или верните карточку в сумку.", "Открыть черновик", _show_archive_draft)
			return
	var definition := Cases.get_case(state.case_id)
	if state.case_id != "finale" and state.read_documents.size() < definition.documents.size():
		var purpose := "Сверьте имя и прочитайте, как описана вещь." if state.case_id == "nina" else "Проверьте имя и описание находки в бумагах."
		_set_task("Сверьте бумаги", purpose, "Разложить бумаги рядом", _show_comparison)
		return
	if state.case_id == "melnikovs" and "lock_code" not in state.asked_topics and "leonid_alone" not in state.asked_topics:
		_set_task("Уточните код замка", "Один из заявителей знает комбинацию.", "Спросить Мельниковых", _show_conversation)
		return
	if state.package.location != "desk":
		var on_desk := Rules.desk_package_id(state)
		if not on_desk.is_empty():
			_set_task("Освободите стол", "На столе помещается одна находка.", "Вернуть вещь на полку", _move_find.bind(on_desk, "shelf"))
		else:
			_set_task("Возьмите " + _p().item_accusative, "Вещь лежит на полке. Осматривать её удобнее на столе.", "Перенести на стол", _move.bind("desk"))
		return
	if state.case_id == "melnikovs" and not state.package.unlocked:
		_set_task("Откройте замок", "Введите комбинацию, которую назвал посетитель.", "Поднести чемодан", _show_inspection)
		return
	if state.inspected_details.is_empty() or _has_unchecked_items(definition.get("required_details", []), state.inspected_details):
		var instruction: String = {
			"nina":"Приблизьте деталь и отметьте хотя бы одно наблюдение.",
			"melnikovs":"Проверьте пятно и загляните под подкладку.",
			"gleb":"Отметьте корпус, ремешок и содержимое сумки.",
			"serov":"Отметьте бирку и все приметы пальто.",
			"finale":"Отметьте каждую вещь, найденную в сумке."
		}.get(state.case_id, "Приблизьте деталь и отметьте наблюдение.")
		_set_task("Осмотрите " + _p().item_accusative, instruction, "Начать осмотр", _show_inspection)
		return
	if state.case_id == "serov" and _has_unchecked_items(definition.required_topics, state.asked_topics):
		_set_task("Расспросите Серова", "Поговорите о старом деле и о том, зачем он едет.", "Вернуться к Серову", _show_conversation)
	elif state.case_id == "finale":
		if "card" not in state.read_documents:
			_set_task("Сверьте карточку № 314 с актом", "Прочитайте, что осталось в журнале приёма.", "Открыть карточку и акт", _show_final_papers)
		else:
			_set_task("Возьмите карточку № 314", "С ней можно будет подойти к окну или к архиву.", "Достать карточку", _take_card)
	else:
		_set_task("Решите судьбу находки", "Проверка завершена. Можно ещё раз поговорить с посетителем.", "Выбрать исход", _show_decision)

func _has_unchecked_items(required: Array, checked: Array) -> bool:
	for id in required:
		if id not in checked:
			return true
	return false

func _set_task(title: String, instruction: String = "", button_text: String = "", action: Callable = Callable()) -> void:
	objective.text = title
	_task_detail.text = instruction
	_task_detail.visible = not instruction.is_empty()
	_task_button.text = button_text
	_task_button.visible = action.is_valid()
	_task_action = action
	_task_panel.set_deferred("size", Vector2(417, 0))

func _run_task() -> void:
	if not is_instance_valid(modal) and _task_action.is_valid():
		_task_action.call()

func on_visitor_arrived() -> void:
	_visitor_ready = true
	_arrival_dialogue_pending = snapshot.case_status == "active" and snapshot.dialogue_id == "greeting" and snapshot.read_documents.is_empty()
	_present_arrival_dialogue()
	render(snapshot)
	if snapshot.has("deferred_gleb") and not snapshot.get("orlov_heard", false):
		play_cue("phone")

func _present_arrival_dialogue() -> void:
	if not _arrival_dialogue_pending or not snapshot.get("started", false):
		return
	if is_instance_valid(_start_screen) or is_instance_valid(modal):
		return
	_arrival_dialogue_pending = false
	_show_conversation(true)
	render(snapshot)

func open_target(target_id: String) -> void:
	if not snapshot.get("started",false) or (is_instance_valid(modal) and _modal_kind not in ["dialogue","result"]):
		return
	if (not _visitor_ready or _arrival_dialogue_pending) and target_id in ["identity", "claim", snapshot.case_id, snapshot.package.id]:
		_show_hint("Дождитесь посетителя у стойки.")
		return
	if _card_target(target_id):
		return
	var auxiliary := Rules.auxiliary_item(snapshot, target_id)
	if not auxiliary.is_empty():
		if snapshot.case_status == "resolved" and snapshot.decision == "issue" and not _can_advance:
			_show_hint("Дождитесь завершения передачи.")
		elif auxiliary.location == "shelf":
			_move_find(target_id, "desk")
		else:
			_show_inspection(target_id)
	elif target_id == snapshot.package.id:
		if snapshot.case_status == "resolved":
			_show_hint("Решение уже принято.")
		elif snapshot.package.location == "shelf":
			_move("desk")
		else:
			_show_inspection()
	elif target_id == "serov" and _serov_at_bus:
		_show_waiting_serov()
	elif target_id == snapshot.case_id:
		if snapshot.case_status == "active":
			_show_conversation()
	elif target_id in Cases.get_case(snapshot.case_id).documents:
		if snapshot.case_status == "active":
			_show_document(target_id)
	elif target_id in ["identity", "claim"] and snapshot.case_id == "melnikovs":
		if snapshot.case_status == "active":
			_show_comparison()
	elif target_id == "clerk_identity":
		_show_clerk_id()
	elif target_id == "archive":
		_show_old_act()
	elif target_id == "hatch":
		_show_hint("Передаточный блок. Выдача — после проверки и явного решения.")

func _move(destination: String) -> void:
	_close_modal()
	if GameStore.dispatch({"type":"MOVE_PACKAGE","destination":destination}).ok:
		_focus("desk" if destination == "desk" else "shelf")
		_show_hint(_p().item_nominative + (" на столе. Нажмите для осмотра." if destination == "desk" else " на полке. Решение ещё не принято."))

func _show_document_selection() -> void:
	_begin_modal("Бумаги Мельниковых", "document")
	for id in Cases.get_case(snapshot.case_id).documents:
		var document_id: String = id
		_button(modal_body, GameStore.content.documents[id].title, func(): _show_document(document_id))

func _show_document(id: String) -> void:
	if id == "card":
		_show_final_papers()
		return
	if not GameStore.dispatch({"type":"READ_DOCUMENT","document_id":id}).ok:
		return
	play_cue("paper")
	_begin_modal(GameStore.content.documents[id].title,"document")
	if id == "identity":
		modal.position = Vector2(36,250)
		modal.size = Vector2(580,520)
	_document(modal_body,GameStore.content.documents[id],id)
	_button(modal_body,"Вернуться к столу",_close_modal)
	GameStore.set_resume_view({"kind":"document", "id":id})

func _show_comparison(selected: Array = []) -> void:
	var documents: Array = selected if not selected.is_empty() else Cases.get_case(snapshot.case_id).documents
	for id in documents:
		GameStore.dispatch({"type":"READ_DOCUMENT","document_id":id})
	play_cue("paper")
	_begin_modal("Сверка бумаг · " + _p().name,"comparison")
	if documents.size() > 2:
		modal.position = Vector2(36,118)
		modal.size = Vector2(1100,680)
	elif snapshot.case_id in ["gleb", "serov"]:
		modal.position = Vector2(36,420)
		modal.size = Vector2(1100,400)
	if snapshot.case_id == "nina":
		modal.position = Vector2(36, 237)
		modal.size = Vector2(1100, 565)
		_text(modal_body, "Слева удостоверение, справа заявление. Сверьте имя и запомните, что Нина оставила внутри переноски.", 16, LIGHT)
	for offset in range(0, documents.size(), 2):
		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		modal_body.add_child(row)
		for index in range(offset, mini(offset + 2, documents.size())):
			var id: String = documents[index]
			_document(row,GameStore.content.documents[id],id)
	_button(modal_body,"Вернуться к столу",_close_modal)
	var selection := "" if selected.is_empty() else str(selected[0]).get_slice("_", 0)
	GameStore.set_resume_view({"kind":"comparison", "id":selection})

func _show_final_papers() -> void:
	if not GameStore.dispatch({"type":"READ_DOCUMENT", "document_id":"card"}).ok:
		return
	play_cue("paper")
	_begin_modal("Карточка № 314 и акт 2014 года", "comparison")
	modal.position = Vector2(36, 175)
	modal.size = Vector2(1130, 615)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_body.add_child(row)
	_document(row, GameStore.old_act, "old_act")
	_document(row, GameStore.content.documents.card, "card")
	_text(modal_body,GameStore.content.comparison_note,16,MUTED)
	_button(modal_body,"Вернуться к столу",_close_modal)
	GameStore.set_resume_view({"kind":"comparison", "id":"card"})

func _document(parent: Node, record: Dictionary, id: String) -> void:
	var paper := Paper.new()
	paper.name = "Paper_" + id
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(paper)
	paper.compose(record, id, _p(), snapshot.case_id == "melnikovs", _modal_kind == "comparison", _typewriter_font)

func _find_content(id: String) -> Dictionary:
	if id in Cases.LOOSE_FINDS:
		return GameStore.loose_finds[id]
	if id == "P04" and snapshot.has("deferred_gleb"):
		return GameStore.get_case_content("gleb")
	return GameStore.get_case_content(Cases.future_case(snapshot.case_id, id))

func _inspection_content() -> Dictionary:
	return GameStore.content if _inspection_find_id.is_empty() else _find_content(_inspection_find_id)

func _inspection_command(type: String, find_id: String) -> Dictionary:
	var command := {"type":type}
	if not find_id.is_empty():
		command.package_id = find_id
	return command

func _show_inspection(find_id: String = "") -> void:
	var item: Dictionary = snapshot.package if find_id.is_empty() else Rules.auxiliary_item(snapshot, find_id)
	if item.has("unlocked") and not item.unlocked:
		_show_lock(find_id)
		return
	_close_modal()
	_focus("desk")
	if not item.opened:
		if not GameStore.dispatch(_inspection_command("OPEN_PACKAGE", find_id)).ok:
			return
	var content: Dictionary = GameStore.content if find_id.is_empty() else _find_content(find_id)
	var presentation: Dictionary = content.presentation
	var observed: Array = snapshot.inspected_details if find_id.is_empty() else item.inspected_details
	_begin_modal(presentation.package_title,"inspection")
	_inspection_find_id = find_id
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_body.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.20
	row.add_child(left)
	var box := SubViewportContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.stretch = true
	box.custom_minimum_size = Vector2(380,270)
	left.add_child(box)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(560,420)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(viewport)
	_inspection = load("res://scenes/objects/inspection_stage.tscn").instantiate()
	_inspection.set_item(item.id)
	viewport.add_child(_inspection)
	_inspection.set_opened(true)
	_inspection.set_lining_lifted(item.get("lining_lifted", false))
	_inspection.reduced_motion = _reduced
	_inspection.detail_selected.connect(_preview_detail)
	_inspection.focus_changed.connect(_refresh_inspection_focus)
	_inspection.zoom_changed.connect(_refresh_inspection_zoom)
	_inspection_caption = _label(left,"П" + presentation.number + " · Общий вид",14,MUTED)
	_inspection_caption.name = "InspectionCaption"
	var turn := HBoxContainer.new()
	left.add_child(turn)
	_inspection_turns.clear()
	_inspection_turns.append(_button(turn,"↶ Влево",func(): _inspection.rotate_item(-1.0)))
	_inspection_turns.append(_button(turn,"Вправо ↷",func(): _inspection.rotate_item(1.0)))
	_inspection_overview = _button(turn,presentation.overview,func(): _inspection.reset_focus())
	_inspection_overview.name = "InspectionOverview"
	_inspection_overview.disabled = true
	for button in _inspection_turns + [_inspection_overview]:
		button.add_theme_font_size_override("font_size",16)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var zoom := HBoxContainer.new()
	zoom.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(zoom)
	_zoom_out = _button(zoom, "−", func(): _inspection.change_zoom(-1))
	_zoom_out.tooltip_text = "Отдалить · колесо вниз"
	_zoom_caption = _label(zoom, "100 %", 15, MUTED)
	_zoom_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_caption.custom_minimum_size.x = 64
	_zoom_in = _button(zoom, "+", func(): _inspection.change_zoom(1))
	_zoom_in.tooltip_text = "Приблизить · колесо вверх"
	for button in [_zoom_out, _zoom_in]:
		button.custom_minimum_size = Vector2(38, 29)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_label(right,"НАБЛЮДЕНИЯ",13,GOLD)
	_inspection_zone = -1
	_detail_buttons.clear()
	_lining_button = null
	_card_button = null
	if item.has("lining_lifted"):
		_lining_button = _button(right,"Приподнять подкладку",_lift_lining)
		_lining_button.disabled = item.lining_lifted
	_action(right,"Следующий ракурс",_next_inspection_zone)
	for id in content.details:
		var detail_id: String = id
		var button := _action(right,content.details[id].title+" ✓",func(): _preview_detail(detail_id))
		button.visible = id in observed
		_detail_buttons[id] = button
	_observation_text = _text(right,"",18)
	_observation_text.name = "Observation"
	_observation_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_record_observation = _button(right,"Отметить наблюдение",_record_focused_detail)
	_refresh_inspection_focus("")
	if item.id == "P08":
		_card_button = _button(right,"Сверить карточку и акт",_show_final_papers)
		_card_button.disabled = "card" not in observed
	_button(modal_body,"Закончить осмотр · Esc",_close_modal)
	if not find_id.is_empty():
		_button(modal_body,"Вернуть находку на полку",func(): _move_find(find_id, "shelf"))

func _preview_detail(id: String) -> void:
	if id == "lining":
		_lift_lining()
		return
	if _modal_kind == "inspection":
		_inspection.focus_detail(id)

func _next_inspection_zone() -> void:
	var details: Array = _inspection_content().details.keys()
	for offset in range(1, details.size() + 1):
		var index: int = (_inspection_zone + offset) % details.size()
		if _inspection.can_focus_detail(details[index]):
			_preview_detail(details[index])
			return

func _record_focused_detail() -> void:
	var id: String = _inspection.get_focus_id()
	if not id.is_empty():
		_inspect_detail(id)

func _inspect_detail(id: String) -> void:
	var command := _inspection_command("INSPECT_DETAIL", _inspection_find_id)
	command.detail_id = id
	if not GameStore.dispatch(command).ok:
		return
	if _modal_kind == "inspection":
		_detail_buttons[id].show()
		if id == "card" and is_instance_valid(_card_button):
			_card_button.disabled = false
		if _inspection.get_focus_id() == id:
			_refresh_inspection_focus(id)
		else:
			_inspection.focus_detail(id)
	_show_hint("Осмотрено: "+_inspection_content().details[id].title)

func _show_lock(find_id: String = "") -> void:
	_close_modal()
	_focus("desk")
	_begin_modal("Кодовый замок · П03","lock")
	modal.position = Vector2(410,300)
	modal.size = Vector2(620,280)
	var prompt := "Три колёсика. Какой код назвал посетитель?" if find_id.is_empty() else "Замок на трёх колёсиках. Владелец ещё не подошёл."
	if find_id.is_empty() and ("lock_code" in snapshot.asked_topics or "leonid_alone" in snapshot.asked_topics):
		prompt = "Из журнала · Леонид назвал 246."
	_text(modal_body,prompt,19)
	var code := LineEdit.new()
	code.name = "LockCode"
	code.placeholder_text = "Три цифры"
	code.max_length = 3
	code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.custom_minimum_size.y = 42
	modal_body.add_child(code)
	var feedback := _label(modal_body,"",16,GOLD)
	feedback.name = "LockFeedback"
	var unlock := func():
		var command := _inspection_command("UNLOCK_PACKAGE", find_id)
		command.code = code.text
		var result: Dictionary = GameStore.dispatch(command)
		if result.ok:
			_show_inspection(find_id)
		else:
			feedback.text = result.error
			code.grab_focus()
	_button(modal_body,"Открыть замок",unlock)
	if not find_id.is_empty():
		_button(modal_body,"Вернуть находку на полку",func(): _move_find(find_id, "shelf"))
	code.text_submitted.connect(func(_text_value: String): unlock.call())
	code.grab_focus()

func _lift_lining() -> void:
	if not GameStore.dispatch(_inspection_command("LIFT_LINING", _inspection_find_id)).ok:
		return
	if is_instance_valid(_inspection):
		_inspection.set_lining_lifted(true)
	if is_instance_valid(_lining_button):
		_lining_button.disabled = true
	if is_instance_valid(_observation_text):
		_observation_text.text = "Подкладка приподнята. Осмотрите то, что было под ней."

func _remember_inspection(detail_id: String) -> void:
	var package_id: String = snapshot.package.id if _inspection_find_id.is_empty() else _inspection_find_id
	var view := {"kind":"inspection", "id":package_id, "detail":detail_id}
	var zoom_step: int = _inspection.get_zoom_step()
	if zoom_step > 0:
		view.zoom_step = zoom_step
	GameStore.set_resume_view(view)

func _refresh_inspection_zoom() -> void:
	var step: int = _inspection.get_zoom_step()
	_zoom_caption.text = "%d %%" % roundi(_inspection.zoom_ratio() * 100.0)
	_zoom_out.disabled = step == 0
	_zoom_in.disabled = step == _inspection.MAX_ZOOM_STEP
	_inspection_overview.disabled = step == 0 and _inspection.get_focus_id().is_empty()
	_remember_inspection(_inspection.get_focus_id())

func _refresh_inspection_focus(id: String) -> void:
	if _modal_kind != "inspection":
		return
	_refresh_inspection_zoom()
	var content := _inspection_content()
	var overview := id.is_empty()
	var item := Rules.auxiliary_item(snapshot, _inspection_find_id)
	var observed: Array = snapshot.inspected_details if _inspection_find_id.is_empty() else item.inspected_details
	var recorded := id in observed
	if overview:
		_inspection_caption.text = "П" + content.presentation.number + " · Общий вид"
		_observation_text.text = "Нажмите на деталь или выберите «Следующий ракурс». Чтобы повернуть вещь, потяните мышью с зажатой ЛКМ. Колесо меняет масштаб."
	else:
		_inspection_zone = content.details.keys().find(id)
		_inspection_caption.text = "Крупный план" + (" · " + content.details[id].title if recorded else "")
		if recorded:
			_observation_text.text = content.details[id].text
			if snapshot.case_id == "nina" and _inspection_find_id.is_empty() and Rules.finished_checking(snapshot):
				_observation_text.text += "\n\nДля решения этого достаточно. Можно закончить осмотр или проверить другие детали."
		else:
			_observation_text.text = "Нажмите «Отметить наблюдение», чтобы записать эту примету. Колесо меняет масштаб."
	_record_observation.visible = not overview and not recorded
	for button in _inspection_turns:
		button.disabled = not overview

func _show_conversation(arrival: bool = false, resume_line: int = 0) -> void:
	if snapshot.get("case_status","") != "active":
		return
	_close_modal()
	_focus("window")
	_begin_modal("Нина Лукина" if snapshot.case_id == "finale" else _p().name,"dialogue")
	_speech_at_bus = false
	_speech_arrival = arrival
	_speech_prefix = 0
	dialogue_text = _text(modal_body,"",21)
	dialogue_text.name = "SpeechText"
	# A bounded text area avoids transient auto-height from an unlaid-out width.
	dialogue_text.fit_content = false
	dialogue_text.scroll_active = true
	dialogue_text.custom_minimum_size.y = 98
	_speech_choices = VBoxContainer.new()
	_speech_choices.add_theme_constant_override("separation", 3)
	modal_body.add_child(_speech_choices)
	var speech: String = GameStore.content.dialogues.get(snapshot.dialogue_id, "")
	var gleb: Dictionary = snapshot.completed_cases.get("gleb", {})
	if arrival and snapshot.case_id == "serov" and not gleb.is_empty() and not gleb.get("after_orlov_call", false):
		_speech_prefix = 1
		var camera_outcome: String = gleb.decision
		speech = GameStore.content.camera_followup[camera_outcome] + "\n" + speech
	elif snapshot.case_id == "finale":
		var lunch_outcome: String = snapshot.completed_cases.nina.decision
		speech += "\n" + GameStore.content.lunch_followup[lunch_outcome]
	_set_speech(speech, resume_line)

func _set_speech(text_value: String, resume_line: int = 0) -> void:
	_speech_parts.clear()
	if text_value.contains("\n"):
		for line in text_value.split("\n", false):
			_speech_parts.append(line.strip_edges())
		_speech_index = clampi(resume_line, 0, _speech_parts.size() - 1)
		_refresh_speech()
		return
	var current := ""
	for sentence in text_value.split(". "):
		if current.length()+sentence.length() > 155 and not current.is_empty():
			_speech_parts.append(current.strip_edges())
			current = ""
		var punctuation: bool = sentence.ends_with(".") or sentence.ends_with("?") or sentence.ends_with("!") or sentence.ends_with("…")
		current += sentence + (" " if punctuation else ". ")
	if not current.strip_edges().is_empty():
		_speech_parts.append(current.strip_edges())
	if _speech_parts.is_empty():
		_speech_parts.append(text_value)
	_speech_index = clampi(resume_line, 0, _speech_parts.size() - 1)
	_refresh_speech()

func _refresh_speech() -> void:
	var line := _speech_parts[_speech_index]
	GameStore.set_resume_view({"kind":"dialogue", "line":_speech_index, "arrival":_speech_arrival})
	dialogue_text.text = line
	_speech_heading.modulate.a = 0.0 if VisitorActing.SPEAKERS.has(line.get_slice(":", 0)) else 1.0
	_speak_line(line, snapshot.case_id, snapshot.dialogue_id, maxi(0, _speech_index - _speech_prefix))
	_clear(_speech_choices)
	if _speech_index < _speech_parts.size()-1:
		_layout_dialogue(185)
		_dialogue_button(_speech_choices,"Далее",func():
			_speech_index += 1
			_refresh_speech())
		return
	var definition: Dictionary = Cases.get_case(snapshot.case_id)
	var topics := GridContainer.new()
	topics.columns = 2
	topics.add_theme_constant_override("h_separation", 24)
	topics.add_theme_constant_override("v_separation", 3)
	_speech_choices.add_child(topics)
	var shown := 0
	for id in definition.topics:
		var topic: String = id
		if topic == "contents_probe" and "show_contents" in snapshot.asked_topics:
			continue
		if definition.topic_requires.has(topic) and definition.topic_requires[topic] not in snapshot.inspected_details:
			continue
		var option := _dialogue_button(topics,GameStore.content.topic_labels[topic],func():
			if GameStore.dispatch({"type":"ASK_TOPIC","topic_id":topic}).ok:
				_speech_prefix = 0
				_speech_arrival = false
				_set_speech(GameStore.content.dialogues[topic]))
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shown += 1
	_layout_dialogue(185 + ceili(shown / 2.0) * 33)
	_dialogue_button(_speech_choices,"К работе",_close_modal)

func _layout_dialogue(height: float) -> void:
	modal.size.y = height
	_align_dialogue_bottom(modal)

func _align_dialogue_bottom(panel: Control) -> void:
	panel.position.y = size.y - 12.0 - panel.size.y

func _dialogue_button(parent: Node, label: String, action: Callable) -> Button:
	var button := _button(parent, label, action)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 29
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _style(Color(0.34, 0.40, 0.34, 0.26), Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("pressed", _style(Color(0.34, 0.40, 0.34, 0.43), Color.TRANSPARENT, 0))
	return button

func _speak_line(line: String, case_id: String, dialogue: String, index: int) -> void:
	var speaker := VisitorActing.speaker(line, case_id)
	var pose := VisitorActing.pose(case_id, dialogue, index, speaker)
	var voice_length := 0.60 if speaker == VisitorActing.actor(case_id) or speaker in ["vera", "leonid"] else 0.0
	dialogue_pose_changed.emit(pose, voice_length, _speech_at_bus)
	_sound.speak(speaker, line)

func _show_decision() -> void:
	if snapshot.case_id == "finale":
		_take_card()
		return
	_begin_modal("Куда отправить находку?","decision")
	_text(modal_body,"Обращение № " + _p().number + " · " + _p().name,16,MUTED)
	if snapshot.case_id == "nina":
		_text(modal_body,"Выдача передаст вещь Нине. Хранение вернёт её на общую полку до востребования. Под столом вещь останется у вас.",17)
	if not Rules.finished_checking(snapshot):
		_text(modal_body,"Можно оформить решение сейчас или продолжить проверку.",16,GOLD)
	var definition: Dictionary = Cases.get_case(snapshot.case_id)
	for id in definition.recipients:
		var recipient: String = id
		var action := _show_hatch.bind(recipient) if snapshot.package.id in ["P01", "P03"] else _decide.bind("ISSUE_PACKAGE", recipient)
		_button(modal_body,_p().recipient_captions[recipient],action)
	_button(modal_body,"Завершить обращение · оставить на хранении",func(): _decide("RETAIN_PACKAGE"))
	if definition.allow_appropriate:
		_button(modal_body,_p().appropriate_caption,func(): _decide("APPROPRIATE_PACKAGE"))
	if snapshot.case_id == "gleb":
		_button(modal_body,"Отложить · принять Серова",_defer_camera)
	_button(modal_body,"Пока не решать",_close_modal)

func _show_hatch(recipient: String) -> void:
	_close_modal()
	_focus("window")
	_begin_modal("Передаточный шлюз · П" + _p().number, "hatch")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_body.add_child(row)
	var stage := HatchStage.new()
	stage.name = "HatchStage"
	stage.item_id = snapshot.package.id
	row.add_child(stage)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 308
	row.add_child(controls)
	var suitcase := stage.item_id == "P03"
	_text(controls, "Зажмите ЛКМ над подносом и тяните вверх или вниз. ПКМ поворачивает чемодан." if suitcase else "Зажмите ЛКМ над подносом и мягко подайте его к светлым меткам. Резкий рывок встряхнёт блюдце.", 17)
	_action(controls,"Подать вперёд",stage.nudge.bind(0.15))
	_action(controls,"Потянуть к себе",stage.nudge.bind(-0.15))
	var strap: Button
	if suitcase:
		_action(controls,"Повернуть на 90°",stage.turn.bind(PI / 2.0))
		strap = _action(controls,"Убрать ремешок",stage.tuck_handle)
		strap.disabled = true
	var feedback := _text(controls,"",17,GOLD)
	feedback.name = "HatchFeedback"
	var confirm := _button(modal_body,"Подписать и передать" if not suitcase else "Закончить передачу",func():
		if stage.ready_to_deliver():
			var handling := "jolted" if stage.jolted else "steady"
			_decide("ISSUE_PACKAGE",recipient,handling))
	confirm.disabled = true
	var update := func():
		feedback.text = stage.message
		confirm.disabled = not stage.ready_to_deliver()
		if is_instance_valid(strap):
			strap.disabled = not stage.caught
	stage.changed.connect(update)
	stage.contact.connect(func(): play_cue("latch"))
	_button(modal_body,"Вернуться к решению",_show_decision)
	GameStore.set_resume_view({"kind":"hatch", "id":recipient})

func _defer_camera() -> void:
	_close_modal()
	if GameStore.dispatch({"type":"DEFER_GLEB"}).ok:
		_focus("window")
		_show_hint("Камера осталась на полке. Серов подходит к окну.")

func _show_deferred_camera() -> void:
	if not snapshot.has("deferred_gleb"):
		return
	var already_heard: bool = snapshot.get("orlov_heard", false)
	if not already_heard and not GameStore.dispatch({"type":"HEAR_ORLOV"}).ok:
		return
	_begin_modal("Дело Глеба · камера", "camera_call")
	_text(modal_body,"Николай Орлов по телефону: Верх серебристый. Я зашил ремешок у левого ушка. Ещё там три луковицы. Оставьте сумку до утра, я зайду.",20)
	var deferred: Dictionary = snapshot.deferred_gleb
	_text(modal_body,"Камера на полке. Глеб ждёт в зале." if deferred.package.location == "shelf" else "Камера на столе. Глеб ждёт в зале.",17,GOLD)
	if not deferred.inspected_details.is_empty():
		var details: Dictionary = GameStore.get_case_content("gleb").details
		var sightings := PackedStringArray()
		for detail in deferred.inspected_details:
			sightings.append(details[detail].title)
		_text(modal_body,"Уже отмечено · " + ", ".join(sightings),16,MUTED)
	var inspect := _button(modal_body,"Осмотреть камеру",func():
		_close_modal()
		if snapshot.deferred_gleb.package.location == "shelf":
			if GameStore.dispatch({"type":"MOVE_PACKAGE", "package_id":"P04", "destination":"desk"}).ok:
				_show_inspection("P04")
		else:
			_show_inspection("P04"))
	inspect.disabled = Rules.desk_package_id(snapshot) not in ["", "P04"]
	inspect.tooltip_text = "Сначала освободите стол." if inspect.disabled else ""
	_button(modal_body,"Оставить для Орлова",_resolve_deferred_camera.bind("retain"))
	_button(modal_body,"Всё равно выдать Глебу",_resolve_deferred_camera.bind("issue"))
	_button(modal_body,"Убрать камеру под стол",_resolve_deferred_camera.bind("appropriate"))
	_button(modal_body,"Вернуться к Серову",_close_modal)
	GameStore.set_resume_view({"kind":"camera_call"})

func _resolve_deferred_camera(decision: String) -> void:
	if not GameStore.dispatch({"type":"RESOLVE_DEFERRED_GLEB", "decision":decision}).ok:
		return
	_close_modal()
	play_cue("paper")
	_show_hint({"retain":"Камера осталась на полке для Орлова.", "issue":"Глеб забрал камеру. Для Орлова осталась запись о выдаче.", "appropriate":"Камера под столом. Орлов придёт утром."}[decision])

func _show_camera_comparison() -> void:
	_begin_modal("Заявление и находка", "camera_evidence")
	_text(modal_body,"Выберите строку из заявления и то, что заметили в сумке. Совпадения тоже можно проверить.",18)
	var claims := OptionButton.new()
	var evidence := OptionButton.new()
	for line in ["Камера: корпус чёрный", "Два рулона плёнки", "Ремень потёрт слева"]:
		claims.add_item(line)
	for id in snapshot.inspected_details:
		evidence.add_item(GameStore.content.details[id].title)
	for select in [claims, evidence]:
		select.custom_minimum_size.y = 40
		modal_body.add_child(select)
		select.select(0)
	var feedback := _text(modal_body,"",17,GOLD)
	_button(modal_body,"Сопоставить",func():
		var detail: String = snapshot.inspected_details[evidence.selected]
		var expected: String = ["camera_body", "onions", "strap"][claims.selected]
		if detail != expected:
			feedback.text = "Это разные приметы. Попробуйте подобрать наблюдение к этой строке."
			return
		if detail == "strap":
			feedback.text = "Место совпадает. Проверьте, может ли Глеб описать саму штопку."
			return
		var topic := "body_mismatch" if detail == "camera_body" else "film_mismatch"
		if GameStore.dispatch({"type":"ASK_TOPIC", "topic_id":topic}).ok:
			_show_conversation())

func _decide(type: String, recipient: String = "", handling: String = "") -> void:
	var command := {"type":type}
	if type == "ISSUE_PACKAGE":
		command.recipient = recipient if not recipient.is_empty() else (Cases.get_case(snapshot.case_id).recipients[0] if Cases.get_case(snapshot.case_id).recipients.size() == 1 else "")
		if not handling.is_empty():
			command.handling = handling
	if not GameStore.dispatch(command).ok:
		return
	if snapshot.case_id == "nina" and not handling.is_empty():
		play_cue("stamp")
	_close_modal()
	_focus("window" if type == "ISSUE_PACKAGE" else ("shelf" if type == "RETAIN_PACKAGE" else "personal"))
	_action_panel.hide()
	_show_hint("Обращение завершено.")
	_begin_modal(_p().first_name,"result")
	var outcome := Cases.outcome_key(snapshot)
	var reaction: String = GameStore.content.reactions[outcome]
	if handling == "jolted":
		reaction = "Ох, блюдце звякнуло. Давай сюда, я потом поправлю салфетку. Спасибо, Павел."
	_text(modal_body,reaction,21)
	_speech_at_bus = false
	_speak_line(reaction.get_slice("\n", 0), snapshot.case_id, outcome, 0)
	var buttons := HBoxContainer.new()
	modal_body.add_child(buttons)
	_button(buttons,"К работе",_close_modal)
	_add_next_button(buttons)
	_button(buttons,"Начать заново",_restart)

func _take_card() -> void:
	if GameStore.dispatch({"type":"TAKE_CARD"}).ok:
		_close_modal()
		_focus("desk")
		play_cue("paper")

func _render_card_actions() -> void:
	if snapshot.card_location == "archive_draft":
		_action(sidebar,"Открыть дополнение",_show_archive_draft)
	else:
		_label(sidebar,"КАРТОЧКА У ВАС",13,GOLD)
		_action(sidebar,"Посмотреть на Серова",func(): _focus("bus"))
		_action(sidebar,"Посмотреть на архив",func(): _focus("archive"))
		_action(sidebar,"Посмотреть под стол",func(): _focus("personal_bag"))
		_text(sidebar,"Щёлкните по Серову, папке архива или личному месту.",16,MUTED)
	_action(sidebar,"Вернуть карточку в сумку",_return_card)

func _card_target(target_id: String) -> bool:
	if snapshot.case_id != "finale" or snapshot.case_status != "active":
		return false
	if snapshot.card_location == "hand":
		match target_id:
			"serov": _finish_shift("serov")
			"personal_bag": _finish_shift("keep")
			"archive":
				if GameStore.dispatch({"type":"FILE_CARD"}).ok:
					_show_archive_draft()
			_: return false
		return true
	if snapshot.card_location == "archive_draft" and target_id == "archive":
		_show_archive_draft()
		return true
	return false

func _return_card() -> void:
	if GameStore.dispatch({"type":"RETURN_CARD"}).ok:
		_close_modal()
		_focus("desk")
		play_cue("paper")

func _show_archive_draft() -> void:
	if snapshot.card_location != "archive_draft":
		return
	_begin_modal("Дополнение к акту 2014 года", "archive_draft")
	modal.position = Vector2(36, 118)
	modal.size = Vector2(750, 680)
	_document(modal_body, _supplement_record(false), "supplement_draft")
	_button(modal_body,"Подписать дополнение",func(): _finish_shift("archive"))
	_button(modal_body,"Вернуть карточку в сумку",_return_card)
	GameStore.set_resume_view({"kind":"archive_draft"})
	play_cue("paper")

func _supplement_record(signed: bool) -> Dictionary:
	var record: Dictionary = GameStore.content.archive_supplement.duplicate()
	record.text += "\n\nПодпись: " + ("Павел Фомин" if signed else "________________")
	return record

func _finish_shift(ending: String) -> void:
	if not GameStore.dispatch({"type":"FINAL_ACTION", "ending":ending}).ok:
		return
	play_cue("stamp" if ending == "archive" else "paper")
	_show_ending()

func _show_ending() -> void:
	_close_modal()
	_focus({"serov":"bus", "archive":"archive", "keep":"personal_bag"}[snapshot.decision])
	_begin_modal("Последняя смена", "ending")
	GameStore.set_resume_view({"kind":"ending"})
	var heading := _label(modal_body, _p().outcomes[snapshot.decision], 22, GOLD)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reaction: String = GameStore.content.reactions[snapshot.decision]
	_text(modal_body, reaction, 18)
	_rule(modal_body)
	_label(modal_body, "ЧТО СТАЛО С НАХОДКАМИ", 14, GOLD)
	for case_id in Cases.ORDER:
		if case_id == "finale":
			continue
		var record: Dictionary = snapshot.completed_cases[case_id]
		var presentation: Dictionary = GameStore.get_case_content(case_id).presentation
		_label(modal_body, "П" + presentation.number + "  " + presentation.outcomes[Cases.outcome_key(record)], 17)
	for id in Cases.LOOSE_FINDS:
		var title: String = GameStore.loose_finds[id].presentation.package_title
		_label(modal_body, title + (" · на полке" if snapshot.loose_finds[id].location == "shelf" else " · на столе"), 17)
	var bag_place := "в личном месте" if snapshot.package.location == "personal" else "на полке"
	_label(modal_body, "П08 · Синяя сумка " + bag_place, 17)
	if snapshot.get("shift_closed", false):
		_label(modal_body, "Лампа погашена. Последний рейс ушёл.", 17, GOLD)
	else:
		var close_text: String = {
			"keep":"Застегнуть сумку и погасить лампу",
			"archive":"Закрыть архив и погасить лампу",
			"serov":"Погасить лампу после отправления"
		}[snapshot.decision]
		_button(modal_body, close_text, _shut_off_desk)
	var buttons := HBoxContainer.new()
	modal_body.add_child(buttons)
	_button(buttons,"Осмотреть бюро",_close_modal)
	_button(buttons,"Начать новую смену",_restart)
	_button(buttons,"Выйти",_quit_game)

func _shut_off_desk() -> void:
	if GameStore.dispatch({"type":"CLOSE_SHIFT"}).ok:
		_close_modal()
		_focus("desk")
		play_cue("boarding")
		_show_hint("Лампа погашена. Последний рейс ушёл.")

func _show_journal() -> void:
	if not snapshot.get("started", false) or is_instance_valid(modal):
		return
	_begin_modal("Журнал · " + _p().name, "journal")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_body.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(entries)
	if snapshot.read_documents.is_empty() and snapshot.inspected_details.is_empty() and snapshot.asked_topics.is_empty():
		_text(entries,"Записи появятся, когда вы откроете бумаги, осмотрите находку или зададите вопрос.",18)
	for id in snapshot.read_documents:
		var paper: Dictionary = GameStore.content.documents[id]
		_label(entries,paper.title,19,GOLD)
		_text(entries,paper.text,17)
	for id in snapshot.inspected_details:
		var detail: Dictionary = GameStore.content.details[id]
		_label(entries,detail.title,19,GOLD)
		_text(entries,detail.text,17)
	for id in snapshot.asked_topics:
		_label(entries,GameStore.content.topic_labels[id],19,GOLD)
		_text(entries,GameStore.content.dialogues[id],17)
	_button(modal_body,"К работе",_close_modal)

func _make_start_screen() -> Control:
	var screen := ColorRect.new()
	screen.color = Color(0.015,0.022,0.020,0.48)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var rules := _panel(screen,Color(0.035,0.043,0.035,0.88))
	rules.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rules.offset_left = 68
	rules.offset_right = -580
	rules.offset_top = 100
	rules.offset_bottom = -100
	var content := VBoxContainer.new()
	rules.add_child(_margin(content,52,38))
	_label(content,"СТАРЫЙ АВТОВОКЗАЛ   /   СЛУЖБА ХРАНЕНИЯ",15,GOLD)
	var title := _label(content,"ДО\nВОСТРЕБОВАНИЯ",65,LIGHT)
	title.add_theme_font_override("font",_heading_font)
	_label(content,"ПОСЛЕДНЯЯ СМЕНА",18,GOLD)
	var gap := Control.new()
	gap.custom_minimum_size.y = 23
	content.add_child(gap)
	_text(content,"Вы Павел Фомин, дежурный бюро находок. Сегодня старый автовокзал закрывается, и вам предстоит принять последних посетителей.",21)
	var content_ok: bool = GameStore.content_errors.is_empty()
	var saved: Dictionary = GameStore.read_saved_shift() if content_ok else {}
	if not saved.is_empty():
		var resume := _button(content,"Продолжить смену",_resume_shift)
		resume.custom_minimum_size = Vector2(360, 49)
		resume.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var start := _button(content,"Начать смену",_request_start_shift)
	start.disabled = not content_ok
	if not saved.is_empty():
		start.tooltip_text = "Начать новую смену с Нины и заменить автосохранение."
	start.custom_minimum_size.y = 49
	start.custom_minimum_size.x = 360
	start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var exit_button := _button(content,"Выйти",_quit_game)
	exit_button.custom_minimum_size.x = 360
	exit_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var settings := VBoxContainer.new()
	content.add_child(settings)
	var mute := CheckButton.new()
	mute.text = "Играть без звука"
	mute.button_pressed = _muted
	mute.toggled.connect(_set_muted)
	settings.add_child(mute)
	var motion := CheckButton.new()
	motion.text = "Уменьшить движение камеры"
	motion.button_pressed = _reduced
	motion.toggled.connect(_set_reduced_motion)
	settings.add_child(motion)
	_menu_status = _label(content,"Мышь — предметы  ·  ПКМ — осмотреться
Escape — пауза",15,MUTED)
	if not content_ok:
		_menu_status.text = "Не удалось загрузить игру. " + GameStore.content_errors[0]
		_menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif saved.get("recovered", false):
		_menu_status.text = "Найдена резервная копия смены."
	elif saved.is_empty() and GameStore.has_save_files():
		_menu_status.text = "Сохранение повреждено. Можно начать новую смену."
	_label(content,"БЮРО № 4                        15 ОКТЯБРЯ 2026",13,GOLD).add_theme_font_override("font",_typewriter_font)
	return screen

func _request_start_shift() -> void:
	if GameStore.has_save_files():
		_confirm("Начать новую смену?", "Текущее автосохранение будет заменено.", "Начать заново", _start_shift)
	else:
		_start_shift()

func _start_shift() -> void:
	if _booting or snapshot.get("started",false):
		return
	_booting = true
	_menu_status.text = "Открываем смену…"
	await get_tree().process_frame
	await get_tree().process_frame
	if not GameStore.dispatch({"type":"START"}).ok:
		_booting = false
		return
	await _open_workstation()
	_show_briefing()

func _resume_shift() -> void:
	if _booting:
		return
	_booting = true
	var saved: Dictionary = GameStore.continue_shift()
	if saved.is_empty():
		_menu_status.text = "Сохранение не удалось прочитать."
		_booting = false
		return
	await _open_workstation()
	_restore_panel(saved.view)
	_present_arrival_dialogue()
func _open_workstation() -> void:
	if not _reduced:
		var fade := create_tween()
		fade.tween_property(_start_screen,"modulate:a",0.0,0.35)
		await fade.finished
	_start_screen.queue_free()
	_start_screen = null
	_hud.show()
	modal_changed.emit(false)
	_sound.start(_muted)
	_focus("window")

func _show_briefing() -> void:
	_begin_modal("Записка дежурному", "briefing")
	_label(modal_body, "Павлу Фомину · Бюро находок № 4", 19, GOLD).add_theme_font_override("font", _typewriter_font)
	_text(modal_body, "Паша, сегодня старый автовокзал закрывают. Прими последних посетителей. Первой подойдёт Нина из хозяйственной службы.", 22)
	_text(modal_body, "Сверь удостоверение и заявление, потом сними вещь с полки и проверь приметы на столе. Если сомневаешься, оставь её на хранении. Утром дежурный передаст оставшиеся вещи в новый терминал.", 22)
	_rule(modal_body)
	_text(modal_body, "Щёлкайте по предметам и бумагам. Кнопки внизу переводят взгляд, а подсказка укажет следующий шаг.", 17, MUTED)
	var start := _button(modal_body, "К окну бюро", _close_modal)
	start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	start.custom_minimum_size.x = 200
	GameStore.set_resume_view({"kind":"briefing"})

func _restore_panel(view: Dictionary) -> void:
	var id: String = view.get("id", "")
	match view.get("kind", ""):
		"briefing":
			_show_briefing()
		"dialogue":
			_arrival_dialogue_pending = false
			_show_conversation(view.get("arrival", false), int(view.get("line", 0)))
			render(snapshot)
		"hatch":
			_arrival_dialogue_pending = false
			_show_hatch(id)
		"camera_call":
			_show_deferred_camera()
		"document":
			if id == "clerk_identity":
				_show_clerk_id()
			elif id == "old_act":
				_show_old_act()
			else:
				_show_document(id)
		"comparison":
			if id == "card":
				_show_final_papers()
			elif id in ["vera", "leonid"]:
				_show_comparison([id + "_identity", id + "_claim"])
			else:
				_show_comparison()
		"inspection":
			_show_inspection("" if id == snapshot.package.id else id)
			var detail: String = view.get("detail", "")
			if is_instance_valid(_inspection):
				if not detail.is_empty():
					_inspection.focus_detail(detail)
				_inspection.set_zoom_step(int(view.get("zoom_step", 0)))
		"archive_draft":
			_show_archive_draft()
		"ending":
			_show_ending()

func _show_pause() -> void:
	if is_instance_valid(_start_screen) or _modal_kind == "pause":
		return
	_begin_modal("Перерыв","pause")
	_text(modal_body,"Сверьте бумаги, осмотрите вещь на столе и решите её судьбу. Следующий шаг показан в левом углу.\n\nЛКМ выбирает предмет. Удерживайте ПКМ, чтобы осмотреться. Клавиши 1–4 переводят взгляд. В осмотре потяните вещь мышью или приблизьте её колесом.\n\nСмена сохраняется автоматически.",18)
	var mute := CheckButton.new()
	mute.text = "Выключить звук"
	mute.button_pressed = _muted
	mute.toggled.connect(_set_muted)
	modal_body.add_child(mute)
	var motion := CheckButton.new()
	motion.text = "Уменьшить движение камеры"
	motion.button_pressed = _reduced
	motion.toggled.connect(_set_reduced_motion)
	modal_body.add_child(motion)
	_button(modal_body,"Продолжить",_close_modal)
	if GameStore.persistence_enabled:
		_save_message = _label(modal_body,"",15,MUTED)
		_save_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_save_message.hide()
		_button(modal_body,"Сохранить смену",_save_now)
	_button(modal_body,"Начать смену заново",_restart)
	_button(modal_body,"В главное меню",_return_to_title)
	_button(modal_body,"Выйти из игры",_quit_game)

func _save_now() -> void:
	if GameStore.save_progress():
		_show_save_error("Смена сохранена.")

func _show_save_error(message: String) -> void:
	if _modal_kind == "pause" and is_instance_valid(_save_message):
		_save_message.text = message
		_save_message.show()
	else:
		_show_hint(message)
		hint.show()

func _quit_game() -> void:
	if snapshot.get("started", false) and GameStore.persistence_enabled and not GameStore.save_progress():
		_confirm("Выйти без сохранения?", "Последние изменения останутся только в этой открытой смене.", "Выйти без сохранения", get_tree().quit)
		return
	get_tree().quit()

func _confirm(title: String, message: String, accept_label: String, action: Callable) -> void:
	if is_instance_valid(_confirmation):
		return
	var dialog := ConfirmationDialog.new()
	_confirmation = dialog
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = accept_label
	dialog.cancel_button_text = "Отмена"
	add_child(dialog)
	dialog.confirmed.connect(func():
		dialog.hide()
		_confirmation = null
		dialog.queue_free()
		action.call())
	dialog.canceled.connect(func():
		dialog.hide()
		_confirmation = null
		dialog.queue_free())
	dialog.popup_centered()

func _return_to_title() -> void:
	if not GameStore.leave_shift():
		return
	_close_modal(true)
	_close_modal(true)
	_booting = false
	_visitor_ready = false
	_arrival_dialogue_pending = false
	_sound.stop()
	_hud.hide()
	_start_screen = _make_start_screen()
	modal_changed.emit(true)

func _begin_modal(title: String, kind: String) -> void:
	if kind == "pause":
		_pause_return = {"panel":modal, "body":modal_body if is_instance_valid(modal) else null, "kind":_modal_kind}
		if is_instance_valid(modal):
			modal.hide()
			modal.process_mode = Node.PROCESS_MODE_DISABLED
		_set_paused(true)
	else:
		_close_modal()
	_modal_kind = kind
	_set_dialogue_presentation(kind == "dialogue")
	_task_panel.hide()
	hint.hide()
	interaction_hint.hide()
	_action_panel.hide()
	_actions_button.disabled = true
	_journal_button.disabled = true
	modal = _panel(self,Color(0.025,0.035,0.028,0.83) if kind in ["dialogue","result"] else DARK)
	modal.name = "ContentPanel"
	var rect: Rect2
	match kind:
		"dialogue":
			rect = Rect2(270, 703, 900, 185)
			modal.add_theme_stylebox_override("panel", _style(Color(0.013, 0.019, 0.016, 0.89), Color.TRANSPARENT, 0))
		"result": rect = Rect2(30,480,740,340) if snapshot.case_id == "melnikovs" else Rect2(30,570,620,250)
		"document": rect = Rect2(36,118,555,680)
		"comparison": rect = Rect2(36,500,1100,320)
		"inspection": rect = Rect2(36,240,990,580)
		"decision": rect = Rect2(670,445,730,375) if snapshot.case_id in ["nina", "gleb"] else Rect2(670,500,730,320)
		"hatch": rect = Rect2(186,115,1068,681)
		"camera_call": rect = Rect2(190,190,690,505)
		"camera_evidence": rect = Rect2(320,225,770,395)
		"journal": rect = Rect2(288,117,864,688)
		"briefing": rect = Rect2(66, 194, 612, 388)
		"ending": rect = Rect2(34,235,650,585)
		"pause": rect = Rect2(410,160,620,630)
		_: rect = Rect2(410,190,620,560)
	modal.position = rect.position
	modal.size = rect.size
	modal_body = VBoxContainer.new()
	modal.add_child(_margin(modal_body,18,14))
	var top := HBoxContainer.new()
	modal_body.add_child(top)
	var heading := _label(top,title,15 if kind == "dialogue" else 21,GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := _dialogue_button(top, "Закрыть · Esc", _close_modal) if kind == "dialogue" else _button(top,"Закрыть · Esc",_close_modal)
	close.add_theme_font_size_override("font_size",14)
	close.custom_minimum_size.y = 28
	if kind == "dialogue":
		_speech_heading = heading
		modal_body.add_theme_constant_override("separation", 4)
		modal.resized.connect(_align_dialogue_bottom.bind(modal))
		_align_dialogue_bottom(modal)
	else:
		_rule(modal_body)
	modal_changed.emit(kind not in ["dialogue","result"])

func _set_dialogue_presentation(active: bool) -> void:
	_brand.visible = not active
	objective.visible = not active
	_footer.visible = not active
	_actions_button.visible = not active
	_journal_button.visible = not active
	dialogue_framing_changed.emit(active, snapshot.get("case_id") == "melnikovs")

func _set_paused(value: bool) -> void:
	get_tree().paused = value
	_sound.set_paused(value)

func _close_modal(keep_resume: bool = false) -> void:
	if _modal_kind == "pause":
		modal.hide()
		modal.queue_free()
		modal = _pause_return.panel
		modal_body = _pause_return.body
		_modal_kind = _pause_return.kind
		_pause_return.clear()
		_set_paused(false)
		if is_instance_valid(modal):
			modal.process_mode = Node.PROCESS_MODE_INHERIT
			modal.show()
			_set_dialogue_presentation(_modal_kind == "dialogue")
			modal_changed.emit(_modal_kind not in ["dialogue", "result"])
			return
	if _modal_kind in ["dialogue", "result"]:
		_sound.stop_speech()
		dialogue_pose_changed.emit(0, 0.0, _speech_at_bus)
		_speech_at_bus = false
		_set_dialogue_presentation(false)
	if not keep_resume:
		GameStore.set_resume_view({})
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal = null
	modal_body = null
	_modal_kind = ""
	_inspection_find_id = ""
	_task_panel.show()
	hint.show()
	_actions_button.disabled = false
	_journal_button.disabled = false
	_refresh_interaction_hint()
	if is_instance_valid(_action_panel) and snapshot.get("started",false):
		_action_panel.show()
	modal_changed.emit(false)
	_present_arrival_dialogue.call_deferred()

func _restart() -> void:
	if GameStore.persistence_enabled:
		_confirm("Начать смену заново?", "Ход этой смены будет заменён.", "Начать заново", _restart_shift)
	else:
		_restart_shift()

func _restart_shift() -> void:
	if not GameStore.restart_shift():
		return
	_close_modal()
	_close_modal()
	_action_panel.show()
	_focus("window")
	_show_briefing()

func _focus(view_id: String) -> void:
	if is_instance_valid(modal) and _modal_kind not in ["dialogue","result"]:
		return
	_view = view_id
	focus_requested.emit(view_id)
	_render_task()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal): _close_modal()
		else: _show_pause()
		get_viewport().set_input_as_handled()
	if not snapshot.get("started",false):
		return
	if event.keycode == KEY_F1:
		_toggle_actions()
		get_viewport().set_input_as_handled()
	var views := {KEY_1:"window",KEY_2:"shelf",KEY_3:"desk",KEY_4:"personal"}
	if views.has(event.keycode):
		_focus(views[event.keycode])
		get_viewport().set_input_as_handled()

func _show_hint(message: String) -> void:
	if is_instance_valid(hint): hint.text = message

func _toggle_actions() -> void:
	if snapshot.get("started",false) and not is_instance_valid(modal):
		_action_panel.visible = not _action_panel.visible

func set_hovered_target(target_id: String) -> void:
	_hovered_target = target_id
	_refresh_interaction_hint()

func _refresh_interaction_hint() -> void:
	if not is_instance_valid(interaction_hint):
		return
	var text_value := ""
	if snapshot.get("started",false) and not is_instance_valid(modal):
		if snapshot.case_id == "finale" and snapshot.case_status == "active" and snapshot.card_location == "hand" and _hovered_target in ["serov", "archive", "personal_bag"]:
			text_value = "ЛКМ · " + {"serov":"Передать карточку Серову", "archive":"Положить карточку в архив", "personal_bag":"Убрать сумку вместе с карточкой"}[_hovered_target]
		elif _hovered_target == "serov" and _serov_at_bus:
			text_value = "ЛКМ · Поговорить с Серовым у рейса"
		elif not Rules.auxiliary_item(snapshot, _hovered_target).is_empty():
			text_value = "ЛКМ · " + ("Поставить находку на стол" if Rules.auxiliary_item(snapshot, _hovered_target).location == "shelf" else "Осмотреть находку")
		elif _hovered_target == "clerk_identity":
			text_value = "ЛКМ · Прочитать удостоверение Павла"
		elif _hovered_target == "archive":
			text_value = "ЛКМ · Прочитать акт 2014 года"
		elif snapshot.case_status != "active":
			pass
		elif _hovered_target == snapshot.package.id:
			text_value = "ЛКМ · " + ("Поставить " + _p().item_accusative + " на стол" if snapshot.package.location == "shelf" else "Открыть и осмотреть " + _p().item_accusative)
		elif _hovered_target == snapshot.case_id:
			text_value = "ЛКМ · " + _p().talk_hint
		else:
			match _hovered_target:
				"identity": text_value = "ЛКМ · Прочитать удостоверение"
				"claim": text_value = "ЛКМ · Прочитать заявление"
				"archive": text_value = "ЛКМ · Папка старых дел"
				"hatch": text_value = "ЛКМ · Передаточный блок"
	interaction_hint.text = text_value
	interaction_hint.visible = not text_value.is_empty()

func _p() -> Dictionary:
	return GameStore.content.presentation

func set_can_advance(value: bool) -> void:
	var changed := _can_advance != value
	_can_advance = value
	for button in find_children("NextCase", "Button", true, false):
		button.disabled = not _advance_available()
	if changed:
		_render_task()

func _advance_available() -> bool:
	return _can_advance and not snapshot.has("deferred_gleb") and (snapshot.case_id != "serov" or snapshot.old_act_read)

func _add_next_button(parent: Node) -> void:
	if Cases.has_next(snapshot.case_id):
		var after_serov: bool = snapshot.case_id == "serov"
		var button := _button(parent,"Продолжить смену" if after_serov else "Следующий посетитель",_next_case)
		button.name = "NextCase"
		button.disabled = not _advance_available()
		button.tooltip_text = "Посетитель должен отойти от стойки, а передаточный блок — закрыться."
		if snapshot.has("deferred_gleb"):
			button.tooltip_text = "Сначала решите, что делать с камерой."
			_button(parent,"Дело Глеба · камера",_show_deferred_camera)
		if after_serov and not snapshot.old_act_read:
			button.tooltip_text = "Сначала прочитайте акт 2014 года."
			_button(parent,"Акт 2014 года",_show_old_act)

func _next_case() -> void:
	if not _advance_available() or snapshot.case_status != "resolved":
		return
	_close_modal()
	_visitor_ready = false
	_arrival_dialogue_pending = false
	_can_advance = false
	if GameStore.dispatch({"type":"NEXT_CASE"}).ok:
		_focus("window")
		_show_hint("Следующий посетитель подходит к стойке.")

func _set_muted(value: bool) -> void:
	_muted = value
	_sound.set_muted(value)
	GameStore.save_preferences(_muted, _reduced)

func _set_reduced_motion(value: bool) -> void:
	_reduced = value
	motion_changed.emit(value)
	GameStore.save_preferences(_muted, _reduced)

func play_cue(id: String) -> void:
	_sound.cue(id)

func _label(parent: Node, text_value: String, font_size: int = 19, color: Color = LIGHT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _text(parent: Node, text_value: String, font_size: int = 19, color: Color = LIGHT) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.text = text_value
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size",font_size)
	label.add_theme_color_override("default_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 37
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _action(parent: Node, text_value: String, callback: Callable) -> Button:
	var button := _button(parent,text_value,callback)
	button.add_theme_font_size_override("font_size",16)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button

func _rule(parent: Node) -> void:
	var line := HSeparator.new()
	line.custom_minimum_size.y = 2
	var stroke := StyleBoxLine.new()
	stroke.color = Color(0.51,0.54,0.44,0.38)
	stroke.thickness = 1
	line.add_theme_stylebox_override("separator",stroke)
	parent.add_child(line)

func _panel(parent: Node, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",_style(color,Color("66705a")))
	parent.add_child(panel)
	return panel

func _margin(child: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for property in ["margin_left","margin_right"]: margin.add_theme_constant_override(property,horizontal)
	for property in ["margin_top","margin_bottom"]: margin.add_theme_constant_override(property,vertical)
	margin.add_child(child)
	return margin

func _style(color: Color, border: Color = Color(0,0,0,0), width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
