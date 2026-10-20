extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(560, 420)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var stage: Node3D = load("res://scenes/objects/inspection_stage.tscn").instantiate()
	stage.set_item("P02")
	stage.reduced_motion = true
	viewport.add_child(stage)
	await process_frame
	var package := stage.get_node("Pivot/Package") as Node3D
	_expect(package.get_node("Contents").visible and not package.get_node("FoldedShirt").visible, "P02 opens the shirt to show brick")
	_expect(stage.find_children("Target_sandwiches", "StaticBody3D", true, false).is_empty(), "P02 inspection does not keep P01 targets")
	_expect(package.get_node("Target_P02").collision_layer == 0, "room target disabled in inspection")
	for id in ["corner", "paint", "collar"]:
		_expect(package.get_node("Target_" + id).collision_layer == 2, id + ": inspection target enabled")
	var brick := package.find_child("ChamferedBrick", true, false) as MeshInstance3D
	var arrays: Array = brick.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var centre := Vector3(0, 0.1275, 0)
	var side_count := 0
	for i in range(0, vertices.size(), 3):
		var middle := (vertices[i] + vertices[i + 1] + vertices[i + 2]) / 3
		var outward := middle - centre
		var front := -(vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).normalized()
		_expect(front.dot(outward) > 0.001, "brick triangle faces outside; back-face culling keeps the solid")
		_expect(normals[i].dot(outward) > 0.001, "brick lighting normal faces outside")
		if absf(front.y) < 0.1:
			side_count += 1
	_expect(side_count == 10, "five closed side faces include chamfer")
	var paint := package.find_child("OldBluePaint", true, false) as Node3D
	var plaster := package.find_child("WhitePlaster", true, false) as Node3D
	_expect(plaster.position.y > paint.position.y, "white plaster overlays old blue paint")
	var patch := package.find_child("DarkPatch", true, false)
	_expect(is_instance_valid(patch) and patch.get_parent().name == "ShirtCollar", "patch belongs to the turned collar")
	var camera := stage.get_node("Camera3D") as Camera3D
	var overview := camera.transform
	var fov := camera.fov
	for id in ["corner", "paint", "collar"]:
		stage.focus_detail(id)
		_expect(stage.get_focus_id() == id and not camera.transform.is_equal_approx(overview), id + ": own close-up camera")
		stage.reset_focus()
		_expect(stage.get_focus_id().is_empty() and camera.transform.is_equal_approx(overview) and is_equal_approx(camera.fov, fov), id + ": returns to whole P02")
	stage.focus_detail("napkin")
	_expect(stage.get_focus_id().is_empty(), "Nina detail cannot focus Fedor camera")
	package.set_opened(false)
	_expect(not package.get_node("Contents").visible and package.get_node("FoldedShirt").visible, "closed wrap covers brick")
	viewport.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d brick geometry and inspection checks." % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
