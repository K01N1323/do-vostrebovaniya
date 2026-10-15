extends SceneTree
## Captures our game's rendered frames and exercises actual button callbacks.

var main: Node
var ui: Control
var failures: Array[String] = []
var output_dir: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	output_dir = ProjectSettings.globalize_path("res://tools/preview")
	DirAccess.make_dir_recursive_absolute(output_dir)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	ui = main.get_node("Interface/GameUI")
	await _frame("01-title")
	var mute := _find(ui, "Играть без звука")
	mute.button_pressed = true
	await _click(_find(ui, "Начать смену"))
	await _frame("02-room")
	_check(root.get_node("GameStore").get_snapshot().started, "Button START works")
	await _click(_find(ui, "Сравнить обе бумаги"))
	await _frame("03-documents")
	_check(is_instance_valid(ui.modal) and ui._modal_kind == "document", "Button comparison opens document")
	_check(root.get_node("GameStore").get_snapshot().read_documents.size() == 2, "Button comparison records papers")
	if is_instance_valid(ui.modal):
		await _click(_find(ui.modal, "Вернуться к столу"))
	await _click(_find(ui, "Поставить на стол"))
	await _frame("04-desk")
	await _click(_find(ui, "Открыть и осмотреть"))
	await _frame("05-inspection")
	_check(ui._modal_kind == "inspection", "Button inspection opens stage")
	if is_instance_valid(ui.modal):
		await _click(_find(ui.modal, "Три бутерброда"))
		await _frame("06-detail")
		_check("sandwiches" in root.get_node("GameStore").get_snapshot().inspected_details, "Button detail records observation")
		await _click(_find(ui.modal, "Закончить осмотр · Esc"))
	await _click(_find(ui, "Принять решение"))
	await _frame("07-decision")
	if is_instance_valid(ui.modal):
		await _click(_find(ui.modal, "Выдать переноску Нине Лукиной"))
	await _frame("08-result")
	_check(root.get_node("GameStore").get_snapshot().decision == "issue", "Button decision issues package")
	for decision in ["retain", "appropriate"]:
		ui._restart()
		var store := root.get_node("GameStore")
		for command in [{"type":"READ_DOCUMENT","document_id":"identity"},{"type":"READ_DOCUMENT","document_id":"claim"},{"type":"MOVE_PACKAGE","destination":"desk"},{"type":"OPEN_PACKAGE"},{"type":"INSPECT_DETAIL","detail_id":"sandwiches"}]:
			store.dispatch(command)
		ui._show_decision()
		var caption: String = "Завершить обращение · оставить на хранении" if decision == "retain" else "Убрать под стол · присвоить переноску"
		await _click(_find(ui.modal, caption))
		ui._close_modal()
		await _frame("09-" + decision)
		_check(store.get_snapshot().decision == decision, "Button decision " + decision)
	if failures.is_empty():
		print("PASS: rendered previews and UI button workflow")
	else:
		for message in failures:
			push_error(message)
	main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _frame(id: String) -> void:
	await create_timer(0.8).timeout
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	image.save_png(output_dir.path_join(id + ".png"))

func _click(button: Button) -> void:
	if not is_instance_valid(button):
		failures.append("Missing visible button")
		return
	await process_frame
	button.pressed.emit()
	await process_frame

func _find(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var result := _find(child, caption)
		if result:
			return result
	return null

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
