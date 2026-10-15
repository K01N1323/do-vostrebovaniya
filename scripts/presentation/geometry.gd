extends RefCounted
## Small shared primitive library. All generated meshes belong to their scene.

static func material(color: Color, roughness: float = 0.86) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result

static func box(parent: Node3D, size: Vector3, position: Vector3, mat: Material, object_name: String = "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = position
	if not object_name.is_empty():
		instance.name = object_name
	parent.add_child(instance)
	return instance

static func cylinder(parent: Node3D, radius: float, height: float, position: Vector3, mat: Material, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = position
	parent.add_child(instance)
	return instance

static func sphere(parent: Node3D, radius: float, position: Vector3, mat: Material, shape_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = position
	instance.scale = shape_scale
	parent.add_child(instance)
	return instance

static func rod(parent: Node3D, start: Vector3, finish: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var instance := cylinder(parent, radius, start.distance_to(finish), (start + finish) * 0.5, mat)
	var direction := (finish - start).normalized()
	if absf(direction.dot(Vector3.UP)) > 0.999:
		return instance
	instance.quaternion = Quaternion(Vector3.UP, direction)
	return instance

static func label(parent: Node3D, text: String, position: Vector3, font_size: int = 28, color: Color = Color("d9d2ba")) -> Label3D:
	var result := Label3D.new()
	result.text = text
	result.font_size = font_size
	result.pixel_size = 0.0025
	result.modulate = color
	result.outline_size = 0
	result.position = position
	parent.add_child(result)
	return result

static func target(parent: Node3D, target_id: String, size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Target_" + target_id
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("target_id", target_id)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	parent.add_child(body)
	return body

static func triangle_slice(parent: Node3D, size: Vector3, position: Vector3, mat: Material) -> MeshInstance3D:
	var a := Vector3(-size.x * 0.5, 0, size.z * 0.5)
	var b := Vector3(size.x * 0.5, 0, size.z * 0.5)
	var c := Vector3(0, 0, -size.z * 0.5)
	var rise := Vector3(0, size.y, 0)
	var points: Array[Vector3] = [a, c, b, a + rise, b + rise, c + rise,
		a, b, b + rise, a, b + rise, a + rise,
		b, c, c + rise, b, c + rise, b + rise,
		c, a, a + rise, c, a + rise, c + rise]
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in points:
		builder.add_vertex(point)
	builder.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = builder.commit()
	instance.material_override = mat
	instance.position = position
	parent.add_child(instance)
	return instance
