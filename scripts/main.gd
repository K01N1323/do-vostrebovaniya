extends Node3D

@onready var room = $Room
@onready var camera_rig = $CameraRig
@onready var game_ui = $Interface/GameUI

func _ready() -> void:
	GameStore.state_changed.connect(_on_state)
	room.target_clicked.connect(game_ui.open_target)
	room.visitor_arrived.connect(game_ui.on_visitor_arrived)
	game_ui.focus_requested.connect(camera_rig.focus)
	camera_rig.view_changed.connect(room.set_view)
	game_ui.modal_changed.connect(func(blocked: bool):
		room.set_input_enabled(not blocked)
		camera_rig.look_enabled = not blocked)
	game_ui.motion_changed.connect(func(reduced: bool):
		camera_rig.reduced_motion = reduced
		room.set_reduced_motion(reduced))
	_on_state(GameStore.get_snapshot())
	room.set_input_enabled(false)
	camera_rig.look_enabled = false

func _on_state(snapshot: Dictionary) -> void:
	room.apply_snapshot(snapshot)
	game_ui.render(snapshot)
