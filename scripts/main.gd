extends Node3D

@onready var room = $Room
@onready var camera_rig = $CameraRig
@onready var game_ui = $Interface/GameUI

func _ready() -> void:
	get_tree().auto_accept_quit = false
	if not GameStore.content_errors.is_empty():
		return
	var film := CanvasLayer.new()
	film.name = "FilmGrade"
	film.set_script(preload("res://scripts/presentation/film_grade.gd"))
	add_child(film)
	GameStore.state_changed.connect(_on_state)
	room.target_clicked.connect(game_ui.open_target)
	room.hover_changed.connect(game_ui.set_hovered_target)
	room.visitor_arrived.connect(game_ui.on_visitor_arrived)
	room.sound_requested.connect(game_ui.play_cue)
	room.visitor_departed.connect(_refresh_transition)
	room.handover_finished.connect(_refresh_transition)
	game_ui.focus_requested.connect(camera_rig.focus)
	game_ui.dialogue_framing_changed.connect(camera_rig.set_dialogue_framing)
	game_ui.dialogue_framing_changed.connect(room.set_dialogue_framing)
	game_ui.dialogue_pose_changed.connect(room.set_dialogue_pose)
	camera_rig.view_changed.connect(room.set_view)
	game_ui.modal_changed.connect(func(blocked: bool):
		room.set_input_enabled(not blocked)
		camera_rig.look_enabled = not blocked)
	game_ui.motion_changed.connect(func(reduced: bool):
		camera_rig.reduced_motion = reduced
		room.set_reduced_motion(reduced))
	game_ui.motion_changed.emit(game_ui.get("_reduced"))
	_on_state(GameStore.get_snapshot())
	room.set_input_enabled(false)
	camera_rig.look_enabled = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(game_ui):
		game_ui._quit_game()

func _on_state(snapshot: Dictionary) -> void:
	room.apply_snapshot(snapshot, GameStore.restoring)
	game_ui.render(snapshot)
	if GameStore.restoring and snapshot.case_status == "active":
		game_ui.on_visitor_arrived()
	_refresh_transition()

func _refresh_transition() -> void:
	game_ui.set_serov_at_bus(room.is_serov_at_bus())
	game_ui.set_can_advance(room.visitor_phase in ["gone", "at_bus"] and not room.transfer_active)
