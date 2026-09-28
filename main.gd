extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")
const HAZARD_SCRIPT = preload("res://hazard_drone.gd")

var player: CharacterBody3D
var camera: Camera3D
var arena_size := 42.0
var rng := RandomNumberGenerator.new()
var hazards: Array[Node3D] = []
var pickups: Array[Node3D] = []
var wave := 0
var score := 0
var running := false
var game_over := false
var wave_timer := 0.0
var pickup_timer := 0.0
var elapsed := 0.0

var score_label: Label
var wave_label: Label
var health_bar: ProgressBar
var message_label: Label
var menu_panel: PanelContainer
var pause_button: Button
var boost_button: Button
var touch_buttons: Array[Button] = []

func _ready() -> void:
	rng.randomize()
	_build_environment()
	_build_arena()
	_create_player()
	_create_camera()
	_build_ui()
	_show_menu()

func _process(delta: float) -> void:
	elapsed += delta
	if running and not game_over and not get_tree().paused:
		wave_timer -= delta
		pickup_timer -= delta
		_update_pickups(delta)
		_update_camera(delta)
		if wave_timer <= 0.0:
			_start_wave()
		if pickup_timer <= 0.0:
			_spawn_pickup()
			pickup_timer = rng.randf_range(4.0, 7.0)
	_update_hud()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#050914")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#5e74b8")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color("#a5caff")
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 8, 0)
	fill.light_color = Color("#33d6ff")
	fill.light_energy = 2.4
	fill.omni_range = 28.0
	add_child(fill)

func _build_arena() -> void:
	var ground := StaticBody3D.new()
	add_child(ground)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(arena_size, 0.8, arena_size)
	box.material = _mat(Color("#0b1422"), 0.25, 0.6, Color("#0b3150"), 0.6)
	mesh.mesh = box
	mesh.position.y = -0.4
	ground.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(arena_size, 0.8, arena_size)
	collider.shape = shape
	collider.position.y = -0.4
	ground.add_child(collider)

	for side in [-1.0, 1.0]:
		_create_wall(Vector3(side * arena_size * 0.5, 2.0, 0.0), Vector3(0.6, 4.0, arena_size))
		_create_wall(Vector3(0.0, 2.0, side * arena_size * 0.5), Vector3(arena_size, 4.0, 0.6))

	for i in range(22):
		var x := rng.randf_range(-arena_size * 0.42, arena_size * 0.42)
		var z := rng.randf_range(-arena_size * 0.42, arena_size * 0.42)
		if Vector2(x, z).length() < 7.0:
			continue
		_create_obstacle(Vector3(x, 0.0, z), rng.randf_range(1.2, 2.7), rng.randf_range(1.4, 4.0))

	for i in range(30):
		_create_neon_marker(Vector3(rng.randf_range(-19.0, 19.0), 0.02, rng.randf_range(-19.0, 19.0)))

func _create_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _mat(Color("#111b2c"), 0.3, 0.55, Color("#143d59"), 0.55)
	mesh.mesh = box
	body.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

func _create_obstacle(pos: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3.UP * (height * 0.5)
	add_child(body)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.72
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.material = _mat(Color("#1c2c42"), 0.35, 0.42, Color("#314b72"), 0.7)
	mesh.mesh = cyl
	body.add_child(mesh)
	var ring := OmniLight3D.new()
	ring.light_color = Color("#5b74ff")
	ring.light_energy = 1.4
	ring.omni_range = radius * 4.0
	ring.position.y = height * 0.2
	body.add_child(ring)
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collider.shape = shape
	body.add_child(collider)

func _create_neon_marker(pos: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.035, 1.2)
	box.material = _mat(Color("#31bfff"), 0.05, 0.15, Color("#31bfff"), 2.4)
	marker.mesh = box
	marker.position = pos
	add_child(marker)

func _create_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.position = Vector3(0, 0.1, 8)
	add_child(player)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)

	var trail := GPUParticles3D.new()
	trail.amount = 80
	trail.lifetime = 0.65
	trail.emitting = true
	trail.position = Vector3(0, 0.45, 0.8)
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, 0, 1)
	process_material.spread = 15.0
	process_material.initial_velocity_min = 0.5
	process_material.initial_velocity_max = 1.3
	process_material.scale_min = 0.035
	process_material.scale_max = 0.08
	process_material.color = Color("#4ceaff")
	trail.process_material = process_material
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.045
	particle_mesh.height = 0.09
	particle_mesh.material = _mat(Color("#4ceaff"), 0.0, 0.15, Color("#4ceaff"), 3.0)
	trail.draw_pass_1 = particle_mesh
	player.add_child(trail)
	player.boost_requested.connect(_on_boost)

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	camera.global_position = Vector3(0, 8.2, 14.0)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	layer.add_child(margin)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 14)
	margin.add_child(top)

	score_label = _label("SCORE 000000", 24)
	wave_label = _label("WAVE 00", 24)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(230, 28)
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	top.add_child(score_label)
	top.add_child(wave_label)
	top.add_child(health_bar)

	pause_button = _button("Ⅱ", Vector2(64, 48))
	pause_button.position = Vector2(20, 110)
	pause_button.pressed.connect(_toggle_pause)
	layer.add_child(pause_button)

	var crosshair := Label.new()
	crosshair.text = "✦"
	crosshair.add_theme_font_size_override("font_size", 34)
	crosshair.modulate = Color("#87edff")
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-18, -30)
	layer.add_child(crosshair)

	message_label = _label("", 22)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-250, 90)
	message_label.size = Vector2(500, 80)
	layer.add_child(message_label)

	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var menu_box := VBoxContainer.new()
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 18)
	menu_panel.add_child(menu_box)

	var title := _label("NEON FRONTIER", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(title)
	var subtitle := _label("Procedural 3D survival prototype", 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(subtitle)
	var start := _button("START RUN", Vector2(260, 60))
	start.pressed.connect(_start_game)
	menu_box.add_child(start)
	var rules := _label("Move: arrows / touch    •    Boost: Shift / BOOST", 16)
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(rules)
	layer.add_child(menu_panel)

	_create_touch_controls(layer)

func _create_touch_controls(layer: CanvasLayer) -> void:
	left_button = _button("◀", Vector2(70, 70))
	right_button = _button("▶", Vector2(70, 70))
	up_button = _button("▲", Vector2(70, 70))
	down_button = _button("▼", Vector2(70, 70))
	boost_button = _button("BOOST", Vector2(110, 82))
	left_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	right_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	up_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	down_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	boost_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	left_button.position = Vector2(24, -110)
	down_button.position = Vector2(102, -32)
	up_button.position = Vector2(102, -188)
	right_button.position = Vector2(180, -110)
	boost_button.position = Vector2(-134, -110)
	for b in [left_button, down_button, up_button, right_button, boost_button]:
		layer.add_child(b)
		touch_buttons.append(b)
	left_button.button_down.connect(func(): player.set_move_input(Vector2(-1, 0)))
	right_button.button_down.connect(func(): player.set_move_input(Vector2(1, 0)))
	up_button.button_down.connect(func(): player.set_move_input(Vector2(0, -1)))
	down_button.button_down.connect(func(): player.set_move_input(Vector2(0, 1)))
	for b in [left_button, right_button, up_button, down_button]:
		b.button_up.connect(func(): player.clear_move_input())
	boost_button.pressed.connect(_boost_pressed)

func _boost_pressed() -> void:
	if running and not game_over and not get_tree().paused and player:
		player.boost()

func _start_game() -> void:
	menu_panel.hide()
	running = true
	game_over = false
	get_tree().paused = false
	wave = 0
	score = 0
	player.health = player.max_health
	player.position = Vector3(0, 0.1, 8)
	for e in hazards:
		if is_instance_valid(e):
			e.queue_free()
	hazards.clear()
	for p in pickups:
		if is_instance_valid(p):
			p.queue_free()
	pickups.clear()
	wave_timer = 0.1
	message_label.text = "SURVIVE THE HAZARDS"
	_update_hud()

func _show_menu() -> void:
	running = false
	game_over = false
	menu_panel.show()
	pause_button.hide()
	for b in touch_buttons:
		b.hide()
	message_label.text = ""

func _start_wave() -> void:
	wave += 1
	wave_timer = 20.0
	var count := min(18, 3 + wave * 2)
	for i in range(count):
		_spawn_hazard(1.0 + wave * 0.3)
	message_label.text = "WAVE %d" % wave
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_callback(func(): if running and not game_over: message_label.text = "")

func _spawn_hazard(difficulty: float) -> void:
	var drone := HAZARD_SCRIPT.new()
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(15.0, 19.0)
	drone.position = Vector3(cos(angle) * distance, 0.1, sin(angle) * distance)
	add_child(drone)
	drone.setup(player, difficulty)
	drone.defeated.connect(_on_hazard_removed)
	hazards.append(drone)

func _spawn_pickup() -> void:
	var orb := Area3D.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	sphere.material = _mat(Color("#3effd0"), 0.05, 0.1, Color("#2effd1"), 3.2)
	mesh.mesh = sphere
	orb.add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color("#2effd1")
	light.light_energy = 2.8
	light.omni_range = 4.0
	orb.add_child(light)
	orb.position = Vector3(rng.randf_range(-16.0, 16.0), 0.75, rng.randf_range(-16.0, 16.0))
	add_child(orb)
	pickups.append(orb)

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var p := pickups[i]
		if not is_instance_valid(p):
			pickups.remove_at(i)
			continue
		p.rotation.y += delta * 2.8
		p.position.y = 0.75 + sin(elapsed * 4.0 + float(i)) * 0.14
		if player.global_position.distance_to(p.global_position) < 1.6:
			score += 75
			player.heal(10.0)
			p.queue_free()
			pickups.remove_at(i)

func _update_camera(delta: float) -> void:
	if not player or not camera:
		return
	var desired := player.global_position + Vector3(0, 7.2, 10.5)
	camera.global_position = camera.global_position.lerp(desired, min(1.0, delta * 4.0))
	camera.look_at(player.global_position + Vector3(0, 0.7, -1.4), Vector3.UP)

func _on_boost() -> void:
	message_label.text = "BOOST!"
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func(): if running and not game_over: message_label.text = "")

func _on_hazard_removed(drone: Node3D) -> void:
	score += 120 + wave * 15
	hazards.erase(drone)

func _update_hud() -> void:
	if score_label:
		score_label.text = "SCORE %06d" % score
	if wave_label:
		wave_label.text = "WAVE %02d" % wave
	if pause_button:
		pause_button.visible = running and not game_over
	if running and not game_over:
		for b in touch_buttons:
			b.show()
	if health_bar:
		health_bar.value = player.health if player else 100.0

func _on_player_health_changed(value: float) -> void:
	if health_bar:
		health_bar.value = value
	if value <= 30.0 and running:
		message_label.text = "LOW ENERGY"
	elif running:
		message_label.text = ""

func _on_player_died() -> void:
	game_over = true
	running = false
	message_label.text = "RUN ENDED  •  SCORE %06d" % score
	for b in touch_buttons:
		b.hide()
	pause_button.hide()

func _toggle_pause() -> void:
	if not running or game_over:
		return
	get_tree().paused = not get_tree().paused
	message_label.text = "PAUSED" if get_tree().paused else ""

func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#eaf7ff"))
	return label

func _button(text_value: String, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", 20)
	return b

func _mat(color: Color, metallic: float, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
