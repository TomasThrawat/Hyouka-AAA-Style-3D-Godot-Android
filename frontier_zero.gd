extends Node3D

const PLAYER_SCENE = preload("res://aaa_player.gd")
const ENEMY_SCENE = preload("res://aaa_enemy.gd")
const PROJECTILE_SCENE = preload("res://aaa_projectile.gd")
const SAVE_SCENE = preload("res://save_system.gd")
const AUDIO_SCENE = preload("res://audio_manager.gd")
const JOYSTICK_SCENE = preload("res://joystick.gd")
const STATION_SCENE = preload("res://assets/orbital_field_station.glb")

const MAPS := ["NEON DISTRICT", "DUST BASIN", "FROZEN RELAY"]
const MAP_INFO := [
	"Orbital ruins // dense neon cover",
	"Industrial basin // long sight lines",
	"Frozen relay // exposed lanes"
]
const STAGES := ["NIGHTFALL", "SUNFALL", "WHITEOUT"]
const MAX_ENEMIES: int = 20
const MAX_PROJECTILES: int = 26

var player: CharacterBody3D
var camera: Camera3D
var world: Node3D
var environment_node: WorldEnvironment
var particles: GPUParticles3D
var save_system: Node
var audio_manager: Node

var enemies: Array[Node3D] = []
var projectiles: Array[Node3D] = []
var pickups: Array[Node3D] = []
var fx_nodes: Array[Node3D] = []
var touch_controls: Array[Control] = []
var map_buttons: Array[Button] = []

var stage: int = 1
var wave: int = 0
var score: int = 0
var best_score: int = 0
var selected_map: int = 0
var quality: int = 2
var running: bool = false
var game_over: bool = false
var boss_active: bool = false
var wave_timer: float = 1.0
var pickup_timer: float = 5.0
var message_timer: float = 0.0
var combo_timer: float = 0.0
var combo: int = 0
var fps_value: float = 60.0
var frame_ms: float = 16.7
var shake: float = 0.0
var camera_yaw: float = 0.0
var camera_pitch: float = -0.22
var touch_id: int = -1
var touch_last := Vector2.ZERO

var menu_panel: PanelContainer
var pause_panel: PanelContainer
var pause_button: Button
var resume_button: Button
var start_button: Button
var mission_info: Label
var stage_label: Label
var wave_label: Label
var score_label: Label
var objective_label: Label
var message_label: Label
var combo_label: Label
var profile_label: Label
var health_bar: ProgressBar
var energy_bar: ProgressBar
var boss_bar: ProgressBar
var ammo_label: Label
var status_label: Label
var flash: ColorRect
var touch_root: Control
var joystick: Control
var fire_button: Button
var boost_button: Button
var pulse_button: Button
var shield_button: Button
var reload_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(Time.get_ticks_msec())
	Engine.max_fps = 60
	save_system = SAVE_SCENE.new()
	add_child(save_system)
	save_system.load_state()
	best_score = int(save_system.best_score)
	audio_manager = AUDIO_SCENE.new()
	add_child(audio_manager)
	_build_environment()
	_build_world()
	_build_player()
	_build_camera()
	_build_ui()
	_show_menu()
	call_deferred("_fullscreen")

func _process(delta: float) -> void:
	fps_value = lerp(fps_value, 1.0 / max(delta, 0.0001), 0.08)
	frame_ms = 1000.0 / max(fps_value, 1.0)
	message_timer = max(0.0, message_timer - delta)
	combo_timer = max(0.0, combo_timer - delta)
	shake = max(0.0, shake - delta)
	if combo_timer <= 0.0:
		combo = 0

	if running and not game_over and not get_tree().paused:
		wave_timer -= delta
		pickup_timer -= delta
		_update_projectiles(delta)
		_update_pickups(delta)
		_update_camera(delta)
		_cleanup()
		if wave_timer <= 0.0:
			_start_wave()
		if pickup_timer <= 0.0:
			_spawn_pickup()
			pickup_timer = randf_range(5.0, 8.0)
		if wave >= 3 and enemies.is_empty() and not boss_active:
			_complete_stage()

	_update_hud()
	if message_timer <= 0.0 and not boss_active:
		message_label.text = ""

func _build_environment() -> void:
	environment_node = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#070a12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9bb7d6")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.03
	env.fog_enabled = true
	env.fog_light_color = Color("#566b83")
	env.fog_density = 0.005
	environment_node.environment = env
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 52.0
	add_child(sun)

func _build_world() -> void:
	if is_instance_valid(world):
		world.queue_free()

	world = Node3D.new()
	world.name = "World"
	add_child(world)

	var floor_color := Color("#111725")
	var accent := Color("#53d4ff")
	if selected_map == 1:
		floor_color = Color("#1b1510")
		accent = Color("#ffae62")
	elif selected_map == 2:
		floor_color = Color("#101923")
		accent = Color("#8de3ff")

	_make_box(Vector3(0, -0.45, 0), Vector3(82, 0.9, 82), floor_color)
	_make_box(Vector3(0, 2.8, -41), Vector3(82, 6, 0.7), Color("#10151f"))
	_make_box(Vector3(0, 2.8, 41), Vector3(82, 6, 0.7), Color("#10151f"))
	_make_box(Vector3(-41, 2.8, 0), Vector3(0.7, 6, 82), Color("#10151f"))
	_make_box(Vector3(41, 2.8, 0), Vector3(0.7, 6, 82), Color("#10151f"))

	for i in range(14):
		var angle: float = float(i) * TAU / 14.0
		var radius: float = 12.0 + float((i * 17) % 190) / 10.0
		_make_obstacle(Vector3(cos(angle) * radius, 0, sin(angle) * radius), 1.2 + float(i % 3) * 0.3, 2.6 + float(i % 4) * 0.8, accent)

	var points: Array[Vector3] = [
		Vector3(-27, 0, -27),
		Vector3(27, 0, -27),
		Vector3(-27, 0, 27),
		Vector3(27, 0, 27)
	]
	var station_count: int = 2 if selected_map == 1 else 4
	for i in range(station_count):
		var station := STATION_SCENE.instantiate()
		station.name = "Station_%02d" % i
		station.position = points[i]
		station.scale = Vector3.ONE * (0.80 + float(selected_map) * 0.08)
		world.add_child(station)

	for i in range(4):
		var light := OmniLight3D.new()
		light.position = [Vector3(-18, 6, -8), Vector3(18, 6, -8), Vector3(-20, 4, 18), Vector3(20, 4, 18)][i]
		light.light_color = accent if i % 2 == 0 else Color("#8e9bff")
		light.light_energy = 1.8
		light.omni_range = 10.0
		world.add_child(light)

	particles = GPUParticles3D.new()
	particles.name = "Atmosphere"
	particles.amount = 60
	particles.lifetime = 8.0
	particles.visibility_aabb = AABB(Vector3(-42, 0, -42), Vector3(84, 16, 84))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 24.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.40
	pm.scale_min = 0.02
	pm.scale_max = 0.05
	pm.color = Color(accent.r, accent.g, accent.b, 0.42)
	particles.process_material = pm
	var dust := SphereMesh.new()
	dust.radius = 0.035
	dust.height = 0.07
	dust.material = _material(accent, 0.15, accent, 1.1)
	particles.draw_pass_1 = dust
	world.add_child(particles)

func _make_box(position: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = position
	world.add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color, 0.82, Color("#4e6377"), 0.25)
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _make_obstacle(position: Vector3, radius: float, height: float, accent: Color) -> void:
	var body := StaticBody3D.new()
	body.position = position + Vector3.UP * height * 0.5
	world.add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.70
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = _material(Color("#283340"), 0.74, accent, 0.25)
	visual.mesh = mesh
	body.add_child(visual)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.74
	torus.outer_radius = radius * 0.82
	torus.material = _material(accent, 0.24, accent, 1.7)
	ring.mesh = torus
	ring.position.y = height * 0.46
	body.add_child(ring)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)

func _material(albedo: Color, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = 0.42
	mat.emission_enabled = energy > 0.0
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat

func _build_player() -> void:
	player = PLAYER_SCENE.new()
	player.name = "Player"
	player.position = Vector3(0, 0.15, 17)
	add_child(player)
	player.fire_requested.connect(_on_fire)
	player.boost_requested.connect(_on_boost)
	player.tactical_requested.connect(_on_pulse)
	player.shield_requested.connect(_on_shield)
	player.health_changed.connect(_on_health)
	player.energy_changed.connect(_on_energy)
	player.ammo_changed.connect(_on_ammo)
	player.died.connect(_on_dead)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "GameplayCamera"
	camera.current = true
	camera.fov = 62.0
	camera.position = Vector3(0, 7, 25)
	add_child(camera)
	camera.look_at(Vector3(0, 1, 5), Vector3.UP)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	var info := VBoxContainer.new()
	info.position = Vector2(18, 16)
	info.size = Vector2(470, 100)
	layer.add_child(info)
	stage_label = _label("SECTOR 01 / NIGHTFALL", 20)
	wave_label = _label("WAVE 00", 17)
	score_label = _label("SCORE 000000", 22)
	info.add_child(stage_label)
	info.add_child(wave_label)
	info.add_child(score_label)

	profile_label = _label("60 FPS | 16.7 ms | Q2", 14)
	profile_label.position = Vector2(1015, 16)
	profile_label.size = Vector2(245, 28)
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(profile_label)

	objective_label = _label("AWAITING DEPLOYMENT", 18)
	objective_label.position = Vector2(360, 25)
	objective_label.size = Vector2(560, 48)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(objective_label)

	message_label = _label("", 30)
	message_label.position = Vector2(280, 118)
	message_label.size = Vector2(720, 58)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(message_label)

	health_bar = _bar("HealthBar", Vector2(26, 602), Vector2(280, 24), layer)
	energy_bar = _bar("EnergyBar", Vector2(26, 636), Vector2(280, 16), layer)

	ammo_label = _label("AMMO 30 / 30", 23)
	ammo_label.position = Vector2(980, 602)
	ammo_label.size = Vector2(270, 40)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(ammo_label)

	status_label = _label("BOOST READY    PULSE READY    SHIELD READY", 12)
	status_label.position = Vector2(770, 636)
	status_label.size = Vector2(480, 22)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(status_label)

	combo_label = _label("COMBO x0", 17)
	combo_label.position = Vector2(25, 555)
	combo_label.size = Vector2(220, 28)
	layer.add_child(combo_label)

	var hp := _label("HULL INTEGRITY", 12)
	hp.position = Vector2(28, 577)
	hp.size = Vector2(200, 20)
	layer.add_child(hp)

	var ep := _label("ENERGY CORE", 11)
	ep.position = Vector2(28, 619)
	ep.size = Vector2(200, 18)
	layer.add_child(ep)

	boss_bar = ProgressBar.new()
	boss_bar.name = "BossHealth"
	boss_bar.max_value = 100.0
	boss_bar.value = 0.0
	boss_bar.show_percentage = false
	boss_bar.position = Vector2(300, 96)
	boss_bar.size = Vector2(680, 20)
	boss_bar.hide()
	layer.add_child(boss_bar)

	flash = ColorRect.new()
	flash.name = "ScreenFlash"
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate = Color(1, 1, 1, 0)
	flash.z_index = 400
	layer.add_child(flash)

	pause_button = _button("PAUSE", Vector2(86, 48), 17)
	pause_button.name = "PauseButton"
	pause_button.position = Vector2(1180, 55)
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_button.pressed.connect(_toggle_pause)
	layer.add_child(pause_button)

	menu_panel = PanelContainer.new()
	menu_panel.name = "MainMenu"
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.z_index = 500
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 8)
	menu_panel.add_child(menu)

	var title := _label("FRONTIER // ZERO", 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)

	var subtitle := _label("ECLIPSE PROTOCOL", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(subtitle)

	var desc := _label("THIRD-PERSON // SINGLE PLAYER // ANDROID", 12)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(desc)

	var select := _label("MISSION SELECT", 12)
	select.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(select)

	for i in range(MAPS.size()):
		var b := _button(MAPS[i], Vector2(420, 45), 17)
		b.name = "Mission_%02d" % (i + 1)
		b.pressed.connect(_select_map.bind(i))
		menu.add_child(b)
		map_buttons.append(b)

	mission_info = _label(MAP_INFO[0], 13)
	mission_info.custom_minimum_size = Vector2(620, 32)
	mission_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(mission_info)

	start_button = _button("DEPLOY", Vector2(300, 60), 23)
	start_button.name = "StartButton"
	start_button.pressed.connect(_start_game)
	menu.add_child(start_button)
	layer.add_child(menu_panel)

	pause_panel = PanelContainer.new()
	pause_panel.name = "PauseMenu"
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-220, -170)
	pause_panel.size = Vector2(440, 340)
	pause_panel.z_index = 350
	var pause_box := VBoxContainer.new()
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 12)
	pause_panel.add_child(pause_box)

	var paused_label := _label("PAUSED", 44)
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(paused_label)

	resume_button = _button("RESUME", Vector2(280, 54), 19)
	resume_button.name = "ResumeButton"
	resume_button.pressed.connect(_toggle_pause)
	pause_box.add_child(resume_button)

	var home := _button("MAIN MENU", Vector2(280, 52), 18)
	home.name = "MainMenuButton"
	home.pressed.connect(_show_menu)
	pause_box.add_child(home)
	layer.add_child(pause_panel)
	pause_panel.hide()

	_build_touch_controls()
	_set_touch_visible(false)

func _bar(name_value: String, pos: Vector2, size_value: Vector2, parent: CanvasLayer) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = name_value
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.position = pos
	bar.size = size_value
	parent.add_child(bar)
	return bar

func _button(value: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#121c28cc")
	normal.border_color = Color("#3d7394")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(12)
	var hover := normal.duplicate()
	hover.bg_color = Color("#20364acc")
	hover.border_color = Color("#61d9ff")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#3c6075dd")
	pressed.border_color = Color("#b8f2ff")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	return b

func _label(value: String, size: int) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#e7f6ff"))
	l.add_theme_color_override("font_shadow_color", Color("#000000cc"))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TouchControls"
	layer.layer = 20
	add_child(layer)

	touch_root = Control.new()
	touch_root.name = "TouchRoot"
	touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(touch_root)

	joystick = JOYSTICK_SCENE.new()
	joystick.name = "MoveJoystick"
	joystick.size = Vector2(220, 220)
	joystick.custom_minimum_size = Vector2(220, 220)
	touch_root.add_child(joystick)
	joystick.value_changed.connect(_on_joystick)
	joystick.released.connect(func() -> void: player.clear_move_input())
	touch_controls.append(joystick)

	fire_button = _button("FIRE", Vector2(170, 102), 22)
	fire_button.name = "FireButton"
	fire_button.button_down.connect(func() -> void: player.set_fire_input(true))
	fire_button.button_up.connect(func() -> void: player.set_fire_input(false))
	touch_root.add_child(fire_button)
	touch_controls.append(fire_button)

	boost_button = _button("BOOST", Vector2(150, 60), 17)
	boost_button.name = "BoostButton"
	boost_button.pressed.connect(_boost_pressed)
	touch_root.add_child(boost_button)
	touch_controls.append(boost_button)

	pulse_button = _button("PULSE", Vector2(150, 60), 17)
	pulse_button.name = "TacticalButton"
	pulse_button.pressed.connect(func() -> void: player.tactical())
	touch_root.add_child(pulse_button)
	touch_controls.append(pulse_button)

	shield_button = _button("SHIELD", Vector2(150, 60), 17)
	shield_button.name = "ShieldButton"
	shield_button.pressed.connect(func() -> void: player.shield())
	touch_root.add_child(shield_button)
	touch_controls.append(shield_button)

	reload_button = _button("RELOAD", Vector2(150, 52), 16)
	reload_button.name = "ReloadButton"
	reload_button.pressed.connect(func() -> void: player.reload())
	touch_root.add_child(reload_button)
	touch_controls.append(reload_button)

	get_viewport().size_changed.connect(_layout_touch)
	if pause_button.get_parent() != touch_root:
		pause_button.reparent(touch_root, true)
	pause_button.z_index = 1000
	_layout_touch()

func _layout_touch() -> void:
	var size := get_viewport().get_visible_rect().size
	joystick.position = Vector2(28, max(24.0, size.y - 252.0))
	fire_button.position = Vector2(max(24.0, size.x - 198.0), max(24.0, size.y - 238.0))
	reload_button.position = Vector2(max(24.0, size.x - 198.0), max(24.0, size.y - 120.0))
	boost_button.position = Vector2(max(24.0, size.x - 366.0), max(24.0, size.y - 118.0))
	pulse_button.position = Vector2(max(24.0, size.x - 366.0), max(24.0, size.y - 188.0))
	shield_button.position = Vector2(max(24.0, size.x - 366.0), max(24.0, size.y - 48.0))
	pause_button.position = Vector2(max(24.0, size.x - 100.0), 55.0)

func _set_touch_visible(value: bool) -> void:
	touch_root.visible = value
	touch_root.mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_IGNORE
	for control in touch_controls:
		if is_instance_valid(control):
			control.visible = value

func _select_map(index: int) -> void:
	if running:
		return
	selected_map = clamp(index, 0, MAPS.size() - 1)
	mission_info.text = MAP_INFO[selected_map]
	for i in range(map_buttons.size()):
		map_buttons[i].text = ("[ SELECTED ] " if i == selected_map else "") + MAPS[i]
	_rebuild_selected_world()

func _rebuild_selected_world() -> void:
	_build_world()
	if player:
		player.position = Vector3(0, 0.15, 17)

func _start_game() -> void:
	stage = 1
	wave = 0
	score = 0
	running = true
	game_over = false
	boss_active = false
	wave_timer = 0.8
	pickup_timer = 4.0
	get_tree().paused = false
	menu_panel.hide()
	pause_panel.hide()
	pause_button.show()
	_set_touch_visible(true)
	player.reset_for_run()
	player.position = Vector3(0, 0.15, 17)
	_clear_dynamic()
	objective_label.text = _objective()
	_set_message("SECTOR 01 // DEPLOY", 1.2)

func _show_menu() -> void:
	get_tree().paused = false
	running = false
	game_over = false
	boss_active = false
	_clear_dynamic()
	menu_panel.show()
	pause_panel.hide()
	pause_button.hide()
	_set_touch_visible(false)
	objective_label.text = "AWAITING DEPLOYMENT"
	message_label.text = ""

func _start_wave() -> void:
	wave += 1
	wave_timer = 15.0
	if stage == 3 and wave == 4:
		_spawn_enemy("heavy", 3.8, true)
		boss_active = true
		boss_bar.show()
		objective_label.text = "ELIMINATE WARDEN PRIME"
		_set_message("WARDEN PRIME // BOSS SIGNAL", 0.0)
		return
	if stage < 3 and wave > 3:
		return

	var count: int = min(MAX_ENEMIES, 3 + stage * 2 + wave * 2)
	var difficulty: float = 0.8 + stage * 0.45 + wave * 0.15
	for i in range(count):
		var roll: int = randi_range(0, 99)
		var kind: String = "scout"
		if stage >= 2 and roll < 35:
			kind = "striker"
		if stage >= 3 and roll < 18:
			kind = "heavy"
		_spawn_enemy(kind, difficulty, false)

	objective_label.text = "SURVIVE WAVE %02d" % wave
	_set_message("WAVE %02d // INBOUND" % wave, 0.9)

func _spawn_enemy(kind: String, difficulty: float, is_boss: bool) -> void:
	if enemies.size() >= MAX_ENEMIES and not is_boss:
		return
	var enemy: CharacterBody3D = ENEMY_SCENE.new()
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(24.0, 34.0)
	enemy.position = Vector3(cos(angle) * radius, 0.2, sin(angle) * radius)
	add_child(enemy)
	enemy.setup(player, difficulty, kind, is_boss)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.attack_requested.connect(_on_enemy_attack)
	enemy.health_changed.connect(_on_boss_health)
	enemies.append(enemy)

func _on_boss_health(current: float, maximum: float) -> void:
	if boss_active:
		boss_bar.max_value = maximum
		boss_bar.value = current

func _on_enemy_attack(origin: Vector3, direction: Vector3, damage: float) -> void:
	_spawn_projectile(origin, direction, false, damage, 11.0, 5.0, Color("#ff6f67"))

func _on_fire(origin: Vector3, direction: Vector3, damage: float) -> void:
	if running and not get_tree().paused:
		_spawn_projectile(origin, direction, true, damage, 34.0, 2.7, Color("#75ddff"))
		_muzzle(origin)

func _spawn_projectile(origin: Vector3, direction: Vector3, friendly: bool, damage: float, speed: float, life: float, tint: Color) -> void:
	if projectiles.size() >= MAX_PROJECTILES:
		var old: Node3D = projectiles.pop_front() as Node3D
		if is_instance_valid(old):
			old.queue_free()
	var shot: Node3D = PROJECTILE_SCENE.new() as Node3D
	add_child(shot)
	shot.setup(origin, direction, friendly, damage, speed, life, tint)
	projectiles.append(shot)

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Node3D = projectiles[i]
		if not is_instance_valid(shot):
			projectiles.remove_at(i)
			continue
		shot.advance(delta)
		if not shot.active:
			shot.queue_free()
			projectiles.remove_at(i)
			continue

		var removed: bool = false
		if shot.friendly:
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					if shot.global_position.distance_to(enemy.global_position + Vector3.UP * 0.85) <= shot.hit_radius:
						enemy.take_damage(shot.damage)
						score += 5
						_impact(shot.global_position, Color("#8be7ff"), 1.0)
						shot.queue_free()
						projectiles.remove_at(i)
						removed = true
						break
		elif is_instance_valid(player):
			if shot.global_position.distance_to(player.global_position + Vector3.UP * 0.8) <= shot.hit_radius:
				player.take_damage(shot.damage)
				_impact(shot.global_position, Color("#ff665e"), 1.2)
				shot.queue_free()
				projectiles.remove_at(i)
				removed = true

		if removed:
			continue
		if abs(shot.global_position.x) > 45.0 or abs(shot.global_position.z) > 45.0:
			shot.queue_free()
			projectiles.remove_at(i)

func _spawn_pickup() -> void:
	var pickup := Node3D.new()
	pickup.name = "EnergyCell"
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	sphere.material = _material(Color("#9be9ff"), 0.1, Color("#59d9ff"), 4.0)
	visual.mesh = sphere
	pickup.add_child(visual)
	pickup.position = Vector3(randf_range(-30.0, 30.0), 0.9, randf_range(-30.0, 30.0))
	world.add_child(pickup)
	pickups.append(pickup)

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup: Node3D = pickups[i]
		if not is_instance_valid(pickup):
			pickups.remove_at(i)
			continue
		pickup.rotation.y += delta * 2.6
		if player.global_position.distance_to(pickup.global_position) < 1.8:
			player.heal(14.0)
			player.restore_energy(30.0)
			score += 120
			_impact(pickup.global_position, Color("#74ddff"), 1.4)
			pickup.queue_free()
			pickups.remove_at(i)

func _on_enemy_defeated(enemy: Node3D, is_boss: bool) -> void:
	enemies.erase(enemy)
	combo += 1
	combo_timer = 4.0
	if is_boss:
		boss_active = false
		boss_bar.hide()
		score += 5000
		best_score = max(best_score, score)
		save_system.save_state(4, score, best_score)
		game_over = true
		running = false
		_set_touch_visible(false)
		pause_button.hide()
		_set_message("CAMPAIGN COMPLETE // %06d" % score, 4.0)
	else:
		score += 250 + stage * 75 + wave * 25 + combo * 20
		_impact(enemy.global_position + Vector3.UP, Color("#74d8ff"), 1.4)

func _complete_stage() -> void:
	if stage >= 3:
		return
	stage += 1
	wave = 0
	score += stage * 1000
	best_score = max(best_score, score)
	save_system.save_state(stage, score, best_score)
	_clear_dynamic()
	_build_world()
	player.position = _spawn_position()
	wave_timer = 0.8
	objective_label.text = _objective()
	_set_message("SECTOR %02d // ONLINE" % stage, 1.0)

func _spawn_position() -> Vector3:
	return Vector3(0, 0.15, 17) if stage != 2 else Vector3(0, 0.15, -17)

func _objective() -> String:
	return "CLEAR 3 WAVES // " + MAPS[selected_map]

func _on_boost() -> void:
	shake = max(shake, 0.08)
	_impact(player.global_position, Color("#72ddff"), 1.5)
	_set_message("BOOST // ENGAGED", 0.7)

func _boost_pressed() -> void:
	player.boost()

func _on_pulse(origin: Vector3, direction: Vector3) -> void:
	shake = max(shake, 0.22)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var distance: float = origin.distance_to(enemy.global_position)
			if distance <= 7.2:
				enemy.take_damage(95.0 - distance * 5.0)
	_impact(origin, Color("#68dcff"), 3.2)
	_flash(Color("#6ddcff"), 0.30)
	_set_message("PULSE // SHOCKWAVE", 0.9)

func _on_shield() -> void:
	_flash(Color("#6fa9ff"), 0.20)
	_set_message("SHIELD // ACTIVE", 0.9)

func _on_health(value: float) -> void:
	health_bar.value = value
	if value <= 30.0 and running:
		_flash(Color("#ff5e5e"), 0.16)

func _on_energy(value: float) -> void:
	energy_bar.value = value

func _on_ammo(current: int, capacity: int) -> void:
	ammo_label.text = "AMMO %02d / %02d" % [current, capacity]

func _on_dead() -> void:
	if game_over:
		return
	game_over = true
	running = false
	save_system.save_state(stage, score, max(best_score, score))
	_set_touch_visible(false)
	pause_button.hide()
	_set_message("MISSION FAILED // PROGRESS SAVED", 2.5)
	var tween := create_tween()
	tween.tween_interval(1.7)
	tween.tween_callback(_show_menu)

func _toggle_pause() -> void:
	if not running or game_over:
		return
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused
	_set_touch_visible(not get_tree().paused)

func _input(event: InputEvent) -> void:
	var position := Vector2.ZERO
	var pressed := false

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		position = mouse.position
		pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		position = touch.position
		pressed = touch.pressed

	if get_tree().paused:
		if pressed and resume_button.get_global_rect().has_point(position):
			_toggle_pause()
			get_viewport().set_input_as_handled()
		return

	if running and pressed and pause_button.visible and pause_button.get_global_rect().has_point(position):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if not running:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var size := get_viewport().get_visible_rect().size
		if touch.position.x > size.x * 0.45 and touch.position.y < size.y * 0.72:
			if touch.pressed:
				touch_id = touch.index
				touch_last = touch.position
			elif touch.index == touch_id:
				touch_id = -1
	elif event is InputEventScreenDrag and touch_id >= 0:
		var drag := event as InputEventScreenDrag
		if drag.index == touch_id:
			var d: Vector2 = drag.position - touch_last
			touch_last = drag.position
			camera_yaw -= d.x * 0.01
			camera_pitch = clamp(camera_pitch - d.y * 0.01, -0.60, -0.05)

func _update_camera(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var desired := player.global_position + Vector3(0, 6.7, 10) + Basis(Vector3.UP, camera_yaw) * Vector3(0, 0, 8.5)
	camera.global_position = camera.global_position.lerp(desired, min(1.0, delta * 7.0))
	camera.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	if shake > 0.0:
		camera.global_position += Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0)

func _on_joystick(value: Vector2) -> void:
	if is_instance_valid(player):
		player.set_move_input(value)

func _cleanup() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if not is_instance_valid(enemies[i]):
			enemies.remove_at(i)

func _clear_dynamic() -> void:
	if boss_bar:
		boss_bar.hide()
	for node in enemies:
		if is_instance_valid(node):
			node.queue_free()
	enemies.clear()
	for node in projectiles:
		if is_instance_valid(node):
			node.queue_free()
	projectiles.clear()
	for node in pickups:
		if is_instance_valid(node):
			node.queue_free()
	pickups.clear()
	for node in fx_nodes:
		if is_instance_valid(node):
			node.queue_free()
	fx_nodes.clear()

func _muzzle(position: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.22
	torus.material = _material(Color("#75ddff"), 0.08, Color("#75ddff"), 3.2)
	ring.mesh = torus
	ring.position = position
	add_child(ring)
	fx_nodes.append(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.3, 0.10)
	tween.tween_callback(func() -> void:
		fx_nodes.erase(ring)
		if is_instance_valid(ring):
			ring.queue_free()
	)

func _impact(position: Vector3, tint: Color, power: float) -> void:
	if quality == 0 and power < 2.0:
		return
	var fx := GPUParticles3D.new()
	fx.one_shot = true
	fx.amount = int(8 + power * 4)
	fx.lifetime = 0.3 + power * 0.04
	fx.explosiveness = 1.0
	fx.position = position
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0 * power
	pm.initial_velocity_max = 4.5 * power
	pm.scale_min = 0.025
	pm.scale_max = 0.08 * power
	pm.color = tint
	fx.process_material = pm
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.10
	mesh.material = _material(tint, 0.05, tint, 3.0)
	fx.draw_pass_1 = mesh
	add_child(fx)
	fx_nodes.append(fx)
	fx.finished.connect(_on_fx_finished.bind(fx), CONNECT_ONE_SHOT)
	fx.emitting = true

func _on_fx_finished(effect: GPUParticles3D):
	fx_nodes.erase(effect)
	if is_instance_valid(effect):
		effect.queue_free()

func _flash(tint: Color, alpha: float) -> void:
	flash.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", alpha, 0.04)
	tween.tween_property(flash, "modulate:a", 0.0, 0.20)

func _set_message(value: String, duration: float) -> void:
	message_label.text = value
	message_timer = duration

func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	var index: int = clamp(stage - 1, 0, STAGES.size() - 1)
	stage_label.text = "SECTOR %02d / %s" % [stage, STAGES[index]]
	wave_label.text = "WAVE %02d | THREATS %02d" % [wave, enemies.size()]
	score_label.text = "SCORE %06d" % score
	combo_label.text = "COMBO x%d" % combo
	var state: Dictionary = player.get_state()
	var reload_text: String = "RELOADING" if float(state["reloadTimer"]) > 0.0 else "RELOAD READY"
	var pulse_text: String = "PULSE %.1f" % float(state["pulseCooldown"]) if float(state["pulseCooldown"]) > 0.0 else "PULSE READY"
	var shield_text: String = "SHIELD %.1f" % float(state["shieldCooldown"]) if float(state["shieldCooldown"]) > 0.0 else "SHIELD READY"
	status_label.text = "%s    %s    %s" % [reload_text, pulse_text, shield_text]
	profile_label.text = "%02d FPS | %04.1f ms | Q%d" % [int(fps_value), frame_ms, quality]

func _fullscreen() -> void:
	if OS.has_environment("CI"):
		return
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func get_runtime_state() -> Dictionary:
	return {
		"running": running,
		"gameOver": game_over,
		"paused": get_tree().paused,
		"stage": stage,
		"wave": wave,
		"score": score,
		"bestScore": best_score,
		"bossActive": boss_active,
		"enemyCount": enemies.size(),
		"projectileCount": projectiles.size(),
		"quality": quality,
		"map": MAPS[selected_map],
		"player": player.get_state() if is_instance_valid(player) else {}
	}

func get_ui_state() -> Dictionary:
	var controls: Array[Dictionary] = []
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		var value: String = ""
		if control is Button:
			value = (control as Button).text
		elif control is Label:
			value = (control as Label).text
		if value != "" or control.name in ["MainMenu", "PauseMenu", "TouchRoot"]:
			var rect: Rect2 = control.get_global_rect()
			controls.append({
				"name": control.name,
				"text": value,
				"visible": control.visible,
				"disabled": control is Button and (control as Button).disabled,
				"x": rect.position.x,
				"y": rect.position.y,
				"width": rect.size.x,
				"height": rect.size.y
			})
	return {"paused": get_tree().paused, "running": running, "controls": controls}
