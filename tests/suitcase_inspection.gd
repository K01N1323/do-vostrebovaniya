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
	viewport.size = Vector2i(560,420)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var stage: Node3D = load("res://scenes/objects/inspection_stage.tscn").instantiate()
	stage.set_item("P03")
	stage.reduced_motion = true
	viewport.add_child(stage)
	await process_frame
	var package := stage.get_node("Pivot/Package") as Node3D
	_expect(package.opened and package.unlocked and not package.lining_lifted, "inspection shows opened suitcase with original lining down")
	_expect(package.get_node("Target_P03").collision_layer == 0, "P03 world collider disabled in isolated inspection")
	_expect(package.get_node("Target_lining").collision_layer == 2 and package.get_node("Target_zipper").collision_layer == 0, "lining covers disabled hidden target")
	stage.focus_detail("zipper")
	_expect(stage.get_focus_id().is_empty(), "hidden pull cannot select its close-up")
	var stain := package.find_child("GreenPaintStain",true,false) as MeshInstance3D
	var arrays: Array = stain.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0,vertices.size(),3):
		_expect((vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).y < 0, "green stain front faces upward with culling")
		_expect(normals[i].y > 0.8, "green stain lighting faces inspection camera")
	stage.set_lining_lifted(true)
	_expect(package.lining_lifted and package.get_node("Target_zipper").collision_layer == 2 and package.get_node("Target_lining").collision_layer == 0, "lifting changes both targets without duplicating pull")
	var pull := package.find_child("BrokenZipperPull",true,false) as Node3D
	var flap := package.find_child("LooseLining",true,false) as Node3D
	_expect(is_instance_valid(pull) and flap.rotation_degrees.z > 60, "fold physically reveals a real pull mesh")
	var camera := stage.get_node("Camera3D") as Camera3D
	var overview := camera.transform
	var overview_fov := camera.fov
	for id in ["combination","green_stain","zipper"]:
		stage.focus_detail(id)
		_expect(stage.get_focus_id() == id and not camera.transform.is_equal_approx(overview), id + ": own close-up")
		stage.reset_focus()
		_expect(stage.get_focus_id().is_empty() and camera.transform.is_equal_approx(overview) and is_equal_approx(camera.fov,overview_fov), id + ": restores overview")
	_expect(package.find_children("BrokenZipperPull","Node3D",true,false).size() == 1, "one physical pull in one suitcase")
	stage.focus_detail("paint")
	_expect(stage.get_focus_id().is_empty(), "previous case detail cannot select camera")
	viewport.queue_free()
	await process_frame
	# Fresh inspection rebuilds the raised lining from stored knowledge.
	var restored_viewport := SubViewport.new()
	root.add_child(restored_viewport)
	var restored: Node3D = load("res://scenes/objects/inspection_stage.tscn").instantiate()
	restored.set_item("P03")
	restored.set_lining_lifted(true)
	restored_viewport.add_child(restored)
	_expect(restored.get_node("Pivot/Package").lining_lifted, "raised lining restores when configured before tree entry")
	restored_viewport.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d suitcase geometry and inspection checks." % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
