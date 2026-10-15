extends Control

signal focus_requested(view_id: String)
signal modal_changed(blocked: bool)
signal motion_changed(reduced: bool)

const Rules = preload("res://scripts/core/state_reducer.gd")
const INK = Color("293e3c")
const PAPER = Color("ede9dc")
const MUTED = Color("697873")
const GOLD = Color("ba8b4c")

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
var _muted: bool = false
var _reduced: bool = false
var _inspection: Node3D
var _detail_buttons: Dictionary = {}
var _start_screen: Control

func _ready() -> void:
	_build_theme()
	_build_shell()
	GameStore.command_rejected.connect(_show_hint)
	_create_audio()
	_start_screen = _make_start_screen()

func _build_theme() -> void:
	var skin := Theme.new()
	skin.default_font_size = 19
	skin.set_color("font_color", "Label", INK)
	skin.set_color("default_color", "RichTextLabel", INK)
	skin.set_constant("line_separation", "RichTextLabel", 5)
	skin.set_color("font_color", "Button", INK)
	skin.set_color("font_hover_color", "Button", INK)
	skin.set_color("font_pressed_color", "Button", INK)
	skin.set_color("font_hover_pressed_color", "Button", INK)
	skin.set_color("font_disabled_color", "Button", Color("8a938a"))
	skin.set_stylebox("normal", "Button", _style(Color("e4e4d8"), 7, Color("c4cbbb")))
	skin.set_stylebox("hover", "Button", _style(Color("f9f4e5"), 7, GOLD))
	skin.set_stylebox("pressed", "Button", _style(Color("c3cfc2"), 7, INK))
	skin.set_stylebox("disabled", "Button", _style(Color("e4e4dd"), 7, Color("d0d4c8")))
	skin.set_stylebox("focus", "Button", _style(Color(0,0,0,0), 7, GOLD, 2))
	skin.set_constant("separation", "VBoxContainer", 11)
	skin.set_constant("separation", "HBoxContainer", 10)
	theme = skin

func _build_shell() -> void:
	var header := _panel(self, Color("162b2b"))
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 83
	var top := HBoxContainer.new()
	header.add_child(_margin(top, 28, 15))
	var branding := VBoxContainer.new()
	branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(branding)
	_label(branding, "ДО ВОСТРЕБОВАНИЯ", 25, Color("f0ecdd"))
	_label(branding, "БЮРО НАХОДОК   /   СТАРЫЙ АВТОВОКЗАЛ", 12, Color("a5b7ab"))
	_label(top, "ПЕРВАЯ СМЕНА  ·  01", 14, Color("c6cbbc"))
	_button(top, "Пауза · Esc", _show_pause)
	var side := _panel(self, Color("ede9dc"))
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_bottom = 1.0
	side.offset_left = -410
	side.offset_top = 101
	side.offset_right = -18
	side.offset_bottom = -112
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(_margin(scroll, 21, 20))
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sidebar)
	var bottom := _panel(self, Color("162b2b"))
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -93
	var nav := HBoxContainer.new()
	bottom.add_child(_margin(nav, 22, 19))
	for entry in [["window", "1 · Окно выдачи"], ["shelf", "2 · Полка"], ["desk", "3 · Рабочий стол"], ["personal", "4 · Под столом"]]:
		var view_id: String = entry[0]
		var button := _button(nav, entry[1], func(): _focus(view_id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint = _label(self, "Мышь — выбрать предмет    ·    1–4 — перевести взгляд    ·    Esc — пауза", 15, Color("f1eddf"))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 28
	hint.offset_top = -137
	hint.offset_right = 1000
	hint.offset_bottom = -103
	hint.add_theme_color_override("font_shadow_color", Color("152725"))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 2)

func render(state: Dictionary) -> void:
	snapshot = state
	if not is_instance_valid(sidebar):
		return
	_clear(sidebar)
	_label(sidebar, "ОБРАЩЕНИЕ № 01", 13, MUTED)
	_label(sidebar, "Нина Лукина", 28)
	_label(sidebar, "Уборщица · переноска с обедом", 15, MUTED)
	_rule(sidebar)
	if state.case_status == "resolved":
		_label(sidebar, "Обращение завершено", 21)
		_text(sidebar, GameStore.content.reactions.get(state.decision, ""), 19)
		var outcomes := {"issue": "Переноска выдана Нине.", "retain": "Переноска осталась на полке.", "appropriate": "Переноска лежит в личном месте под столом."}
		_text(sidebar, outcomes.get(state.decision, ""), 17)
		_rule(sidebar)
		_text(sidebar, "Первый этап прототипа закончен. Можно осмотреть комнату или начать обращение заново, чтобы проверить другое решение.", 17)
		_button(sidebar, "Начать заново", _restart)
		return
	objective = _label(sidebar, _next_step(state), 18)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ready: bool = Rules.can_decide(state)
	var decision_button := _button(sidebar, "Принять решение", _show_decision)
	decision_button.disabled = not ready
	decision_button.tooltip_text = "Прочтите обе бумаги, откройте переноску и осмотрите хотя бы один признак."
	var doc_row := HBoxContainer.new()
	sidebar.add_child(doc_row)
	for entry in [["identity", "Удостоверение"], ["claim", "Заявление"]]:
		var id: String = entry[0]
		var caption: String = entry[1] + (" ✓" if id in state.read_documents else "")
		var button := _button(doc_row, caption, func(): _show_document(id))
		button.add_theme_font_size_override("font_size", 15)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(sidebar, "Сравнить обе бумаги", _show_comparison)
	_rule(sidebar)
	var locations := {"shelf": "На полке", "desk": "На рабочем столе", "personal": "Под столом", "issued": "Выдана"}
	_label(sidebar, "P01 · Кошачья переноска", 19)
	_label(sidebar, locations.get(state.package.location, ""), 15, MUTED)
	if state.package.location == "shelf":
		_button(sidebar, "Поставить на стол", func(): _move("desk"))
	elif state.package.location == "desk":
		_button(sidebar, "Открыть и осмотреть" if not state.package.opened else "Осмотреть содержимое", _show_inspection)
		_button(sidebar, "Вернуть на полку · пока думаю", func(): _move("shelf"))
	_rule(sidebar)
	_label(sidebar, "НИНА", 12, MUTED)
	var full_dialogue: String = GameStore.content.dialogues.get(state.dialogue_id, "")
	dialogue_text = _text(sidebar, full_dialogue.left(100) + ("…" if full_dialogue.length() > 100 else ""), 18)
	_button(sidebar, "Поговорить", _show_conversation)

func _next_step(state: Dictionary) -> String:
	if state.read_documents.size() < 2:
		return "Сначала сравните имя и описание в бумагах."
	if state.package.location == "shelf" and not state.package.opened:
		return "Поставьте переноску на стол для осмотра."
	if not state.package.opened or state.inspected_details.is_empty():
		return "Откройте переноску и осмотрите её содержимое."
	return "Бумаги прочитаны, содержимое осмотрено. Решение за вами."

func open_target(target_id: String) -> void:
	if is_instance_valid(modal) or not snapshot.get("started", false):
		return
	match target_id:
		"P01":
			if snapshot.case_status == "resolved":
				_show_hint("Обращение завершено. Переноска остаётся на выбранном месте.")
			elif snapshot.package.location == "shelf":
				_move("desk")
			else:
				_show_inspection()
		"identity", "claim":
			if snapshot.case_status == "active":
				_show_document(target_id)
		"nina":
			if snapshot.case_status == "active":
				_show_conversation()
		"archive":
			_show_hint("Архив пока закрыт. Сейчас у окна ждёт Нина.")

func _move(destination: String) -> void:
	if GameStore.dispatch({"type": "MOVE_PACKAGE", "destination": destination}).ok:
		_focus("desk" if destination == "desk" else "shelf")
		_show_hint("Переноска на столе. Теперь её можно открыть." if destination == "desk" else "Переноска на полке. Обращение ещё открыто.")

func _show_document(id: String) -> void:
	if not GameStore.dispatch({"type": "READ_DOCUMENT", "document_id": id}).ok:
		return
	var record: Dictionary = GameStore.content.documents[id]
	_begin_modal(record.title, "document")
	_document(modal_body, record)
	_button(modal_body, "Вернуться к столу", _close_modal)

func _show_comparison() -> void:
	for id in ["identity", "claim"]:
		GameStore.dispatch({"type": "READ_DOCUMENT", "document_id": id})
	_begin_modal("Бумаги Нины Лукиной", "document")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_body.add_child(row)
	for id in ["identity", "claim"]:
		_document(row, GameStore.content.documents[id])
	_button(modal_body, "Вернуться к столу", _close_modal)

func _document(parent: Node, record: Dictionary) -> void:
	var page := _panel(parent, Color("f7f1df"))
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stack := VBoxContainer.new()
	page.add_child(_margin(stack, 25, 22))
	_label(stack, record.title, 22)
	_rule(stack)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var body := _text(scroll, record.text, 20)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _show_inspection() -> void:
	if not snapshot.package.opened:
		if not GameStore.dispatch({"type": "OPEN_PACKAGE"}).ok:
			return
	_begin_modal("P01 · Осмотр переноски", "inspection")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_body.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.35
	row.add_child(left)
	var viewport_box := SubViewportContainer.new()
	viewport_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_box.stretch = true
	viewport_box.custom_minimum_size = Vector2(400, 300)
	left.add_child(viewport_box)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(620, 420)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_box.add_child(viewport)
	_inspection = load("res://scenes/objects/inspection_stage.tscn").instantiate()
	viewport.add_child(_inspection)
	_inspection.reduced_motion = _reduced
	if _inspection.has_method("set_opened"):
		_inspection.set_opened(true)
	if _inspection.has_signal("detail_selected"):
		_inspection.detail_selected.connect(_inspect_detail)
	var rotate_row := HBoxContainer.new()
	left.add_child(rotate_row)
	_button(rotate_row, "↶ Повернуть", func(): _inspection.rotate_item(-1.0))
	_button(rotate_row, "Повернуть ↷", func(): _inspection.rotate_item(1.0))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_label(right, "Присмотритесь к деталям", 21)
	_text(right, "Выберите признак, чтобы рассмотреть его и записать наблюдение.", 18)
	_detail_buttons.clear()
	for id in ["sandwiches", "saucer", "napkin"]:
		var detail_id: String = id
		var title: String = GameStore.content.details[id].title
		_detail_buttons[id] = _button(right, title + (" ✓" if id in snapshot.inspected_details else ""), func(): _inspect_detail(detail_id))
	var observation := _text(right, "В переноске нет кота. На блюдце лежит обед.", 20)
	observation.name = "Observation"
	observation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(modal_body, "Закончить осмотр · Esc", _close_modal)

func _inspect_detail(detail_id: String) -> void:
	if not GameStore.dispatch({"type": "INSPECT_DETAIL", "detail_id": detail_id}).ok:
		return
	var observation: Node = modal_body.find_child("Observation", true, false)
	if observation:
		observation.text = GameStore.content.details[detail_id].text
	if is_instance_valid(_detail_buttons.get(detail_id)):
		_detail_buttons[detail_id].text = GameStore.content.details[detail_id].title + " ✓"
	_show_hint("Наблюдение: " + GameStore.content.details[detail_id].title)

func _show_conversation() -> void:
	_begin_modal("Нина Лукина", "dialogue")
	var speech := _text(modal_body, GameStore.content.dialogues.get(snapshot.dialogue_id, ""), 23)
	speech.custom_minimum_size.y = 260
	speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for entry in [["carrier", "Почему кошачья переноска?"], ["old_room", "Что разбирают в старой комнате?"], ["lunch", "Вы приготовили обед на троих?"]]:
		var topic: String = entry[0]
		if topic == "lunch" and "sandwiches" not in snapshot.inspected_details:
			continue
		_button(modal_body, entry[1], func():
			if GameStore.dispatch({"type": "ASK_TOPIC", "topic_id": topic}).ok:
				speech.text = GameStore.content.dialogues[topic])
	_button(modal_body, "Вернуться к работе", _close_modal)

func _show_decision() -> void:
	_begin_modal("Решение по обращению № 01", "decision")
	_text(modal_body, "Вы прочли документы и осмотрели переноску. Выберите, где она окажется после завершения обращения.", 23)
	_rule(modal_body)
	var on_desk: bool = snapshot.package.location == "desk"
	var issue := _button(modal_body, "Выдать переноску Нине Лукиной", func(): _decide("ISSUE_PACKAGE"))
	issue.disabled = not on_desk
	_button(modal_body, "Завершить обращение · оставить на хранении", func(): _decide("RETAIN_PACKAGE"))
	var appropriate := _button(modal_body, "Убрать под стол · присвоить переноску", func(): _decide("APPROPRIATE_PACKAGE"))
	appropriate.disabled = not on_desk
	if not on_desk:
		_text(modal_body, "Для выдачи или присвоения сначала верните переноску на стол.", 18)
	_button(modal_body, "Пока не решать", _close_modal)

func _decide(type: String) -> void:
	var command := {"type": type}
	if type == "ISSUE_PACKAGE":
		command.recipient = "nina"
	if not GameStore.dispatch(command).ok:
		return
	_close_modal()
	_focus("personal" if type == "APPROPRIATE_PACKAGE" else ("shelf" if type == "RETAIN_PACKAGE" else "window"))
	_show_hint("Обращение завершено. Выберите ракурс, чтобы осмотреть результат.")
	_begin_modal("Обращение завершено", "result")
	_label(modal_body, "Нина", 18, MUTED)
	_text(modal_body, GameStore.content.reactions[snapshot.decision], 25)
	_rule(modal_body)
	_text(modal_body, "Это конец первого игрового этапа. Следующим будет обращение Фёдора.", 19)
	_button(modal_body, "Осмотреть результат в комнате", _close_modal)
	_button(modal_body, "Попробовать другое решение", _restart)

func _make_start_screen() -> Control:
	var screen := ColorRect.new()
	screen.color = Color(0.04, 0.11, 0.11, 0.91)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var box := VBoxContainer.new()
	screen.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -350
	box.offset_right = 350
	box.offset_top = -210
	box.offset_bottom = 240
	_label(box, "ПОСЛЕДНИЕ ДНИ СТАРОГО АВТОВОКЗАЛА", 14, Color("c4b98f"))
	_label(box, "До востребования", 52, Color("f0ecdd"))
	_label(box, "Первое обращение", 23, Color("bdcdbf"))
	var gap := Control.new()
	gap.custom_minimum_size.y = 30
	box.add_child(gap)
	var intro := _text(box, "Вы — Павел Фомин, смотритель бюро находок.\nЗа окном ждёт Нина. На полке — её переноска.\nПрочтите бумаги, осмотрите находку и примите решение.", 22)
	intro.add_theme_color_override("default_color", Color("e5e6d8"))
	_button(box, "Начать смену", func():
		if GameStore.dispatch({"type": "START"}).ok:
			_start_screen.queue_free()
			_start_screen = null
			modal_changed.emit(false)
			if not _muted:
				_sound.play()
			_focus("window"))
	var mute := CheckButton.new()
	mute.text = "Играть без звука"
	mute.add_theme_color_override("font_color", INK)
	mute.toggled.connect(func(value: bool): _muted = value; _sound.stream_paused = value)
	box.add_child(mute)
	return screen

func _show_pause() -> void:
	if is_instance_valid(_start_screen):
		return
	_begin_modal("Пауза", "pause")
	_text(modal_body, "Мышь — выбрать предмет. Клавиши 1–4 — перевести взгляд. Escape — выйти из осмотра или открыть паузу.\n\nВ первом этапе прогресс хранится до закрытия игры.", 21)
	var mute := CheckButton.new()
	mute.text = "Выключить звук"
	mute.button_pressed = _muted
	mute.toggled.connect(func(value: bool): _muted = value; _sound.stream_paused = value)
	modal_body.add_child(mute)
	var motion := CheckButton.new()
	motion.text = "Уменьшить движение камеры"
	motion.button_pressed = _reduced
	motion.toggled.connect(func(value: bool): _reduced = value; motion_changed.emit(value))
	modal_body.add_child(motion)
	_button(modal_body, "Продолжить", _close_modal)
	_button(modal_body, "Начать обращение заново", _restart)
	_button(modal_body, "Выйти из игры", func(): get_tree().quit())

func _begin_modal(title: String, kind: String) -> void:
	_close_modal()
	_modal_kind = kind
	modal = ColorRect.new()
	modal.color = Color(0.035, 0.08, 0.08, 0.86)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var panel := _panel(modal, PAPER)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 110
	panel.offset_top = 96
	panel.offset_right = -110
	panel.offset_bottom = -96
	modal_body = VBoxContainer.new()
	panel.add_child(_margin(modal_body, 32, 26))
	var top := HBoxContainer.new()
	modal_body.add_child(top)
	var heading := _label(top, title, 29)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top, "Закрыть · Esc", _close_modal)
	_rule(modal_body)
	modal_changed.emit(true)

func _close_modal() -> void:
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal = null
	_modal_kind = ""
	modal_changed.emit(false)

func _restart() -> void:
	_close_modal()
	GameStore.dispatch({"type": "RESTART"})
	GameStore.dispatch({"type": "START"})
	_focus("window")
	_show_hint("Новое обращение. Нина ждёт у окна выдачи.")

func _focus(view_id: String) -> void:
	if is_instance_valid(modal):
		return
	_view = view_id
	focus_requested.emit(view_id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal):
			_close_modal()
		else:
			_show_pause()
		get_viewport().set_input_as_handled()
	if not snapshot.get("started", false) or is_instance_valid(modal):
		return
	var views := {KEY_1: "window", KEY_2: "shelf", KEY_3: "desk", KEY_4: "personal"}
	if views.has(event.keycode):
		_focus(views[event.keycode])
		get_viewport().set_input_as_handled()

func _show_hint(message: String) -> void:
	if is_instance_valid(hint):
		hint.text = message

func _create_audio() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -37
	add_child(_sound)
	var data := PackedByteArray()
	var sample_rate: int = 22050
	data.resize(sample_rate * 2)
	for i in sample_rate:
		var time: float = float(i) / sample_rate
		var value: float = sin(TAU * 50.0 * time) * 0.65 + sin(TAU * 100.0 * time) * 0.12
		data.encode_s16(i * 2, int(value * 13000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = sample_rate
	_sound.stream = stream

func _label(parent: Node, text_value: String, font_size: int = 19, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _text(parent: Node, text_value: String, font_size: int = 19) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.text = text_value
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 43
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _rule(parent: Node) -> void:
	var line := HSeparator.new()
	line.add_theme_stylebox_override("separator", _style(Color("ccd0bf"), 0))
	line.custom_minimum_size.y = 2
	parent.add_child(line)

func _panel(parent: Node, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color, 8))
	parent.add_child(panel)
	return panel

func _margin(child: Control, horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	margin.add_child(child)
	return margin

func _style(color: Color, radius: int = 0, border: Color = Color(0,0,0,0), width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
