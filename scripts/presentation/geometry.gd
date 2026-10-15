extends RefCounted
## Small shared primitive library. All generated meshes belong to their scene.

static var _worn_cache: Dictionary = {}

static var _surface_textures: Dictionary = {}

static func worn_material(color: Color, style: String = "paint", roughness: float = 0.88, metallic: float = 0.0) -> Material:
	var key := color.to_html() + style + str(roughness) + str(metallic)
	if _worn_cache.has(key):
		return _worn_cache[key]
	var mat := material(color, roughness)
	mat.metallic = minf(metallic, 0.22) # The visible layer is worn paint, not polished metal.
	mat.metallic_specular = 0.28
	var texture_path := ""
	var repeat_scale := 1.0
	var average := Color.WHITE
	match style:
		"plaster", "rust":
			texture_path = "res://assets/materials/plaster-worn-v1.png"
			repeat_scale = 0.42 if style == "plaster" else 2.0
			average = Color(0.64, 0.60, 0.53)
		"wood":
			texture_path = "res://assets/materials/walnut-worn-v1.png"
			repeat_scale = 0.72
			average = Color(0.34, 0.26, 0.19)
		"metal", "paint":
			texture_path = "res://assets/materials/steel-painted-v1.png"
			repeat_scale = 1.6 if style == "metal" else 0.8
			average = Color(0.31, 0.31, 0.28)
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		if not _surface_textures.has(texture_path):
			_surface_textures[texture_path] = load(texture_path)
		var surface := ShaderMaterial.new()
		surface.shader = preload("res://assets/shaders/worn_surface.gdshader")
		surface.set_shader_parameter("surface_map", _surface_textures[texture_path])
		surface.set_shader_parameter("tint", color)
		surface.set_shader_parameter("map_average", average)
		surface.set_shader_parameter("repeat_scale", repeat_scale)
		surface.set_shader_parameter("detail_strength", 0.42 if style == "plaster" else (0.60 if style == "wood" else 0.48))
		surface.set_shader_parameter("surface_roughness", roughness)
		surface.set_shader_parameter("surface_metallic", minf(metallic, 0.18))
		_worn_cache[key] = surface
		return surface
	else:
		mat.albedo_texture = _fine_surface(style)
		if style == "tile":
			mat.roughness = 0.68
			repeat_scale = 2.4
		elif style == "cloth":
			repeat_scale = 8.0
		elif style == "leather":
			repeat_scale = 5.0
		else:
			repeat_scale = 3.0
	# Object-space projection keeps grain attached to moving packages, in metre units.
	# It also avoids stretching one tiny bitmap over long thin cuboid faces.
	mat.uv1_triplanar = true
	mat.uv1_triplanar_sharpness = 8.0
	mat.uv1_scale = Vector3.ONE * repeat_scale
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_worn_cache[key] = mat
	return mat

static func _fine_surface(style: String) -> Texture2D:
	if _surface_textures.has(style):
		return _surface_textures[style]
	var noise := FastNoiseLite.new()
	noise.seed = 7813 + style.hash()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045 if style == "tile" else 0.16
	noise.fractal_octaves = 4
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.66, 0.64, 0.60))
	gradient.set_color(1, Color(1.0, 0.99, 0.96))
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	texture.color_ramp = gradient
	_surface_textures[style] = texture
	return texture

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
	result.shaded = true
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
