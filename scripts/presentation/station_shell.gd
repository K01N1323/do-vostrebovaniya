extends RefCounted
## Static station walls and waiting hall fixtures.

const G = preload("res://scripts/presentation/geometry.gd")

static func build(room: Node3D) -> void:
	var wall := G.worn_material(Color("99917f"), "plaster")
	var lower := G.worn_material(Color("6d746b"), "tile")
	var trim := G.worn_material(Color("464b43"), "metal", 0.86, 0.3)
	var floor := G.worn_material(Color("57564b"), "tile")
	G.box(room, Vector3(7.0, 0.12, 10.0), Vector3(0, -0.06, -2.0), floor)
	var grout := G.material(Color("363a32"))
	for z in range(21):
		G.box(room, Vector3(6.95, 0.003, 0.009), Vector3(0, 0.002, -6.8 + z * 0.48), grout)
	for x in range(15):
		G.box(room, Vector3(0.009, 0.003, 9.85), Vector3(-3.45 + x * 0.48, 0.002, -1.86), grout)
	G.box(room, Vector3(2.8, 0.009, 2.2), Vector3(-0.65, 0.009, 0.85), G.worn_material(Color("49483a"), "leather"))
	G.box(room, Vector3(7.0, 3.3, 0.2), Vector3(0, 1.65, -6.8), wall)
	for x in [-3.5, 2.4]:
		G.box(room, Vector3(0.16, 3.3, 9.8), Vector3(x, 1.65, -2.0), wall)
		G.box(room, Vector3(0.025, 1.12, 9.8), Vector3(x + (0.09 if x < 0 else -0.09), 0.56, -2.0), lower)
		G.box(room, Vector3(0.045, 0.09, 9.8), Vector3(x + (0.11 if x < 0 else -0.11), 0.06, -2.0), trim)
		G.box(room, Vector3(0.04, 0.045, 9.8), Vector3(x + (0.11 if x < 0 else -0.11), 1.15, -2.0), trim)
		for height in [0.28, 0.56, 0.84]:
			G.box(room, Vector3(0.005, 0.008, 9.7), Vector3(x + (0.108 if x < 0 else -0.108), height, -2.0), grout)
	G.box(room, Vector3(7.0, 1.12, 0.025), Vector3(0, 0.56, -6.68), lower)
	G.box(room, Vector3(7.0, 0.045, 0.04), Vector3(0, 1.16, -6.66), trim)
	G.box(room, Vector3(7.0, 0.10, 0.05), Vector3(0, 0.06, -6.64), trim)
	# A real ceiling, cornice and service conduits keep the hall enclosed.
	G.box(room, Vector3(7.0, 0.14, 10.0), Vector3(0, 3.15, -2.0), G.worn_material(Color("888878"), "plaster"))
	for x in [-3.37, 2.27]:
		G.box(room, Vector3(0.12, 0.13, 9.8), Vector3(x, 3.01, -2.0), G.worn_material(Color("73776b"), "plaster"))
	for z in [-5.7, -3.2, 0.1, 2.6]:
		G.box(room, Vector3(5.8, 0.025, 0.035), Vector3(-0.5, 3.06, z), trim)
	G.rod(room, Vector3(2.24, 2.91, -6.6), Vector3(2.24, 2.91, 2.5), 0.018, trim)
	G.rod(room, Vector3(2.24, 2.91, -2.9), Vector3(2.24, 0.3, -2.9), 0.018, trim)
	G.box(room, Vector3(0.11, 0.18, 0.16), Vector3(2.23, 1.65, -2.9), trim)
	_build_station_door(room)
	_build_hall_window(room)
	_build_notices(room)
	_build_bench(room)
	_build_ceiling_fixture(room, Vector3(-0.6, 3.0, -3.4), true)
	_build_ceiling_fixture(room, Vector3(0.7, 3.0, -5.9), false)
	# Small irregular moisture stains belong to the low wall, away from the face.
	var damp := G.worn_material(Color("565b50"), "rust")
	_add_wall_stain(room, Vector3(-2.9, 0.18, -6.65), Vector2(0.75, 0.38), damp)
	_add_wall_stain(room, Vector3(1.94, 0.17, -6.65), Vector2(0.54, 0.25), damp)
	_build_clock(room)
	G.label(room, "А В Т О В О К З А Л", Vector3(0.1, 2.76, -6.62), 27, Color("b0ac94"))

static func _build_clock(room: Node3D) -> void:
	var clock := Node3D.new()
	clock.position = Vector3(-0.56, 2.26, -6.60)
	room.add_child(clock)
	var rim := G.cylinder(clock, 0.20, 0.04, Vector3.ZERO, G.worn_material(Color("555949"), "metal", 0.7, 0.4))
	rim.rotation_degrees.x = 90
	var dial := G.cylinder(clock, 0.176, 0.01, Vector3(0, 0, 0.025), G.worn_material(Color("b7b69b"), "paper"))
	dial.rotation_degrees.x = 90
	var ink := G.material(Color("2c3b30"))
	G.rod(clock, Vector3(0, 0, 0.036), Vector3(-0.09, 0.04, 0.036), 0.007, ink)
	G.rod(clock, Vector3(0, 0, 0.038), Vector3(0.05, 0.13, 0.038), 0.005, ink)
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		G.sphere(clock, 0.006, Vector3(sin(angle) * 0.15, cos(angle) * 0.15, 0.037), ink)

static func _build_station_door(room: Node3D) -> void:
	var frame := G.worn_material(Color("69624f"), "wood")
	var paint := G.worn_material(Color("6d7165"), "paint")
	var metal := G.worn_material(Color("73746a"), "metal", 0.82, 0.4)
	G.box(room, Vector3(1.08, 2.28, 0.03), Vector3(-1.7, 1.14, -6.65), G.material(Color("252c27")))
	for x in [-2.29, -1.11]:
		G.box(room, Vector3(0.11, 2.42, 0.17), Vector3(x, 1.21, -6.59), frame)
	G.box(room, Vector3(1.29, 0.12, 0.17), Vector3(-1.7, 2.39, -6.59), frame)
	G.box(room, Vector3(1.13, 0.045, 0.32), Vector3(-1.7, 0.027, -6.48), metal)
	var wing := Node3D.new()
	wing.name = "HalfOpenStationDoor"
	wing.position = Vector3(-2.23, 0, -6.57)
	wing.rotation_degrees.y = -61
	room.add_child(wing)
	G.box(wing, Vector3(1.03, 2.23, 0.075), Vector3(0.515, 1.15, 0), paint)
	G.box(wing, Vector3(0.81, 0.87, 0.025), Vector3(0.515, 1.59, 0.05), frame)
	G.box(wing, Vector3(0.70, 0.76, 0.015), Vector3(0.515, 1.59, 0.069), G.worn_material(Color("59645d"), "tile"))
	G.box(wing, Vector3(0.91, 0.27, 0.02), Vector3(0.515, 0.24, 0.049), metal)
	G.box(wing, Vector3(0.07, 0.17, 0.018), Vector3(0.88, 1.08, 0.055), metal)
	G.rod(wing, Vector3(0.88, 1.11, 0.09), Vector3(0.77, 1.11, 0.09), 0.014, metal)
	G.label(room, "ПЛАТФОРМЫ  1—4", Vector3(-1.7, 2.60, -6.55), 23, Color("aca995"))
	# A second, shut employee door gives the secure side a believable entrance.
	var employee := Node3D.new()
	employee.position = Vector3(-3.39, 0, 1.65)
	employee.rotation_degrees.y = 90
	room.add_child(employee)
	G.box(employee, Vector3(0.91, 2.16, 0.055), Vector3(0, 1.08, 0), G.worn_material(Color("555447"), "wood"))
	for x in [-0.50, 0.50]:
		G.box(employee, Vector3(0.09, 2.30, 0.11), Vector3(x, 1.15, 0.02), frame)
	G.box(employee, Vector3(1.09, 0.10, 0.11), Vector3(0, 2.25, 0.02), frame)
	G.box(employee, Vector3(0.16, 0.15, 0.025), Vector3(0.32, 1.04, 0.045), metal)
	G.rod(employee, Vector3(0.34, 1.07, 0.075), Vector3(0.22, 1.07, 0.075), 0.014, metal)
	G.label(employee, "СЛУЖЕБНОЕ", Vector3(0, 1.72, 0.042), 17, Color("c0b59a"))

static func _build_hall_window(room: Node3D) -> void:
	var window := Node3D.new()
	window.name = "StationWindowAndRadiator"
	window.position = Vector3(2.29, 0, -4.3)
	window.rotation_degrees.y = -90
	room.add_child(window)
	var wood := G.worn_material(Color("777669"), "wood")
	var glass := G.worn_material(Color("657174"), "tile", 0.57)
	G.box(window, Vector3(1.65, 1.45, 0.07), Vector3(0, 1.96, 0), G.material(Color("363f3c")))
	for x in [-0.81, 0.0, 0.81]:
		G.box(window, Vector3(0.065, 1.45, 0.10), Vector3(x, 1.96, 0.035), wood)
	for x in [-0.40, 0.40]:
		G.box(window, Vector3(0.72, 1.28, 0.025), Vector3(x, 1.96, 0.025), glass)
	for y in [1.26, 2.66]:
		G.box(window, Vector3(1.72, 0.07, 0.13), Vector3(0, y, 0.04), wood)
	G.box(window, Vector3(1.88, 0.065, 0.31), Vector3(0, 1.23, 0.13), G.worn_material(Color("8d8d7c"), "plaster"))
	var radiator := G.worn_material(Color("7e8277"), "metal", 0.9, 0.25)
	for i in range(11):
		var x := -0.66 + i * 0.132
		G.rod(window, Vector3(x, 0.31, 0.11), Vector3(x, 0.91, 0.11), 0.041, radiator)
	for y in [0.38, 0.84]:
		G.rod(window, Vector3(-0.77, y, 0.11), Vector3(0.78, y, 0.11), 0.025, radiator)
	G.rod(window, Vector3(0.83, 0.35, 0.11), Vector3(0.83, 0.13, 0.11), 0.018, radiator)
	G.cylinder(window, 0.038, 0.035, Vector3(0.83, 0.33, 0.11), G.material(Color("4d5147")))

static func _build_notices(room: Node3D) -> void:
	var board := Node3D.new()
	board.name = "DustyStationNoticeBoard"
	board.position = Vector3(0.96, 1.73, -6.64)
	room.add_child(board)
	G.box(board, Vector3(1.63, 1.34, 0.07), Vector3.ZERO, G.worn_material(Color("4b493b"), "wood"))
	G.box(board, Vector3(1.49, 1.20, 0.02), Vector3(0, 0, 0.046), G.worn_material(Color("706955"), "cloth"))
	_wall_notice(board, Vector3(-0.32, 0.12, 0.065), Vector2(0.63, 0.88), "РАСПИСАНИЕ", "06:20   ПРИГОРОД\n08:10   СЕВЕРНЫЙ\n12:40   РЕЧНОЙ\n18:15   ПРИГОРОД\n22:40   ПОСЛЕДНИЙ", -2.0)
	_wall_notice(board, Vector3(0.40, 0.25, 0.068), Vector2(0.53, 0.55), "ОБЪЯВЛЕНИЕ", "БИЛЕТЫ\nСОХРАНЯТЬ\nДО КОНЦА ПОЕЗДКИ", 2.5)
	_wall_notice(board, Vector3(0.37, -0.36, 0.071), Vector2(0.48, 0.31), "ЗАБЫТЫЕ ВЕЩИ", "СПРАВА ОТ КАССЫ", -4.0)
	# Older notices leave pale rectangles and torn paper below the board.
	var old_paste := G.worn_material(Color("aaa08a"), "paper")
	G.box(room, Vector3(0.29, 0.48, 0.006), Vector3(-0.52, 1.53, -6.686), old_paste)
	G.box(room, Vector3(0.23, 0.09, 0.008), Vector3(-0.49, 1.18, -6.679), old_paste)
	var phone := Node3D.new()
	phone.position = Vector3(2.29, 1.73, -2.6)
	phone.rotation_degrees.y = -90
	room.add_child(phone)
	_wall_notice(phone, Vector3.ZERO, Vector2(0.54, 0.68), "СПРАВОЧНАЯ", "ПРИ УТЕРЕ БАГАЖА\nОБРАТИТЕСЬ К\nСМОТРИТЕЛЮ\n\nЧАСЫ РАБОТЫ\n08:00 — 23:00", -1.0)

static func _wall_notice(parent: Node3D, position: Vector3, size: Vector2, title: String, text: String, angle: float) -> void:
	var notice := Node3D.new()
	notice.position = position
	notice.rotation_degrees.z = angle
	parent.add_child(notice)
	G.box(notice, Vector3(size.x, size.y, 0.007), Vector3.ZERO, G.worn_material(Color("c6baa0"), "paper"))
	var header := G.label(notice, title, Vector3(0, size.y * 0.35, 0.007), 19, Color("4b5144"))
	header.pixel_size = 0.00175
	var body := G.label(notice, text, Vector3(0, -size.y * 0.05, 0.008), 14, Color("555a4b"))
	body.pixel_size = 0.00155
	var nail := G.material(Color("777466"))
	G.sphere(notice, 0.006, Vector3(-size.x * 0.40, size.y * 0.42, 0.01), nail)
	G.sphere(notice, 0.006, Vector3(size.x * 0.40, size.y * 0.42, 0.01), nail)

static func _build_bench(room: Node3D) -> void:
	var bench := Node3D.new()
	bench.name = "WaitingHallBench"
	bench.position = Vector3(0.87, 0, -5.42)
	room.add_child(bench)
	var wood := G.worn_material(Color("6e6045"), "wood")
	var steel := G.worn_material(Color("424a40"), "metal", 0.87, 0.45)
	for x in [-0.61, 0.61]:
		G.rod(bench, Vector3(x, 0.04, 0.16), Vector3(x, 0.43, 0.11), 0.022, steel)
		G.rod(bench, Vector3(x, 0.04, -0.18), Vector3(x, 0.96, -0.25), 0.022, steel)
		G.rod(bench, Vector3(x, 0.39, -0.20), Vector3(x, 0.39, 0.20), 0.023, steel)
	for z in [-0.15, 0.0, 0.15]:
		G.box(bench, Vector3(1.63, 0.035, 0.12), Vector3(0, 0.45, z), wood)
	for y in [0.64, 0.79, 0.94]:
		G.box(bench, Vector3(1.63, 0.12, 0.035), Vector3(0, y, -0.25), wood)
	G.box(bench, Vector3(0.24, 0.015, 0.17), Vector3(0.45, 0.48, 0.02), G.worn_material(Color("b3aa92"), "paper"))

static func _build_ceiling_fixture(room: Node3D, position: Vector3, working: bool) -> void:
	var fixture := Node3D.new()
	fixture.name = "FluorescentFixture"
	fixture.position = position
	room.add_child(fixture)
	var enamel := G.worn_material(Color("83877b"), "metal", 0.8, 0.3)
	G.box(fixture, Vector3(1.38, 0.085, 0.29), Vector3.ZERO, enamel)
	G.box(fixture, Vector3(1.24, 0.025, 0.22), Vector3(0, -0.054, 0), G.material(Color("4c554b")))
	var tube := G.material(Color("abb4a2") if working else Color("72786c"))
	if working:
		tube.emission_enabled = true
		tube.emission = Color("b1c0ae")
		tube.emission_energy_multiplier = 0.35
	for z in [-0.065, 0.065]:
		var light_mesh := G.cylinder(fixture, 0.018, 1.13, Vector3(0, -0.077, z), tube)
		light_mesh.rotation_degrees.z = 90
		for x in [-0.58, 0.58]:
			G.box(fixture, Vector3(0.045, 0.065, 0.05), Vector3(x, -0.059, z), enamel)

static func _add_wall_stain(parent: Node3D, position: Vector3, size: Vector2, material: Material) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = [Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.48, -0.09, 0), Vector3(0.34, -0.04, 0), Vector3(0.25, 0.33, 0), Vector3(0.09, 0.12, 0), Vector3(-0.11, 0.50, 0), Vector3(-0.23, 0.18, 0), Vector3(-0.47, 0.22, 0)]
	for i in range(1, points.size() - 1):
		for point in [points[0], points[i], points[i + 1]]:
			builder.add_vertex(Vector3(point.x * size.x, point.y * size.y, 0))
	builder.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = builder.commit()
	mesh.material_override = material
	mesh.position = position
	parent.add_child(mesh)
