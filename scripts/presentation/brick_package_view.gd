extends Node3D
## P02 is one package: a brick and the work shirt wrapped around it.

const G = preload("res://scripts/presentation/geometry.gd")
var opened := false
var _wrap: Node3D
var _contents: Node3D
var _halo: MeshInstance3D
var _target: StaticBody3D
var _details: Array[StaticBody3D] = []

func _ready() -> void:
	var cloth := G.worn_material(Color("686e69"), "cloth")
	var seam := G.material(Color("a39e81"))
	# The opened shirt has a body, sleeves, button placket and a turned collar.
	G.box(self, Vector3(0.68, 0.018, 0.48), Vector3(0, 0.012, 0), cloth, "ShirtBody")
	for side in [-1.0, 1.0]:
		var sleeve := G.box(self, Vector3(0.17, 0.024, 0.32), Vector3(side * 0.34, 0.025, -0.03), cloth)
		sleeve.rotation_degrees.y = side * 22.0
		for i in range(4):
			G.rod(self, Vector3(side * 0.24, 0.027, -0.16 + i * 0.10), Vector3(side * 0.35, 0.028, -0.10 + i * 0.09), 0.002, seam)
	G.box(self, Vector3(0.035, 0.009, 0.45), Vector3(0.23, 0.026, 0), G.worn_material(Color("747a72"), "cloth"))
	for z in [-0.17, -0.06, 0.06, 0.17]:
		G.cylinder(self, 0.008, 0.006, Vector3(0.23, 0.034, z), G.material(Color("b4ad93")))
	_contents = Node3D.new()
	_contents.name = "Contents"
	add_child(_contents)
	_build_brick(_contents)
	var collar := Node3D.new()
	collar.name = "ShirtCollar"
	collar.position = Vector3(0.28, 0.041, 0.16)
	collar.rotation_degrees.y = -18
	_contents.add_child(collar)
	G.box(collar, Vector3(0.19, 0.018, 0.13), Vector3.ZERO, cloth)
	G.box(collar, Vector3(0.10, 0.005, 0.065), Vector3(0, 0.012, 0), G.worn_material(Color("313c3c"), "cloth"), "DarkPatch")
	for i in range(7):
		for z in [-0.032, 0.032]:
			G.rod(collar, Vector3(-0.045 + i * 0.015, 0.016, z), Vector3(-0.040 + i * 0.015, 0.016, z), 0.0016, seam)
	for x in [-0.050, 0.050]:
		for i in range(4):
			G.rod(collar, Vector3(x, 0.016, -0.025 + i * 0.016), Vector3(x, 0.016, -0.018 + i * 0.016), 0.0016, seam)
	_wrap = Node3D.new()
	_wrap.name = "FoldedShirt"
	add_child(_wrap)
	for side in [-1.0, 1.0]:
		var flap := G.box(_wrap, Vector3(0.32, 0.045, 0.41), Vector3(side * 0.12, 0.23, 0), cloth)
		flap.rotation_degrees.z = side * 12
		G.box(_wrap, Vector3(0.045, 0.20, 0.38), Vector3(side * 0.27, 0.12, 0), cloth)
	var tag := G.box(_wrap, Vector3(0.13, 0.008, 0.075), Vector3(0.10, 0.265, 0.055), G.material(Color("c5b48e")))
	tag.rotation_degrees.y = -6
	var number := G.label(_wrap, "П02", Vector3(0.10, 0.271, 0.055), 22, Color("444d43"))
	number.rotation_degrees.x = -90
	number.pixel_size = 0.0017
	_target = G.target(self, "P02", Vector3(0.74, 0.30, 0.50), Vector3(0, 0.15, 0))
	_details.append(G.target(self, "corner", Vector3(0.11, 0.19, 0.12), Vector3(-0.20, 0.12, 0.10)))
	_details.append(G.target(self, "paint", Vector3(0.29, 0.05, 0.14), Vector3(0.03, 0.23, -0.01)))
	_details.append(G.target(self, "collar", Vector3(0.17, 0.045, 0.12), Vector3(0.28, 0.067, 0.16)))
	_halo = G.box(self, Vector3(0.77, 0.005, 0.53), Vector3(0, -0.003, 0), G.material(Color("b4b38a")))
	_halo.name = "HoverIndicator"
	_halo.visible = false
	set_detail_picking(false)
	set_opened(opened)

func _build_brick(parent: Node3D) -> void:
	# An extruded polygon makes the missing corner visible from top and side.
	var contour: Array[Vector2] = [Vector2(-0.25, -0.13), Vector2(0.25, -0.13), Vector2(0.25, 0.13), Vector2(-0.17, 0.13), Vector2(-0.25, 0.05)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, contour.size() - 1):
		_triangle(surface, Vector3(contour[0].x, 0.225, contour[0].y), Vector3(contour[i].x, 0.225, contour[i].y), Vector3(contour[i + 1].x, 0.225, contour[i + 1].y))
		_triangle(surface, Vector3(contour[0].x, 0.030, contour[0].y), Vector3(contour[i + 1].x, 0.030, contour[i + 1].y), Vector3(contour[i].x, 0.030, contour[i].y))
	for i in contour.size():
		var a := Vector3(contour[i].x, 0.030, contour[i].y)
		var b := Vector3(contour[(i + 1) % contour.size()].x, 0.030, contour[(i + 1) % contour.size()].y)
		_triangle(surface, a, b + Vector3.UP * 0.195, a + Vector3.UP * 0.195)
		_triangle(surface, a, b, b + Vector3.UP * 0.195)
	surface.generate_normals()
	var brick := MeshInstance3D.new()
	brick.name = "ChamferedBrick"
	brick.mesh = surface.commit()
	brick.material_override = G.worn_material(Color("9f6045"), "rust")
	parent.add_child(brick)
	# Layer order: brick, old blue paint, fragments of the white plaster above it.
	var blue := G.worn_material(Color("4a7b8a"), "paint")
	G.box(parent, Vector3(0.34, 0.003, 0.085), Vector3(0.025, 0.228, -0.005), blue, "OldBluePaint")
	var plaster := G.worn_material(Color("c9c3ae"), "plaster")
	G.box(parent, Vector3(0.29, 0.018, 0.10), Vector3(0.035, 0.239, -0.073), plaster, "WhitePlaster")
	for i in range(5):
		var piece := G.box(parent, Vector3(0.045, 0.010, 0.018), Vector3(-0.09 + i * 0.051, 0.236, -0.017 + (i % 2) * 0.009), plaster)
		piece.rotation_degrees.y = -10 + i * 7
	var pit := G.material(Color("704c39"))
	for i in range(18):
		G.box(parent, Vector3(0.006, 0.002, 0.004), Vector3(-0.14 + (i % 6) * 0.054, 0.226, 0.069 + (i / 6) * 0.018), pit)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point in [a, b, c]:
		surface.add_vertex(point)

func set_opened(value: bool) -> void:
	opened = value
	if is_instance_valid(_wrap):
		_wrap.visible = not value
		_contents.visible = value

func set_highlighted(value: bool) -> void:
	if is_instance_valid(_halo):
		_halo.visible = value

func set_detail_picking(value: bool) -> void:
	if is_instance_valid(_target):
		_target.collision_layer = 0 if value else 1
	for detail in _details:
		detail.collision_layer = 2 if value else 0
