extends Node3D
## P01: a rigid cat carrier with a latched grille; there is no animal inside.

const G = preload("res://scripts/presentation/geometry.gd")

var opened: bool = false
var highlighted: bool = false
var _lid: Node3D
var _door: Node3D
var _contents: Node3D
var _halo: MeshInstance3D
var _detail_targets: Array[StaticBody3D] = []
var _target: StaticBody3D

func _ready() -> void:
	_build()
	set_opened(opened)
	set_highlighted(highlighted)

func set_opened(value: bool) -> void:
	opened = value
	if not is_instance_valid(_lid):
		return
	_lid.rotation_degrees.x = -112.0 if opened else 0.0
	# The wire door folds back along the outer side, keeping the food in view.
	_door.rotation_degrees.y = -95.0 if opened else 0.0
	_door.position.x = 0.438 if opened else 0.385
	_contents.visible = opened

func set_highlighted(value: bool) -> void:
	highlighted = value
	if is_instance_valid(_halo):
		_halo.visible = value

func set_detail_picking(value: bool) -> void:
	if is_instance_valid(_target):
		_target.collision_layer = 0 if value else 1
	for body in _detail_targets:
		body.collision_layer = 2 if value else 0

func _build() -> void:
	var shell := G.worn_material(Color("b7b19a"), "plastic", 0.88, 0.0)
	var upper_shell := G.worn_material(Color("c9c3ad"), "plastic", 0.84, 0.0)
	var rim := G.worn_material(Color("8c8975"), "plastic", 0.90, 0.0)
	var dark := G.worn_material(Color("303833"), "metal", 0.85, 0.3)
	var metal := G.worn_material(Color("50594f"), "metal", 0.80, 0.4)
	var cloth := G.worn_material(Color("ada88e"), "cloth")
	var seam := G.material(Color("8a856d"))
	var blue := G.worn_material(Color("4d7380"), "cloth")
	_rounded_box(self, Vector3(0.84, 0.075, 0.62), Vector3(0, 0.038, 0), 0.036, shell)
	_rounded_box(self, Vector3(0.84, 0.17, 0.035), Vector3(0, 0.15, -0.29), 0.016, shell)
	_rounded_box(self, Vector3(0.035, 0.18, 0.60), Vector3(-0.405, 0.15, 0), 0.016, shell)
	_rounded_box(self, Vector3(0.035, 0.18, 0.60), Vector3(0.405, 0.15, 0), 0.016, shell)
	_rounded_box(self, Vector3(0.84, 0.035, 0.035), Vector3(0, 0.09, 0.29), 0.016, rim)
	var faded := G.worn_material(Color("c9c4af"), "plastic", 0.94, 0.0)
	for side in [-1.0, 1.0]:
		for i in range(3):
			G.box(self, Vector3(0.002, 0.006 + i * 0.002, 0.045 + i * 0.013), Vector3(side * 0.424, 0.10 + i * 0.032, -0.20 + i * 0.12), faded)
	for x in [-0.403, 0.403]:
		for z in [-0.28, 0.28]:
			G.cylinder(self, 0.022, 0.19, Vector3(x, 0.137, z), shell)
			G.sphere(self, 0.022, Vector3(x, 0.232, z), shell, Vector3(1, 0.5, 1))
	G.box(self, Vector3(0.18, 0.035, 0.009), Vector3(0.18, 0.041, 0.315), G.worn_material(Color("b0a58a"), "paper"))
	var front_id := G.label(self, "П01", Vector3(0.18, 0.041, 0.321), 13, Color("42483e"))
	front_id.pixel_size = 0.0016
	# The grille has real spaces between rods, two hinges and a visible latch.
	_door = Node3D.new()
	_door.name = "GrilleDoor"
	_door.position = Vector3(0.385, 0.075, 0.32)
	add_child(_door)
	for y in [0.025, 0.36]:
		_rounded_box(_door, Vector3(0.77, 0.025, 0.028), Vector3(-0.385, y, 0), 0.012, dark)
	for x in [-0.758, -0.012]:
		_rounded_box(_door, Vector3(0.025, 0.36, 0.028), Vector3(x, 0.1925, 0), 0.012, dark)
	for i in range(1, 10):
		var x := -0.77 + float(i) * 0.077
		G.rod(_door, Vector3(x, 0.035, 0), Vector3(x, 0.35, 0), 0.007, metal)
	for y in [0.115, 0.205, 0.295]:
		G.rod(_door, Vector3(-0.75, y, 0), Vector3(-0.02, y, 0), 0.007, metal)
	G.box(_door, Vector3(0.065, 0.10, 0.045), Vector3(-0.735, 0.20, 0.025), dark)
	G.box(_door, Vector3(0.028, 0.065, 0.055), Vector3(-0.735, 0.20, 0.052), metal)
	for y in [0.10, 0.32]:
		G.cylinder(_door, 0.019, 0.07, Vector3(0.006, y, 0), dark)
	# The rigid upper shell opens backwards to expose the contents.
	_lid = Node3D.new()
	_lid.name = "RigidTopShell"
	_lid.position = Vector3(0, 0.235, -0.29)
	add_child(_lid)
	_arched_roof(_lid, upper_shell)
	for z in [0.0, 0.59]:
		_rounded_box(_lid, Vector3(0.84, 0.035, 0.035), Vector3(0, 0.015, z), 0.016, rim)
	for x in [-0.405, 0.405]:
		_rounded_box(_lid, Vector3(0.035, 0.035, 0.59), Vector3(x, 0.015, 0.29), 0.016, rim)
	_rounded_box(_lid, Vector3(0.85, 0.045, 0.035), Vector3(0, 0.188, 0.59), 0.016, upper_shell)
	_rounded_box(_lid, Vector3(0.85, 0.205, 0.035), Vector3(0, 0.105, 0), 0.016, upper_shell)
	for x in [-0.407, 0.407]:
		# Two rows of broad rectangular ventilation holes, with moulded dividers.
		for y in [0.035, 0.1125, 0.1875]:
			_rounded_box(_lid, Vector3(0.036, 0.035, 0.60), Vector3(x, y, 0.29), 0.012, upper_shell)
		for z in [0.045, 0.212, 0.379, 0.546]:
			_rounded_box(_lid, Vector3(0.036, 0.19, 0.028), Vector3(x, 0.11, z), 0.009, upper_shell)
	for x in [-0.425, 0.425]:
		for z in [0.10, 0.49]:
			G.box(_lid, Vector3(0.018, 0.065, 0.055), Vector3(x, 0.025, z), dark)
			G.box(_lid, Vector3(0.020, 0.025, 0.032), Vector3(x * 1.015, 0.020, z), metal)
	# A single dark U-shaped moulded handle gives the familiar carrier silhouette.
	var handle := G.worn_material(Color("3e433a"), "plastic", 0.85, 0.0)
	for x in [-0.14, 0.14]:
		G.rod(_lid, Vector3(x, 0.26, 0.29), Vector3(x, 0.33, 0.29), 0.018, handle)
	var last := Vector3(-0.14, 0.33, 0.29)
	for i in range(1, 13):
		var angle := PI - float(i) / 12.0 * PI
		var point := Vector3(cos(angle) * 0.14, 0.33 + sin(angle) * 0.06, 0.29)
		G.rod(_lid, last, point, 0.018, handle)
		last = point
	G.box(_lid, Vector3(0.20, 0.008, 0.105), Vector3(0.15, 0.254, 0.46), G.material(Color("d2c6a0")))
	var tag := G.label(_lid, "П01", Vector3(0.15, 0.260, 0.46), 24, Color("4d5b4b"))
	tag.rotation_degrees.x = -90
	tag.pixel_size = 0.002
	_contents = Node3D.new()
	_contents.name = "Contents"
	add_child(_contents)
	# The only blue patch is stitched onto the napkin inside the carrier.
	G.box(_contents, Vector3(0.73, 0.012, 0.48), Vector3(0, 0.084, 0.01), cloth)
	var patch := G.box(_contents, Vector3(0.105, 0.008, 0.085), Vector3(-0.29, 0.097, 0.18), blue)
	patch.rotation_degrees.y = -7
	for offset in [-0.035, 0.035]:
		G.rod(_contents, Vector3(-0.335, 0.103, 0.18 + offset), Vector3(-0.245, 0.103, 0.18 + offset), 0.002, seam)
	for offset in [-0.043, 0.043]:
		for i in range(4):
			G.rod(_contents, Vector3(-0.29 + offset, 0.103, 0.15 + i * 0.018), Vector3(-0.29 + offset, 0.103, 0.157 + i * 0.018), 0.0014, seam)
	_build_chipped_saucer(_contents)
	var bread := G.material(Color("e2ce99"))
	var crust := G.material(Color("b8864c"))
	var filling := G.material(Color("b56c55"))
	var butter := G.material(Color("e2c576"))
	var sandwich_positions: Array[Vector3] = [Vector3(-0.055, 0.119, -0.105), Vector3(0.135, 0.119, -0.08), Vector3(0.045, 0.119, 0.095)]
	for i in range(3):
		var sandwich := Node3D.new()
		sandwich.name = "Sandwich" + str(i + 1)
		sandwich.position = sandwich_positions[i]
		sandwich.rotation_degrees.y = -13 + i * 13
		_contents.add_child(sandwich)
		G.triangle_slice(sandwich, Vector3(0.20, 0.024, 0.17), Vector3.ZERO, crust)
		G.triangle_slice(sandwich, Vector3(0.185, 0.009, 0.155), Vector3(0, 0.024, 0), filling)
		G.triangle_slice(sandwich, Vector3(0.19, 0.006, 0.16), Vector3(0, 0.033, 0), butter)
		G.triangle_slice(sandwich, Vector3(0.20, 0.024, 0.17), Vector3(0, 0.039, 0), bread)
		# A few shallow pores make the bread read as food rather than flat plastic.
		var pore := G.material(Color("b8a376"))
		for point in [Vector3(-0.038, 0.064, 0.036), Vector3(0.032, 0.064, 0.029), Vector3(0.001, 0.064, -0.021), Vector3(-0.018, 0.064, 0.058), Vector3(0.059, 0.064, 0.063)]:
			G.sphere(sandwich, 0.0031, point, pore, Vector3(1, 0.24, 0.75))
	_target = G.target(self, "P01", Vector3(0.91, 0.67, 0.68), Vector3(0, 0.32, 0))
	_detail_targets.append(G.target(self, "sandwiches", Vector3(0.42, 0.12, 0.40), Vector3(0.04, 0.17, 0)))
	_detail_targets.append(G.target(self, "saucer", Vector3(0.22, 0.05, 0.18), Vector3(0.24, 0.13, 0.17)))
	_detail_targets.append(G.target(self, "napkin", Vector3(0.16, 0.06, 0.14), Vector3(-0.29, 0.13, 0.18)))
	for body in _detail_targets:
		body.collision_layer = 0
	var glow := G.material(Color("d5ba74"))
	glow.emission_enabled = true
	glow.emission = Color("b79e58")
	glow.emission_energy_multiplier = 0.75
	_halo = G.box(self, Vector3(0.91, 0.007, 0.68), Vector3(0, 0.005, 0), glow, "SelectionOutline")

func _build_chipped_saucer(parent: Node3D) -> void:
	var porcelain := G.material(Color("dedbc6"), 0.32)
	var rim := G.material(Color("91aaa1"), 0.44)
	var chip := G.material(Color("b6a88b"))
	var plate := Node3D.new()
	plate.name = "ChippedSaucer"
	plate.position = Vector3(0.045, 0.108, -0.015)
	parent.add_child(plate)
	G.rod(plate, Vector3(0.162, 0.030, 0.175), Vector3(0.128, 0.015, 0.13), 0.0011, G.material(Color("777b68")))
	G.cylinder(plate, 0.215, 0.016, Vector3.ZERO, porcelain)
	var bowl := SurfaceTool.new()
	var border := SurfaceTool.new()
	var broken_edge := SurfaceTool.new()
	bowl.begin(Mesh.PRIMITIVE_TRIANGLES)
	border.begin(Mesh.PRIMITIVE_TRIANGLES)
	broken_edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(48):
		var a := float(i) / 48.0 * TAU
		var b := float(i + 1) / 48.0 * TAU
		var radius_a := _saucer_radius(i)
		var radius_b := _saucer_radius(i + 1)
		var inner_a := Vector3(sin(a) * 0.21, 0.008, cos(a) * 0.21)
		var inner_b := Vector3(sin(b) * 0.21, 0.008, cos(b) * 0.21)
		var outer_a := Vector3(sin(a) * radius_a, 0.028, cos(a) * radius_a)
		var outer_b := Vector3(sin(b) * radius_b, 0.028, cos(b) * radius_b)
		var edge_a := Vector3(sin(a) * (radius_a - 0.012), 0.0285, cos(a) * (radius_a - 0.012))
		var edge_b := Vector3(sin(b) * (radius_b - 0.012), 0.0285, cos(b) * (radius_b - 0.012))
		_add_quad(bowl, inner_a, inner_b, outer_b, outer_a)
		_add_quad(border, edge_a, edge_b, outer_b, outer_a)
		var edge_builder: SurfaceTool = broken_edge if radius_a < 0.27 or radius_b < 0.27 else bowl
		_add_quad(edge_builder, outer_a, outer_b, outer_b - Vector3(0, 0.025, 0), outer_a - Vector3(0, 0.025, 0))
	for part in [[bowl, porcelain], [border, rim], [broken_edge, chip]]:
		var builder: SurfaceTool = part[0]
		builder.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = builder.commit()
		mesh.material_override = part[1]
		plate.add_child(mesh)

func _saucer_radius(index: int) -> float:
	# The front-right outline has a real irregular notch instead of a painted mark.
	var step := index % 48
	if step == 4:
		return 0.257
	if step == 5:
		return 0.234
	if step == 6:
		return 0.249
	return 0.279

func _add_quad(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point in [a, c, b, a, d, c]:
		builder.add_vertex(point)

func _rounded_box(parent: Node3D, size: Vector3, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var half := size * 0.5
	var bevel := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.98)
	var core := half - Vector3.ONE * bevel
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array = [
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	]
	for face in faces:
		var normal: Vector3 = face[0]
		var axis_u: Vector3 = face[1]
		var axis_v: Vector3 = face[2]
		var half_n := absf(normal.x) * half.x + absf(normal.y) * half.y + absf(normal.z) * half.z
		var half_u := absf(axis_u.x) * half.x + absf(axis_u.y) * half.y + absf(axis_u.z) * half.z
		var half_v := absf(axis_v.x) * half.x + absf(axis_v.y) * half.y + absf(axis_v.z) * half.z
		var us := _round_axis(half_u, bevel)
		var vs := _round_axis(half_v, bevel)
		for u in range(us.size() - 1):
			for v in range(vs.size() - 1):
				var a := normal * half_n + axis_u * us[u] + axis_v * vs[v]
				var b := normal * half_n + axis_u * us[u + 1] + axis_v * vs[v]
				var c := normal * half_n + axis_u * us[u + 1] + axis_v * vs[v + 1]
				var d := normal * half_n + axis_u * us[u] + axis_v * vs[v + 1]
				for point in [a, b, c, a, c, d]:
					var nearest: Vector3 = point.clamp(-core, core)
					var outward: Vector3 = (point - nearest).normalized()
					builder.set_normal(outward)
					builder.add_vertex(nearest + outward * bevel)
	var instance := MeshInstance3D.new()
	instance.mesh = builder.commit()
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance

func _round_axis(half: float, radius: float) -> PackedFloat32Array:
	return PackedFloat32Array([-half, -half + radius * 0.25, -half + radius * 0.60, -half + radius, half - radius, half - radius * 0.60, half - radius * 0.25, half])

func _arched_roof(parent: Node3D, material: Material) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(24):
		var x0 := -0.425 + float(i) / 24.0 * 0.85
		var x1 := -0.425 + float(i + 1) / 24.0 * 0.85
		var y0 := _roof_y(x0)
		var y1 := _roof_y(x1)
		_roof_quad(builder, Vector3(x0, y0, -0.02), Vector3(x0, y0, 0.60), Vector3(x1, y1, 0.60), Vector3(x1, y1, -0.02))
		_roof_quad(builder, Vector3(x0, y0 - 0.027, -0.02), Vector3(x1, y1 - 0.027, -0.02), Vector3(x1, y1 - 0.027, 0.60), Vector3(x0, y0 - 0.027, 0.60))
		_roof_quad(builder, Vector3(x0, y0 - 0.027, 0.60), Vector3(x1, y1 - 0.027, 0.60), Vector3(x1, y1, 0.60), Vector3(x0, y0, 0.60))
		_roof_quad(builder, Vector3(x1, y1 - 0.027, -0.02), Vector3(x0, y0 - 0.027, -0.02), Vector3(x0, y0, -0.02), Vector3(x1, y1, -0.02))
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.425
		var y := _roof_y(x)
		if side < 0:
			_roof_quad(builder, Vector3(x, y - 0.027, -0.02), Vector3(x, y - 0.027, 0.60), Vector3(x, y, 0.60), Vector3(x, y, -0.02))
		else:
			_roof_quad(builder, Vector3(x, y - 0.027, 0.60), Vector3(x, y - 0.027, -0.02), Vector3(x, y, -0.02), Vector3(x, y, 0.60))
	builder.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "MouldedArchedRoof"
	instance.mesh = builder.commit()
	instance.material_override = material
	parent.add_child(instance)

func _roof_y(x: float) -> float:
	return 0.205 + 0.05 * (1.0 - pow(absf(x) / 0.425, 2.8))

func _roof_quad(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point in [a, b, c, a, c, d]:
		builder.add_vertex(point)
