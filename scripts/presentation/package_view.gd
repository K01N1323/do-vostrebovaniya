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
	_build_used_napkin(_contents)
	_build_chipped_saucer(_contents)
	var sandwich_positions: Array[Vector3] = [Vector3(-0.055, 0.119, -0.105), Vector3(0.135, 0.119, -0.08), Vector3(0.045, 0.119, 0.095)]
	for i in range(3):
		var sandwich := Node3D.new()
		sandwich.name = "Sandwich" + str(i + 1)
		sandwich.position = sandwich_positions[i]
		sandwich.rotation_degrees.y = -13 + i * 13
		_contents.add_child(sandwich)
		_build_sandwich(sandwich, i)
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
	var porcelain := G.material(Color("c8c4b0"), 0.56)
	porcelain.metallic_specular = 0.26
	var rim := G.material(Color("7f9389"), 0.62)
	var chip := G.material(Color("b5a88d"), 0.96)
	var plate := Node3D.new()
	plate.name = "ChippedSaucer"
	plate.position = Vector3(0.045, 0.108, -0.015)
	parent.add_child(plate)
	var bowl := SurfaceTool.new()
	var border := SurfaceTool.new()
	var broken_edge := SurfaceTool.new()
	bowl.begin(Mesh.PRIMITIVE_TRIANGLES)
	border.begin(Mesh.PRIMITIVE_TRIANGLES)
	broken_edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A closed ceramic profile: shallow bowl, rolled rim and a raised foot ring.
	var profile: Array[Vector2] = [Vector2(0, 0.009), Vector2(0.17, 0.008), Vector2(0.209, 0.010), Vector2(0.235, 0.018), Vector2(0.259, 0.027), Vector2(0.269, 0.029), Vector2(0.275, 0.030), Vector2(0.279, 0.026), Vector2(0.276, 0.015), Vector2(0.235, -0.001), Vector2(0.166, -0.009), Vector2(0.151, -0.017), Vector2(0.143, -0.017), Vector2(0.140, -0.004), Vector2(0, -0.001)]
	for i in range(96):
		var a := float(i) / 96.0 * TAU
		var b := float(i + 1) / 96.0 * TAU
		var chipped := _dish_outer_radius(a) < 0.268 or _dish_outer_radius(b) < 0.268
		for row in range(profile.size() - 1):
			var builder: SurfaceTool = bowl
			if row == 5 and not chipped:
				builder = border
			elif chipped and row >= 5 and row <= 8:
				builder = broken_edge
			var p0 := _dish_profile_point(profile[row], a)
			var p1 := _dish_profile_point(profile[row], b)
			var p2 := _dish_profile_point(profile[row + 1], b)
			var p3 := _dish_profile_point(profile[row + 1], a)
			if row == 0:
				for point in [p0, p3, p2]:
					builder.add_vertex(point)
			elif row == profile.size() - 2:
				for point in [p0, p2, p1]:
					builder.add_vertex(point)
			else:
				_add_quad(builder, p0, p1, p2, p3)
	for part in [[bowl, porcelain], [border, rim], [broken_edge, chip]]:
		var builder: SurfaceTool = part[0]
		builder.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = builder.commit()
		mesh.material_override = part[1]
		plate.add_child(mesh)
	# Restrained local wear, with no random dirt across the whole plate.
	var scratch := G.material(Color("a8ad9b"), 0.92)
	_dish_mark(plate, [Vector2(0.197, 0.076), Vector2(0.209, 0.064), Vector2(0.223, 0.052)], 0.00065, scratch)
	_dish_mark(plate, [Vector2(0.185, 0.092), Vector2(0.198, 0.081)], 0.00045, scratch)
	var crack := G.material(Color("878c79"), 0.98)
	_dish_mark(plate, [Vector2(0.145, 0.185), Vector2(0.136, 0.170), Vector2(0.134, 0.154), Vector2(0.125, 0.141)], 0.0008, crack)
	_dish_mark(plate, [Vector2(0.136, 0.170), Vector2(0.148, 0.161)], 0.0004, crack)
	var faded := G.material(Color("a1aea0"), 0.8)
	for segment in [[1.58, 1.69], [4.55, 4.72]]:
		var marks: Array[Vector2] = []
		for i in range(7):
			var angle: float = lerpf(float(segment[0]), float(segment[1]), float(i) / 6.0)
			marks.append(Vector2(sin(angle), cos(angle)) * 0.272)
		_dish_mark(plate, marks, 0.0015, faded)

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

func _dish_outer_radius(angle: float) -> float:
	var position := fposmod(angle, TAU) / TAU * 48.0
	var step := int(floor(position))
	return lerpf(_saucer_radius(step), _saucer_radius(step + 1), position - float(step))

func _dish_profile_point(profile: Vector2, angle: float) -> Vector3:
	var radius := profile.x + (_dish_outer_radius(angle) - 0.279) * clampf((profile.x - 0.21) / 0.069, 0.0, 1.0)
	var warp := sin(angle * 3.0 + 0.4) * 0.00065 * clampf(profile.x / 0.25, 0.0, 1.0) if profile.y > 0 else 0.0
	return Vector3(sin(angle) * radius, profile.y + warp, cos(angle) * radius)

func _dish_top_height(radius: float) -> float:
	var rings: Array[Vector2] = [Vector2(0, 0.009), Vector2(0.17, 0.008), Vector2(0.209, 0.010), Vector2(0.235, 0.018), Vector2(0.259, 0.027), Vector2(0.269, 0.029), Vector2(0.279, 0.030)]
	for i in range(rings.size() - 1):
		if radius <= rings[i + 1].x:
			return lerpf(rings[i].y, rings[i + 1].y, inverse_lerp(rings[i].x, rings[i + 1].x, radius))
	return 0.030

func _dish_mark(parent: Node3D, points: Array, width: float, material: Material) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var start: Vector2 = points[i]
		var finish: Vector2 = points[i + 1]
		var side := (finish - start).normalized().orthogonal() * width * 0.5
		for point in [start - side, finish + side, finish - side, start - side, start + side, finish + side]:
			var p: Vector2 = point
			builder.set_normal(Vector3.UP)
			builder.add_vertex(Vector3(p.x, _dish_top_height(p.length()) + 0.0007, p.y))
	var instance := MeshInstance3D.new()
	instance.mesh = builder.commit()
	instance.material_override = material
	parent.add_child(instance)

func _cloth_y(x: float, z: float) -> float:
	var outside_plate := smoothstep(0.19, 0.29, Vector2(x - 0.045, z + 0.015).length())
	var edge := pow(clampf(maxf(absf(x) / 0.365, absf(z - 0.01) / 0.24), 0, 1), 7.0)
	var edge_wave := sin(x * 39.0 + z * 16.0) * 0.0017 * edge
	var front_fold := exp(-pow((x + 0.316) / 0.057, 2) - pow((z - 0.188) / 0.061, 2)) * 0.006
	var back_fold := exp(-pow((x + 0.325) / 0.047, 2) - pow((z + 0.183) / 0.052, 2)) * 0.012
	var crease := exp(-pow((z - 0.01 - (x * 0.90 + 0.28)) / 0.017, 2)) * 0.004
	return 0.088 + edge_wave + outside_plate * (front_fold + back_fold + crease)

func _woven_material(color: Color) -> StandardMaterial3D:
	var material := G.material(color, 0.98)
	material.vertex_color_use_as_albedo = true
	material.metallic_specular = 0.10
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in range(128):
		for x in range(128):
			var warp := x % 4 == 0
			var weft := y % 4 == 0
			var over := ((x >> 2) + (y >> 2)) % 2 == 0
			var shade := 0.985
			if warp or weft:
				shade = 0.936
			if warp and weft:
				shade = 0.962 if over else 0.918
			image.set_pixel(x, y, Color(shade, shade, shade * 0.995))
	image.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_scale = Vector3(12, 12, 1)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material

func _build_used_napkin(parent: Node3D) -> void:
	var cloth := _woven_material(Color("b8b29c"))
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(24):
		for column in range(32):
			var x0 := -0.365 + float(column) / 32.0 * 0.73
			var x1 := -0.365 + float(column + 1) / 32.0 * 0.73
			var z0 := -0.23 + float(row) / 24.0 * 0.48
			var z1 := -0.23 + float(row + 1) / 24.0 * 0.48
			# Godot's front faces are clockwise; the cloth must face the camera above it.
			for point in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z0), Vector2(x1, z1), Vector2(x0, z1)]:
				var p: Vector2 = point
				var wear := 0.98 - 0.025 * exp(-pow((p.x + 0.33) / 0.06, 2) - pow((p.y - 0.20) / 0.05, 2))
				builder.set_color(Color(wear, wear, wear))
				builder.set_uv(Vector2((p.x + 0.365) / 0.73, (p.y + 0.23) / 0.48))
				builder.add_vertex(Vector3(p.x, _cloth_y(p.x, p.y), p.y))
	builder.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "FoldedNapkin"
	mesh.mesh = builder.commit()
	mesh.material_override = cloth
	parent.add_child(mesh)
	# A narrow turned hem follows the real folded surface, rather than a box edge.
	var hem := _woven_material(Color("a5a38d"))
	for side in range(4):
		var hem_points: Array[Vector2] = []
		for i in range(25):
			var t := float(i) / 24.0
			match side:
				0: hem_points.append(Vector2(lerpf(-0.36, 0.36, t), -0.225))
				1: hem_points.append(Vector2(0.36, lerpf(-0.225, 0.245, t)))
				2: hem_points.append(Vector2(lerpf(0.36, -0.36, t), 0.245))
				3: hem_points.append(Vector2(-0.36, lerpf(0.245, -0.225, t)))
		_cloth_line(parent, hem_points, 0.0034, 0.0007, hem)
	_build_blue_patch(parent)

func _cloth_line(parent: Node3D, points: Array, width: float, rise: float, material: Material) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var side := (b - a).normalized().orthogonal() * width * 0.5
		for point in [a - side, b + side, b - side, a - side, a + side, b + side]:
			var p: Vector2 = point
			builder.set_normal(Vector3.UP)
			builder.set_color(Color.WHITE)
			builder.set_uv(Vector2((p.x + 0.365) / 0.73, (p.y + 0.23) / 0.48))
			builder.add_vertex(Vector3(p.x, _cloth_y(p.x, p.y) + rise, p.y))
	var instance := MeshInstance3D.new()
	instance.mesh = builder.commit()
	instance.material_override = material
	parent.add_child(instance)

func _patch_point(local: Vector2) -> Vector2:
	return Vector2(-0.29, 0.18) + local.rotated(deg_to_rad(-7.0))

func _build_blue_patch(parent: Node3D) -> void:
	var blue := _woven_material(Color("5c8290"))
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(10):
		for column in range(12):
			var x0 := -0.0525 + float(column) / 12.0 * 0.105
			var x1 := -0.0525 + float(column + 1) / 12.0 * 0.105
			var z0 := -0.0425 + float(row) / 10.0 * 0.085
			var z1 := -0.0425 + float(row + 1) / 10.0 * 0.085
			for point in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z0), Vector2(x1, z1), Vector2(x0, z1)]:
				var local: Vector2 = point
				var p := _patch_point(local)
				var fade := 0.96 + 0.04 * clampf(local.length() / 0.067, 0, 1)
				builder.set_color(Color(fade, fade, fade))
				builder.set_uv(Vector2((local.x + 0.0525) / 0.105, (local.y + 0.0425) / 0.085))
				builder.add_vertex(Vector3(p.x, _cloth_y(p.x, p.y) + 0.0016, p.y))
	builder.generate_normals()
	var patch := MeshInstance3D.new()
	patch.name = "BluePatch"
	patch.mesh = builder.commit()
	patch.material_override = blue
	parent.add_child(patch)
	var stitches := SurfaceTool.new()
	stitches.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector2] = [Vector2(-0.046, -0.036), Vector2(0.046, -0.036), Vector2(0.046, 0.036), Vector2(-0.046, 0.036)]
	for edge in range(4):
		var count := 11 if edge % 2 == 0 else 9
		var start := corners[edge]
		var finish := corners[(edge + 1) % 4]
		for i in range(count):
			var jitter := sin(float(i * 7 + edge * 11)) * 0.0006
			var a := _patch_point(start.lerp(finish, (float(i) + 0.16) / float(count)) + Vector2(jitter, -jitter))
			var b := _patch_point(start.lerp(finish, (float(i) + 0.68) / float(count)) + Vector2(-jitter, jitter))
			var side := (b - a).normalized().orthogonal() * 0.00055
			for point in [a - side, b + side, b - side, a - side, a + side, b + side]:
				var p: Vector2 = point
				stitches.set_normal(Vector3.UP)
				stitches.add_vertex(Vector3(p.x, _cloth_y(p.x, p.y) + 0.0028, p.y))
	var seam := MeshInstance3D.new()
	seam.name = "RepairStitches"
	seam.mesh = stitches.commit()
	seam.material_override = G.material(Color("c6bba0"), 0.98)
	parent.add_child(seam)
	# A few short loose fibres are confined to the repaired edge.
	for i in range(5):
		var a := _patch_point(Vector2(-0.052, -0.027 + float(i) * 0.012))
		var b := _patch_point(Vector2(-0.056 - float(i % 2) * 0.002, -0.026 + float(i) * 0.012))
		_cloth_line(parent, [a, b], 0.00045, 0.0019, blue)

func _build_sandwich(parent: Node3D, index: int) -> void:
	_build_bread_slice(parent, 0.0, 0.024, index, false)
	_build_filling(parent, 0.024, 0.009, 0.94, index + 2, Color("aa816c"))
	_build_filling(parent, 0.033, 0.006, 0.95, index + 5, Color("c8ba98"))
	_build_bread_slice(parent, 0.039, 0.024, index + 5, true)

func _bread_outline(seed: int) -> PackedVector2Array:
	var corners: Array[Vector2] = [Vector2(-0.10, 0.085), Vector2(0.10, 0.085), Vector2(0, -0.085)]
	var outline := PackedVector2Array()
	for i in range(3):
		var corner := corners[i]
		var previous := corners[(i + 2) % 3]
		var next := corners[(i + 1) % 3]
		var rounding := 0.010 + float((seed + i) % 3) * 0.001
		var start := corner + (previous - corner).normalized() * rounding
		var finish := corner + (next - corner).normalized() * rounding
		for j in range(5):
			var t := float(j) / 4.0
			outline.append((1.0 - t) * (1.0 - t) * start + 2.0 * (1.0 - t) * t * corner + t * t * finish)
		var next_corner := corners[(i + 1) % 3]
		var next_start := next_corner + (corner - next_corner).normalized() * (0.010 + float((seed + i + 1) % 3) * 0.001)
		var outward := -(next_start - finish).normalized().orthogonal()
		for j in range(1, 4):
			var t := float(j) / 4.0
			outline.append(finish.lerp(next_start, t) + outward * sin(float(seed * 3 + i * 7 + j)) * 0.0013)
	return outline

func _bread_pores(seed: int) -> Array[Vector3]:
	# x, z, radius. Only a few authored air pockets, not noise over every surface.
	var pores: Array[Vector3] = [Vector3(-0.045, 0.040, 0.0034), Vector3(0.039, 0.043, 0.0026), Vector3(0.001, -0.036, 0.0029), Vector3(0.018, 0.014, 0.0036), Vector3(-0.026, 0.002, 0.0024), Vector3(0.060, 0.064, 0.0030), Vector3(-0.029, 0.064, 0.0027), Vector3(0.004, 0.066, 0.0035)]
	for i in range(pores.size()):
		pores[i].x += sin(float(seed + i * 5)) * 0.0015
		pores[i].y += cos(float(seed * 3 + i)) * 0.0012
	return pores

func _crumb_depth(point: Vector2, pores: Array[Vector3]) -> float:
	var depth := 0.0
	for pore in pores:
		var distance := Vector2((point.x - pore.x) / pore.z, (point.y - pore.y) / (pore.z * 0.72)).length()
		if distance < 1.0:
			depth = maxf(depth, 0.0018 * pow(1.0 - distance, 1.5))
	return depth

func _crumb_height(point: Vector2, top: float, seed: int, pores: Array[Vector3]) -> float:
	var bulge := clampf(1.0 - Vector2(point.x / 0.105, point.y / 0.09).length(), 0, 1) * 0.0017
	var grain := sin(point.x * 37.0 + float(seed) * 0.9) * sin(point.y * 24.0) * 0.00045
	return top + bulge + grain - _crumb_depth(point, pores)

func _build_bread_slice(parent: Node3D, base: float, thickness: float, seed: int, porous: bool) -> void:
	var outline := _bread_outline(seed)
	var inner := PackedVector2Array()
	for point in outline:
		inner.append(point * 0.94)
	var pores: Array[Vector3] = []
	if porous:
		pores = _bread_pores(seed)
	var side := SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var next := (i + 1) % outline.size()
		var a := outline[i]
		var b := outline[next]
		var baked := smoothstep(0.049, 0.078, (a.y + b.y) * 0.5)
		var color := Color("cdbc9e").lerp(Color("a0784f"), baked)
		var shade := 0.985 + sin(float(i * 3 + seed * 7)) * 0.018
		color = Color(color.r * shade, color.g * shade, color.b * shade)
		_bread_colored_quad(side, Vector3(a.x, base + 0.0013, a.y), Vector3(b.x, base + 0.0013, b.y), Vector3(b.x, base + thickness - 0.001, b.y), Vector3(a.x, base + thickness - 0.001, a.y), color)
		var ia := inner[i]
		var ib := inner[next]
		_bread_colored_quad(side, Vector3(a.x, base + thickness - 0.001, a.y), Vector3(b.x, base + thickness - 0.001, b.y), Vector3(ib.x, _crumb_height(ib, base + thickness, seed, pores), ib.y), Vector3(ia.x, _crumb_height(ia, base + thickness, seed, pores), ia.y), color.lightened(0.04))
		for point in [Vector3(0, base, 0), Vector3(a.x, base + 0.0013, a.y), Vector3(b.x, base + 0.0013, b.y)]:
			side.set_color(Color("cebd9e"))
			side.add_vertex(point)
	side.generate_normals()
	var side_mesh := MeshInstance3D.new()
	side_mesh.name = "CrustAndCutEdges"
	side_mesh.mesh = side.commit()
	var side_material := G.material(Color.WHITE, 0.94)
	side_material.vertex_color_use_as_albedo = true
	side_material.metallic_specular = 0.10
	side_mesh.material_override = side_material
	parent.add_child(side_mesh)
	# Triangulation incorporates the pores themselves, producing actual depressions.
	var points := inner.duplicate()
	for row in range(1, 9):
		for column in range(1, 10):
			var point := Vector2(-0.09 + float(column) * 0.018, -0.075 + float(row) / 9.0 * 0.15)
			if Geometry2D.is_point_in_polygon(point, inner):
				points.append(point)
	for pore in pores:
		var center := Vector2(pore.x, pore.y)
		points.append(center)
		for i in range(10):
			var angle := float(i) / 10.0 * TAU
			var point := center + Vector2(cos(angle) * pore.z, sin(angle) * pore.z * 0.72)
			if Geometry2D.is_point_in_polygon(point, inner):
				points.append(point)
	var indices := Geometry2D.triangulate_delaunay(points)
	var crumb := SurfaceTool.new()
	crumb.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var a: Vector2 = points[indices[i]]
		var b: Vector2 = points[indices[i + 1]]
		var c: Vector2 = points[indices[i + 2]]
		if not Geometry2D.is_point_in_polygon((a + b + c) / 3.0, inner):
			continue
		var vertices: Array[Vector2] = [a, b, c]
		if Vector3(b.x - a.x, 0, b.y - a.y).cross(Vector3(c.x - a.x, 0, c.y - a.y)).y > 0:
			vertices = [a, c, b]
		for point in vertices:
			var depth := _crumb_depth(point, pores)
			var color := Color("ded1b7").lerp(Color("b6a081"), depth / 0.0018 * 0.40)
			crumb.set_color(color)
			crumb.add_vertex(Vector3(point.x, _crumb_height(point, base + thickness, seed, pores), point.y))
	crumb.generate_normals()
	var crumb_mesh := MeshInstance3D.new()
	crumb_mesh.name = "PorousBread" if porous else "LowerBread"
	crumb_mesh.mesh = crumb.commit()
	var crumb_material := G.material(Color.WHITE, 0.98)
	crumb_material.vertex_color_use_as_albedo = true
	crumb_material.metallic_specular = 0.08
	crumb_mesh.material_override = crumb_material
	parent.add_child(crumb_mesh)

func _bread_colored_quad(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for point in [a, c, b, a, d, c]:
		builder.set_color(color)
		builder.add_vertex(point)

func _build_filling(parent: Node3D, base: float, thickness: float, scale: float, seed: int, color: Color) -> void:
	var outline := _bread_outline(seed)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var next := (i + 1) % outline.size()
		var a := outline[i] * scale
		var b := outline[next] * scale
		var a_top := base + thickness + sin(float(i * 2 + seed)) * 0.00065
		var b_top := base + thickness + sin(float(next * 2 + seed)) * 0.00065
		var edge_color := color.darkened(0.05 + sin(float(i * 3 + seed)) * 0.018)
		_bread_colored_quad(builder, Vector3(a.x, base, a.y), Vector3(b.x, base, b.y), Vector3(b.x, b_top, b.y), Vector3(a.x, a_top, a.y), edge_color)
		for point in [Vector3(0, base + thickness, 0), Vector3(b.x, b_top, b.y), Vector3(a.x, a_top, a.y)]:
			builder.set_color(color)
			builder.add_vertex(point)
		for point in [Vector3(0, base, 0), Vector3(a.x, base, a.y), Vector3(b.x, base, b.y)]:
			builder.set_color(edge_color)
			builder.add_vertex(point)
	builder.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = "UnevenFilling"
	instance.mesh = builder.commit()
	var material := G.material(Color.WHITE, 0.89)
	material.vertex_color_use_as_albedo = true
	material.metallic_specular = 0.18
	instance.material_override = material
	parent.add_child(instance)
