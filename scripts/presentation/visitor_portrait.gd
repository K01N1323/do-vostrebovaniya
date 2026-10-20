extends Sprite3D
## Restrained painted-cutout motion, anchored to the visitor's floor position.

var _elapsed := 0.0
var anchor_position := Vector3(0, 0.92, 0.06)

func _process(delta: float) -> void:
	var room := get_parent().get_parent()
	if not is_visible_in_tree() or room.reduced_motion:
		position = anchor_position
		rotation.z = 0
		scale = Vector3.ONE
		return
	_elapsed += delta
	var walking: bool = room.visitor_phase in ["arriving", "leaving"]
	var movement := sin(_elapsed * (10.0 if walking else 1.35))
	position.y = anchor_position.y + absf(movement) * (0.009 if walking else 0.0014)
	rotation.z = movement * (0.008 if walking else 0.0025)
	scale.y = 1.0 + (0.0015 * movement if not walking else 0.0)
