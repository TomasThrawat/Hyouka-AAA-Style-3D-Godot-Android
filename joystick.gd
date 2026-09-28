extends Control

signal value_changed(value: Vector2)
signal released

@export var stick_radius := 82.0
@export var knob_radius := 32.0

var active_pointer := -1
var mouse_active := false
var stick_value := Vector2.ZERO
var contrast_applied := false

func _ready() -> void:
	custom_minimum_size = Vector2(228, 228)
	size = custom_minimum_size
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 26.0
	offset_right = 254.0
	offset_top = -250.0
	offset_bottom = -22.0
	position = Vector2.ZERO
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()
	call_deferred("_apply_contrast_and_control_layout")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	# High-contrast virtual stick designed to stay visible over dark gameplay.
	draw_circle(center, stick_radius + 14.0, Color(0.0, 0.0, 0.0, 0.72))
	draw_circle(center, stick_radius + 8.0, Color(0.04, 0.10, 0.15, 0.96))
	draw_circle(center, stick_radius, Color(0.07, 0.25, 0.35, 0.86))
	draw_arc(center, stick_radius + 1.0, 0.0, TAU, 64, Color(0.35, 0.92, 1.0, 0.99), 4.0)
	draw_arc(center, stick_radius - 11.0, 0.0, TAU, 64, Color(0.12, 0.57, 0.76, 0.86), 2.0)
	var tick_color := Color(0.78, 0.97, 1.0, 0.78)
	draw_line(center + Vector2(0, -58), center + Vector2(0, -44), tick_color, 4.0, true)
	draw_line(center + Vector2(58, 0), center + Vector2(44, 0), tick_color, 4.0, true)
	draw_line(center + Vector2(0, 58), center + Vector2(0, 44), tick_color, 4.0, true)
	draw_line(center + Vector2(-58, 0), center + Vector2(-44, 0), tick_color, 4.0, true)
	var knob_center := center + stick_value * stick_radius
	draw_circle(knob_center, knob_radius + 8.0, Color(0.0, 0.0, 0.0, 0.60))
	draw_circle(knob_center, knob_radius, Color(0.28, 0.86, 1.0, 0.99))
	draw_circle(knob_center - Vector2(9, 9), knob_radius * 0.27, Color(0.94, 1.0, 1.0, 0.94))

func _apply_contrast_and_control_layout() -> void:
	if contrast_applied:
		return
	contrast_applied = true
	var scene_root := get_tree().current_scene
	if scene_root:
		var ground := scene_root.get_node_or_null("World/Ground")
		if ground:
			_apply_dark_wood_floor(ground)
		var fire := _find_button(scene_root, "FIRE")
		var boost := _find_button(scene_root, "BOOST")
		if fire:
			_anchor_touch_button(fire, Vector2(-190, -238), Vector2(-28, -130), Color("#7d3048"), Color("#ff7fa1"))
		if boost:
			_anchor_touch_button(boost, Vector2(-190, -120), Vector2(-28, -52), Color("#1d6c8f"), Color("#68eaff"))

func _find_button(node: Node, wanted_text: String) -> Button:
	if node is Button and (node as Button).text == wanted_text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, wanted_text)
		if found:
			return found
	return null

func _anchor_touch_button(button: Button, top_left: Vector2, bottom_right: Vector2, fill_color: Color, border_color: Color) -> void:
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = top_left.x
	button.offset_right = bottom_right.x
	button.offset_top = top_left.y
	button.offset_bottom = bottom_right.y
	button.position = Vector2.ZERO
	button.size = Vector2(bottom_right.x - top_left.x, bottom_right.y - top_left.y)
	button.z_index = 100
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = fill_color if state != "pressed" else fill_color.lightened(0.14)
		style.bg_color.a = 0.92
		style.border_color = border_color
		style.set_border_width_all(3)
		style.corner_radius_top_left = 22
		style.corner_radius_top_right = 22
		style.corner_radius_bottom_left = 22
		style.corner_radius_bottom_right = 22
		style.shadow_color = Color(0, 0, 0, 0.64)
		style.shadow_size = 8
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, style)
	button.add_theme_font_size_override("font_size", 22 if button.text == "FIRE" else 18)
	button.add_theme_color_override("font_color", Color("#f6fcff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))

func _apply_dark_wood_floor(ground: Node) -> void:
	var floor := ground.get_node_or_null("Floor")
	if floor and floor is MeshInstance3D:
		var floor_mesh := floor as MeshInstance3D
		if floor_mesh.mesh is BoxMesh:
			var base := (floor_mesh.mesh as BoxMesh).material
			if base is StandardMaterial3D:
				var material := base.duplicate() as StandardMaterial3D
				material.albedo_color = Color("#1d130e")
				material.metallic = 0.0
				material.roughness = 0.94
				material.emission_enabled = true
				material.emission = Color("#120905")
				material.emission_energy_multiplier = 0.08
				(floor_mesh.mesh as BoxMesh).material = material

	var arena_size := 76.0
	var board_count := 6
	var board_width := (arena_size - 2.0) / float(board_count)
	for i in range(board_count):
		var board := MeshInstance3D.new()
		board.name = "WoodBoard_%02d" % i
		var box := BoxMesh.new()
		box.size = Vector3(board_width - 0.10, 0.06, arena_size - 2.0)
		var tone := Color("#2a1910") if i % 2 == 0 else Color("#23150e")
		box.material = _wood_material(tone)
		board.mesh = box
		board.position = Vector3(-arena_size * 0.5 + 1.0 + board_width * (float(i) + 0.5), 0.035, 0.0)
		ground.add_child(board)

	for i in range(board_count - 1):
		var seam := MeshInstance3D.new()
		seam.name = "WoodSeam_%02d" % i
		var seam_box := BoxMesh.new()
		seam_box.size = Vector3(0.05, 0.012, arena_size - 2.0)
		seam_box.material = _wood_material(Color("#090604"))
		seam.mesh = seam_box
		seam.position = Vector3(-arena_size * 0.5 + 1.0 + board_width * float(i + 1), 0.069, 0.0)
		ground.add_child(seam)

func _wood_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.94
	material.emission_enabled = true
	material.emission = Color("#100704")
	material.emission_energy_multiplier = 0.06
	return material

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_pointer == -1 and get_global_rect().has_point(event.position):
			active_pointer = event.index
			_set_value_from_screen(event.position)
			accept_event()
		elif not event.pressed and event.index == active_pointer:
			_reset_stick()
			accept_event()
	elif event is InputEventScreenDrag and event.index == active_pointer:
		_set_value_from_screen(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not mouse_active and get_global_rect().has_point(event.position):
			mouse_active = true
			_set_value_from_screen(event.position)
			accept_event()
		elif not event.pressed and mouse_active:
			mouse_active = false
			_reset_stick()
			accept_event()
	elif event is InputEventMouseMotion and mouse_active:
		_set_value_from_screen(event.position)
		accept_event()

func _set_value_from_screen(screen_position: Vector2) -> void:
	var local := screen_position - global_position
	var center := size * 0.5
	var offset := local - center
	if offset.length() > stick_radius:
		offset = offset.normalized() * stick_radius
	stick_value = offset / stick_radius
	if stick_value.length() < 0.12:
		stick_value = Vector2.ZERO
	queue_redraw()
	value_changed.emit(stick_value)

func _reset_stick() -> void:
	active_pointer = -1
	mouse_active = false
	stick_value = Vector2.ZERO
	queue_redraw()
	value_changed.emit(Vector2.ZERO)
	released.emit()
