extends Node3D
## P03: one shared suitcase. Lifting its lining reveals an actual hidden pull.

const G = preload("res://scripts/presentation/geometry.gd")
var opened := false
var lining_lifted := false
var unlocked := false
var _lid: Node3D
var _contents: Node3D
var _lining: Node3D
var _halo: MeshInstance3D
var _target: StaticBody3D
var _details: Dictionary = {}
var _numbers: Array[Label3D] = []
var _detail_picking := false

func _ready() -> void:
	var leather := G.worn_material(Color("6d5440"), "leather")
	var rim := G.worn_material(Color("403d32"), "leather")
	var cloth := G.worn_material(Color("8c8773"), "cloth")
	var metal := G.worn_material(Color("6f766b"), "metal")
	G.box(self, Vector3(0.76, 0.028, 0.48), Vector3(0, 0.016, 0), leather)
	for side in [-1.0, 1.0]:
		G.box(self, Vector3(0.028, 0.145, 0.48), Vector3(side * 0.366, 0.095, 0), leather)
		G.box(self, Vector3(0.74, 0.145, 0.026), Vector3(0, 0.095, side * 0.227), leather)
		G.box(self, Vector3(0.76, 0.012, 0.018), Vector3(0, 0.165, side * 0.232), rim)
	# Handle projects from the front and remains separate from the combination lock.
	for x in [-0.12, 0.12]:
		G.rod(self, Vector3(x, 0.075, 0.24), Vector3(x, 0.075, 0.31), 0.012, rim)
	G.rod(self, Vector3(-0.12, 0.075, 0.31), Vector3(0.12, 0.075, 0.31), 0.015, rim)
	G.box(self, Vector3(0.22, 0.075, 0.017), Vector3(0, 0.125, 0.249), metal)
	for i in range(3):
		var wheel := G.cylinder(self, 0.027, 0.041, Vector3(-0.056 + i * 0.056, 0.125, 0.259), rim)
		wheel.rotation_degrees.z = 90
		var number := G.label(self, "0", Vector3(-0.056 + i * 0.056, 0.125, 0.287), 23, Color("dfd5b7"))
		number.pixel_size = 0.0015
		_numbers.append(number)
	_lid = Node3D.new()
	_lid.name = "SuitcaseLid"
	_lid.position = Vector3(0, 0.17, -0.23)
	add_child(_lid)
	G.box(_lid, Vector3(0.76, 0.055, 0.48), Vector3(0, 0.025, 0.23), leather)
	G.box(_lid, Vector3(0.69, 0.008, 0.40), Vector3(0, -0.007, 0.23), cloth)
	for x in [-0.29, 0.29]:
		G.box(_lid, Vector3(0.045, 0.008, 0.46), Vector3(x, 0.057, 0.23), rim)
	var tag := G.box(_lid, Vector3(0.13, 0.006, 0.07), Vector3(0.16, 0.059, 0.32), G.material(Color("c8b891")))
	tag.rotation_degrees.y = -7
	var label := G.label(_lid, "П03", Vector3(0.16, 0.065, 0.32), 22, Color("41473e"))
	label.rotation_degrees.x = -90
	label.pixel_size = 0.0017
	_contents = Node3D.new()
	_contents.name = "Contents"
	add_child(_contents)
	G.box(_contents, Vector3(0.69, 0.009, 0.40), Vector3(0, 0.036, 0), cloth, "FadedLining")
	_build_stain()
	_lining = Node3D.new()
	_lining.name = "LooseLining"
	_lining.position = Vector3(0.055, 0.054, 0.055)
	_contents.add_child(_lining)
	G.box(_lining, Vector3(0.25, 0.007, 0.25), Vector3(0.125, 0, 0), cloth, "LiningFlap")
	var thread := G.material(Color("c2b896"))
	for i in range(10):
		G.rod(_lining, Vector3(0.013 + i * 0.024, 0.005, 0.119), Vector3(0.023 + i * 0.024, 0.005, 0.119), 0.0013, thread)
	var pull := Node3D.new()
	pull.name = "BrokenZipperPull"
	pull.position = Vector3(0.23, 0.048, 0.08)
	pull.rotation_degrees.y = -24
	_contents.add_child(pull)
	for x in [-0.019, 0.019]:
		G.rod(pull, Vector3(x, 0, -0.03), Vector3(x, 0, 0.03), 0.004, metal)
	G.rod(pull, Vector3(-0.019, 0, 0.03), Vector3(0.019, 0, 0.03), 0.004, metal)
	G.box(pull, Vector3(0.036, 0.006, 0.023), Vector3(0, 0, -0.024), metal)
	G.rod(pull, Vector3(-0.018, 0, -0.03), Vector3(-0.009, 0, -0.044), 0.003, metal)
	_target = G.target(self, "P03", Vector3(0.80, 0.25, 0.63), Vector3(0, 0.12, 0.03))
	_details.combination = G.target(self, "combination", Vector3(0.22, 0.075, 0.055), Vector3(0, 0.125, 0.28))
	_details.green_stain = G.target(self, "green_stain", Vector3(0.23, 0.035, 0.22), Vector3(-0.17, 0.055, 0.015))
	_details.lining = G.target(self, "lining", Vector3(0.25, 0.025, 0.25), Vector3(0.18, 0.065, 0.055))
	_details.zipper = G.target(self, "zipper", Vector3(0.10, 0.027, 0.12), Vector3(0.23, 0.058, 0.08))
	_halo = G.box(self, Vector3(0.81, 0.005, 0.64), Vector3(0, -0.004, 0.03), G.material(Color("b4b38a")))
	_halo.visible = false
	set_opened(opened)
	set_lining_lifted(lining_lifted)
	set_unlocked(unlocked)
	_update_targets()

func _build_stain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector2] = [Vector2(-0.13,-0.08),Vector2(0.02,-0.095),Vector2(0.115,-0.04),Vector2(0.08,0.045),Vector2(-0.01,0.09),Vector2(-0.105,0.045)]
	for i in points.size():
		for p in [Vector2.ZERO, points[i], points[(i + 1) % points.size()]]:
			surface.add_vertex(Vector3(p.x - 0.16, 0.042, p.y + 0.01))
	surface.generate_normals()
	var stain := MeshInstance3D.new()
	stain.name = "GreenPaintStain"
	stain.mesh = surface.commit()
	stain.material_override = G.worn_material(Color("527c52"), "paint")
	_contents.add_child(stain)

func set_opened(value: bool) -> void:
	opened = value
	if is_instance_valid(_lid):
		_lid.rotation_degrees.x = -112 if value else 0
		_contents.visible = value

func set_lining_lifted(value: bool) -> void:
	lining_lifted = value
	if is_instance_valid(_lining):
		_lining.rotation_degrees.z = 78 if value else 0
		_update_targets()

func set_unlocked(value: bool) -> void:
	unlocked = value
	for i in _numbers.size():
		_numbers[i].text = "246"[i] if value else "0"

func set_highlighted(value: bool) -> void:
	if is_instance_valid(_halo):
		_halo.visible = value

func set_detail_picking(value: bool) -> void:
	_detail_picking = value
	_update_targets()

func _update_targets() -> void:
	if is_instance_valid(_target):
		_target.collision_layer = 0 if _detail_picking else 1
	for id in _details:
		var allowed: bool = _detail_picking
		if id == "zipper":
			allowed = allowed and lining_lifted
		elif id == "lining":
			allowed = allowed and not lining_lifted
		_details[id].collision_layer = 2 if allowed else 0
