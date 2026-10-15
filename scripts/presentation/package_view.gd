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
	_door.rotation_degrees.y = 95.0 if opened else 0.0
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
	var shell := G.material(Color("a7a38b"), 0.66)
	var upper_shell := G.material(Color("c0bba1"), 0.59)
	var dark := G.material(Color("50594f"), 0.52)
	var metal := G.material(Color("8e9788"), 0.36)
	var cloth := G.material(Color("d0c7ad"))
	var seam := G.material(Color("8a856d"))
	var blue := G.material(Color("668d9f"))
	G.box(self, Vector3(0.84, 0.075, 0.62), Vector3(0, 0.038, 0), shell)
	G.box(self, Vector3(0.84, 0.17, 0.035), Vector3(0, 0.15, -0.29), shell)
	G.box(self, Vector3(0.035, 0.18, 0.60), Vector3(-0.405, 0.15, 0), shell)
	G.box(self, Vector3(0.035, 0.18, 0.60), Vector3(0.405, 0.15, 0), shell)
	G.box(self, Vector3(0.84, 0.035, 0.035), Vector3(0, 0.09, 0.29), dark)
	# The grille has real spaces between rods, two hinges and a visible latch.
	_door = Node3D.new()
	_door.name = "GrilleDoor"
	_door.position = Vector3(0.385, 0.075, 0.32)
	add_child(_door)
	for y in [0.025, 0.395]:
		G.box(_door, Vector3(0.77, 0.025, 0.028), Vector3(-0.385, y, 0), dark)
	for x in [-0.758, -0.012]:
		G.box(_door, Vector3(0.025, 0.395, 0.028), Vector3(x, 0.21, 0), dark)
	for i in range(1, 10):
		var x := -0.77 + float(i) * 0.077
		G.rod(_door, Vector3(x, 0.035, 0), Vector3(x, 0.385, 0), 0.008, metal)
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
	G.box(_lid, Vector3(0.85, 0.055, 0.62), Vector3(0, 0.23, 0.29), upper_shell)
	for z in [0.0, 0.59]:
		G.box(_lid, Vector3(0.84, 0.035, 0.035), Vector3(0, 0.015, z), dark)
	for x in [-0.405, 0.405]:
		G.box(_lid, Vector3(0.035, 0.035, 0.59), Vector3(x, 0.015, 0.29), dark)
	G.box(_lid, Vector3(0.85, 0.06, 0.035), Vector3(0, 0.21, 0.59), upper_shell)
	G.box(_lid, Vector3(0.85, 0.23, 0.035), Vector3(0, 0.115, 0), upper_shell)
	for x in [-0.407, 0.407]:
		G.box(_lid, Vector3(0.036, 0.045, 0.60), Vector3(x, 0.205, 0.29), upper_shell)
		for i in range(7):
			G.box(_lid, Vector3(0.036, 0.17, 0.037), Vector3(x, 0.105, 0.047 + i * 0.081), upper_shell)
	for x in [-0.425, 0.425]:
		for z in [0.10, 0.49]:
			G.box(_lid, Vector3(0.018, 0.065, 0.055), Vector3(x, 0.025, z), dark)
	# One handle attached to the roof, instead of cloth bag handles.
	for x in [-0.15, 0.15]:
		G.rod(_lid, Vector3(x, 0.26, 0.29), Vector3(x, 0.37, 0.29), 0.022, dark)
	G.rod(_lid, Vector3(-0.15, 0.37, 0.29), Vector3(0.15, 0.37, 0.29), 0.026, dark)
	G.box(_lid, Vector3(0.20, 0.008, 0.105), Vector3(0.15, 0.262, 0.46), G.material(Color("d2c6a0")))
	var tag := G.label(_lid, "П01", Vector3(0.15, 0.269, 0.46), 24, Color("4d5b4b"))
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
