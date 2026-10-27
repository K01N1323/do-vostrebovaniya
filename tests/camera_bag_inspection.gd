extends "res://tests/suitcase_inspection.gd"

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(560,420)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var stage: Node3D = load("res://scenes/objects/inspection_stage.tscn").instantiate()
	stage.set_item("P04")
	stage.reduced_motion = true
	viewport.add_child(stage)
	await process_frame
	var package := stage.get_node("Pivot/Package") as Node3D
	_expect(package.opened and package.get_node("Contents").visible and not package.get_node("FoldedBagTop").visible, "inspection unfolds the bag and shows fixed contents")
	_expect(package.get_node("Target_P04").collision_layer == 0, "world package collider cannot swallow detail clicks")
	_expect(package.find_children("Onion*","Node3D",true,false).size() == 3, "exactly three physical onions, no fourth prop")
	_expect(package.find_children("SilverFilmCamera","Node3D",true,false).size() == 1, "one physical camera")
	var silver := package.find_child("SilverBody",true,false) as MeshInstance3D
	_expect(silver.material_override.albedo_color.r > 0.65 and silver.material_override.albedo_color.g > 0.65, "camera body remains silver independently of the claim")
	_expect(is_instance_valid(package.find_child("MendedFabricStrap",true,false)), "strap includes an actual repair mesh")
	var camera := stage.get_node("Camera3D") as Camera3D
	var overview := camera.transform
	for id in ["camera_body","strap","onions"]:
		var target := package.get_node("Target_" + id) as StaticBody3D
		_expect(target.collision_layer == 2, id + " selectable only in inspection")
		stage.focus_detail(id)
		_expect(stage.get_focus_id() == id and not camera.transform.is_equal_approx(overview), id + " owns a close-up")
		_expect(not camera.is_position_behind(target.global_position), id + " target remains in front of close-up camera")
		stage.reset_focus()
		_expect(stage.get_focus_id().is_empty() and camera.transform.is_equal_approx(overview), id + " returns to overview")
	stage.focus_detail("zipper")
	_expect(stage.get_focus_id().is_empty(), "shared-case detail cannot select the camera-bag view")
	package.set_opened(false)
	_expect(package.get_node("FoldedBagTop").visible and not package.get_node("Contents").visible, "closing hides camera and onions together")
	for id in ["camera_body","strap","onions"]:
		_expect(package.get_node("Target_" + id).collision_layer == 0, "closed bag blocks " + id)
	package.set_opened(true)
	_expect(package.find_children("Onion*","Node3D",true,false).size() == 3, "reopening never duplicates contents")
	viewport.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d camera-bag geometry and inspection checks." % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
