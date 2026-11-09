extends Node3D
## P05–P07 use the same interaction surface as the other package models.

const G = preload("res://scripts/presentation/geometry.gd")

@export var package_id := "P05"
var opened := false
var _closed_view := Node3D.new()
var _open_view := Node3D.new()
var _details: Array[StaticBody3D] = []
var _detail_picking := false
var _outline: MeshInstance3D
var _card: Node3D

func _ready() -> void:
	_closed_view.name = "ClosedFind"
	_open_view.name = "OpenFind"
	add_child(_closed_view)
	add_child(_open_view)
	var bounds: Vector3
	match package_id:
		"P05":
			_build_coat()
			bounds = Vector3(0.56, 0.22, 0.41)
		"P06":
			_build_camera_case()
			bounds = Vector3(0.38, 0.24, 0.28)
		"P07":
			_build_remotes()
			bounds = Vector3(0.42, 0.18, 0.32)
		"P08":
			_build_travel_bag()
			bounds = Vector3(0.58, 0.29, 0.36)
	G.target(self, package_id, bounds, Vector3(0, bounds.y * 0.5, 0))
	var highlight := G.material(Color("b4a16d"))
	highlight.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline = G.box(self, Vector3(bounds.x + 0.045, 0.003, bounds.z + 0.045), Vector3(0, 0.005, 0), highlight)
	set_highlighted(false)
	set_opened(opened)

func set_opened(value: bool) -> void:
	opened = value
	_closed_view.visible = not value
	_open_view.visible = value
	set_detail_picking(_detail_picking)

func set_detail_picking(value: bool) -> void:
	_detail_picking = value
	for target in _details:
		target.collision_layer = 2 if value and opened else 0

func set_highlighted(value: bool) -> void:
	_outline.visible = value

func _detail(id: String, size: Vector3, position: Vector3) -> void:
	_details.append(G.target(_open_view, id, size, position))

func _build_coat() -> void:
	var paper := G.worn_material(Color("84644a"), "paper")
	var fold := G.worn_material(Color("b18b64"), "paper")
	var wool := G.worn_material(Color("333833"), "cloth")
	var lining := G.worn_material(Color("625d4f"), "cloth")
	var thread := G.worn_material(Color("cfc4ac"), "cloth")
	var dark := G.material(Color("242620"))
	G.box(_closed_view, Vector3(0.49, 0.15, 0.33), Vector3(0, 0.075, 0), paper)
	G.box(_closed_view, Vector3(0.475, 0.017, 0.31), Vector3(0.005, 0.154, 0.006), fold).rotation.y = 0.035
	for x in [-0.15, 0.15]:
		G.box(_closed_view, Vector3(0.011, 0.164, 0.341), Vector3(x, 0.081, 0), dark)
	_coat_tag(_closed_view, Vector3(0.025, 0.166, 0.047))

	G.box(_open_view, Vector3(0.91, 0.018, 0.57), Vector3(0, 0.010, 0), paper).rotation.y = -0.045
	G.box(_open_view, Vector3(0.52, 0.047, 0.49), Vector3(0, 0.040, -0.025), wool)
	for side in [-1.0, 1.0]:
		var sleeve := G.box(_open_view, Vector3(0.115, 0.040, 0.37), Vector3(side * 0.31, 0.045, -0.06), wool)
		sleeve.rotation.y = side * 0.33
		G.box(_open_view, Vector3(0.116, 0.045, 0.076), Vector3(side * 0.361, 0.048, 0.097), wool).rotation.y = side * 0.33
		G.box(_open_view, Vector3(0.223, 0.013, 0.44), Vector3(side * 0.128, 0.069, -0.023), lining)
		G.box(_open_view, Vector3(0.123, 0.028, 0.115), Vector3(side * 0.059, 0.074, -0.231), wool).rotation.y = side * 0.25
		for row in range(3):
			for col in range(2):
				var x: float = side * (0.087 + col * 0.099)
				var z := -0.134 + row * 0.132
				_pocket(Vector3(x, 0.079, z), 0.080 - 0.006 * col, 0.086 + 0.009 * row, lining, dark)
	# The narrow thirteenth pocket exposes its pale seam allowance.
	_pocket(Vector3(0, 0.080, 0.094), 0.052, 0.145, fold, dark)
	for x in [-0.022, 0.022]:
		for stitch in range(9):
			G.box(_open_view, Vector3(0.003, 0.003, 0.006), Vector3(x, 0.098, 0.040 + stitch * 0.012), thread)
	for row in range(2):
		for stitch in range(8):
			var mark := G.box(_open_view, Vector3(0.009, 0.004, 0.003), Vector3(-0.394 + stitch * 0.009, 0.074, 0.096 + row * 0.014), thread)
			mark.rotation.y = 0.32
	_coat_tag(_open_view, Vector3(0.337, 0.023, 0.235))
	_detail("coat_tag", Vector3(0.19, 0.04, 0.073), Vector3(0.337, 0.035, 0.235))
	_detail("coat_pockets", Vector3(0.47, 0.035, 0.39), Vector3(0, 0.081, -0.027))
	_detail("coat_cuff", Vector3(0.122, 0.060, 0.09), Vector3(-0.36, 0.057, 0.108))
	_detail("coat_reversed", Vector3(0.058, 0.045, 0.151), Vector3(0, 0.102, 0.094))

func _pocket(at: Vector3, width: float, depth: float, fabric: Material, dark: Material) -> void:
	var pocket := Node3D.new()
	pocket.name = "Pocket"
	pocket.position = at
	_open_view.add_child(pocket, true)
	G.box(pocket, Vector3(width, 0.006, depth), Vector3.ZERO, dark)
	G.box(pocket, Vector3(width, 0.010, depth * 0.80), Vector3(0, 0.009, depth * 0.10), fabric)
	G.box(pocket, Vector3(width, 0.009, 0.009), Vector3(0, 0.014, -depth * 0.29), fabric)
	for x in [-width * 0.47, width * 0.47]:
		G.box(pocket, Vector3(0.003, 0.008, depth), Vector3(x, 0.007, 0), fabric)

func _coat_tag(parent: Node3D, at: Vector3) -> void:
	G.box(parent, Vector3(0.185, 0.005, 0.067), at, G.worn_material(Color("d1b98d"), "paper"))
	var stamp := G.label(parent, "СЛУЖЕБНОЕ", at + Vector3(0, 0.004, 0), 20, Color("4d3e31"))
	stamp.rotation_degrees.x = -90
	stamp.pixel_size = 0.00135

func _build_camera_case() -> void:
	var canvas := G.worn_material(Color("303330"), "cloth")
	var lining := G.worn_material(Color("51544c"), "cloth")
	var rubber := G.worn_material(Color("232724"), "leather")
	for parent in [_closed_view, _open_view]:
		G.box(parent, Vector3(0.32, 0.025, 0.23), Vector3(0, 0.015, 0), canvas)
		for x in [-0.148, 0.148]:
			G.box(parent, Vector3(0.024, 0.093, 0.23), Vector3(x, 0.063, 0), canvas)
		for z in [-0.103, 0.103]:
			G.box(parent, Vector3(0.299, 0.092, 0.024), Vector3(0, 0.063, z), canvas)
		G.rod(parent, Vector3(-0.051, 0.049, 0.143), Vector3(0.051, 0.049, 0.143), 0.009, rubber)
		for x in [-0.051, 0.051]:
			G.rod(parent, Vector3(x, 0.049, 0.143), Vector3(x, 0.061, 0.108), 0.009, rubber)
	G.box(_closed_view, Vector3(0.322, 0.031, 0.234), Vector3(0, 0.117, 0), canvas)
	G.box(_closed_view, Vector3(0.318, 0.007, 0.238), Vector3(0, 0.107, 0), lining)
	G.box(_open_view, Vector3(0.312, 0.18, 0.020), Vector3(0, 0.135, -0.140), canvas).rotation.x = -0.47
	G.box(_open_view, Vector3(0.266, 0.016, 0.175), Vector3(0, 0.031, 0), lining)
	G.box(_open_view, Vector3(0.017, 0.049, 0.18), Vector3(0.040, 0.057, 0), lining)
	var cap := G.cylinder(_open_view, 0.044, 0.018, Vector3(0.092, 0.049, 0.024), rubber)
	cap.name = "RubberLensCap"
	G.cylinder(_open_view, 0.037, 0.005, Vector3(0.092, 0.059, 0.024), canvas)
	_detail("case_interior", Vector3(0.168, 0.043, 0.172), Vector3(-0.051, 0.044, 0))
	_detail("lens_cap", Vector3(0.093, 0.035, 0.093), Vector3(0.092, 0.059, 0.024))

func _build_remotes() -> void:
	var colors := [Color("393d3a"), Color("686a60"), Color("343b43"), Color("5e5046"), Color("474846")]
	var cavity := G.material(Color("212420"))
	var terminal := G.worn_material(Color("a9aaa0"), "metal")
	var band := G.worn_material(Color("a6814f"), "leather")
	for parent in [_closed_view, _open_view]:
		for i in range(5):
			var remote := Node3D.new()
			remote.name = "Remote%d" % (i + 1)
			remote.position = Vector3(-0.148 + i * 0.074, 0, 0.011 * (i % 2))
			remote.rotation.y = (i - 2) * 0.08
			parent.add_child(remote)
			var length := 0.21 + 0.016 * ((i + 2) % 4)
			var width := 0.058 + (i % 3) * 0.005
			var plastic := G.worn_material(colors[i], "plastic")
			G.box(remote, Vector3(width, 0.030, length), Vector3(0, 0.018, 0), plastic)
			if parent == _closed_view:
				G.cylinder(remote, 0.009, 0.006, Vector3(0, 0.036, -length * 0.37), G.material(Color("864f49")))
				for row in range(4 + i % 2):
					for col in range(3):
						G.box(remote, Vector3(0.009, 0.005, 0.010), Vector3((col - 1) * 0.015, 0.035, -0.052 + row * 0.025), cavity)
			else:
				var bay := G.box(remote, Vector3(width - 0.014, 0.004, 0.068), Vector3(0, 0.034, 0.036), cavity)
				bay.name = "EmptyBatteryBay"
				for x in [-0.010, 0.010]:
					for j in range(4):
						G.box(remote, Vector3(0.010, 0.007, 0.002), Vector3(x, 0.037, 0.006 + j * 0.003), terminal)
				G.box(remote, Vector3(width - 0.008, 0.012, 0.049), Vector3(0, 0.040, 0.092), plastic)
		G.box(parent, Vector3(0.369, 0.005, 0.013), Vector3(0, 0.047, -0.031), band)
		G.box(parent, Vector3(0.369, 0.004, 0.013), Vector3(0, 0.004, -0.031), band)
		for x in [-0.184, 0.184]:
			G.box(parent, Vector3(0.004, 0.043, 0.013), Vector3(x, 0.024, -0.031), band)
	_detail("remote_bundle", Vector3(0.375, 0.042, 0.126), Vector3(0, 0.031, -0.075))
	_detail("battery_bays", Vector3(0.375, 0.042, 0.139), Vector3(0, 0.031, 0.071))

func set_card_inside(value: bool) -> void:
	if is_instance_valid(_card):
		_card.visible = value

func _build_travel_bag() -> void:
	var canvas := G.worn_material(Color("3c5667"), "cloth")
	var seam := G.worn_material(Color("65727a"), "cloth")
	var interior := G.worn_material(Color("535a59"), "cloth")
	var webbing := G.worn_material(Color("343b39"), "cloth")
	for parent in [_closed_view, _open_view]:
		G.box(parent, Vector3(0.57, 0.037, 0.34), Vector3(0, 0.022, 0), canvas)
		for x in [-0.265, 0.265]:
			G.box(parent, Vector3(0.038, 0.16, 0.33), Vector3(x, 0.102, 0), canvas)
			G.rod(parent, Vector3(x, 0.18, -0.15), Vector3(x, 0.18, 0.15), 0.004, seam)
		for z in [-0.154, 0.154]:
			G.box(parent, Vector3(0.505, 0.153, 0.032), Vector3(0, 0.102, z), canvas)
			G.rod(parent, Vector3(-0.25, 0.174, z), Vector3(0.25, 0.174, z), 0.004, seam)
		for x in [-0.13, 0.13]:
			G.box(parent, Vector3(0.026, 0.15, 0.008), Vector3(x, 0.10, 0.175), webbing)
		G.rod(parent, Vector3(-0.13, 0.11, 0.179), Vector3(-0.09, 0.056, 0.224), 0.012, webbing)
		G.rod(parent, Vector3(0.13, 0.11, 0.179), Vector3(0.094, 0.058, 0.228), 0.012, webbing)
		G.rod(parent, Vector3(0.094, 0.058, 0.228), Vector3(-0.058, 0.053, 0.228), 0.012, webbing)
	G.box(_closed_view, Vector3(0.555, 0.032, 0.326), Vector3(0, 0.174, 0), canvas)
	G.rod(_closed_view, Vector3(-0.26, 0.194, 0.014), Vector3(0.26, 0.194, 0.014), 0.005, webbing)
	var flap := G.box(_open_view, Vector3(0.52, 0.18, 0.022), Vector3(0, 0.178, -0.193), canvas)
	flap.rotation.x = -0.73
	G.box(_open_view, Vector3(0.50, 0.017, 0.30), Vector3(0, 0.042, 0), interior)
	var cotton := G.worn_material(Color("c8c2ae"), "cloth")
	G.box(_open_view, Vector3(0.247, 0.041, 0.219), Vector3(-0.115, 0.072, 0.006), cotton)
	for x in [-0.153, -0.092]:
		G.box(_open_view, Vector3(0.074, 0.018, 0.079), Vector3(x, 0.104, -0.068), cotton).rotation.y = 0.36 if x < -0.1 else -0.36
	G.rod(_open_view, Vector3(-0.124, 0.096, -0.038), Vector3(-0.124, 0.096, 0.11), 0.002, seam)
	for z in [-0.02, 0.025, 0.07]:
		G.cylinder(_open_view, 0.006, 0.005, Vector3(-0.124, 0.096, z), G.material(Color("dfd8c3")))
	_bag_paper(Vector3(0.105, 0.063, 0.068), Vector2(0.116, 0.054), "БИЛЕТ 2014", Color("c9ad7d"))
	_bag_paper(Vector3(0.107, 0.059, -0.001), Vector2(0.10, 0.06), "СТАЖЁР", Color("a7aaa1"))
	G.box(_open_view, Vector3(0.148, 0.011, 0.077), Vector3(0.145, 0.079, -0.083), seam)
	_card = _bag_paper(Vector3(0.145, 0.089, -0.10), Vector2(0.12, 0.056), "№ 314", Color("bea986"))
	_detail("shirt", Vector3(0.243, 0.05, 0.211), Vector3(-0.115, 0.090, 0.006))
	_detail("ticket", Vector3(0.118, 0.036, 0.055), Vector3(0.105, 0.073, 0.068))
	_detail("pass", Vector3(0.102, 0.031, 0.06), Vector3(0.107, 0.069, -0.001))
	_detail("card", Vector3(0.125, 0.044, 0.064), Vector3(0.145, 0.102, -0.10))

func _bag_paper(at: Vector3, size: Vector2, title: String, color: Color) -> Node3D:
	var card := Node3D.new()
	card.position = at
	_open_view.add_child(card)
	G.box(card, Vector3(size.x, 0.004, size.y), Vector3.ZERO, G.worn_material(color, "paper"))
	var print_mark := G.label(card, title, Vector3(0, 0.003, 0), 18, Color("4b4335"))
	print_mark.rotation_degrees.x = -90
	print_mark.pixel_size = 0.0009
	return card
