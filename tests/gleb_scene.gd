extends "res://tests/gleb_rules.gd"
## Visual storage of three appropriated items, then a full scene reset.

func _run() -> void:
	var state := _before_gleb("APPROPRIATE_PACKAGE", "APPROPRIATE_PACKAGE", "")
	for command in [{"type":"READ_DOCUMENT","document_id":"identity"}, {"type":"READ_DOCUMENT","document_id":"claim"},
		{"type":"MOVE_PACKAGE","destination":"desk"}, {"type":"OPEN_PACKAGE"},
		{"type":"INSPECT_DETAIL","detail_id":"camera_body"}, {"type":"INSPECT_DETAIL","detail_id":"strap"},
		{"type":"INSPECT_DETAIL","detail_id":"onions"}, {"type":"APPROPRIATE_PACKAGE"}]:
		state = _apply(state,command)
	var scene := Node3D.new()
	root.add_child(scene)
	var room: Node3D = load("res://scenes/room/room.tscn").instantiate()
	scene.add_child(room)
	room.reduced_motion = true
	room.apply_snapshot(state)
	var rig: Node3D = load("res://scenes/room/camera_rig.tscn").instantiate()
	scene.add_child(rig)
	rig.reduced_motion = true
	rig.focus("personal")
	await process_frame
	var views: Dictionary = room.get("_package_views")
	for id in ["P01", "P02", "P04"]:
		_expect(views[id].visible and not views[id].opened, id + " remains closed in personal storage")
	_expect(not _visible_bounds(views.P01).intersects(_visible_bounds(views.P04)), "P04 does not intersect an appropriated P01")
	_expect(not _visible_bounds(views.P02).intersects(_visible_bounds(views.P04)), "P04 does not intersect an appropriated P02")
	var bag_bounds := _visible_bounds(views.P04)
	_expect(is_equal_approx(bag_bounds.position.y,0.25), "bag rests on its dedicated stand")
	_expect(room.find_children("Target_P04","StaticBody3D",true,false).size() == 1, "one room bag across the whole shift")
	if DisplayServer.get_name() != "headless":
		var film := CanvasLayer.new()
		film.set_script(load("res://scripts/presentation/film_grade.gd"))
		scene.add_child(film)
		await create_timer(0.5).timeout
		RenderingServer.force_draw(false)
		var image := root.get_texture().get_image()
		_expect(image.save_png(ProjectSettings.globalize_path("res://tools/input-08/all-personal.png")) == OK, "all appropriated items captured together")
	room.apply_snapshot(Rules.initial_state())
	_expect(not views.P04.opened and views.P04.get_node("Target_P04").collision_layer == 0, "restart restores the inactive bag without a live collider")
	_expect(not room.find_child("GlebPortrait",true,false).visible, "restart hides Gleb's portrait")
	scene.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("%s: %d Gleb storage and reset checks." % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _visible_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in node.find_children("*","MeshInstance3D",true,false):
		if not child.is_visible_in_tree():
			continue
		var box: AABB = child.global_transform * child.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
