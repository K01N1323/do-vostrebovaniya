extends SceneTree
## Focused presentation checks for iteration 0.4; no game commands are sent.

var _checks := 0
var _failures: Array[String] = []
var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _overview: Transform3D
var _overview_fov: float


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := root.get_node_or_null("GameStore")
	var initial_history: Dictionary = store.call("get_snapshot") if is_instance_valid(store) else {}
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(560, 420)
	_viewport.own_world_3d = true
	root.add_child(_viewport)
	_stage = load("res://scenes/objects/inspection_stage.tscn").instantiate()
	_viewport.add_child(_stage)
	await process_frame
	var api_ready := _stage.has_method("focus_detail") and _stage.has_method("reset_focus") and _stage.has_method("get_focus_id")
	_expect(api_ready, "inspection exposes focus, reset and focus-id API")
	_camera = _stage.get_node_or_null("Camera3D") as Camera3D
	var pivot := _stage.get_node_or_null("Pivot") as Node3D
	_expect(is_instance_valid(_camera) and is_instance_valid(pivot), "overview camera and rotation pivot exist")
	if not api_ready or not is_instance_valid(_camera) or not is_instance_valid(pivot):
		_viewport.queue_free()
		await process_frame
		_finish()
		return
	_overview = _camera.transform
	_overview_fov = _camera.fov
	_test_visible_surfaces()
	_expect(_stage.call("get_focus_id") == "", "initial focus shows entire carrier")
	_stage.set("reduced_motion", false)
	for id in ["saucer", "napkin", "sandwiches"]:
		_stage.call("focus_detail", id)
		await create_timer(0.6).timeout
		_expect(_stage.call("get_focus_id") == id, id + ": close-up records selected focus")
		_expect(not _is_overview(), id + ": close-up changes camera transform or FOV")
		_stage.call("reset_focus")
		await create_timer(0.6).timeout
		_expect(_stage.call("get_focus_id") == "" and _is_overview(), id + ": reset returns to overview camera")
	var old_angle: float = pivot.rotation.y
	_stage.call("rotate_item", 1.0)
	await create_timer(0.3).timeout
	_expect(not is_equal_approx(old_angle, pivot.rotation.y), "normal-motion overview remains rotatable")
	_expect(_stage.call("get_focus_id") == "", "overview rotation keeps overview focus")
	_stage.set("reduced_motion", true)
	old_angle = pivot.rotation.y
	_stage.call("rotate_item", -1.0)
	_expect(not is_equal_approx(old_angle, pivot.rotation.y), "reduced-motion overview rotates immediately")
	_stage.call("focus_detail", "napkin")
	_expect(_stage.call("get_focus_id") == "napkin" and not _is_overview(), "reduced-motion close-up is immediate")
	_stage.call("reset_focus")
	_expect(_stage.call("get_focus_id") == "" and _is_overview(), "reduced-motion reset is immediate")
	_stage.call("focus_detail", "saucer")
	var focused_camera: Transform3D = _camera.transform
	var focused_fov: float = _camera.fov
	_stage.call("rotate_item", 1.0)
	var focus_after_rotation: String = str(_stage.call("get_focus_id"))
	_expect(focus_after_rotation in ["", "saucer"], "rotation in close-up either stays disabled or returns to overview")
	if focus_after_rotation == "":
		_expect(_is_overview(), "rotating out of close-up restores overview camera")
	else:
		_expect(_camera.transform.is_equal_approx(focused_camera) and is_equal_approx(_camera.fov, focused_fov), "disabled close-up rotation preserves focused camera")
	_stage.call("reset_focus")
	_stage.set("reduced_motion", false)
	_stage.call("focus_detail", "saucer")
	_stage.call("focus_detail", "napkin")
	_stage.call("reset_focus")
	await create_timer(0.7).timeout
	_expect(_stage.call("get_focus_id") == "" and _is_overview(), "reset cancels unfinished focus transitions")
	if is_instance_valid(store):
		_expect(store.call("get_snapshot") == initial_history, "inspection presentation never changes game history")
	_stage.call("focus_detail", "saucer")
	_viewport.queue_free()
	await process_frame
	await process_frame
	_finish()


func _is_overview() -> bool:
	return _camera.transform.is_equal_approx(_overview) and is_equal_approx(_camera.fov, _overview_fov)


func _test_visible_surfaces() -> void:
	# These clues must face upwards with back-face culling enabled. Camera motion alone
	# can pass while the patch and bread surface are entirely invisible in the render.
	for mesh_name in ["FoldedNapkin", "BluePatch", "RepairStitches", "PorousBread"]:
		var meshes := _stage.find_children(mesh_name, "MeshInstance3D", true, false)
		_expect(not meshes.is_empty(), mesh_name + ": visible clue mesh exists")
		for mesh in meshes:
			var arrays: Array = mesh.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var up := 0.0
			for normal in normals:
				up += normal.y
			_expect(not normals.is_empty() and up / maxf(normals.size(), 1) > 0.8,
				mesh_name + ": front face and lighting face the inspection camera")
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var front_faces := 0
			var back_faces := 0
			for i in range(0, vertices.size(), 3):
				var winding := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).y
				if winding < -0.0000000001:
					front_faces += 1
				elif winding > 0.0000000001:
					back_faces += 1
			_expect(front_faces > 0 and back_faces == 0,
				mesh_name + ": top-facing triangles remain visible with back-face culling")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: %d inspection focus checks." % _checks)
		quit(0)
	else:
		for message in _failures:
			push_error(message)
		print("FAIL: %d failures / %d inspection focus checks" % [_failures.size(), _checks])
		quit(1)
