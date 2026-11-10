extends PanelContainer
## Native-resolution paper, independent from the scene's retro shader.

const INK := Color("272c27")

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

func compose(record: Dictionary, id: String, captions: Dictionary, shared_claim: bool, comparing: bool, typewriter: Font) -> void:
	var identity := id.ends_with("identity")
	if id == "identity" and not comparing and captions.get("identity_layout", "sheet") == "booklet":
		_identity_booklet(record, captions.portrait, typewriter)
		return
	grain_seed = 47 if identity else 13
	var stack := VBoxContainer.new()
	add_child(stack)
	var head := HBoxContainer.new()
	stack.add_child(head)
	var header: String = record.title if shared_claim or id in ["old_act", "card", "supplement", "supplement_draft", "clerk_identity"] else (captions.document_header if identity else "ФОРМА БН–" + captions.number)
	var title := _label(head,header,16,INK)
	title.add_theme_font_override("font",typewriter)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(head,"2014" if id in ["old_act", "card"] else "15 / X",14,Color("65644e"))
	_rule(stack)
	var sheet_body := HBoxContainer.new()
	sheet_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(sheet_body)
	if identity:
		var portrait_path: String = str(record.get("portrait", captions.portrait))
		var crop := Rect2(0.32, 0.025, 0.39, 0.29)
		match id:
			"clerk_identity": crop = Rect2(0, 0, 1, 1)
			"vera_identity": crop = Rect2(0.19, 0.035, 0.26, 0.22)
			"leonid_identity": crop = Rect2(0.52, 0.025, 0.26, 0.22)
		if record.has("portrait"):
			crop = Rect2(0, 0, 1, 1)
		sheet_body.add_child(_identity_photo(portrait_path, crop, Vector2(72, 92)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet_body.add_child(scroll)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := _text(scroll,record.text,18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color",INK)
	body.add_theme_font_override("normal_font",typewriter)
	var seal_text: String = "АРХИВ АВТОВОКЗАЛА" if id == "old_act" else ("БЮРО НАХОДОК  ·  ПРИНЯТО" if not identity else captions.identity_seal)
	match id:
		"card": seal_text = "КОПИРНЫЙ ЭКЗЕМПЛЯР"
		"clerk_identity": seal_text = "ДЕЙСТВИТЕЛЬНО НА СМЕНУ"
		"supplement": seal_text = "ПОДПИСАНО · П. ФОМИН"
		"supplement_draft": seal_text = "ПОДГОТОВЛЕНО К ПОДПИСИ"
	var seal := _label(stack,seal_text,12,Color("704f42"))
	seal.add_theme_font_override("font",typewriter)
	seal.rotation = -0.018

func _identity_booklet(record: Dictionary, portrait_path: String, typewriter: Font) -> void:
	booklet = true
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",24)
	add_child(columns)
	var portrait_column := VBoxContainer.new()
	portrait_column.custom_minimum_size.x = 138
	columns.add_child(portrait_column)
	_label(portrait_column,"АВТОВОКЗАЛ",14,INK).add_theme_font_override("font",typewriter)
	var backing := PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("8c8c7a")
	frame.border_color = Color("66705a")
	frame.set_border_width_all(1)
	frame.content_margin_left = 10
	frame.content_margin_right = 10
	frame.content_margin_top = 5
	frame.content_margin_bottom = 5
	backing.add_theme_stylebox_override("panel", frame)
	portrait_column.add_child(backing)
	var crop := Rect2(0, 0, 1, 1) if record.has("portrait") else Rect2(0.32, 0.025, 0.39, 0.29)
	backing.add_child(_identity_photo(record.get("portrait", portrait_path), crop, Vector2(118, 150)))
	_label(portrait_column,"ТАБЕЛЬНЫЙ
№ 047",16,INK).add_theme_font_override("font",typewriter)
	var seal := _label(portrait_column,"ХОЗ. СЛУЖБА
• АВТОВОКЗАЛ •",12,Color("73564b"))
	seal.rotation = -0.035
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	_label(right,"УДОСТОВЕРЕНИЕ",17,INK).add_theme_font_override("font",typewriter)
	_rule(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var body := _text(scroll,record.text,16,INK)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_override("normal_font",typewriter)

func _identity_photo(path: String, crop: Rect2, size_hint: Vector2) -> TextureRect:
	var photo := TextureRect.new()
	photo.name = "IdentityPhoto"
	var source := load(path) as Texture2D
	if source != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(crop.position * source.get_size(), crop.size * source.get_size())
		photo.texture = atlas
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	photo.custom_minimum_size = size_hint
	photo.modulate = Color("d6d0b7")
	return photo

func _label(parent: Node, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _text(parent: Node, text_value: String, font_size: int, color: Color = INK) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.text = text_value
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _rule(parent: Node) -> void:
	var separator := HSeparator.new()
	separator.custom_minimum_size.y = 2
	var stroke := StyleBoxLine.new()
	stroke.color = Color(0.51, 0.54, 0.44, 0.38)
	stroke.thickness = 1
	separator.add_theme_stylebox_override("separator", stroke)
	parent.add_child(separator)
