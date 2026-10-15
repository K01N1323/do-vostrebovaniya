extends PanelContainer
## Native-resolution paper, independent from the scene's retro shader.

@export var paper_color := Color("d5c9a6")
@export var grain_seed: int = 47
@export var booklet := false

func _ready() -> void:
	var blank := StyleBoxEmpty.new()
	blank.content_margin_left = 22
	blank.content_margin_right = 22
	blank.content_margin_top = 20
	blank.content_margin_bottom = 20
	add_theme_stylebox_override("panel",blank)
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 4 or size.y < 4:
		return
	if booklet:
		draw_rect(Rect2(Vector2.ZERO,size),Color("494234"))
		draw_rect(Rect2(Vector2(5,5),size-Vector2(10,10)),paper_color)
		for i in range(7):
			draw_line(Vector2(167+i,8),Vector2(167+i,size.y-8),Color(0.21,0.19,0.13,0.15-float(i)*0.018),1)
	var outline := PackedVector2Array([Vector2(3,2),Vector2(size.x-17,0),Vector2(size.x,17),Vector2(size.x-2,size.y-5),Vector2(10,size.y),Vector2(0,size.y-11)])
	if not booklet:
		draw_colored_polygon(outline,paper_color)
	draw_polyline(PackedVector2Array([Vector2(size.x-17,0),Vector2(size.x-17,17),Vector2(size.x,17)]),Color("9c977b"),1)
	draw_line(Vector2(10,7),Vector2(size.x-25,7),Color(0.3,0.29,0.22,0.15),1)
	var rng := RandomNumberGenerator.new()
	rng.seed = grain_seed
	for i in range(180):
		var at := Vector2(rng.randf_range(8,size.x-8),rng.randf_range(9,size.y-9))
		draw_line(at,at+Vector2(rng.randf_range(1,7),rng.randf_range(-0.6,0.6)),Color(0.25,0.23,0.15,rng.randf_range(0.025,0.095)),1)
	for x in [4.0,size.x-5]:
		draw_line(Vector2(x,22),Vector2(x,size.y-16),Color(0.2,0.19,0.13,0.12),2)
