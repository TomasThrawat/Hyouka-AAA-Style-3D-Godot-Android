extends Node3D
class_name FrontierZero

const PLAYER_SCRIPT = preload("res://aaa_player.gd")
const ENEMY_SCRIPT = preload("res://aaa_enemy.gd")
const PROJECTILE_SCRIPT = preload("res://aaa_projectile.gd")
const SAVE_SCRIPT = preload("res://save_system.gd")
const AUDIO_SCRIPT = preload("res://audio_manager.gd")
const JOYSTICK_SCRIPT = preload("res://joystick.gd")
const STATION_SCENE = preload("res://assets/orbital_field_station.glb")

const MAP_NAMES := ["NEON DISTRICT", "DUST BASIN", "FROZEN RELAY"]
const MAP_DESCRIPTIONS := [
	"Orbital megacity ruins. Dense lanes and elevated industrial cover.",
	"Industrial desert basin. Long sightlines and thermal haze.",
	"Arctic relay complex. Exposed lanes and high-contrast lighting."
]
const STAGE_NAMES := ["NIGHTFALL", "SUNFALL", "WHITEOUT"]
const MAX_ENEMIES := 22
const MAX_PROJECTILES := 28

var player: CharacterBody3D
var camera: Camera3D
var environment_node: WorldEnvironment
var arena_root: Node3D
var atmosphere: GPUParticles3D
var audio_manager: Node
var save_system: Node
var rng := RandomNumberGenerator.new()

var enemies: Array[Node3D] = []
var projectiles: Array[Node3D] = []
var pickups: Array[Node3D] = []
var fx_nodes: Array[Node3D] = []

var stage: int = 1
var wave: int = 0
var score: int = 0
var best_score: int = 0
var selected_map: int = 0
var quality_level: int = 2
var running: bool = false
var game_over: bool = false
var boss_active: bool = false
var transition_lock: bool = false

var elapsed: float = 0.0
var wave_timer: float = 1.4
var pickup_timer: float = 5.0
var message_timer: float = 0.0
var combo_timer: float = 0.0
var combo_count: int = 0
var hud_timer: float = 0.0
var camera_shake: float = 0.0
var fps_value: float = 60.0
var frame_ms: float = 16.7
var camera_yaw: float = 0.0
var camera_pitch: float = -0.22
var camera_touch_id: int = -1
var camera_touch_last := Vector2.ZERO

var menu_panel: PanelContainer
var pause_panel: PanelContainer
var pause_button: Button
var start_button: Button
var map_info_label: Label
var map_buttons: Array[Button] = []
var stage_label: Label
var wave_label: Label
var score_label: Label
var objective_label: Label
var message_label: Label
var health_bar: ProgressBar
var energy_bar: ProgressBar
var boss_bar: ProgressBar
var ammo_label: Label
var cooldown_label: Label
var profile_label: Label
var combo_label: Label
var screen_flash: ColorRect
var touch_root: Control
var joystick: Control
var fire_button: Button
var boost_button: Button
var tactical_button: Button
var shield_button: Button
var reload_button: Button

func _ready() -> void:
	rng.randomize()
	Engine.max_fps = 60
	save_system = SAVE_SCRIPT.new()
	add_child(save_system)
	save_system.load_state()
	best_score = int(save_system.best_score)
	audio_manager = AUDIO_SCRIPT.new()
	add_child(audio_manager)
	_build_environment()
	_build_arena(selected_map)
	_create_player()
	_create_camera()
	_build_ui()
	_show_menu()
	call_deferred("_force_fullscreen")

func _process(delta: float) -> void:
	elapsed += delta
	message_timer = max(0.0, message_timer - delta)
	combo_timer = max(0.0, combo_timer - delta)
	hud_timer -= delta
	camera_shake = max(0.0, camera_shake - delta)
	if combo_timer <= 0.0:
		combo_count = 0
	_update_performance(delta)

	if running and not game_over and not get_tree().paused:
		wave_timer -= delta
		pickup_timer -= delta
		_update_projectiles(delta)
		_update_pickups(delta)
		_update_camera(delta)
		_cleanup_enemies()
		if wave_timer <= 0.0 and not transition_lock:
			_start_next_wave()
		if pickup_timer <= 0.0:
			_spawn_pickup()
			pickup_timer = rng.randf_range(5.0, 8.0)
		_check_progression()

	if hud_timer <= 0.0:
		hud_timer = 0.10
		_update_hud()
	if message_timer <= 0.0 and not boss_active:
		message_label.text = ""

func _build_environment() -> void:
	environment_node = WorldEnvironment.new()
	environment_node.name = "WorldEnvironment"
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
	env.fog_light_energy = 0.50
	env.fog_density = 0.005
	environment_node.environment = env
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)

func _build_arena(map_id: int) -> void:
	if is_instance_valid(arena_root):
		arena_root.queue_free()
	arena_root = null
	arena_root = Node3D.new()
	arena_root.name = "World"
	add_child(arena_root)

	var floor_color := Color("#111725")
	var accent := Color("#53d4ff")
	if map_id == 1:
		floor_color = Color("#1b1510")
		accent = Color("#ffae62")
	elif map_id == 2:
		floor_color = Color("#101923")
		accent = Color("#8de3ff")

	_box(Vector3(0, -0.45, 0), Vector3(82, 0.9, 82), floor_color)
	_box(Vector3(0, 2.8, -41), Vector3(82, 6, 0.7), Color("#10151f"))
	_box(Vector3(0, 2.8, 41), Vector3(82, 6, 0.7), Color("#10151f"))
	_box(Vector3(-41, 2.8, 0), Vector3(0.7, 6, 82), Color("#10151f"))
	_box(Vector3(41, 2.8, 0), Vector3(0.7, 6, 82), Color("#10151f"))

	if map_id == 0:
		for i in range(22):
			var angle: float = float(i) * TAU / 22.0 + rng.randf_range(-0.06, 0.06)
			var radius: float = rng.randf_range(10.0, 33.0)
			_obstacle(Vector3(cos(angle) * radius, 0, sin(angle) * radius), rng.randf_range(1.0, 2.5), rng.randf_range(2.0, 7.0), accent)
	elif map_id == 1:
		for row in range(5):
			for col in range(8):
				var p := Vector3((col - 3.5) * 8.0, 0, (row - 2.0) * 8.5)
				if p.length() > 10.0:
					_obstacle(p, 1.5, 2.8 + float((row + col) % 4) * 0.6, accent)
	else:
		for i in range(18):
			var p := Vector3((i % 6 - 2.5) * 8.6, 0, (i / 6 - 1.0) * 11.0)
			if p.length() > 9.0:
				_obstacle(p, 1.15, 3.2 + float(i % 3) * 1.1, accent)

	for i in range(4 if map_id != 1 else 2):
		var landmark := STATION_SCENE.instantiate()
		landmark.name = "Station_%02d" % i
		landmark.position = [Vector3(-27, 0, -27), Vector3(27, 0, -27), Vector3(-27, 0, 27), Vector3(27, 0, 27)][i]
		landmark.scale = Vector3.ONE * (0.82 + map_id * 0.10)
		landmark.rotation.y = float(i) * 0.55
		arena_root.add_child(landmark)

	for side in [-1.0, 1.0]:
		for i in range(3):
			var beacon := MeshInstance3D.new()
			var beam := CylinderMesh.new()
			beam.height = 5.0 + i * 1.4
			beam.top_radius = 0.10
			beam.bottom_radius = 0.12
			beam.material = _material(accent, 0.2, accent, 2.2)
			beacon.mesh = beam
			beacon.position = Vector3(side * 34.0, beam.height * 0.5, -22.0 + i * 11.0)
			arena_root.add_child(beacon)

	for i in range(6):
		var light := OmniLight3D.new()
		light.position = [Vector3(-18, 6, -8), Vector3(18, 6, -8), Vector3(-20, 4, 18), Vector3(20, 4, 18), Vector3(0, 5, -30), Vector3(0, 5, 30)][i]
		light.light_color = accent if i % 2 == 0 else Color("#8e9bff")
		light.light_energy = 2.0
		light.omni_range = 11.0
		arena_root.add_child(light)

	atmosphere = GPUParticles3D.new()
	atmosphere.name = "Atmosphere"
	atmosphere.amount = 90
	atmosphere.lifetime = 8.0
	atmosphere.randomness = 0.65
	atmosphere.visibility_aabb = AABB(Vector3(-42, 0, -42), Vector3(84, 16, 84))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 24.0
	pm.initial_velocity_min = 0.10
	pm.initial_velocity_max = 0.45
	pm.scale_min = 0.02
	pm.scale_max = 0.06
	pm.color = Color(accent.r, accent.g, accent.b, 0.45)
	atmosphere.process_material = pm
	var dust := SphereMesh.new()
	dust.radius = 0.035
	dust.height = 0.07
	dust.material = _material(accent, 0.15, accent, 1.2)
	atmosphere.draw_pass_1 = dust
	arena_root.add_child(atmosphere)

func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	arena_root.add_child(body)
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

func _obstacle(pos: Vector3, radius: float, height: float, accent: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3.UP * height * 0.5
	arena_root.add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.70
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = _material(Color("#283340"), 0.74, accent, 0.28)
	visual.mesh = mesh
	body.add_child(visual)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.74
	torus.outer_radius = radius * 0.82
	torus.material = _material(accent, 0.24, accent, 1.8)
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
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = 0.42
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _create_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.position = _spawn_position()
	add_child(player)
	player.fire_requested.connect(_on_player_fire)
	player.boost_requested.connect(_on_player_boost)
	player.tactical_requested.connect(_on_player_tactical)
	player.shield_requested.connect(_on_player_shield)
	player.health_changed.connect(_on_player_health)
	player.energy_changed.connect(_on_player_energy)
	player.ammo_changed.connect(_on_ammo)
	player.died.connect(_on_player_died)

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "GameplayCamera"
	camera.current = true
	camera.fov = 62.0
	camera.position = Vector3(0, 7.0, 25.0)
	add_child(camera)
	camera.look_at(Vector3(0, 1.1, 5.0), Vector3.UP)

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

	profile_label = _label("60 FPS | 16.7 ms | Q3", 14)
	profile_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	profile_label.position = Vector2(-280, 16)
	profile_label.size = Vector2(260, 28)
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(profile_label)

	objective_label = _label("AWAITING DEPLOYMENT", 18)
	objective_label.position = Vector2(360, 25)
	objective_label.size = Vector2(560, 48)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(objective_label)

	message_label = _label("", 30)
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-360, 118)
	message_label.size = Vector2(720, 58)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(message_label)

	health_bar = _bar("HealthBar", 26, -118, 280, 24)
	energy_bar = _bar("EnergyBar", 26, -84, 280, 16)
	var hp := _label("HULL INTEGRITY", 12)
	hp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp.position = Vector2(28, -143)
	hp.size = Vector2(200, 20)
	layer.add_child(hp)
	var en := _label("ENERGY CORE", 11)
	en.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	en.position = Vector2(28, -106)
	en.size = Vector2(200, 18)
	layer.add_child(en)

	ammo_label = _label("AMMO 30 / 30", 23)
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.position = Vector2(-292, -108)
	ammo_label.size = Vector2(260, 40)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(ammo_label)

	cooldown_label = _label("BOOST READY    PULSE READY    SHIELD READY", 12)
	cooldown_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cooldown_label.position = Vector2(-480, -78)
	cooldown_label.size = Vector2(448, 22)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(cooldown_label)

	combo_label = _label("COMBO x0", 17)
	combo_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	combo_label.position = Vector2(25, -177)
	combo_label.size = Vector2(220, 28)
	layer.add_child(combo_label)

	boss_bar = ProgressBar.new()
	boss_bar.name = "BossHealth"
	boss_bar.max_value = 100
	boss_bar.value = 0
	boss_bar.show_percentage = false
	boss_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_bar.position = Vector2(300, 96)
	boss_bar.size = Vector2(680, 20)
	boss_bar.hide()
	layer.add_child(boss_bar)

	screen_flash = ColorRect.new()
	screen_flash.name = "ScreenFlash"
	screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.modulate = Color(1, 1, 1, 0)
	layer.add_child(screen_flash)

	pause_button = _button("PAUSE", Vector2(86, 48), 17)
	pause_button.name = "PauseButton"
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-108, 55)
	pause_button.pressed.connect(_toggle_pause)
	layer.add_child(pause_button)

	menu_panel = PanelContainer.new()
	menu_panel.name = "MainMenu"
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.z_index = 200
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 9)
	menu_panel.add_child(menu)
	var brand := _label("HYOKUA // SYSTEM 7", 14)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(brand)
	var title := _label("FRONTIER // ZERO", 62)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)
	var subtitle := _label("ECLIPSE PROTOCOL", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(subtitle)
	var meta := _label("TACTICAL THIRD-PERSON // SINGLE PLAYER // ANDROID", 12)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(meta)
	var mission := _label("MISSION SELECT", 12)
	mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(mission)

	for i in range(MAP_NAMES.size()):
		var map_button := _button(MAP_NAMES[i], Vector2(420, 45), 17)
		map_button.name = "Mission_%02d" % (i + 1)
		map_button.pressed.connect(_select_map.bind(i))
		menu.add_child(map_button)
		map_buttons.append(map_button)

	map_info_label = _label(MAP_DESCRIPTIONS[0], 13)
	map_info_label.custom_minimum_size = Vector2(620, 32)
	map_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(map_info_label)

	start_button = _button("DEPLOY", Vector2(300, 60), 23)
	start_button.name = "StartButton"
	start_button.pressed.connect(_start_game_pressed)
	menu.add_child(start_button)
	layer.add_child(menu_panel)

	pause_panel = PanelContainer.new()
	pause_panel.name = "PauseMenu"
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-220, -170)
	pause_panel.size = Vector2(440, 340)
	pause_panel.z_index = 150
	var pause_box := VBoxContainer.new()
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 12)
	pause_panel.add_child(pause_box)
	var paused_title := _label("PAUSED", 44)
	paused_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(paused_title)
	var resume := _button("RESUME", Vector2(280, 54), 19)
	resume.name = "ResumeButton"
	resume.pressed.connect(_toggle_pause)
	pause_box.add_child(resume)
	var home := _button("MAIN MENU", Vector2(280, 52), 18)
	home.name = "MainMenuButton"
	home.pressed.connect(_show_menu)
	pause_box.add_child(home)
	var note := _label("PROGRESS AUTO-SAVED", 11)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(note)
	layer.add_child(pause_panel)
	pause_panel.hide()

	_build_touch_controls()
	_set_touch_controls_visible(false)

func _bar(node_name: String, x: float, y: float, width: float, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bar.position = Vector2(x, y)
	bar.size = Vector2(width, height)
	get_node("HUD").add_child(bar)
	return bar

func _button(text_value: String, size_value: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = size_value
	button.add_theme_font_size_override("font_size", font_size)
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
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	return button

func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#e7f6ff"))
	label.add_theme_color_override("font_shadow_color", Color("#000000cc"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TouchControls"
	layer.layer = 20
	add_child(layer)
	touch_root = Control.new()
	touch_root.name = "TouchRoot"
	touch_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_root.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(touch_root)

	joystick = JOYSTICK_SCRIPT.new()
	joystick.name = "MoveJoystick"
	joystick.size = Vector2(220, 220)
	joystick.custom_minimum_size = Vector2(220, 220)
	touch_root.add_child(joystick)
	joystick.value_changed.connect(func(value: Vector2): player.set_move_input(value))
	joystick.released.connect(func(): player.clear_move_input())
	touch_controls.append(joystick)

	fire_button = _button("FIRE", Vector2(170, 102), 22)
	fire_button.name = "FireButton"
	touch_root.add_child(fire_button)
	fire_button.button_down.connect(func(): player.set_fire_input(true))
	fire_button.button_up.connect(func(): player.set_fire_input(false))
	touch_controls.append(fire_button)

	boost_button = _button("BOOST", Vector2(150, 60), 17)
	boost_button.name = "BoostButton"
	boost_button.pressed.connect(_boost_pressed)
	touch_root.add_child(boost_button)
	touch_controls.append(boost_button)

	tactical_button = _button("PULSE", Vector2(150, 60), 17)
	tactical_button.name = "TacticalButton"
	tactical_button.pressed.connect(func(): player.tactical())
	touch_root.add_child(tactical_button)
	touch_controls.append(tactical_button)

	shield_button = _button("SHIELD", Vector2(150, 60), 17)
	shield_button.name = "ShieldButton"
	shield_button.pressed.connect(func(): player.shield())
	touch_root.add_child(shield_button)
	touch_controls.append(shield_button)

	reload_button = _button("RELOAD", Vector2(150, 52), 16)
	reload_button.name = "ReloadButton"
	reload_button.pressed.connect(func(): player.reload())
	touch_root.add_child(reload_button)
	touch_controls.append(reload_button)

	get_viewport().size_changed.connect(_layout_touch_controls)
	_layout_touch_controls()

func _layout_touch_controls() -> void:
	if not touch_root or not joystick:
		return
	var size := get_viewport().get_visible_rect().size
	joystick.position = Vector2(28, max(30.0, size.y - 252.0))
	fire_button.position = Vector2(max(28.0, size.x - 198.0), max(30.0, size.y - 238.0))
	reload_button.position = Vector2(max(28.0, size.x - 198.0), max(30.0, size.y - 120.0))
	boost_button.position = Vector2(max(28.0, size.x - 366.0), max(30.0, size.y - 118.0))
	tactical_button.position = Vector2(max(28.0, size.x - 366.0), max(30.0, size.y - 188.0))
	shield_button.position = Vector2(max(28.0, size.x - 366.0), max(30.0, size.y - 48.0))

func _select_map(index: int) -> void:
	if running:
		return
	selected_map = clamp(index, 0, MAP_NAMES.size() - 1)
	map_info_label.text = MAP_DESCRIPTIONS[selected_map]
	for i in range(map_buttons.size()):
		map_buttons[i].text = ("[ SELECTED ] " if i == selected_map else "") + MAP_NAMES[i]
	_retheme()
	_build_arena(selected_map)
	if player:
		player.position = _spawn_position()

func _retheme() -> void:
	match selected_map:
		0:
			environment_node.environment.background_color = Color("#070a12")
			environment_node.environment.ambient_light_color = Color("#9bb7d6")
		1:
			environment_node.environment.background_color = Color("#100b07")
			environment_node.environment.ambient_light_color = Color("#c9a67f")
		2:
			environment_node.environment.background_color = Color("#061016")
			environment_node.environment.ambient_light_color = Color("#a6ddff")

func _spawn_position() -> Vector3:
	return Vector3(0, 0.15, 17) if stage != 2 else Vector3(0, 0.15, -17)

func _start_game_pressed() -> void:
	_begin_run(false)

func _begin_run(continue_run: bool) -> void:
	if continue_run:
		save_system.load_state()
		stage = clamp(int(save_system.stage), 1, 3)
		score = max(0, int(save_system.score))
	else:
		stage = 1
		score = 0
	wave = 0
	running = true
	game_over = false
	boss_active = false
	transition_lock = false
	wave_timer = 1.4
	pickup_timer = 5.0
	get_tree().paused = false
	menu_panel.hide()
	pause_panel.hide()
	pause_button.show()
	_set_touch_controls_visible(true)
	player.reset_for_run()
	player.position = _spawn_position()
	_clear_dynamic()
	objective_label.text = _stage_objective()
	_set_message("SECTOR %02d // DEPLOY" % stage, 1.6)

func _show_menu() -> void:
	get_tree().paused = false
	running = false
	game_over = false
	boss_active = false
	_clear_dynamic()
	menu_panel.show()
	pause_panel.hide()
	pause_button.hide()
	_set_touch_controls_visible(false)
	objective_label.text = "AWAITING DEPLOYMENT"
	message_label.text = ""

func _start_next_wave() -> void:
	if stage < 3 and wave >= 3:
		wave_timer = 9999.0
		return
	if stage == 3 and wave >= 4:
		wave_timer = 9999.0
		return
	wave += 1
	wave_timer = 18.0
	if stage == 3 and wave == 4:
		_spawn_enemy("heavy", 3.6, true)
		boss_active = true
		boss_bar.show()
		_set_message("WARDEN PRIME // BOSS SIGNAL", 0.0)
		objective_label.text = "ELIMINATE WARDEN PRIME"
		_play_sound("boss")
		return

	var count: int = int(min(MAX_ENEMIES, 3 + stage * 2 + wave * 2))
	var difficulty: float = 0.8 + stage * 0.48 + wave * 0.16
	for i in range(count):
		var roll: int = rng.randi_range(0, 99)
		var kind := "scout"
		if stage >= 2 and roll < 33:
			kind = "striker"
		if stage >= 3 and roll < 16:
			kind = "heavy"
		_spawn_enemy(kind, difficulty, false)
	objective_label.text = "SURVIVE WAVE %02d" % wave
	_set_message("WAVE %02d // INBOUND" % wave, 1.2)

func _spawn_enemy(kind: String, difficulty: float, boss: bool) -> void:
	if enemies.size() >= MAX_ENEMIES and not boss:
		return
	var enemy: CharacterBody3D = ENEMY_SCRIPT.new()
	var angle: float = rng.randf_range(0.0, TAU)
	var distance: float = rng.randf_range(24.0, 34.0)
	enemy.position = Vector3(cos(angle) * distance, 0.2, sin(angle) * distance)
	add_child(enemy)
	enemy.setup(player, difficulty, kind, boss)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.attack_requested.connect(_on_enemy_attack)
	enemy.health_changed.connect(_on_enemy_health_changed)
	if boss:
		boss_bar.max_value = enemy.max_health
		boss_bar.value = enemy.health
	enemies.append(enemy)

func _on_enemy_health_changed(current: float, maximum: float) -> void:
	if boss_active:
		boss_bar.max_value = maximum
		boss_bar.value = current

func _on_enemy_attack(origin: Vector3, direction: Vector3, damage: float) -> void:
	if running and not game_over:
		_spawn_projectile(origin, direction, false, damage, 11.0, 5.2, Color("#ff6f67"))

func _on_player_fire(origin: Vector3, direction: Vector3, damage: float) -> void:
	if running and not game_over and not get_tree().paused:
		player.set_aim_direction(direction)
		_spawn_projectile(origin, direction, true, damage, 34.0, 2.7, Color("#75ddff"))
		_spawn_muzzle_fx(origin, Color("#75ddff"))
		_play_sound("shoot")

func _spawn_projectile(origin: Vector3, direction: Vector3, friendly: bool, damage: float, speed: float, life: float, tint: Color) -> void:
	if projectiles.size() >= MAX_PROJECTILES:
		var oldest: Node3D = projectiles.pop_front() as Node3D
		if is_instance_valid(oldest):
			oldest.queue_free()
	var projectile: Node3D = PROJECTILE_SCRIPT.new() as Node3D
	add_child(projectile)
	projectile.setup(origin, direction, friendly, damage, speed, life, tint)
	projectiles.append(projectile)

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
		if shot.friendly:
			var hit := false
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					if shot.global_position.distance_to(enemy.global_position + Vector3.UP * 0.85) <= shot.hit_radius:
						enemy.take_damage(shot.damage)
						score += 5
						_spawn_impact_fx(shot.global_position, Color("#8be7ff"), 1.0)
						shot.queue_free()
						projectiles.remove_at(i)
						hit = true
						break
			if hit:
				continue
		elif is_instance_valid(player) and shot.global_position.distance_to(player.global_position + Vector3.UP * 0.8) <= shot.hit_radius:
			player.take_damage(shot.damage)
			_spawn_impact_fx(shot.global_position, Color("#ff665e"), 1.2)
			shot.queue_free()
			projectiles.remove_at(i)
			continue
		if abs(shot.global_position.x) > 45.0 or abs(shot.global_position.z) > 45.0:
			shot.queue_free()
			projectiles.remove_at(i)

func _spawn_pickup() -> void:
	var pickup := Node3D.new()
	pickup.name = "EnergyCell"
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	sphere.material = _material(Color("#9be9ff"), 0.1, Color("#59d9ff"), 4.0)
	core.mesh = sphere
	pickup.add_child(core)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.64
	torus.material = _material(Color("#c6f6ff"), 0.08, Color("#6ee4ff"), 3.0)
	ring.mesh = torus
	ring.rotation_degrees.x = 90
	pickup.add_child(ring)
	pickup.position = Vector3(rng.randf_range(-30, 30), 0.9, rng.randf_range(-30, 30))
	arena_root.add_child(pickup)
	pickups.append(pickup)

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup: Node3D = pickups[i]
		if not is_instance_valid(pickup):
			pickups.remove_at(i)
			continue
		pickup.rotation.y += delta * 2.6
		pickup.position.y = 0.9 + sin(elapsed * 3.8 + float(i)) * 0.16
		if player.global_position.distance_to(pickup.global_position) < 1.8:
			player.heal(14.0)
			player.restore_energy(30.0)
			score += 120
			_spawn_impact_fx(pickup.global_position, Color("#74ddff"), 1.4)
			_play_sound("pickup")
			pickup.queue_free()
			pickups.remove_at(i)

func _on_enemy_defeated(enemy: Node3D, boss: bool) -> void:
	enemies.erase(enemy)
	combo_count += 1
	combo_timer = 4.2
	var reward: int = 260 + stage * 80 + wave * 28 + combo_count * 22
	if boss:
		reward = 5000
		boss_active = false
		boss_bar.hide()
		score += reward
		best_score = max(best_score, score)
		save_system.save_state(4, score, best_score)
		_set_message("WARDEN PRIME // NEUTRALIZED", 3.5)
		objective_label.text = "OPERATION COMPLETE // EXTRACTION CONFIRMED"
		_spawn_impact_fx(enemy.global_position + Vector3.UP, Color("#8ee7ff"), 4.0)
		var tween := create_tween()
		tween.tween_interval(3.0)
		tween.tween_callback(_win_game)
	else:
		score += reward
		_spawn_impact_fx(enemy.global_position + Vector3.UP * 0.8, Color("#74d8ff"), 1.45)

func _check_progression() -> void:
	if transition_lock or not running or boss_active:
		return
	var final_wave: bool = (stage < 3 and wave >= 3) or (stage == 3 and wave >= 3)
	if final_wave and enemies.is_empty():
		transition_lock = true
	_complete_stage()

func _complete_stage() -> void:
	score += 1200 * stage
	best_score = max(best_score, score)
	save_system.save_state(stage + 1, score, best_score)
	if stage >= 3:
		_win_game()
		return
	_set_message("SECTOR %02d // CLEAR" % stage, 2.4)
	objective_label.text = "AUTO-SAVE COMPLETE // NEXT OPERATION UNLOCKED"
	var tween := create_tween()
	tween.tween_interval(2.4)
	tween.tween_callback(func():
		stage += 1
		wave = 0
		transition_lock = false
		_clear_dynamic()
		_build_arena(selected_map)
		player.position = _spawn_position()
		wave_timer = 1.4
		objective_label.text = _stage_objective()
	)

func _stage_objective() -> String:
	return "CLEAR 3 WAVES // %s" % MAP_NAMES[selected_map]

func _on_player_boost() -> void:
	camera_shake = max(camera_shake, 0.08)
	_spawn_boost_fx()
	_set_message("BOOST // ENGAGED", 0.9)

func _boost_pressed() -> void:
	if running and not game_over and not get_tree().paused:
		player.boost()

func _on_player_tactical(origin: Vector3, direction: Vector3) -> void:
	if not running or game_over or get_tree().paused:
		return
	camera_shake = max(camera_shake, 0.25)
	var radius: float = 7.2
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var distance: float = origin.distance_to(enemy.global_position + Vector3.UP * 0.8)
			if distance <= radius:
				var falloff: float = 1.0 - clamp(distance / radius, 0.0, 1.0) * 0.45
				enemy.take_damage((105.0 + stage * 12.0) * falloff)
	_spawn_impact_fx(origin, Color("#68dcff"), 3.8)
	_flash_screen(Color("#6ddcff"), 0.34)
	_set_message("PULSE // SHOCKWAVE", 1.0)

func _on_player_shield() -> void:
	_flash_screen(Color("#6fa9ff"), 0.22)
	_set_message("SHIELD // ACTIVE", 1.0)

func _on_player_health(value: float) -> void:
	health_bar.value = value
	if value <= 30.0 and running:
		_flash_screen(Color("#ff5e5e"), 0.18)
		_set_message("HULL CRITICAL", 0.6)

func _on_player_energy(value: float) -> void:
	energy_bar.value = value

func _on_ammo(current: int, capacity: int) -> void:
	ammo_label.text = "AMMO %02d / %02d" % [current, capacity]

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	running = false
	best_score = max(best_score, score)
	save_system.save_state(stage, score, best_score)
	_set_message("MISSION FAILED // PROGRESS SAVED", 3.5)
	_set_touch_controls_visible(false)
	pause_button.hide()
	var tween := create_tween()
	tween.tween_interval(2.6)
	tween.tween_callback(_show_menu)

func _win_game() -> void:
	game_over = true
	running = false
	best_score = max(best_score, score)
	save_system.save_state(4, score, best_score)
	_set_message("CAMPAIGN COMPLETE // %06d" % score, 4.5)
	objective_label.text = "ALL OPERATIONS CLEARED // EXTRACTING"
	_set_touch_controls_visible(false)
	pause_button.hide()
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_callback(_show_menu)

func _toggle_pause() -> void:
	if not running or game_over:
		return
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused
	_set_touch_controls_visible(not get_tree().paused)

func _update_camera(delta: float) -> void:
	var desired := player.global_position + Vector3(0, 6.7, 10.0) + Basis(Vector3.UP, camera_yaw) * Vector3(0, 0, 8.5)
	camera.global_position = camera.global_position.lerp(desired, min(1.0, delta * 7.0))
	camera.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	if camera_shake > 0.0:
		camera.global_position += Vector3(rng.randf_range(-camera_shake, camera_shake), rng.randf_range(-camera_shake, camera_shake), 0)

func _unhandled_input(event: InputEvent) -> void:
	if not running or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var size := get_viewport().get_visible_rect().size
		if touch.position.x > size.x * 0.45 and touch.position.y < size.y * 0.72:
			if touch.pressed:
				camera_touch_id = touch.index
				camera_touch_last = touch.position
			elif touch.index == camera_touch_id:
				camera_touch_id = -1
	elif event is InputEventScreenDrag and camera_touch_id >= 0:
		var drag := event as InputEventScreenDrag
		if drag.index == camera_touch_id:
			var delta := drag.position - camera_touch_last
			camera_touch_last = drag.position
			camera_yaw -= delta.x * 0.01
			camera_pitch = clamp(camera_pitch - delta.y * 0.01, -0.60, -0.05)

func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	stage_label.text = "SECTOR %02d / %s" % [stage, STAGE_NAMES[stage - 1]]
	wave_label.text = "WAVE %02d | THREATS %02d" % [wave, enemies.size()]
	score_label.text = "SCORE %06d" % score
	combo_label.text = "COMBO x%d" % combo_count
	var state: Dictionary = player.get_state()
	var reload_text: String = "RELOADING" if float(state["reloadTimer"]) > 0.0 else "RELOAD READY"
	var pulse_text: String = "PULSE %.1f" % float(state["pulseCooldown"]) if float(state["pulseCooldown"]) > 0.0 else "PULSE READY"
	var shield_text: String = "SHIELD %.1f" % float(state["shieldCooldown"]) if float(state["shieldCooldown"]) > 0.0 else "SHIELD READY"
	cooldown_label.text = "%s    %s    %s" % [reload_text, pulse_text, shield_text]
	profile_label.text = "%02d FPS | %04.1f ms | Q%d" % [int(fps_value), frame_ms, quality_level]

func _update_performance(delta: float) -> void:
	if delta <= 0.0001:
		return
	var instant_fps: float = 1.0 / delta
	fps_value = lerp(fps_value, instant_fps, 0.10)
	frame_ms = 1000.0 / max(fps_value, 1.0)
	if quality_level > 0 and fps_value < 38.0:
		quality_level -= 1
		_apply_quality()
	elif quality_level < 2 and fps_value > 57.0:
		quality_level += 1
		_apply_quality()

func _apply_quality() -> void:
	if atmosphere:
		atmosphere.amount = 90 if quality_level == 2 else (48 if quality_level == 1 else 18)

func _cleanup_enemies() -> void:
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

func _spawn_muzzle_fx(pos: Vector3, tint: Color) -> void:
	if quality_level == 0:
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.10
	torus.outer_radius = 0.22
	torus.material = _material(tint, 0.08, tint, 3.2)
	ring.mesh = torus
	ring.position = pos
	add_child(ring)
	fx_nodes.append(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.4, 0.10)
	tween.tween_callback(func():
		fx_nodes.erase(ring)
		if is_instance_valid(ring):
			ring.queue_free()
	)

func _spawn_impact_fx(pos: Vector3, tint: Color, power: float) -> void:
	if quality_level == 0 and power < 2.0:
		return
	var fx := GPUParticles3D.new()
	fx.one_shot = true
	fx.amount = int(8 + power * 4.0) if quality_level == 2 else int(5 + power * 2.5)
	fx.lifetime = 0.28 + power * 0.05
	fx.explosiveness = 1.0
	fx.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0 * power
	pm.initial_velocity_max = 4.8 * power
	pm.scale_min = 0.025
	pm.scale_max = 0.09 * power
	pm.color = tint
	fx.process_material = pm
	var particle := SphereMesh.new()
	particle.radius = 0.05
	particle.height = 0.10
	particle.material = _material(tint, 0.05, tint, 3.0)
	fx.draw_pass_1 = particle
	add_child(fx)
	fx_nodes.append(fx)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.12 * power
	torus.outer_radius = 0.19 * power
	torus.material = _material(tint, 0.05, tint, 2.4)
	ring.mesh = torus
	ring.position = pos
	add_child(ring)
	fx_nodes.append(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.3, 0.18)
	tween.tween_callback(func():
		fx_nodes.erase(ring)
		if is_instance_valid(ring):
			ring.queue_free()
	)
	var cleanup := create_tween()
	cleanup.tween_interval(fx.lifetime + 0.08)
	cleanup.tween_callback(func():
		fx_nodes.erase(fx)
		if is_instance_valid(fx):
			fx.queue_free()
	)

func _spawn_boost_fx() -> void:
	if quality_level == 0:
		return
	for i in range(3):
		var marker := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.12, 1.25)
		mesh.material = _material(Color("#72ddff"), 0.12, Color("#66d6ff"), 2.6)
		marker.mesh = mesh
		marker.position = player.global_position + Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(0.2, 1.2), 0.6)
		add_child(marker)
		fx_nodes.append(marker)
		var tween := create_tween()
		tween.tween_property(marker, "scale", Vector3(0.2, 0.2, 2.2), 0.22)
		tween.tween_callback(func():
			fx_nodes.erase(marker)
			if is_instance_valid(marker):
				marker.queue_free()
		)

func _set_message(text_value: String, duration: float) -> void:
	message_label.text = text_value
	message_timer = duration

func _flash_screen(tint: Color, alpha: float) -> void:
	screen_flash.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	var tween := create_tween()
	tween.tween_property(screen_flash, "modulate:a", alpha, 0.04)
	tween.tween_property(screen_flash, "modulate:a", 0.0, 0.20)

func _play_sound(kind: String) -> void:
	if audio_manager and audio_manager.has_method("play_sound"):
		audio_manager.play_sound(kind)

func _force_fullscreen() -> void:
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
		"quality": quality_level,
		"map": MAP_NAMES[selected_map],
		"player": player.get_state() if is_instance_valid(player) else {}
	}

func get_ui_state() -> Dictionary:
	var controls: Array[Dictionary] = []
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		if control == null:
			continue
		var text_value: String = ""
		if control is Button:
			text_value = (control as Button).text
		elif control is Label:
			text_value = (control as Label).text
		if text_value != "" or control.name in ["MainMenu", "PauseMenu", "TouchRoot"]:
			var rect := control.get_global_rect()
			controls.append({
				"name": control.name,
				"text": text_value,
				"visible": control.visible,
				"disabled": control is Button and (control as Button).disabled,
				"x": rect.position.x,
				"y": rect.position.y,
				"width": rect.size.x,
				"height": rect.size.y
			})
	return {"paused": get_tree().paused, "running": running, "controls": controls}
