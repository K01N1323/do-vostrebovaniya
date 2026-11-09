extends RefCounted
## One model and one set of close-up targets per package, shared by room and inspection.

const SCENES := {
	"P01": "res://scenes/objects/package.tscn",
	"P02": "res://scenes/objects/brick_package.tscn",
	"P03": "res://scenes/objects/suitcase.tscn",
	"P04": "res://scenes/objects/camera_bag.tscn",
	"P05": "res://scenes/objects/P05.tscn",
	"P06": "res://scenes/objects/P06.tscn",
	"P07": "res://scenes/objects/P07.tscn",
	"P08": "res://scenes/objects/P08.tscn",
}

const VIEWS := {
	"P01": {
		"sandwiches": {"eye": Vector3(0.10, 0.76, 0.70), "at": Vector3(0.04, 0.17, -0.01), "fov": 35.0},
		"saucer": {"eye": Vector3(0.31, 0.46, 0.57), "at": Vector3(0.19, 0.135, 0.18), "fov": 35.0},
		"napkin": {"eye": Vector3(-0.37, 0.33, 0.43), "at": Vector3(-0.29, 0.10, 0.18), "fov": 36.0}
	},
	"P02": {
		"corner": {"eye": Vector3(-0.49, 0.40, 0.48), "at": Vector3(-0.21, 0.13, 0.09), "fov": 35.0},
		"paint": {"eye": Vector3(0.07, 0.78, 0.45), "at": Vector3(0.025, 0.23, -0.005), "fov": 32.0},
		"collar": {"eye": Vector3(0.43, 0.40, 0.48), "at": Vector3(0.28, 0.058, 0.16), "fov": 29.0}
	},
	"P03": {
		"combination": {"eye": Vector3(0, 0.29, 0.76), "at": Vector3(0, 0.125, 0.27), "fov": 31.0},
		"green_stain": {"eye": Vector3(-0.23, 0.64, 0.45), "at": Vector3(-0.16, 0.042, 0.01), "fov": 33.0},
		"zipper": {"eye": Vector3(0.42, 0.37, 0.39), "at": Vector3(0.23, 0.05, 0.08), "fov": 25.0}
	},
	"P04": {
		"camera_body": {"eye": Vector3(0.02, 0.46, 0.56), "at": Vector3(0.025, 0.18, 0.015), "fov": 31.0},
		"strap": {"eye": Vector3(-0.39, 0.43, 0.44), "at": Vector3(-0.17, 0.075, 0.12), "fov": 26.0},
		"onions": {"eye": Vector3(0.30, 0.73, 0.41), "at": Vector3(0.07, 0.08, -0.05), "fov": 37.0}
	},
	"P08": {
		"shirt": {"eye": Vector3(-0.16, 0.47, 0.26), "at": Vector3(-0.115, 0.07, 0.006), "fov": 32.0},
		"ticket": {"eye": Vector3(0.08, 0.30, 0.18), "at": Vector3(0.105, 0.063, 0.068), "fov": 28.0},
		"pass": {"eye": Vector3(0.13, 0.27, 0.10), "at": Vector3(0.107, 0.059, -0.001), "fov": 30.0},
		"card": {"eye": Vector3(0.15, 0.29, 0.04), "at": Vector3(0.145, 0.089, -0.10), "fov": 29.0},
	},
	"P05": {
		"coat_tag": {"eye": Vector3(0.31, 0.30, 0.42), "at": Vector3(0.337, 0.023, 0.235), "fov": 34.0},
		"coat_pockets": {"eye": Vector3(0, 0.66, 0.28), "at": Vector3(0, 0.072, -0.02), "fov": 40.0},
		"coat_cuff": {"eye": Vector3(-0.39, 0.26, 0.22), "at": Vector3(-0.36, 0.06, 0.10), "fov": 31.0},
		"coat_reversed": {"eye": Vector3(0.06, 0.29, 0.24), "at": Vector3(0, 0.09, 0.095), "fov": 34.0},
	},
	"P06": {
		"case_interior": {"eye": Vector3(-0.14, 0.35, 0.23), "at": Vector3(-0.056, 0.03, 0), "fov": 33.0},
		"lens_cap": {"eye": Vector3(0.11, 0.23, 0.20), "at": Vector3(0.092, 0.06, 0.024), "fov": 29.0},
	},
	"P07": {
		"remote_bundle": {"eye": Vector3(0.05, 0.46, 0.22), "at": Vector3(0, 0.04, -0.035), "fov": 38.0},
		"battery_bays": {"eye": Vector3(0, 0.38, 0.21), "at": Vector3(0, 0.04, 0.061), "fov": 37.0},
	},
}

static func detail_views(package_id: String) -> Dictionary:
	return VIEWS.get(package_id, {})

static func instantiate(package_id: String) -> Node3D:
	var scene := load(SCENES[package_id]) as PackedScene
	return scene.instantiate()

static func missing_details(package_id: String, details: Array) -> Array[String]:
	var missing: Array[String] = []
	for id in details:
		if not detail_views(package_id).has(id):
			missing.append(id)
	return missing
