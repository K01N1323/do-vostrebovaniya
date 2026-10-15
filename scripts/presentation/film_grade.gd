extends CanvasLayer
## Grade only the rendered room; all reading and menu controls are drawn later.

func _ready() -> void:
	layer = -1
	var pass_rect := ColorRect.new()
	pass_rect.name = "FilmPass"
	pass_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pass_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade := ShaderMaterial.new()
	grade.shader = preload("res://assets/shaders/film_grade.gdshader")
	pass_rect.material = grade
	add_child(pass_rect)
