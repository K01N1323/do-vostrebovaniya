extends SubViewportContainer
## The transfer tray follows the hand with inertia. The claim stays open until confirmed.

signal changed
signal contact

const Geometry = preload("res://scripts/presentation/geometry.gd")
const Packages = preload("res://scripts/presentation/package_registry.gd")
const ENTRY := 0.40
const EXIT := 0.66
const FINISH := 0.96

var item_id := ""
var progress := 0.0
var jolted := false
var caught := false
var handle_tucked := false
var message := ""
var _target := 0.0
var _angle := 0.0
var _velocity := 0.0
var _dragging := false
var _turning := false
var _tray: Node3D
var _item: Node3D
var _handle: Node3D

func _ready() -> void:
	custom_minimum_size = Vector2(615, 380)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	stretch = true
	mouse_default_cursor_shape = CURSOR_DRAG
	var viewport := SubViewport.new()
	viewport.size = Vector2i(740, 455)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	_build_track(world)

func _build_track(world: Node3D) -> void:
	var steel := Geometry.worn_material(Color("535d53"), "metal")
	var frame := Geometry.worn_material(Color("283b35"), "metal")
	var rubber := Geometry.worn_material(Color("222825"), "plastic")
	var housing := Geometry.worn_material(Color("32423c"), "metal")
	var marks := Geometry.material(Color("b6a268"))
	var width := 0.62 if item_id == "P03" else 0.97
	Geometry.box(world, Vector3(4.6, 0.14, 3.8), Vector3(0, -0.16, 0), housing)
	Geometry.box(world, Vector3(1.68, 0.12, 3.5), Vector3(0, -0.09, 0), frame)
	Geometry.box(world, Vector3(1.12, 0.018, 2.85), Vector3.ZERO, rubber)
	for side in [-1.0, 1.0]:
		Geometry.box(world, Vector3(0.04, 0.043, 2.9), Vector3(side * 0.55, 0.01, 0), steel)
		Geometry.box(world, Vector3(0.14, 0.36, 0.27), Vector3(side * (width / 2.0 + 0.07), 0.18, 0.02), steel)
		Geometry.box(world, Vector3(0.055, 0.018, 0.20), Vector3(side * 0.45, 0.016, -1.16), marks)
		Geometry.box(world, Vector3(1.38, 0.10, 0.38), Vector3(side * 1.46, -0.035, 0.02), frame)
		for z in [-1.3, -0.7, 0.7, 1.3]:
			Geometry.cylinder(world, 0.046, 0.014, Vector3(side * 0.69, -0.018, z), steel)
	_tray = Node3D.new()
	world.add_child(_tray)
	Geometry.box(_tray, Vector3(0.93, 0.04, 0.94), Vector3(0, 0.04, 0), steel)
	for side in [-1.0, 1.0]:
		Geometry.box(_tray, Vector3(0.84, 0.032, 0.021), Vector3(0, 0.069, side * 0.45), frame)
	_item = Packages.instantiate(item_id)
	_tray.add_child(_item)
	_item.position.y = 0.064
	if item_id == "P03":
		_handle = Geometry.box(_item, Vector3(0.26, 0.017, 0.15), Vector3(-0.31, 0.22, 0.24), Geometry.worn_material(Color("866649"), "leather"))
	var key := DirectionalLight3D.new()
	key.light_color = Color("ecd6a4")
	key.light_energy = 0.88
	key.rotation_degrees = Vector3(-61, -29, 0)
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("77b5ad")
	fill.light_energy = 0.57
	fill.rotation_degrees = Vector3(-46, 139, 0)
	world.add_child(fill)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 3.35, 2.10)
	camera.look_at(Vector3(0, 0, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.42
	camera.current = true
	_apply_pose()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_turning = event.pressed
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			nudge(-event.relative.y / size.y * 1.58)
			accept_event()
		elif _turning and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			turn(event.relative.x / size.x * TAU)
			accept_event()

func nudge(amount: float) -> void:
	_target = clampf(_target + amount, 0, 1)

func turn(amount: float) -> void:
	if item_id != "P03":
		return
	if progress > ENTRY + 0.018 and progress < EXIT:
		message = "Подтяните поднос к себе, чтобы развернуть чемодан."
	else:
		_angle = wrapf(_angle + amount, -PI, PI)
		message = ""
		_apply_pose()
	changed.emit()

func tuck_handle() -> void:
	if not caught or not is_instance_valid(_handle):
		return
	caught = false
	handle_tucked = true
	_handle.rotation_degrees.y = 83
	_handle.position = Vector3(-0.27, 0.224, 0.04)
	message = "Ремешок убран. Подайте поднос дальше."
	changed.emit()

func _physics_process(delta: float) -> void:
	var difference := _target - progress
	if absf(difference) < 0.0005 and absf(_velocity) < 0.002:
		return
	var speed_limit := 1.12 if item_id == "P01" else 0.85
	var status_changed := false
	var was_ready := ready_to_deliver()
	_velocity = move_toward(_velocity, clampf(difference * 5.5, -speed_limit, speed_limit), delta * 4.8)
	if item_id == "P01" and not jolted and absf(_velocity) > 0.84:
		jolted = true
		message = "Внутри звякнуло блюдце. Переноску всё ещё можно передать."
		status_changed = true
		contact.emit()
	var next := clampf(progress + _velocity * delta, 0.0, 1.0)
	if item_id == "P03" and _velocity > 0.0 and progress < EXIT and next >= ENTRY:
		var width := absf(cos(_angle)) * 0.76 + absf(sin(_angle)) * 0.48
		if width > 0.60:
			_block(ENTRY, "Чемодан упёрся в раму. Разверните его боком.")
			return
		if not handle_tucked and next >= ENTRY + 0.14:
			caught = true
			_block(ENTRY + 0.14, "Ремешок зацепился за край. Уберите его с направляющей.")
			return
	progress = next
	if progress in [0.0, 1.0]:
		_velocity = 0.0
	if ready_to_deliver() and not was_ready and not jolted:
		message = "Поднос у дальнего края. Можно закончить передачу."
	elif was_ready and not ready_to_deliver() and not jolted:
		message = ""
	_apply_pose()
	if status_changed or was_ready != ready_to_deliver():
		changed.emit()

func _block(at: float, reason: String) -> void:
	progress = at
	_target = at
	_velocity = 0
	message = reason
	_apply_pose()
	contact.emit()
	changed.emit()

func _apply_pose() -> void:
	_tray.position.z = lerpf(1.01, -1.09, progress)
	_item.rotation.y = _angle
	_item.rotation.x = _velocity * 0.045 if item_id == "P01" else 0.0

func ready_to_deliver() -> bool:
	return progress >= FINISH
