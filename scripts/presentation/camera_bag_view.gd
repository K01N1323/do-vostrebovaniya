extends Node3D
## P04 has fixed contents. A claimant's words never change the physical object.

const G = preload("res://scripts/presentation/geometry.gd")
var opened := false
var _closed: Node3D
var _unfolded: Node3D
var _contents: Node3D
var _halo: MeshInstance3D
var _target: StaticBody3D
var _details: Dictionary = {}
var _detail_picking := false

func _ready() -> void:
	var canvas := G.worn_material(Color("a09a7b"), "cloth")
	var hem := G.worn_material(Color("686f58"), "cloth")
	G.box(self, Vector3(0.57, 0.015, 0.43), Vector3(0, 0.0075, 0), canvas, "BagFloor")
	_unfolded = Node3D.new()
	_unfolded.name = "LooseFabricSides"
	add_child(_unfolded)
	_build_loose_fabric(canvas, hem)
	_closed = Node3D.new()
	_closed.name = "FoldedBagTop"
	add_child(_closed)
	for side in [-1.0, 1.0]:
		var wall := G.box(_closed, Vector3(0.56, 0.20, 0.013), Vector3(0, 0.155, side * 0.173), canvas)
		wall.rotation_degrees.x = -side * 18
		G.box(_closed, Vector3(0.012, 0.19, 0.34), Vector3(side * 0.273, 0.153, 0), canvas)
		var last := Vector3(-0.11, 0.25, side * 0.105)
		for i in range(1, 13):
			var angle := PI * float(i) / 12.0
			var point := Vector3(-cos(angle) * 0.11, 0.25 + sin(angle) * 0.17, side * 0.105)
			G.rod(_closed, last, point, 0.012, hem)
			last = point
	G.box(_closed, Vector3(0.55, 0.014, 0.25), Vector3(0, 0.253, 0), canvas)
	var tag := G.label(_closed, "П04", Vector3(0.12, 0.262, 0.06), 23, Color("454e40"))
	tag.rotation_degrees.x = -90
	tag.pixel_size = 0.0016
	_contents = Node3D.new()
	_contents.name = "Contents"
	add_child(_contents)
	_build_camera()
	_build_strap()
	_build_onion(Vector3(-0.20, 0.079, -0.11), 0)
	_build_onion(Vector3(0.19, 0.082, -0.11), 1)
	_build_onion(Vector3(0.20, 0.074, 0.125), 2)
	_target = G.target(self, "P04", Vector3(0.59, 0.43, 0.45), Vector3(0, 0.215, 0))
	_details.camera_body = G.target(self, "camera_body", Vector3(0.29, 0.17, 0.15), Vector3(-0.035, 0.155, 0.005))
	_details.strap = G.target(self, "strap", Vector3(0.11, 0.035, 0.10), Vector3(-0.18, 0.04, 0.13))
	_details.onions = G.target(self, "onions", Vector3(0.13, 0.14, 0.13), Vector3(0.20, 0.08, 0.125))
	_halo = G.box(self, Vector3(0.61, 0.004, 0.47), Vector3(0, -0.001, 0), G.material(Color("b4b38a")))
	_halo.visible = false
	set_opened(opened)
	_update_targets()

func _build_loose_fabric(canvas: Material, hem: Material) -> void:
	# Uneven hems and relaxed handles keep the opened cloth bag distinct from a tray.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lower: Array[Vector3] = [Vector3(-0.26,0.018,-0.18), Vector3(0,0.018,-0.20), Vector3(0.26,0.018,-0.18),
		Vector3(0.28,0.018,0), Vector3(0.26,0.018,0.18), Vector3(0,0.018,0.20),
		Vector3(-0.26,0.018,0.18), Vector3(-0.28,0.018,0)]
	var upper: Array[Vector3] = [Vector3(-0.30,0.075,-0.20), Vector3(-0.03,0.115,-0.22), Vector3(0.29,0.077,-0.21),
		Vector3(0.32,0.09,-0.01), Vector3(0.29,0.066,0.21), Vector3(0.035,0.045,0.23),
		Vector3(-0.29,0.068,0.21), Vector3(-0.31,0.095,0.02)]
	for i in lower.size():
		var j := (i + 1) % lower.size()
		for vertex in [lower[i], upper[i], upper[j], lower[i], upper[j], lower[j]]:
			surface.add_vertex(vertex)
		G.rod(_unfolded, upper[i], upper[j], 0.003, hem)
	surface.generate_normals()
	var cloth := MeshInstance3D.new()
	cloth.name = "WrinkledCloth"
	cloth.mesh = surface.commit()
	var two_sided := canvas.duplicate() as StandardMaterial3D
	two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.material_override = two_sided
	_unfolded.add_child(cloth)
	for side in [-1.0, 1.0]:
		var previous := Vector3(-0.12, 0.06, side * 0.21)
		for i in range(1, 17):
			var angle := PI * float(i) / 16.0
			var point := Vector3(-cos(angle) * 0.12, 0.035 + absf(cos(angle)) * 0.025, side * (0.21 + sin(angle) * 0.14))
			G.rod(_unfolded, previous, point, 0.010, hem)
			previous = point

func _build_camera() -> void:
	var camera := Node3D.new()
	camera.name = "SilverFilmCamera"
	camera.position = Vector3(-0.035, 0.12, 0)
	_contents.add_child(camera)
	var silver := G.material(Color("b9bfba"), 0.49)
	silver.metallic = 0.5
	var dark := G.worn_material(Color("333b33"), "leather")
	var ring := G.material(Color("6c746e"), 0.58)
	G.box(camera, Vector3(0.28, 0.13, 0.075), Vector3.ZERO, silver, "SilverBody")
	G.box(camera, Vector3(0.283, 0.074, 0.079), Vector3(0, -0.006, 0), dark, "BlackGrip")
	G.box(camera, Vector3(0.09, 0.04, 0.067), Vector3(0, 0.08, -0.004), silver)
	G.box(camera, Vector3(0.044, 0.015, 0.032), Vector3(0, 0.105, -0.007), ring)
	for x in [-0.09, 0.09]:
		G.cylinder(camera, 0.022, 0.018, Vector3(x, 0.075, -0.009), ring)
	G.cylinder(camera, 0.009, 0.009, Vector3(0.104, 0.09, 0.017), silver)
	for layer in range(4):
		var barrel := G.cylinder(camera, 0.052 - layer * 0.003, 0.018, Vector3(-0.015, -0.006, 0.043 + layer * 0.014), dark if layer % 2 == 0 else ring)
		barrel.rotation_degrees.x = 90
	var glass := G.material(Color("263f40"), 0.20)
	glass.metallic = 0.25
	var lens := G.cylinder(camera, 0.037, 0.005, Vector3(-0.015, -0.006, 0.098), glass)
	lens.rotation_degrees.x = 90
	G.box(camera, Vector3(0.031, 0.019, 0.003), Vector3(0.072, 0.042, 0.041), dark)
	for x in [-0.143, 0.143]:
		G.rod(camera, Vector3(x, 0.02, 0), Vector3(x, 0.043, 0.02), 0.003, silver)
	var mark := G.label(camera, "35", Vector3(-0.09, 0.047, 0.041), 17, Color("3c463d"))
	mark.pixel_size = 0.0011

func _build_strap() -> void:
	var strap := Node3D.new()
	strap.name = "MendedFabricStrap"
	_contents.add_child(strap)
	var cloth := G.worn_material(Color("69664e"), "cloth")
	var points: Array[Vector3] = [Vector3(-0.18, 0.15, 0), Vector3(-0.24, 0.05, 0.04),
		Vector3(-0.22, 0.031, 0.14), Vector3(-0.10, 0.031, 0.18), Vector3(0.08, 0.031, 0.17), Vector3(0.13, 0.15, 0)]
	for i in range(points.size() - 1):
		G.rod(strap, points[i], points[i + 1], 0.009, cloth)
	G.box(strap, Vector3(0.105, 0.007, 0.032), Vector3(-0.18, 0.034, 0.13), cloth)
	var thread := G.material(Color("d0c2a0"))
	for i in range(9):
		var x := -0.22 + i * 0.009
		G.rod(strap, Vector3(x, 0.039, 0.115), Vector3(x + 0.004, 0.039, 0.145), 0.0012, thread)
	for z in [0.119, 0.126, 0.133, 0.140]:
		G.rod(strap, Vector3(-0.22, 0.040, z), Vector3(-0.144, 0.040, z), 0.0008, thread)

func _build_onion(position: Vector3, index: int) -> void:
	var onion := Node3D.new()
	onion.name = "Onion" + str(index + 1)
	onion.position = position
	_contents.add_child(onion)
	var skin := G.worn_material(Color("aa824d") if index != 1 else Color("bb995f"), "paper")
	var veins := G.material(Color("8e7149"))
	G.sphere(onion, 0.064, Vector3.ZERO, skin, Vector3(1, 0.86, 0.95))
	G.cylinder(onion, 0.018, 0.032, Vector3(0, 0.058, 0), skin, 0.006)
	for i in range(8):
		var angle := TAU * i / 8.0
		var last := Vector3(0, 0.056, 0)
		for j in range(1, 8):
			var arc := PI * float(j) / 8.0
			var point := Vector3(sin(arc) * cos(angle) * 0.0645, cos(arc) * 0.055, sin(arc) * sin(angle) * 0.061)
			G.rod(onion, last, point, 0.0007, veins)
			last = point
		G.rod(onion, Vector3(0, -0.050, 0), Vector3(cos(angle) * 0.024, -0.061, sin(angle) * 0.024), 0.0009, veins)

func set_opened(value: bool) -> void:
	opened = value
	if is_instance_valid(_closed):
		_closed.visible = not value
		_unfolded.visible = value
		_contents.visible = value
		_update_targets()

func set_highlighted(value: bool) -> void:
	if is_instance_valid(_halo):
		_halo.visible = value

func set_detail_picking(value: bool) -> void:
	_detail_picking = value
	_update_targets()

func _update_targets() -> void:
	if is_instance_valid(_target):
		_target.collision_layer = 0 if _detail_picking else 1
	for target in _details.values():
		target.collision_layer = 2 if _detail_picking and opened else 0
