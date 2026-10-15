extends Node3D
## A fixed, handcrafted bureau. Only snapshots determine package state.

signal target_clicked(target_id: String)

const G = preload("res://scripts/presentation/geometry.gd")
const CRATE_PROBE = preload("res://assets/models/crate_probe.glb")
const PACKAGE_POSITIONS := {
	"shelf": Vector3(-2.3, 1.2, -1.8),
	"desk": Vector3(0, 0.98, -0.35),
	"personal": Vector3(1.15, 0.3, 0.55),
}

@export var input_enabled: bool = true
var _hovered: String = ""
var _snapshot: Dictionary = {}
var _highlights: Dictionary = {}
var _paper_materials: Dictionary = {}
var _nina_face: MeshInstance3D
var _nina_normal: Material
var _nina_highlight: Material

@onready var _package: Node3D = $Package

func _ready() -> void:
	_build_room()
	_build_shelf()
	_build_desk()
	_build_window()
	_build_nina()
	_build_lighting()
	if not _snapshot.is_empty():
		apply_snapshot(_snapshot)

func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if not is_node_ready():
		return
	var package_state: Dictionary = snapshot.get("package", {})
	var location: String = str(package_state.get("location", "shelf"))
	_package.visible = location != "issued"
	if PACKAGE_POSITIONS.has(location):
		_package.position = PACKAGE_POSITIONS[location]
	# The opened flag records prior access; close the carrier for storage/transport.
	_package.set_opened(bool(package_state.get("opened", false)) and location == "desk")
	# Hidden packages must not remain raycast targets at their former position.
	var package_target: StaticBody3D = _package.get_node_or_null("Target_P01")
	if is_instance_valid(package_target):
		package_target.collision_layer = 1 if _package.visible else 0
	if not _package.visible and _hovered == "P01":
		set_hovered("")

func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		set_hovered("")

func set_hovered(target_id: String) -> void:
	_hovered = target_id
	if is_instance_valid(_package):
		_package.set_highlighted(target_id == "P01" and _package.visible)
	for key in _highlights:
		var mesh: MeshInstance3D = _highlights[key]
		mesh.visible = key == target_id
	if is_instance_valid(_nina_face):
		_nina_face.material_override = _nina_highlight if target_id == "nina" else _nina_normal

func _physics_process(_delta: float) -> void:
	if not input_enabled or not is_visible_in_tree():
		return
	# Avoid casting through open menus and dialogs that consume mouse events.
	var control := get_viewport().gui_get_hovered_control()
	if is_instance_valid(control) and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		if not _hovered.is_empty():
			set_hovered("")
		return
	var next_hovered := _pick(get_viewport().get_mouse_position())
	if next_hovered != _hovered:
		set_hovered(next_hovered)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target_id := _pick(event.position)
		if not target_id.is_empty():
			target_clicked.emit(target_id)
			get_viewport().set_input_as_handled()

func _pick(screen_position: Vector2) -> String:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return ""
	var origin := camera.project_ray_origin(screen_position)
	var finish := origin + camera.project_ray_normal(screen_position) * 30.0
	var query := PhysicsRayQueryParameters3D.create(origin, finish, 1)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return ""
	var collider: Object = result["collider"]
	return str(collider.get_meta("target_id", ""))

func _build_room() -> void:
	var upper := G.material(Color("788d84"))
	var lower := G.material(Color("4c6b61"))
	var trim := G.material(Color("344c43"))
	var plaster := G.material(Color("b0b4a3"))
	var wood := G.material(Color("635043"))
	G.box(self, Vector3(8.0, 0.12, 7.0), Vector3(0, -0.06, -0.3), wood)
	for row in range(15):
		var tone := 0.02 * float(row % 4)
		var plank := G.material(Color(0.29 + tone, 0.25 + tone, 0.21 + tone))
		var z := -3.65 + row * 0.45
		G.box(self, Vector3(7.98, 0.015, 0.435), Vector3(0, 0.006, z), plank)
		for joint in range(3):
			G.box(self, Vector3(0.012, 0.005, 0.43), Vector3(-3.3 + joint * 2.4 + float(row % 2) * 0.9, 0.016, z), wood)
	G.box(self, Vector3(8.1, 3.3, 0.18), Vector3(0, 1.65, -3.85), upper)
	G.box(self, Vector3(0.18, 3.3, 7.5), Vector3(-4.05, 1.65, -0.2), upper)
	G.box(self, Vector3(8.1, 1.13, 0.035), Vector3(0, 0.565, -3.74), lower)
	G.box(self, Vector3(0.035, 1.13, 7.5), Vector3(-3.94, 0.565, -0.2), lower)
	G.box(self, Vector3(8.1, 0.075, 0.06), Vector3(0, 1.16, -3.71), trim)
	G.box(self, Vector3(0.06, 0.075, 7.5), Vector3(-3.91, 1.16, -0.2), trim)
	G.box(self, Vector3(8.1, 0.10, 0.06), Vector3(0, 0.08, -3.71), trim)
	G.box(self, Vector3(0.06, 0.10, 7.5), Vector3(-3.91, 0.08, -0.2), trim)
	# Flat, slightly irregular plaster patches avoid an immaculate showroom look.
	for patch in [Vector3(-3.30, 2.15, -3.748), Vector3(0.1, 2.65, -3.748)]:
		G.box(self, Vector3(0.31, 0.11, 0.008), patch, plaster)
	_build_clock()
	var sign_board := G.material(Color("293f38"))
	G.box(self, Vector3(2.65, 0.41, 0.08), Vector3(1.3, 2.78, -3.70), sign_board)
	var sign := G.label(self, "ДО ВОСТРЕБОВАНИЯ", Vector3(1.3, 2.78, -3.647), 43)
	sign.pixel_size = 0.0022
	G.label(self, "А В Т О В О К З А Л", Vector3(-2.6, 2.73, -3.64), 22, Color("d2cbb8"))
	# A small faded timetable and wall-mounted key board.
	G.box(self, Vector3(0.68, 0.83, 0.04), Vector3(-0.75, 1.92, -3.71), trim)
	G.box(self, Vector3(0.59, 0.73, 0.016), Vector3(-0.75, 1.92, -3.68), G.material(Color("c3bfa2")))
	G.label(self, "ОКТЯБРЬ\n\n15\n\nЧЕТВЕРГ", Vector3(-0.75, 1.94, -3.66), 24, Color("5c6859"))

func _build_clock() -> void:
	var clock := Node3D.new()
	clock.position = Vector3(-0.6, 2.87, -3.70)
	add_child(clock)
	var brass := G.material(Color("8a8063"), 0.42)
	var face := G.material(Color("d4cfb5"))
	var rim := G.cylinder(clock, 0.235, 0.05, Vector3.ZERO, brass)
	rim.rotation_degrees.x = 90
	var dial := G.cylinder(clock, 0.204, 0.01, Vector3(0, 0, 0.032), face)
	dial.rotation_degrees.x = 90
	var ink := G.material(Color("39433c"))
	G.rod(clock, Vector3(0, 0, 0.044), Vector3(-0.10, 0.045, 0.044), 0.009, ink)
	G.rod(clock, Vector3(0, 0, 0.046), Vector3(0.06, 0.15, 0.046), 0.006, ink)
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		G.sphere(clock, 0.008, Vector3(sin(angle) * 0.175, cos(angle) * 0.175, 0.043), ink)

func _build_shelf() -> void:
	var wood := G.material(Color("665340"))
	var edge := G.material(Color("8c7150"))
	var board := G.material(Color("4f4b3d"))
	G.box(self, Vector3(1.65, 2.55, 0.09), Vector3(-2.3, 1.30, -2.18), board)
	for x in [-3.10, -1.50]:
		G.box(self, Vector3(0.08, 2.60, 0.75), Vector3(x, 1.30, -1.83), wood)
	for height in [0.28, 1.16, 2.02, 2.57]:
		G.box(self, Vector3(1.70, 0.08, 0.78), Vector3(-2.3, height, -1.81), wood)
		G.box(self, Vector3(1.72, 0.08, 0.035), Vector3(-2.3, height, -1.40), edge)
	var kraft := G.material(Color("9b8868"))
	var grey := G.material(Color("6f7b70"))
	var string_mat := G.material(Color("d3c6a1"))
	for info in [Vector3(-2.68, 0.58, -1.82), Vector3(-1.91, 0.50, -1.87), Vector3(-2.70, 2.23, -1.84), Vector3(-1.98, 2.22, -1.86)]:
		var parcel: Node3D
		if info == Vector3(-2.70, 2.23, -1.84):
			parcel = CRATE_PROBE.instantiate()
			parcel.name = "ImportedCrateProbe"
			parcel.scale = Vector3(0.55, 0.42, 0.48)
			parcel.position = info
			add_child(parcel)
		else:
			parcel = G.box(self, Vector3(0.55, 0.42, 0.48), info, kraft if info.x < -2.3 else grey)
		parcel.rotation_degrees.y = 3 if info.x < -2.3 else -4
		G.box(self, Vector3(0.025, 0.425, 0.485), info + Vector3(0.05, 0, 0), string_mat)
	G.label(self, "ХРАНЕНИЕ", Vector3(-2.3, 2.65, -1.38), 28, Color("ddc9a0"))
	var shelf_label := G.label(self, "П01", Vector3(-2.3, 1.16, -1.37), 22, Color("e0c68c"))
	shelf_label.pixel_size = 0.002

func _build_desk() -> void:
	var wood := G.material(Color("74583e"))
	var dark_wood := G.material(Color("4c4134"))
	var mat := G.material(Color("3e6354"))
	var metal := G.material(Color("8d8970"), 0.5)
	G.box(self, Vector3(2.1, 0.10, 1.12), Vector3(0, 0.93, -0.35), wood)
	G.box(self, Vector3(1.40, 0.012, 0.86), Vector3(-0.02, 0.986, -0.35), mat)
	for x in [-0.93, 0.93]:
		for z in [-0.79, 0.09]:
			G.box(self, Vector3(0.10, 0.90, 0.10), Vector3(x, 0.45, z), dark_wood)
	G.box(self, Vector3(0.58, 0.7, 0.85), Vector3(-0.72, 0.48, -0.35), dark_wood)
	for y in [0.31, 0.57, 0.80]:
		G.box(self, Vector3(0.51, 0.20, 0.025), Vector3(-0.72, y, 0.09), wood)
		G.rod(self, Vector3(-0.83, y, 0.115), Vector3(-0.62, y, 0.115), 0.012, metal)
	# Two readable paper targets lie in front of the carrier.
	_build_paper("identity", Vector3(-0.28, 0.997, 0.15), -6, "УДОСТОВЕРЕНИЕ", Color("dbd3b9"))
	_build_paper("claim", Vector3(0.28, 0.999, 0.15), 7, "ЗАЯВЛЕНИЕ № 01", Color("cac4a8"))
	var archive := Node3D.new()
	archive.name = "ArchiveFolder"
	archive.position = Vector3(-0.76, 1.00, -0.41)
	archive.rotation_degrees.y = -5
	add_child(archive)
	G.box(archive, Vector3(0.35, 0.06, 0.51), Vector3(0, 0.03, 0), G.material(Color("847756")))
	G.box(archive, Vector3(0.31, 0.035, 0.47), Vector3(0, 0.07, 0), G.material(Color("c9c1a4")))
	G.box(archive, Vector3(0.36, 0.02, 0.52), Vector3(0, 0.10, 0), G.material(Color("7c7150")))
	var archive_label := G.label(archive, "АРХИВ", Vector3(0, 0.114, 0), 20, Color("d9ceb2"))
	archive_label.rotation_degrees.x = -90
	archive_label.pixel_size = 0.002
	G.target(archive, "archive", Vector3(0.38, 0.15, 0.54), Vector3(0, 0.07, 0))
	_add_highlight(archive, "archive", Vector3(0.39, 0.008, 0.55), Vector3(0, 0.003, 0))
	# An L-shaped desk return covers the clerk's personal shelf under the table.
	G.box(self, Vector3(1.14, 0.10, 1.42), Vector3(1.08, 0.93, 0.35), wood)
	for z in [-0.28, 0.97]:
		G.box(self, Vector3(0.08, 0.90, 0.08), Vector3(1.58, 0.45, z), dark_wood)
	G.box(self, Vector3(0.95, 0.08, 0.84), Vector3(1.15, 0.26, 0.55), dark_wood)
	for x in [0.74, 1.56]:
		G.box(self, Vector3(0.07, 0.28, 0.72), Vector3(x, 0.14, 0.55), dark_wood)
	G.box(self, Vector3(0.45, 0.02, 0.32), Vector3(1.18, 0.311, 0.55), G.material(Color("6e7564")))
	_build_lamp()
	# An enamel cup, pencil and small date stamp provide familiar scale.
	G.cylinder(self, 0.065, 0.13, Vector3(0.82, 1.06, -0.65), G.material(Color("bdc6b2"), 0.42))
	G.cylinder(self, 0.053, 0.004, Vector3(0.82, 1.127, -0.65), G.material(Color("554737")))
	G.rod(self, Vector3(0.70, 0.995, -0.22), Vector3(0.91, 0.995, -0.33), 0.009, G.material(Color("b6a16a")))
	G.box(self, Vector3(0.12, 0.035, 0.10), Vector3(0.76, 1.012, -0.05), dark_wood)
	G.cylinder(self, 0.026, 0.1, Vector3(0.76, 1.073, -0.05), dark_wood)

func _build_paper(target_id: String, position: Vector3, angle: float, title: String, color: Color) -> void:
	var paper := Node3D.new()
	paper.position = position
	paper.rotation_degrees.y = angle
	add_child(paper)
	G.box(paper, Vector3(0.39, 0.008, 0.27), Vector3.ZERO, G.material(color))
	var ink := G.material(Color("777968"))
	for line_index in range(5):
		var length := 0.24 if line_index % 2 == 0 else 0.19
		G.box(paper, Vector3(length, 0.001, 0.003), Vector3(0.015, 0.005, -0.035 + line_index * 0.021), ink)
	var text := G.label(paper, title, Vector3(0, 0.007, -0.087), 13, Color("46574b"))
	text.rotation_degrees.x = -90
	text.pixel_size = 0.00165
	G.target(paper, target_id, Vector3(0.43, 0.035, 0.31), Vector3(0, 0.01, 0))
	_add_highlight(paper, target_id, Vector3(0.43, 0.003, 0.31), Vector3(0, -0.001, 0))

func _build_lamp() -> void:
	var brass := G.material(Color("8c7e53"), 0.35)
	var green := G.material(Color("48664d"), 0.34)
	var base := Vector3(-1.0, 1.01, -0.77)
	G.cylinder(self, 0.15, 0.045, base, brass)
	G.rod(self, base, base + Vector3(0.04, 0.46, -0.06), 0.018, brass)
	G.rod(self, base + Vector3(0.04, 0.46, -0.06), base + Vector3(0.29, 0.57, 0.01), 0.018, brass)
	G.cylinder(self, 0.22, 0.16, base + Vector3(0.29, 0.54, 0.01), green, 0.10)
	var glowing := G.material(Color("e7c885"))
	glowing.emission_enabled = true
	glowing.emission = Color("ebc78e")
	glowing.emission_energy_multiplier = 1.2
	G.cylinder(self, 0.18, 0.009, base + Vector3(0.29, 0.456, 0.01), glowing)
	var lamp := OmniLight3D.new()
	lamp.name = "WarmDeskLamp"
	lamp.position = base + Vector3(0.29, 0.40, 0.01)
	lamp.light_color = Color("ffcc88")
	lamp.light_energy = 1.55
	lamp.omni_range = 3.1
	lamp.omni_attenuation = 1.4
	lamp.shadow_enabled = true
	add_child(lamp)

func _build_window() -> void:
	var frame := G.material(Color("5d4d3c"))
	var edge := G.material(Color("927451"))
	var dark := G.material(Color("3d4e46"))
	G.box(self, Vector3(2.5, 1.06, 0.22), Vector3(1.76, 0.53, -2.35), dark)
	G.box(self, Vector3(2.72, 0.10, 0.65), Vector3(1.76, 1.11, -2.28), edge)
	for x in [0.45, 3.07]:
		G.box(self, Vector3(0.13, 2.55, 0.18), Vector3(x, 1.275, -2.44), frame)
	G.box(self, Vector3(2.75, 0.14, 0.18), Vector3(1.76, 2.48, -2.44), frame)
	G.box(self, Vector3(2.55, 0.28, 0.06), Vector3(1.76, 2.29, -2.45), dark)
	G.label(self, "БЮРО НАХОДОК", Vector3(1.76, 2.3, -2.405), 30, Color("cfc5a9"))
	G.label(self, "УДОСТОВЕРЕНИЕ И ЗАЯВЛЕНИЕ", Vector3(1.76, 0.84, -2.218), 19, Color("c5bba1"))
	# Simple blue panes convey the station beyond the counter without a second room.
	var glass := G.material(Color("809ca0"), 0.60)
	G.box(self, Vector3(1.38, 1.37, 0.03), Vector3(2.83, 1.80, -3.70), glass)
	G.box(self, Vector3(0.045, 1.4, 0.05), Vector3(2.84, 1.80, -3.66), frame)
	G.box(self, Vector3(1.42, 0.045, 0.05), Vector3(2.84, 1.85, -3.66), frame)
	G.label(self, "ПЛАТФОРМА 2", Vector3(2.84, 1.48, -3.63), 17, Color("cfdbcc"))
	var queue := G.material(Color("adb5a2"))
	G.box(self, Vector3(0.70, 0.06, 0.44), Vector3(1.15, 0.48, -3.17), queue)
	for x in [0.9, 1.4]:
		G.box(self, Vector3(0.05, 0.48, 0.06), Vector3(x, 0.24, -3.17), frame)

func _build_nina() -> void:
	var nina := Node3D.new()
	nina.name = "Nina"
	nina.position = Vector3(1.75, 0, -2.95)
	add_child(nina)
	var coat := G.material(Color("6d6759"))
	var skirt := G.material(Color("505c54"))
	var shoes := G.material(Color("353b33"))
	var hair := G.material(Color("77766a"))
	var skin := G.material(Color("c1ab8c"))
	var scarf := G.material(Color("95977c"))
	var eye := G.material(Color("3c4940"))
	_nina_normal = skin
	_nina_highlight = G.material(Color("d2b997"))
	for x in [-0.12, 0.12]:
		G.box(nina, Vector3(0.15, 0.10, 0.28), Vector3(x, 0.06, 0.045), shoes)
		G.cylinder(nina, 0.055, 0.42, Vector3(x, 0.31, 0), skirt)
	G.cylinder(nina, 0.26, 0.44, Vector3(0, 0.69, 0), skirt, 0.20)
	G.cylinder(nina, 0.25, 0.69, Vector3(0, 1.18, 0), coat, 0.21)
	G.sphere(nina, 0.145, Vector3(-0.20, 1.40, 0), coat, Vector3(0.7, 1.1, 0.85))
	G.sphere(nina, 0.145, Vector3(0.20, 1.40, 0), coat, Vector3(0.7, 1.1, 0.85))
	G.rod(nina, Vector3(-0.25, 1.37, 0.01), Vector3(-0.29, 1.10, 0.29), 0.077, coat)
	G.rod(nina, Vector3(0.25, 1.37, 0.01), Vector3(0.29, 1.10, 0.29), 0.077, coat)
	G.rod(nina, Vector3(-0.29, 1.10, 0.29), Vector3(-0.20, 1.19, 0.61), 0.065, coat)
	G.rod(nina, Vector3(0.29, 1.10, 0.29), Vector3(0.18, 1.19, 0.59), 0.065, coat)
	G.sphere(nina, 0.068, Vector3(-0.20, 1.19, 0.61), skin, Vector3(0.65, 0.45, 1.2))
	G.sphere(nina, 0.068, Vector3(0.18, 1.19, 0.59), skin, Vector3(0.65, 0.45, 1.2))
	G.cylinder(nina, 0.065, 0.14, Vector3(0, 1.57, 0), skin)
	G.sphere(nina, 0.21, Vector3(0, 1.79, 0), hair, Vector3(0.88, 1.20, 0.85))
	_nina_face = G.sphere(nina, 0.176, Vector3(0, 1.77, 0.056), skin, Vector3(0.87, 1.16, 0.85))
	G.sphere(nina, 0.10, Vector3(0.05, 1.82, -0.15), hair)
	G.sphere(nina, 0.16, Vector3(-0.034, 1.91, 0.02), hair, Vector3(1.05, 0.45, 1))
	G.sphere(nina, 0.019, Vector3(-0.058, 1.81, 0.196), eye, Vector3(0.8, 0.45, 0.45))
	G.sphere(nina, 0.019, Vector3(0.058, 1.81, 0.196), eye, Vector3(0.8, 0.45, 0.45))
	G.sphere(nina, 0.026, Vector3(0, 1.76, 0.207), skin, Vector3(0.58, 0.9, 0.7))
	G.rod(nina, Vector3(-0.034, 1.704, 0.185), Vector3(0.034, 1.708, 0.185), 0.004, eye)
	G.rod(nina, Vector3(-0.082, 1.84, 0.185), Vector3(-0.038, 1.85, 0.198), 0.006, hair)
	G.rod(nina, Vector3(0.038, 1.85, 0.198), Vector3(0.082, 1.84, 0.185), 0.006, hair)
	G.sphere(nina, 0.12, Vector3(0, 1.53, 0.035), scarf, Vector3(1.55, 0.45, 1.15))
	G.box(nina, Vector3(0.10, 0.34, 0.027), Vector3(-0.06, 1.32, 0.229), scarf)
	for y in [1.05, 1.22, 1.39]:
		G.sphere(nina, 0.014, Vector3(0.06, y, 0.235), eye)
	G.target(nina, "nina", Vector3(0.77, 1.25, 0.85), Vector3(0, 1.39, 0.17))

func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	world.name = "BureauEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("283b36")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b0bfb1")
	environment.ambient_light_energy = 0.56
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var daylight := DirectionalLight3D.new()
	daylight.name = "ColdStationLight"
	daylight.rotation_degrees = Vector3(-43, -27, 0)
	daylight.light_color = Color("bfd0cc")
	daylight.light_energy = 0.95
	daylight.shadow_enabled = true
	daylight.directional_shadow_max_distance = 18
	add_child(daylight)
	var fill := OmniLight3D.new()
	fill.name = "CounterFill"
	fill.position = Vector3(1.2, 2.65, -1.15)
	fill.light_color = Color("eadbb3")
	fill.light_energy = 1.15
	fill.omni_range = 5.5
	add_child(fill)
	var shelf_fill := OmniLight3D.new()
	shelf_fill.name = "ShelfFill"
	shelf_fill.position = Vector3(-2.0, 2.5, 0.05)
	shelf_fill.light_color = Color("acbfb2")
	shelf_fill.light_energy = 0.65
	shelf_fill.omni_range = 3.8
	add_child(shelf_fill)

func _add_highlight(parent: Node3D, target_id: String, size: Vector3, position: Vector3) -> void:
	var mat := G.material(Color("d8bc76"))
	mat.emission_enabled = true
	mat.emission = Color("ad955a")
	mat.emission_energy_multiplier = 0.8
	var mesh := G.box(parent, size, position, mat)
	mesh.visible = false
	_highlights[target_id] = mesh
