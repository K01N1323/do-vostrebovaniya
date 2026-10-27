extends Control

signal focus_requested(view_id: String)
signal modal_changed(blocked: bool)
signal motion_changed(reduced: bool)

const Cases = preload("res://scripts/core/case_definitions.gd")
const Rules = preload("res://scripts/core/state_reducer.gd")
const Paper = preload("res://scripts/ui/paper_sheet.gd")
const INK := Color("272c27")
const LIGHT := Color("e1dac5")
const MUTED := Color("a5aa98")
const GOLD := Color("bdad78")
const DARK := Color(0.035,0.043,0.037,0.91)

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
var _sound: AudioStreamPlayer
var _muted := false
var _reduced := false
var _inspection: Node3D
var _detail_buttons: Dictionary = {}
var _lining_button: Button
var _inspection_caption: Label
var _inspection_overview: Button
var _inspection_turns: Array[Button] = []
var _start_screen: Control
var _action_panel: PanelContainer
var _actions_button: Button
var _hovered_target := ""
var _hud: Control
var _menu_status: Label
var _booting := false
var _visitor_ready := false
var _can_advance := false
var _speech_parts: Array[String] = []
var _speech_index := 0
var _speech_choices: VBoxContainer
var _typewriter_font: SystemFont
var _heading_font: SystemFont

func _ready() -> void:
	_build_theme()
	_build_shell()
	GameStore.command_rejected.connect(_show_hint)
	_create_audio()
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
	var brand := _label(_hud,"БЮРО НАХОДОК",18,GOLD)
	brand.position = Vector2(26,22)
	brand.add_theme_font_override("font",_typewriter_font)
	objective = _label(_hud,"Ожидается посетитель",16,LIGHT)
	objective.position = Vector2(26,48)
	var pause := _button(_hud,"Пауза · Esc",_show_pause)
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left = -176
	pause.offset_right = -24
	pause.offset_top = 20
	pause.offset_bottom = 58
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
	var footer := _panel(_hud,Color(0.02,0.025,0.02,0.52))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -62
	var nav := HBoxContainer.new()
	footer.add_child(_margin(nav,18,7))
	for entry in [["window","1 · Посетитель"],["shelf","2 · Моя полка"],["desk","3 · Стол"],["personal","4 · Под столом"]]:
		var id: String = entry[0]
		var button := _button(nav,entry[1],func(): _focus(id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",16)
	hint = _label(_hud,"ПКМ — повернуть голову   ·   Мышь — выбрать   ·   F1 — действия",15,LIGHT)
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
	if snapshot.get("case_id", "nina") != state.case_id:
		_visitor_ready = false
		_can_advance = false
		_hovered_target = ""
	snapshot = state
	_refresh_interaction_hint()
	if not is_instance_valid(sidebar):
		return
	_clear(sidebar)
	_action_panel.offset_bottom = minf(720, size.y - 110)
	_label(sidebar,"ОБРАЩЕНИЕ " + _p().number,13,GOLD)
	var case_name := _label(sidebar,_p().name,21)
	case_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if state.case_status == "resolved":
		objective.text = "Обращение завершено"
		var outcomes: Dictionary = _p().outcomes
		_text(sidebar,outcomes.get(Cases.outcome_key(state),""),17)
		_add_next_button(sidebar)
		_button(sidebar,"Начать заново",_restart)
		return
	objective.text = _next_step(state)
	var decision := _action(sidebar,"Принять решение",_show_decision)
	decision.disabled = not Rules.can_decide(state)
	decision.tooltip_text = "Сверьте все бумаги и признаки текущего обращения."
	if snapshot.case_id == "melnikovs":
		for person in ["vera", "leonid"]:
			var owner_id: String = person
			var documents: Array = [owner_id + "_identity", owner_id + "_claim"]
			var checked: bool = documents[0] in state.read_documents and documents[1] in state.read_documents
			_action(sidebar,("Бумаги Веры" if owner_id == "vera" else "Бумаги Леонида") + (" ✓" if checked else ""),func(): _show_comparison(documents))
		_action(sidebar,"Сверить все четыре бумаги",_show_comparison)
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

func _next_step(state: Dictionary) -> String:
	if not state.started:
		return "Ожидается посетитель"
	if state.read_documents.size() < Cases.get_case(state.case_id).documents.size():
		return "Сверьте бумаги посетителя"
	if state.case_id == "melnikovs":
		if "lock_code" not in state.asked_topics:
			return "Уточните у посетителей код замка"
		if not state.package.get("unlocked", false):
			return "Откройте замок чемодана на столе"
		if "green_stain" not in state.inspected_details or "zipper" not in state.inspected_details:
			return "Проверьте пятно и деталь под подкладкой"
	if state.case_id == "gleb":
		for id in Cases.get_case("gleb").required_details:
			if id not in state.inspected_details:
				return "Сопоставьте описание с камерой, ремешком и содержимым"
	if not state.package.opened or state.inspected_details.is_empty():
		return "Осмотрите " + _p().item_accusative + " на своём столе"
	return "Проверка завершена. Решение за вами"

func on_visitor_arrived() -> void:
	_visitor_ready = true
	if snapshot.get("started",false) and snapshot.case_status == "active" and not is_instance_valid(_start_screen) and not is_instance_valid(modal):
		_show_conversation()

func open_target(target_id: String) -> void:
	if not snapshot.get("started",false) or (is_instance_valid(modal) and _modal_kind not in ["dialogue","result"]):
		return
	if target_id == snapshot.package.id:
		if snapshot.case_status == "resolved":
			_show_hint("Решение уже принято.")
		elif snapshot.package.location == "shelf":
			_move("desk")
		else:
			_show_inspection()
	elif target_id == snapshot.case_id:
		if snapshot.case_status == "active":
			_show_conversation()
	elif target_id in Cases.get_case(snapshot.case_id).details:
		_inspect_detail(target_id)
	elif target_id in Cases.get_case(snapshot.case_id).documents:
		if snapshot.case_status == "active":
			_show_document(target_id)
	elif target_id in ["identity", "claim"] and snapshot.case_id == "melnikovs":
		if snapshot.case_status == "active":
			_show_comparison()
	elif target_id == "archive":
		_show_hint("Старые дела. Сначала закончите обращение у окна.")
	elif target_id == "hatch":
		_show_hint("Передаточный блок. Выдача — после проверки и явного решения.")

func _move(destination: String) -> void:
	_close_modal()
	if GameStore.dispatch({"type":"MOVE_PACKAGE","destination":destination}).ok:
		_focus("desk" if destination == "desk" else "shelf")
		_show_hint(_p().item_nominative + (" на столе. Нажмите для осмотра." if destination == "desk" else " на полке. Решение ещё не принято."))

func _show_document(id: String) -> void:
	if not GameStore.dispatch({"type":"READ_DOCUMENT","document_id":id}).ok:
		return
	_begin_modal(GameStore.content.documents[id].title,"document")
	if id == "identity":
		modal.position = Vector2(36,250)
		modal.size = Vector2(580,520)
	_document(modal_body,GameStore.content.documents[id],id)
	_button(modal_body,"Вернуться к столу",_close_modal)

func _show_comparison(selected: Array = []) -> void:
	var documents: Array = selected if not selected.is_empty() else Cases.get_case(snapshot.case_id).documents
	for id in documents:
		GameStore.dispatch({"type":"READ_DOCUMENT","document_id":id})
	_begin_modal("Сверка бумаг · " + _p().name,"comparison")
	if documents.size() > 2:
		modal.position = Vector2(36,118)
		modal.size = Vector2(1100,680)
	elif snapshot.case_id == "gleb":
		modal.position = Vector2(36,420)
		modal.size = Vector2(1100,400)
	for offset in range(0, documents.size(), 2):
		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		modal_body.add_child(row)
		for index in range(offset, mini(offset + 2, documents.size())):
			var id: String = documents[index]
			_document(row,GameStore.content.documents[id],id)
	_button(modal_body,"Вернуться к столу",_close_modal)

func _document(parent: Node, record: Dictionary, id: String) -> void:
	var identity := id.ends_with("identity")
	if id == "identity" and _modal_kind != "comparison" and _p().get("identity_layout", "sheet") == "booklet":
		_identity_booklet(parent,record)
		return
	var page := Paper.new()
	page.name = "Paper_"+id
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.grain_seed = 47 if identity else 13
	parent.add_child(page)
	var stack := VBoxContainer.new()
	page.add_child(stack)
	var head := HBoxContainer.new()
	stack.add_child(head)
	var header: String = record.title if snapshot.case_id == "melnikovs" else (_p().document_header if identity else "ФОРМА БН–" + _p().number)
	var title := _label(head,header,16,INK)
	title.add_theme_font_override("font",_typewriter_font)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(head,"15 / X",14,Color("65644e"))
	_rule(stack)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var body := _text(scroll,record.text,18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color",INK)
	body.add_theme_font_override("normal_font",_typewriter_font)
	var seal := _label(stack,"БЮРО НАХОДОК  ·  ПРИНЯТО" if not identity else _p().identity_seal,12,Color("704f42"))
	seal.add_theme_font_override("font",_typewriter_font)
	seal.rotation = -0.018

func _identity_booklet(parent: Node, record: Dictionary) -> void:
	var page := Paper.new()
	page.name = "Paper_identity"
	page.booklet = true
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(page)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",24)
	page.add_child(columns)
	var portrait_column := VBoxContainer.new()
	portrait_column.custom_minimum_size.x = 138
	columns.add_child(portrait_column)
	_label(portrait_column,"АВТОВОКЗАЛ",14,INK).add_theme_font_override("font",_typewriter_font)
	var backing := _panel(portrait_column,Color("8c8c7a"))
	var photo := TextureRect.new()
	photo.name = "IdentityPhoto"
	var source: Texture2D = load(_p().portrait)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(source.get_width()*0.32,source.get_height()*0.025,source.get_width()*0.39,source.get_height()*0.29)
	photo.texture = atlas
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.custom_minimum_size = Vector2(118,150)
	photo.modulate = Color("d6d0b7")
	backing.add_child(photo)
	_label(portrait_column,"ТАБЕЛЬНЫЙ
№ 047",16,INK).add_theme_font_override("font",_typewriter_font)
	var seal := _label(portrait_column,"ХОЗ. СЛУЖБА
• АВТОВОКЗАЛ •",12,Color("73564b"))
	seal.rotation = -0.035
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	_label(right,"УДОСТОВЕРЕНИЕ",17,INK).add_theme_font_override("font",_typewriter_font)
	_rule(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var body := _text(scroll,record.text,16,INK)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_override("normal_font",_typewriter_font)

func _show_inspection() -> void:
	if snapshot.package.has("unlocked") and not snapshot.package.unlocked:
		_show_lock()
		return
	_close_modal()
	_focus("desk")
	if not snapshot.package.opened:
		if not GameStore.dispatch({"type":"OPEN_PACKAGE"}).ok:
			return
	_begin_modal(_p().package_title,"inspection")
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
	_inspection.set_item(snapshot.package.id)
	viewport.add_child(_inspection)
	_inspection.set_opened(true)
	_inspection.set_lining_lifted(snapshot.package.get("lining_lifted", false))
	_inspection.reduced_motion = _reduced
	_inspection.detail_selected.connect(_inspect_detail)
	_inspection.focus_changed.connect(_refresh_inspection_focus)
	_inspection_caption = _label(left,"П" + _p().number + " · Общий вид",14,MUTED)
	_inspection_caption.name = "InspectionCaption"
	var turn := HBoxContainer.new()
	left.add_child(turn)
	_inspection_turns.clear()
	_inspection_turns.append(_button(turn,"↶ Влево",func(): _inspection.rotate_item(-1.0)))
	_inspection_turns.append(_button(turn,"Вправо ↷",func(): _inspection.rotate_item(1.0)))
	_inspection_overview = _button(turn,_p().overview,func(): _inspection.reset_focus())
	_inspection_overview.name = "InspectionOverview"
	_inspection_overview.disabled = true
	for button in _inspection_turns + [_inspection_overview]:
		button.add_theme_font_size_override("font_size",16)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_label(right,"ПРИЗНАКИ",13,GOLD)
	_detail_buttons.clear()
	_lining_button = null
	if snapshot.package.has("lining_lifted"):
		_lining_button = _button(right,"Приподнять подкладку",_lift_lining)
		_lining_button.disabled = snapshot.package.lining_lifted
	for id in Cases.get_case(snapshot.case_id).details:
		var detail_id: String = id
		_detail_buttons[id] = _button(right,GameStore.content.details[id].title+(" ✓" if id in snapshot.inspected_details else ""),func(): _inspect_detail(detail_id))
	if _detail_buttons.has("zipper"):
		_detail_buttons.zipper.disabled = not snapshot.package.get("lining_lifted", false)
		_detail_buttons.zipper.tooltip_text = "Сначала приподнимите подкладку."
	var observation := _text(right,"Выберите предмет на изображении или признак справа, чтобы рассмотреть его ближе. Наблюдения сохранятся после осмотра.",18)
	observation.name = "Observation"
	observation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(modal_body,"Закончить осмотр · Esc",_close_modal)

func _inspect_detail(id: String) -> void:
	if id == "lining":
		_lift_lining()
		return
	if not GameStore.dispatch({"type":"INSPECT_DETAIL","detail_id":id}).ok:
		return
	if is_instance_valid(modal):
		var observation := modal.find_child("Observation",true,false)
		if observation:
			observation.text = GameStore.content.details[id].text
	if is_instance_valid(_detail_buttons.get(id)):
		_detail_buttons[id].text = GameStore.content.details[id].title+" ✓"
	if is_instance_valid(_inspection) and _inspection.is_inside_tree() and _modal_kind == "inspection":
		_inspection.focus_detail(id)
	_show_hint("Осмотрено: "+GameStore.content.details[id].title)

func _show_lock() -> void:
	_close_modal()
	_focus("desk")
	_begin_modal("Кодовый замок · П03","lock")
	modal.position = Vector2(410,300)
	modal.size = Vector2(620,280)
	_text(modal_body,"Три колёсика. Какой код назвал посетитель?",19)
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
		var result: Dictionary = GameStore.dispatch({"type":"UNLOCK_PACKAGE","code":code.text})
		if result.ok:
			_show_inspection()
		else:
			feedback.text = result.error
			code.grab_focus()
	_button(modal_body,"Открыть замок",unlock)
	code.text_submitted.connect(func(_text_value: String): unlock.call())
	code.grab_focus()

func _lift_lining() -> void:
	if not GameStore.dispatch({"type":"LIFT_LINING"}).ok:
		return
	if is_instance_valid(_inspection):
		_inspection.set_lining_lifted(true)
	if is_instance_valid(_lining_button):
		_lining_button.disabled = true
	if _detail_buttons.has("zipper") and is_instance_valid(_detail_buttons.zipper):
		_detail_buttons.zipper.disabled = false
	var observation := modal.find_child("Observation",true,false) if is_instance_valid(modal) else null
	if is_instance_valid(observation):
		observation.text = "Подкладка приподнята. Под тканью видна небольшая металлическая деталь. Осмотрите её."

func _refresh_inspection_focus(id: String) -> void:
	if is_instance_valid(_inspection_caption):
		_inspection_caption.text = ("П" + _p().number + " · Общий вид") if id.is_empty() else "Крупный план · " + GameStore.content.details[id].title
	if is_instance_valid(_inspection_overview):
		_inspection_overview.disabled = id.is_empty()
	for button in _inspection_turns:
		if is_instance_valid(button):
			button.disabled = not id.is_empty()

func _show_conversation() -> void:
	if snapshot.get("case_status","") != "active":
		return
	_close_modal()
	_focus("window")
	_begin_modal(_p().name,"dialogue")
	dialogue_text = _text(modal_body,"",21)
	dialogue_text.name = "SpeechText"
	# A bounded text area avoids transient auto-height from an unlaid-out width.
	dialogue_text.fit_content = false
	dialogue_text.scroll_active = true
	dialogue_text.custom_minimum_size.y = 82
	_speech_choices = VBoxContainer.new()
	modal_body.add_child(_speech_choices)
	_set_speech(GameStore.content.dialogues.get(snapshot.dialogue_id,""))

func _set_speech(text_value: String) -> void:
	_speech_parts.clear()
	if text_value.contains("\n"):
		for line in text_value.split("\n", false):
			_speech_parts.append(line.strip_edges())
		_speech_index = 0
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
	_speech_index = 0
	_refresh_speech()

func _refresh_speech() -> void:
	dialogue_text.text = _speech_parts[_speech_index]
	_clear(_speech_choices)
	if _speech_index < _speech_parts.size()-1:
		modal.size.y = 215
		modal.position.y = 605
		_button(_speech_choices,"Далее",func(): _speech_index+=1; _refresh_speech())
		return
	var many_topics: bool = Cases.get_case(snapshot.case_id).topics.size() > 3
	modal.size.y = 320 if many_topics else 260
	modal.position.y = 500 if many_topics else 560
	var topics := GridContainer.new()
	topics.columns = 2 if many_topics else 3
	_speech_choices.add_child(topics)
	var definition: Dictionary = Cases.get_case(snapshot.case_id)
	for id in definition.topics:
		var topic: String = id
		if definition.topic_requires.has(topic) and definition.topic_requires[topic] not in snapshot.inspected_details:
			continue
		var button := _button(topics,GameStore.content.topic_labels[topic],func():
			if GameStore.dispatch({"type":"ASK_TOPIC","topic_id":topic}).ok:
				_set_speech(GameStore.content.dialogues[topic]))
		button.add_theme_font_size_override("font_size",15)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(_speech_choices,"К работе",_close_modal)

func _show_decision() -> void:
	_begin_modal("Куда отправить находку?","decision")
	_text(modal_body,"Обращение № " + _p().number + " · " + _p().name,16,MUTED)
	var at_desk: bool = snapshot.package.location == "desk"
	var definition: Dictionary = Cases.get_case(snapshot.case_id)
	for id in definition.recipients:
		var recipient: String = id
		var issue := _button(modal_body,_p().recipient_captions[recipient],func(): _decide("ISSUE_PACKAGE",recipient))
		issue.disabled = not at_desk
	_button(modal_body,"Завершить обращение · оставить на хранении",func(): _decide("RETAIN_PACKAGE"))
	if definition.allow_appropriate:
		var appropriate := _button(modal_body,_p().appropriate_caption,func(): _decide("APPROPRIATE_PACKAGE"))
		appropriate.disabled = not at_desk
	if not at_desk:
		_text(modal_body,"Для передачи сначала поставьте " + _p().item_accusative + " на стол.",16)
	_button(modal_body,"Пока не решать",_close_modal)

func _decide(type: String, recipient: String = "") -> void:
	var command := {"type":type}
	if type == "ISSUE_PACKAGE":
		command.recipient = recipient if not recipient.is_empty() else (Cases.get_case(snapshot.case_id).recipients[0] if Cases.get_case(snapshot.case_id).recipients.size() == 1 else "")
	if not GameStore.dispatch(command).ok:
		return
	_close_modal()
	_focus("window" if type == "ISSUE_PACKAGE" else ("shelf" if type == "RETAIN_PACKAGE" else "personal"))
	_action_panel.hide()
	_show_hint("Обращение завершено. Результат сохранён до закрытия игры.")
	_begin_modal(_p().first_name,"result")
	_text(modal_body,GameStore.content.reactions[Cases.outcome_key(snapshot)],21)
	if not Cases.has_next(snapshot.case_id):
		_text(modal_body,"Конец доступного фрагмента. Следующие обращения ещё в разработке.",16,MUTED)
	var buttons := HBoxContainer.new()
	modal_body.add_child(buttons)
	_button(buttons,"К работе",_close_modal)
	_add_next_button(buttons)
	_button(buttons,"Начать заново",_restart)

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
	_text(content,"Бюро закрывается вместе со старым автовокзалом.\nКаждой вещи нужно найти место.",21)
	var start := _button(content,"Начать смену",_start_shift)
	start.custom_minimum_size.y = 49
	start.custom_minimum_size.x = 360
	start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var exit_button := _button(content,"Выйти",func(): get_tree().quit())
	exit_button.custom_minimum_size.x = 360
	exit_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var settings := VBoxContainer.new()
	content.add_child(settings)
	var mute := CheckButton.new()
	mute.text = "Играть без звука"
	mute.button_pressed = _muted
	mute.toggled.connect(func(value: bool): _muted=value; _sound.stream_paused=value)
	settings.add_child(mute)
	var motion := CheckButton.new()
	motion.text = "Уменьшить движение камеры"
	motion.button_pressed = _reduced
	motion.toggled.connect(func(value: bool): _reduced=value; motion_changed.emit(value))
	settings.add_child(motion)
	_menu_status = _label(content,"Мышь — предметы  ·  ПКМ — осмотреться
Escape — пауза",15,MUTED)
	_label(content,"БЮРО № 4                        15 ОКТЯБРЯ 2026",13,GOLD).add_theme_font_override("font",_typewriter_font)
	return screen

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
	if not _reduced:
		var fade := create_tween()
		fade.tween_property(_start_screen,"modulate:a",0.0,0.35)
		await fade.finished
	_start_screen.queue_free()
	_start_screen = null
	_hud.show()
	modal_changed.emit(false)
	if not _muted:
		_sound.play()
	_focus("window")
	if _visitor_ready:
		on_visitor_arrived()

func _show_pause() -> void:
	if is_instance_valid(_start_screen):
		return
	_begin_modal("Перерыв","pause")
	_text(modal_body,"Вы стоите за защищённой стойкой.\nУдерживайте ПКМ, чтобы повернуть голову.\n1–4 возвращают взгляд к рабочим местам.\n\nВ этой версии прогресс хранится до закрытия.",19)
	var mute := CheckButton.new()
	mute.text = "Выключить звук"
	mute.button_pressed = _muted
	mute.toggled.connect(func(value: bool): _muted=value; _sound.stream_paused=value)
	modal_body.add_child(mute)
	var motion := CheckButton.new()
	motion.text = "Уменьшить движение камеры"
	motion.button_pressed = _reduced
	motion.toggled.connect(func(value: bool): _reduced=value; motion_changed.emit(value))
	modal_body.add_child(motion)
	_button(modal_body,"Продолжить",_close_modal)
	_button(modal_body,"Начать смену заново",_restart)
	_button(modal_body,"В главное меню",_return_to_title)
	_button(modal_body,"Выйти из игры",func(): get_tree().quit())

func _return_to_title() -> void:
	_close_modal()
	GameStore.dispatch({"type":"RESTART"})
	_booting = false
	_visitor_ready = false
	_sound.stop()
	_hud.hide()
	_start_screen = _make_start_screen()
	modal_changed.emit(true)

func _begin_modal(title: String, kind: String) -> void:
	_close_modal()
	_modal_kind = kind
	hint.hide()
	interaction_hint.hide()
	_action_panel.hide()
	_actions_button.disabled = true
	modal = _panel(self,Color(0.025,0.035,0.028,0.83) if kind in ["dialogue","result"] else DARK)
	modal.name = "ContentPanel"
	var rect: Rect2
	match kind:
		"dialogue": rect = Rect2(220,520,950,300)
		"result": rect = Rect2(30,480,740,340) if snapshot.case_id == "melnikovs" else Rect2(30,570,620,250)
		"document": rect = Rect2(36,118,555,680)
		"comparison": rect = Rect2(36,500,1100,320)
		"inspection": rect = Rect2(36,240,990,580)
		"decision": rect = Rect2(670,530,730,290)
		_: rect = Rect2(410,190,620,560)
	modal.position = rect.position
	modal.size = rect.size
	modal_body = VBoxContainer.new()
	modal.add_child(_margin(modal_body,18,14))
	var top := HBoxContainer.new()
	modal_body.add_child(top)
	var heading := _label(top,title,21,GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := _button(top,"Закрыть · Esc",_close_modal)
	close.add_theme_font_size_override("font_size",14)
	close.custom_minimum_size.y = 28
	_rule(modal_body)
	modal_changed.emit(kind not in ["dialogue","result"])

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal = null
	_modal_kind = ""
	hint.show()
	_actions_button.disabled = false
	_refresh_interaction_hint()
	if is_instance_valid(_action_panel) and snapshot.get("started",false):
		_action_panel.show()
	modal_changed.emit(false)

func _restart() -> void:
	_close_modal()
	_visitor_ready = false
	GameStore.dispatch({"type":"RESTART"})
	GameStore.dispatch({"type":"START"})
	_action_panel.show()
	_focus("window")
	_show_hint("Следующий посетитель подходит к стойке.")

func _focus(view_id: String) -> void:
	if is_instance_valid(modal) and _modal_kind not in ["dialogue","result"]:
		return
	_view = view_id
	focus_requested.emit(view_id)

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
	if snapshot.get("started",false) and snapshot.get("case_status","") == "active" and not is_instance_valid(modal):
		if _hovered_target == snapshot.package.id:
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
	_can_advance = value
	for button in find_children("NextCase", "Button", true, false):
		button.disabled = not value

func _add_next_button(parent: Node) -> void:
	if Cases.has_next(snapshot.case_id):
		var button := _button(parent,"Следующий посетитель",_next_case)
		button.name = "NextCase"
		button.disabled = not _can_advance
		button.tooltip_text = "Посетитель должен уйти, а передаточный блок — закрыться."
	elif parent == sidebar:
		_text(parent,"Конец доступного фрагмента. Следующие обращения ещё в разработке.",16,MUTED)

func _next_case() -> void:
	if not _can_advance or snapshot.case_status != "resolved":
		return
	_close_modal()
	_visitor_ready = false
	_can_advance = false
	if GameStore.dispatch({"type":"NEXT_CASE"}).ok:
		_focus("window")
		_show_hint("Следующий посетитель подходит к стойке.")

func _create_audio() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -38
	add_child(_sound)
	var data := PackedByteArray()
	data.resize(22050*2)
	for i in 22050:
		var t: float = float(i)/22050.0
		data.encode_s16(i*2,int((sin(TAU*50*t)*0.65+sin(TAU*100*t)*0.12)*13000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050
	_sound.stream = stream

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
