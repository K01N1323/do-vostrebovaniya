extends Control

signal focus_requested(view_id: String)
signal modal_changed(blocked: bool)
signal motion_changed(reduced: bool)

const Rules = preload("res://scripts/core/state_reducer.gd")
const Paper = preload("res://scripts/ui/paper_sheet.gd")
const INK := Color("272c27")
const LIGHT := Color("e1dac5")
const MUTED := Color("a5aa98")
const GOLD := Color("bdad78")
const DARK := Color(0.075,0.10,0.085,0.96)

var snapshot: Dictionary = {}
var sidebar: VBoxContainer
var dialogue_text: RichTextLabel
var objective: Label
var hint: Label
var modal: Control
var modal_body: VBoxContainer
var _modal_kind: String = ""
var _view: String = "window"
var _sound: AudioStreamPlayer
var _muted := false
var _reduced := false
var _inspection: Node3D
var _detail_buttons: Dictionary = {}
var _start_screen: Control
var _action_panel: PanelContainer
var _hud: Control
var _menu_status: Label
var _booting := false
var _visitor_ready := false
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
	skin.set_stylebox("normal","Button",_style(Color("202b25"),Color("65705a")))
	skin.set_stylebox("hover","Button",_style(Color("354238"),GOLD))
	skin.set_stylebox("pressed","Button",_style(Color("48513b"),GOLD))
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
	var actions := _button(_hud,"Действия · F1",func(): _action_panel.visible = not _action_panel.visible)
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
	var footer := _panel(_hud,Color(0.04,0.07,0.06,0.86))
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

func render(state: Dictionary) -> void:
	snapshot = state
	if not is_instance_valid(sidebar):
		return
	_clear(sidebar)
	_label(sidebar,"ОБРАЩЕНИЕ 01",13,GOLD)
	_label(sidebar,"Нина Лукина",21)
	if state.case_status == "resolved":
		objective.text = "Обращение завершено"
		var outcomes := {"issue":"Переноска передана Нине.","retain":"Переноска осталась на полке.","appropriate":"Переноска в личном месте."}
		_text(sidebar,outcomes.get(state.decision,""),17)
		_button(sidebar,"Начать заново",_restart)
		return
	objective.text = _next_step(state)
	var decision := _action(sidebar,"Принять решение",_show_decision)
	decision.disabled = not Rules.can_decide(state)
	decision.tooltip_text = "Прочтите обе бумаги и осмотрите содержимое."
	for entry in [["identity","Удостоверение"],["claim","Заявление"]]:
		var id: String = entry[0]
		_action(sidebar,entry[1]+(" ✓" if id in state.read_documents else ""),func(): _show_document(id))
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
	if state.read_documents.size() < 2:
		return "Сверьте бумаги посетителя"
	if not state.package.opened or state.inspected_details.is_empty():
		return "Осмотрите переноску на своём столе"
	return "Проверка завершена. Решение за вами"

func on_visitor_arrived() -> void:
	_visitor_ready = true
	if snapshot.get("started",false) and snapshot.case_status == "active" and not is_instance_valid(_start_screen) and not is_instance_valid(modal):
		_show_conversation()

func open_target(target_id: String) -> void:
	if not snapshot.get("started",false) or (is_instance_valid(modal) and _modal_kind not in ["dialogue","result"]):
		return
	match target_id:
		"P01":
			if snapshot.case_status == "resolved":
				_show_hint("Решение уже принято.")
			elif snapshot.package.location == "shelf":
				_move("desk")
			else:
				_show_inspection()
		"identity","claim":
			if snapshot.case_status == "active":
				_show_document(target_id)
		"nina":
			if snapshot.case_status == "active":
				_show_conversation()
		"archive":
			_show_hint("Старые дела. Сначала закончите обращение у окна.")
		"sandwiches","saucer","napkin":
			_inspect_detail(target_id)
		"hatch":
			_show_hint("Передаточный блок. Выдача — после проверки и явного решения.")

func _move(destination: String) -> void:
	_close_modal()
	if GameStore.dispatch({"type":"MOVE_PACKAGE","destination":destination}).ok:
		_focus("desk" if destination == "desk" else "shelf")
		_show_hint("Переноска на столе. Нажмите на неё для осмотра." if destination == "desk" else "Переноска возвращена на полку. Решение ещё не принято.")

func _show_document(id: String) -> void:
	if not GameStore.dispatch({"type":"READ_DOCUMENT","document_id":id}).ok:
		return
	_begin_modal(GameStore.content.documents[id].title,"document")
	_document(modal_body,GameStore.content.documents[id],id)
	_button(modal_body,"Вернуться к столу",_close_modal)

func _show_comparison() -> void:
	for id in ["identity","claim"]:
		GameStore.dispatch({"type":"READ_DOCUMENT","document_id":id})
	_begin_modal("Сверка бумаг · Нина Лукина","comparison")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_body.add_child(row)
	for id in ["identity","claim"]:
		_document(row,GameStore.content.documents[id],id)
	_button(modal_body,"Вернуться к столу",_close_modal)

func _document(parent: Node, record: Dictionary, id: String) -> void:
	var page := Paper.new()
	page.name = "Paper_"+id
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.grain_seed = 47 if id == "identity" else 13
	parent.add_child(page)
	var stack := VBoxContainer.new()
	page.add_child(stack)
	var head := HBoxContainer.new()
	stack.add_child(head)
	var title := _label(head,"АВТОВОКЗАЛ / 047" if id == "identity" else "ФОРМА БН–01",16,INK)
	title.add_theme_font_override("font",_typewriter_font)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(head,"15 / X",14,Color("65644e"))
	_rule(stack)
	if id == "identity" and _modal_kind != "comparison" and ResourceLoader.exists("res://assets/characters/nina-v1.png"):
		var photo := TextureRect.new()
		photo.name = "IdentityPhoto"
		var source: Texture2D = load("res://assets/characters/nina-v1.png")
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(source.get_width()*0.24,source.get_height()*0.02,source.get_width()*0.52,source.get_height()*0.27)
		photo.texture = atlas
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		photo.custom_minimum_size = Vector2(74,92)
		head.add_child(photo)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var body := _text(scroll,record.text,18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color",INK)
	body.add_theme_font_override("normal_font",_typewriter_font)
	var seal := _label(stack,"БЮРО НАХОДОК  ·  ПРИНЯТО" if id == "claim" else "ХОЗЯЙСТВЕННАЯ СЛУЖБА",12,Color("704f42"))
	seal.add_theme_font_override("font",_typewriter_font)
	seal.rotation = -0.018

func _show_inspection() -> void:
	_close_modal()
	_focus("desk")
	if not snapshot.package.opened:
		if not GameStore.dispatch({"type":"OPEN_PACKAGE"}).ok:
			return
	_begin_modal("П01 · Переноска с обедом","inspection")
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
	viewport.add_child(_inspection)
	_inspection.set_opened(true)
	_inspection.reduced_motion = _reduced
	_inspection.detail_selected.connect(_inspect_detail)
	var turn := HBoxContainer.new()
	left.add_child(turn)
	_button(turn,"Повернуть влево",func(): _inspection.rotate_item(-1.0))
	_button(turn,"Повернуть вправо",func(): _inspection.rotate_item(1.0))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_label(right,"ПРИЗНАКИ",13,GOLD)
	_detail_buttons.clear()
	for id in ["sandwiches","saucer","napkin"]:
		var detail_id: String = id
		_detail_buttons[id] = _button(right,GameStore.content.details[id].title+(" ✓" if id in snapshot.inspected_details else ""),func(): _inspect_detail(detail_id))
	var observation := _text(right,"Выберите деталь. Наблюдения останутся в памяти после осмотра.",18)
	observation.name = "Observation"
	observation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(modal_body,"Закончить осмотр · Esc",_close_modal)

func _inspect_detail(id: String) -> void:
	if not GameStore.dispatch({"type":"INSPECT_DETAIL","detail_id":id}).ok:
		return
	if is_instance_valid(modal):
		var observation := modal.find_child("Observation",true,false)
		if observation:
			observation.text = GameStore.content.details[id].text
	if is_instance_valid(_detail_buttons.get(id)):
		_detail_buttons[id].text = GameStore.content.details[id].title+" ✓"
	_show_hint("Осмотрено: "+GameStore.content.details[id].title)

func _show_conversation() -> void:
	if snapshot.get("case_status","") != "active":
		return
	_close_modal()
	_focus("window")
	_begin_modal("Нина Лукина","dialogue")
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
		modal.size.y = 240
		modal.position.y = 580
		_button(_speech_choices,"Далее",func(): _speech_index+=1; _refresh_speech())
		return
	modal.size.y = 285
	modal.position.y = 535
	var topics := HBoxContainer.new()
	_speech_choices.add_child(topics)
	for entry in [["carrier","Почему кошачья переноска?"],["old_room","Что разбирают в старой комнате?"],["lunch","Вы приготовили обед на троих?"]]:
		var topic: String = entry[0]
		if topic == "lunch" and "sandwiches" not in snapshot.inspected_details:
			continue
		var button := _button(topics,entry[1],func():
			if GameStore.dispatch({"type":"ASK_TOPIC","topic_id":topic}).ok:
				_set_speech(GameStore.content.dialogues[topic]))
		button.add_theme_font_size_override("font_size",15)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(_speech_choices,"К работе",_close_modal)

func _show_decision() -> void:
	_begin_modal("Куда отправить находку?","decision")
	_text(modal_body,"Обращение № 01 · Нина Лукина",16,MUTED)
	var at_desk: bool = snapshot.package.location == "desk"
	var issue := _button(modal_body,"Выдать переноску Нине Лукиной",func(): _decide("ISSUE_PACKAGE"))
	issue.disabled = not at_desk
	_button(modal_body,"Завершить обращение · оставить на хранении",func(): _decide("RETAIN_PACKAGE"))
	var appropriate := _button(modal_body,"Убрать под стол · присвоить переноску",func(): _decide("APPROPRIATE_PACKAGE"))
	appropriate.disabled = not at_desk
	if not at_desk:
		_text(modal_body,"Для передачи сначала поставьте переноску на стол.",16)
	_button(modal_body,"Пока не решать",_close_modal)

func _decide(type: String) -> void:
	var command := {"type":type}
	if type == "ISSUE_PACKAGE":
		command.recipient = "nina"
	if not GameStore.dispatch(command).ok:
		return
	_close_modal()
	_focus("window" if type == "ISSUE_PACKAGE" else ("shelf" if type == "RETAIN_PACKAGE" else "personal"))
	_action_panel.hide()
	_show_hint("Обращение завершено. Результат сохранён до закрытия игры.")
	_begin_modal("Нина","result")
	_text(modal_body,GameStore.content.reactions[snapshot.decision],21)
	var buttons := HBoxContainer.new()
	modal_body.add_child(buttons)
	_button(buttons,"К работе",_close_modal)
	_button(buttons,"Начать заново",_restart)

func _make_start_screen() -> Control:
	var screen := ColorRect.new()
	screen.color = Color(0.025,0.045,0.035,0.88)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var rules := _panel(screen,Color(0.10,0.14,0.105,0.74))
	rules.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rules.offset_left = 68
	rules.offset_right = -68
	rules.offset_top = 62
	rules.offset_bottom = -62
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
	var settings := HBoxContainer.new()
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
	_menu_status = _label(content,"Мышь — предметы  ·  ПКМ — осмотреться  ·  Escape — пауза",15,MUTED)
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
	_button(modal_body,"Начать обращение заново",_restart)
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
	_action_panel.hide()
	modal = _panel(self,DARK)
	modal.name = "ContentPanel"
	var rect: Rect2
	match kind:
		"dialogue": rect = Rect2(220,520,950,300)
		"result": rect = Rect2(30,570,620,250)
		"document": rect = Rect2(36,118,555,680)
		"comparison": rect = Rect2(36,500,1100,320)
		"inspection": rect = Rect2(36,240,990,580)
		"decision": rect = Rect2(670,470,730,350)
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
		_action_panel.visible = not _action_panel.visible
	var views := {KEY_1:"window",KEY_2:"shelf",KEY_3:"desk",KEY_4:"personal"}
	if views.has(event.keycode):
		_focus(views[event.keycode])
		get_viewport().set_input_as_handled()

func _show_hint(message: String) -> void:
	if is_instance_valid(hint): hint.text = message

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
	return button

func _rule(parent: Node) -> void:
	var line := HSeparator.new()
	line.custom_minimum_size.y = 2
	line.add_theme_stylebox_override("separator",_style(Color("66705a"),Color(0,0,0,0),0))
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
