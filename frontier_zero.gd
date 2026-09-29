extends Node3D
class_name FrontierZero

const PLAYER_SCRIPT = preload("res://aaa_player.gd")
const ENEMY_SCRIPT = preload("res://aaa_enemy.gd")
const PROJECTILE_SCRIPT = preload("res://aaa_projectile.gd")
const SAVE_SCRIPT = preload("res://save_system.gd")
const AUDIO_SCRIPT = preload("res://audio_manager.gd")
const JOYSTICK_SCRIPT = preload("res://joystick.gd")
const STATION_SCENE = preload("res://assets/orbital_field_station.glb")

const MAP_NAMES: Array[String] = ["NEON DISTRICT", "DUST BASIN", "FROZEN RELAY"]
const STAGE_NAMES: Array[String] = ["NIGHTFALL", "SUNFALL", "WHITEOUT"]
const MAP_DESCRIPTIONS: Array[String] = [
	"Urban orbital ruins with dense neon cover.",
	"Industrial basin with long sight lines.",
	"Frozen relay complex with exposed lanes."
]
const MAX_ENEMIES: int = 22
const MAX_PROJECTILES: int = 28

var player: CharacterBody3D
var camera: Camera3D
var world_environment: WorldEnvironment
var arena_root: Node3D
var atmosphere: GPUParticles3D
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
var quality_level: int = 2
var running: bool = false
var game_over: bool = false
var boss_active: bool = false
var transition_lock: bool = false

var elapsed: float = 0.0
var wave_timer: float = 1.2
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
var cooldown_label: Label
var screen_flash: ColorRect
var touch_root: Control
var joystick: Control
var fire_button: Button
var boost_button: Button
var tactical_button: Button
var shield_button: Button
var reload_button: Button

func _ready() -> void:
	seed(Time.get_ticks_msec())
	Engine.max_fps = 60
	save_system = SAVE_SCRIPT.new()
	add_child(save_system)
	save_system.load_state()
	best_score = int(save_system.best_score)
	audio_manager = AUDIO_SCRIPT.new()
	add_child(audio_manager)
	_build_environment()
	_build_arena()
	_create_player()
	_create_camera()
	_build_ui()
	_show_menu()
	call_deferred("_force_fullscreen")

func _process(delta: float) -> void:
	elapsed += delta
	message_timer = max(0.0,message_timer-delta)
	combo_timer = max(0.0,combo_timer-delta)
	hud_timer -= delta
	camera_shake = max(0.0,camera_shake-delta)
	fps_value = lerp(fps_value,1.0/max(delta,0.0001),0.08)
	frame_ms = 1000.0/max(fps_value,1.0)
	if combo_timer <= 0.0:
		combo_count = 0

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
			pickup_timer = randf_range(5.0,8.0)
		_check_progression()

	if hud_timer <= 0.0:
		hud_timer = 0.10
		_update_hud()
	if message_timer <= 0.0 and not boss_active:
		message_label.text = ""

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
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
	world_environment.environment = env
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-28,0)
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)

func _build_arena() -> void:
	if is_instance_valid(arena_root):
		arena_root.queue_free()
	arena_root = Node3D.new()
	arena_root.name = "World"
	add_child(arena_root)

	var floor_color := Color("#111725")
	var accent := Color("#53d4ff")
	if selected_map == 1:
		floor_color = Color("#1b1510")
		accent = Color("#ffae62")
	elif selected_map == 2:
		floor_color = Color("#101923")
		accent = Color("#8de3ff")

	_make_box(Vector3(0,-0.45,0),Vector3(82,0.9,82),floor_color)
	_make_box(Vector3(0,2.8,-41),Vector3(82,6,0.7),Color("#10151f"))
	_make_box(Vector3(0,2.8,41),Vector3(82,6,0.7),Color("#10151f"))
	_make_box(Vector3(-41,2.8,0),Vector3(0.7,6,82),Color("#10151f"))
	_make_box(Vector3(41,2.8,0),Vector3(0.7,6,82),Color("#10151f"))

	for i in range(16):
		var angle: float = float(i)*TAU/16.0 + randf_range(-0.08,0.08)
		var radius: float = randf_range(11.0,31.0)
		_make_obstacle(Vector3(cos(angle)*radius,0,sin(angle)*radius),randf_range(1.0,2.1),randf_range(2.5,6.5),accent)

	var points: Array[Vector3] = [
		Vector3(-27,0,-27),Vector3(27,0,-27),
		Vector3(-27,0,27),Vector3(27,0,27)
	]
	var station_count: int = 2 if selected_map == 1 else 4
	for i in range(station_count):
		var station := STATION_SCENE.instantiate()
		station.name = "Station_%02d" % i
		station.position = points[i]
		station.scale = Vector3.ONE*(0.82+float(selected_map)*0.10)
		arena_root.add_child(station)

	atmosphere = GPUParticles3D.new()
	atmosphere.name = "Atmosphere"
	atmosphere.amount = 70
	atmosphere.lifetime = 8.0
	atmosphere.visibility_aabb = AABB(Vector3(-42,0,-42),Vector3(84,16,84))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0,-1,0)
	pm.spread = 24.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.42
	pm.scale_min = 0.02
	pm.scale_max = 0.06
	pm.color = Color(accent.r,accent.g,accent.b,0.45)
	atmosphere.process_material = pm
	var dust := SphereMesh.new()
	dust.radius = 0.035
	dust.height = 0.07
	dust.material = _material(accent,0.15,accent,1.2)
	atmosphere.draw_pass_1 = dust
	arena_root.add_child(atmosphere)

	for i in range(4):
		var light := OmniLight3D.new()
		light.position = [Vector3(-18,6,-8),Vector3(18,6,-8),Vector3(-20,4,18),Vector3(20,4,18)][i]
		light.light_color = accent if i % 2 == 0 else Color("#8e9bff")
		light.light_energy = 1.8
		light.omni_range = 10.0
		arena_root.add_child(light)

func _make_box(position: Vector3,size: Vector3,color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = position
	arena_root.add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color,0.82,Color("#4e6377"),0.25)
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _make_obstacle(position: Vector3,radius: float,height: float,accent: Color) -> void:
	var body := StaticBody3D.new()
	body.position = position+Vector3.UP*height*0.5
	arena_root.add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius*0.7
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = _material(Color("#283340"),0.74,accent,0.28)
	visual.mesh = mesh
	body.add_child(visual)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius*0.74
	torus.outer_radius = radius*0.82
	torus.material = _material(accent,0.24,accent,1.8)
	ring.mesh = torus
	ring.position.y = height*0.46
	body.add_child(ring)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)

func _material(albedo: Color,roughness: float,emission: Color,energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	mat.metallic = 0.42
	mat.emission_enabled = energy > 0.0
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat

func _create_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.position = Vector3(0,0.15,17)
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
	camera.position = Vector3(0,7,25)
	add_child(camera)
	camera.look_at(Vector3(0,1.1,5),Vector3.UP)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	var info := VBoxContainer.new()
	info.position = Vector2(18,16)
	info.size = Vector2(470,100)
	layer.add_child(info)
	stage_label = _label("SECTOR 01 / NIGHTFALL",20)
	wave_label = _label("WAVE 00",17)
	score_label = _label("SCORE 000000",22)
	info.add_child(stage_label)
	info.add_child(wave_label)
	info.add_child(score_label)

	profile_label = _label("60 FPS | 16.7 ms | Q2",14)
	profile_label.position = Vector2(1015,16)
	profile_label.size = Vector2(245,28)
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(profile_label)

	objective_label = _label("AWAITING DEPLOYMENT",18)
	objective_label.position = Vector2(360,25)
	objective_label.size = Vector2(560,48)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(objective_label)

	message_label = _label("",30)
	message_label.position = Vector2(280,118)
	message_label.size = Vector2(720,58)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(message_label)

	health_bar = _bar("HealthBar",Vector2(26,602),Vector2(280,24),layer)
	energy_bar = _bar("EnergyBar",Vector2(26,636),Vector2(280,16),layer)
	var hp := _label("HULL INTEGRITY",12)
	hp.position = Vector2(28,577)
	hp.size = Vector2(200,20)
	layer.add_child(hp)
	var en := _label("ENERGY CORE",11)
	en.position = Vector2(28,619)
	en.size = Vector2(200,18)
	layer.add_child(en)

	ammo_label = _label("AMMO 30 / 30",23)
	ammo_label.position = Vector2(980,602)
	ammo_label.size = Vector2(270,40)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(ammo_label)

	cooldown_label = _label("BOOST READY    PULSE READY    SHIELD READY",12)
	cooldown_label.position = Vector2(770,636)
	cooldown_label.size = Vector2(480,22)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(cooldown_label)

	combo_label = _label("COMBO x0",17)
	combo_label.position = Vector2(25,555)
	combo_label.size = Vector2(220,28)
	layer.add_child(combo_label)

	boss_bar = ProgressBar.new()
	boss_bar.name = "BossHealth"
	boss_bar.max_value = 100.0
	boss_bar.value = 0.0
	boss_bar.show_percentage = false
	boss_bar.position = Vector2(300,96)
	boss_bar.size = Vector2(680,20)
	boss_bar.hide()
	layer.add_child(boss_bar)

	screen_flash = ColorRect.new()
	screen_flash.name = "ScreenFlash"
	screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.modulate = Color(1,1,1,0)
	screen_flash.z_index = 400
	layer.add_child(screen_flash)

	pause_button = _button("PAUSE",Vector2(86,48),17)
	pause_button.name = "PauseButton"
	pause_button.position = Vector2(1180,55)
	pause_button.pressed.connect(_toggle_pause)
	layer.add_child(pause_button)

	menu_panel = PanelContainer.new()
	menu_panel.name = "MainMenu"
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.z_index = 500
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation",9)
	menu_panel.add_child(menu)

	var brand := _label("HYOKUA // SYSTEM 7",14)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(brand)
	var title := _label("FRONTIER // ZERO",62)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)
	var subtitle := _label("ECLIPSE PROTOCOL",18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(subtitle)
	var meta := _label("THIRD-PERSON // SINGLE PLAYER // ANDROID",12)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(meta)
	var mission := _label("MISSION SELECT",12)
	mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(mission)

	for i in range(MAP_NAMES.size()):
		var b := _button(MAP_NAMES[i],Vector2(420,45),17)
		b.name = "Mission_%02d" % (i+1)
		b.pressed.connect(_select_map.bind(i))
		menu.add_child(b)
		map_buttons.append(b)

	map_info_label = _label(MAP_DESCRIPTIONS[0],13)
	map_info_label.custom_minimum_size = Vector2(620,32)
	map_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(map_info_label)

	start_button = _button("DEPLOY",Vector2(300,60),23)
	start_button.name = "StartButton"
	start_button.pressed.connect(_start_game_pressed)
	menu.add_child(start_button)
	layer.add_child(menu_panel)

	pause_panel = PanelContainer.new()
	pause_panel.name = "PauseMenu"
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-220,-170)
	pause_panel.size = Vector2(440,340)
	pause_panel.z_index = 350

	var pause_box := VBoxContainer.new()
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation",12)
	pause_panel.add_child(pause_box)
	var paused_title := _label("PAUSED",44)
	paused_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(paused_title)
	var resume := _button("RESUME",Vector2(280,54),19)
	resume.name = "ResumeButton"
	resume.pressed.connect(_toggle_pause)
	pause_box.add_child(resume)
	var home := _button("MAIN MENU",Vector2(280,52),18)
	home.name = "MainMenuButton"
	home.pressed.connect(_show_menu)
	pause_box.add_child(home)
	layer.add_child(pause_panel)
	pause_panel.hide()

	_build_touch_controls()
	_set_touch_controls_visible(false)

func _bar(node_name: String,position: Vector2,size: Vector2,parent: CanvasLayer) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.position = position
	bar.size = size
	parent.add_child(bar)
	return bar

func _button(value: String,minimum: Vector2,font_size: int) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = minimum
	b.add_theme_font_size_override("font_size",font_size)
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
	b.add_theme_stylebox_override("normal",normal)
	b.add_theme_stylebox_override("hover",hover)
	b.add_theme_stylebox_override("pressed",pressed)
	return b

func _label(value: String,size: int) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color("#e7f6ff"))
	l.add_theme_color_override("font_shadow_color",Color("#000000cc"))
	l.add_theme_constant_override("shadow_offset_x",2)
	l.add_theme_constant_override("shadow_offset_y",2)
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

	joystick = JOYSTICK_SCRIPT.new()
	joystick.name = "MoveJoystick"
	joystick.position = Vector2(28,470)
	joystick.size = Vector2(220,220)
	joystick.custom_minimum_size = Vector2(220,220)
	touch_root.add_child(joystick)
	joystick.value_changed.connect(_on_joystick_changed)
	joystick.released.connect(_on_joystick_released)
	touch_controls.append(joystick)

	fire_button = _button("FIRE",Vector2(170,102),22)
	fire_button.name = "FireButton"
	fire_button.button_down.connect(func() -> void: player.set_fire_input(true))
	fire_button.button_up.connect(func() -> void: player.set_fire_input(false))
	touch_root.add_child(fire_button)
	touch_controls.append(fire_button)

	boost_button = _button("BOOST",Vector2(150,60),17)
	boost_button.name = "BoostButton"
	boost_button.pressed.connect(_boost_pressed)
	touch_root.add_child(boost_button)
	touch_controls.append(boost_button)

	tactical_button = _button("PULSE",Vector2(150,60),17)
	tactical_button.name = "TacticalButton"
	tactical_button.pressed.connect(func() -> void: player.tactical())
	touch_root.add_child(tactical_button)
	touch_controls.append(tactical_button)

	shield_button = _button("SHIELD",Vector2(150,60),17)
	shield_button.name = "ShieldButton"
	shield_button.pressed.connect(func() -> void: player.shield())
	touch_root.add_child(shield_button)
	touch_controls.append(shield_button)

	reload_button = _button("RELOAD",Vector2(150,52),16)
	reload_button.name = "ReloadButton"
	reload_button.pressed.connect(func() -> void: player.reload())
	touch_root.add_child(reload_button)
	touch_controls.append(reload_button)

	get_viewport().size_changed.connect(_layout_touch_controls)
	_layout_touch_controls()

func _layout_touch_controls() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	joystick.position = Vector2(28,max(24.0,size.y-252.0))
	fire_button.position = Vector2(max(24.0,size.x-198.0),max(24.0,size.y-238.0))
	reload_button.position = Vector2(max(24.0,size.x-198.0),max(24.0,size.y-120.0))
	boost_button.position = Vector2(max(24.0,size.x-366.0),max(24.0,size.y-118.0))
	tactical_button.position = Vector2(max(24.0,size.x-366.0),max(24.0,size.y-188.0))
	shield_button.position = Vector2(max(24.0,size.x-366.0),max(24.0,size.y-48.0))

func _set_touch_controls_visible(value: bool) -> void:
	touch_root.visible = value
	touch_root.mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_IGNORE
	for control in touch_controls:
		if is_instance_valid(control):
			control.visible = value

func _select_map(index: int) -> void:
	if running:
		return
	selected_map = clamp(index,0,MAP_NAMES.size()-1)
	map_info_label.text = MAP_DESCRIPTIONS[selected_map]
	for i in range(map_buttons.size()):
		map_buttons[i].text = ("[ SELECTED ] " if i == selected_map else "") + MAP_NAMES[i]
	_build_arena()
	if player:
		player.position = Vector3(0,0.15,17)

func _retheme() -> void:
	if selected_map == 0:
		world_environment.environment.background_color = Color("#070a12")
	elif selected_map == 1:
		world_environment.environment.background_color = Color("#100b07")
	else:
		world_environment.environment.background_color = Color("#061016")

func _start_game_pressed() -> void:
	_begin_run(false)

func _begin_run(continue_run: bool) -> void:
	if continue_run:
		save_system.load_state()
		stage = clamp(int(save_system.stage),1,3)
		score = max(0,int(save_system.score))
	else:
		stage = 1
		score = 0
	wave = 0
	running = true
	game_over = false
	boss_active = false
	transition_lock = false
	wave_timer = 1.2
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
	_set_message("SECTOR %02d // DEPLOY" % stage,1.4)

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

func _spawn_position() -> Vector3:
	return Vector3(0,0.15,17) if stage != 2 else Vector3(0,0.15,-17)

func _start_next_wave() -> void:
	wave += 1
	wave_timer = 16.0
	if stage == 3 and wave == 4:
		_spawn_enemy("heavy",3.8,true)
		boss_active = true
		boss_bar.show()
		objective_label.text = "ELIMINATE WARDEN PRIME"
		_set_message("WARDEN PRIME // BOSS SIGNAL",0.0)
		_play_sound("boss")
		return
	if stage < 3 and wave > 3:
		wave_timer = 9999.0
		return
	var count: int = min(MAX_ENEMIES,3+stage*2+wave*2)
	var difficulty: float = 0.8+stage*0.45+wave*0.14
	for i in range(count):
		var roll: int = randi_range(0,99)
		var kind: String = "scout"
		if stage >= 2 and roll < 35:
			kind = "striker"
		if stage >= 3 and roll < 18:
			kind = "heavy"
		_spawn_enemy(kind,difficulty,false)
	objective_label.text = "SURVIVE WAVE %02d" % wave
	_set_message("WAVE %02d // INBOUND" % wave,1.0)
	_play_sound("stage")

func _spawn_enemy(kind: String,difficulty: float,boss: bool) -> void:
	if enemies.size() >= MAX_ENEMIES and not boss:
		return
	var enemy: CharacterBody3D = ENEMY_SCRIPT.new()
	var angle: float = randf_range(0.0,TAU)
	var distance: float = randf_range(24.0,34.0)
	enemy.position = Vector3(cos(angle)*distance,0.2,sin(angle)*distance)
	add_child(enemy)
	enemy.setup(player,difficulty,kind,boss)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.attack_requested.connect(_on_enemy_attack)
	enemy.health_changed.connect(_on_enemy_health_changed)
	if boss:
		boss_bar.max_value = enemy.max_health
		boss_bar.value = enemy.health
	enemies.append(enemy)

func _on_enemy_health_changed(current: float,maximum: float) -> void:
	if boss_active:
		boss_bar.max_value = maximum
		boss_bar.value = current

func _on_enemy_attack(origin: Vector3,direction: Vector3,damage: float) -> void:
	if running and not game_over:
		_spawn_projectile(origin,direction,false,damage,11.0,5.0,Color("#ff6f67"))

func _on_player_fire(origin: Vector3,direction: Vector3,damage: float) -> void:
	if running and not game_over and not get_tree().paused:
		_spawn_projectile(origin,direction,true,damage,34.0,2.7,Color("#75ddff"))
		_spawn_muzzle_fx(origin,Color("#75ddff"))
		_play_sound("shoot")

func _spawn_projectile(origin: Vector3,direction: Vector3,friendly: bool,damage: float,speed: float,life: float,color: Color) -> void:
	if projectiles.size() >= MAX_PROJECTILES:
		var old: Node3D = projectiles.pop_front() as Node3D
		if is_instance_valid(old):
			old.queue_free()
	var shot: Node3D = PROJECTILE_SCRIPT.new() as Node3D
	add_child(shot)
	shot.setup(origin,direction,friendly,damage,speed,life,color)
	projectiles.append(shot)

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
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
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy.has_method("take_damage"):
					if shot.global_position.distance_to(enemy.global_position+Vector3.UP*0.85) <= shot.hit_radius:
						enemy.take_damage(shot.damage)
						score += 5
						_spawn_impact_fx(shot.global_position,Color("#8be7ff"),1.0)
						shot.queue_free()
						projectiles.remove_at(i)
						break
		elif is_instance_valid(player):
			if shot.global_position.distance_to(player.global_position+Vector3.UP*0.8) <= shot.hit_radius:
				player.take_damage(shot.damage)
				_spawn_impact_fx(shot.global_position,Color("#ff665e"),1.2)
				shot.queue_free()
				projectiles.remove_at(i)
		if i < projectiles.size() and (abs(shot.global_position.x) > 45.0 or abs(shot.global_position.z) > 45.0):
			if is_instance_valid(shot):
				shot.queue_free()
			projectiles.remove_at(i)

func _spawn_pickup() -> void:
	var pickup := Node3D.new()
	pickup.name = "EnergyCell"
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	sphere.material = _material(Color("#9be9ff"),0.1,Color("#59d9ff"),4.0)
	visual.mesh = sphere
	pickup.add_child(visual)
	pickup.position = Vector3(randf_range(-30.0,30.0),0.9,randf_range(-30.0,30.0))
	arena_root.add_child(pickup)
	pickups.append(pickup)

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size()-1,-1,-1):
		var pickup: Node3D = pickups[i]
		if not is_instance_valid(pickup):
			pickups.remove_at(i)
			continue
		pickup.rotation.y += delta*2.6
		if player.global_position.distance_to(pickup.global_position) < 1.8:
			player.heal(14.0)
			player.restore_energy(30.0)
			score += 120
			_spawn_impact_fx(pickup.global_position,Color("#74ddff"),1.4)
			pickup.queue_free()
			pickups.remove_at(i)

func _on_enemy_defeated(enemy: Node3D,boss: bool) -> void:
	enemies.erase(enemy)
	combo_count += 1
	combo_timer = 4.0
	if boss:
		boss_active = false
		boss_bar.hide()
		score += 5000
		best_score = max(best_score,score)
		save_system.save_state(4,score,best_score)
		_set_message("WARDEN PRIME // NEUTRALIZED",3.0)
		objective_label.text = "CAMPAIGN COMPLETE"
		game_over = true
		running = false
		_set_touch_controls_visible(false)
		pause_button.hide()
	else:
		score += 250 + stage*75 + wave*25 + combo_count*20
		_spawn_impact_fx(enemy.global_position+Vector3.UP,Color("#74d8ff"),1.4)
		_play_sound("hit")

func _check_progression() -> void:
	if transition_lock or boss_active or enemies.size() > 0 or wave < 3:
		return
	transition_lock = true
	if stage < 3:
		_complete_stage()
	elif wave == 3:
		wave_timer = 0.5
		transition_lock = false

func _complete_stage() -> void:
	score += stage*1200
	best_score = max(best_score,score)
	save_system.save_state(stage+1,score,best_score)
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(func() -> void:
		stage = clamp(stage+1,1,3)
		wave = 0
		transition_lock = false
		_clear_dynamic()
		_build_arena()
		player.position = _spawn_position()
		wave_timer = 0.8
		objective_label.text = _stage_objective()
	)

func _stage_objective() -> String:
	return "CLEAR 3 WAVES // %s" % MAP_NAMES[selected_map]

func _on_player_boost() -> void:
	camera_shake = max(camera_shake,0.08)
	_spawn_boost_fx()
	_set_message("BOOST // ENGAGED",0.8)

func _boost_pressed() -> void:
	if running and not game_over and not get_tree().paused:
		player.boost()

func _on_player_tactical(origin: Vector3,direction: Vector3) -> void:
	if not running or game_over or get_tree().paused:
		return
	camera_shake = max(camera_shake,0.22)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var distance: float = origin.distance_to(enemy.global_position+Vector3.UP*0.8)
			if distance <= 7.2:
				enemy.take_damage(95.0-distance*5.0)
	_spawn_impact_fx(origin,Color("#68dcff"),3.2)
	_flash_screen(Color("#6ddcff"),0.30)
	_set_message("PULSE // SHOCKWAVE",0.9)

func _on_player_shield() -> void:
	_flash_screen(Color("#6fa9ff"),0.20)
	_set_message("SHIELD // ACTIVE",0.9)

func _on_player_health(value: float) -> void:
	health_bar.value = value
	if value <= 30.0 and running:
		_flash_screen(Color("#ff5e5e"),0.16)

func _on_player_energy(value: float) -> void:
	energy_bar.value = value

func _on_ammo(current: int,capacity: int) -> void:
	ammo_label.text = "AMMO %02d / %02d" % [current,capacity]

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	running = false
	best_score = max(best_score,score)
	save_system.save_state(stage,score,best_score)
	_set_message("MISSION FAILED // PROGRESS SAVED",2.8)
	_set_touch_controls_visible(false)
	pause_button.hide()
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_callback(_show_menu)

func _toggle_pause() -> void:
	if not running or game_over:
		return
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused
	_set_touch_controls_visible(not get_tree().paused)

func _on_joystick_changed(value: Vector2) -> void:
	player.set_move_input(value)

func _on_joystick_released() -> void:
	player.clear_move_input()

func _update_camera(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var desired := player.global_position+Vector3(0,6.7,10)+Basis(Vector3.UP,camera_yaw)*Vector3(0,0,8.5)
	camera.global_position = camera.global_position.lerp(desired,min(1.0,delta*7.0))
	camera.rotation = Vector3(camera_pitch,camera_yaw,0)
	if camera_shake > 0.0:
		camera.global_position += Vector3(randf_range(-camera_shake,camera_shake),randf_range(-camera_shake,camera_shake),0)
	player.set_aim_direction(-camera.global_transform.basis.z)

func _unhandled_input(event: InputEvent) -> void:
	if not running or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var size: Vector2 = get_viewport().get_visible_rect().size
		if touch.position.x > size.x*0.45 and touch.position.y < size.y*0.72:
			if touch.pressed:
				camera_touch_id = touch.index
				camera_touch_last = touch.position
			elif touch.index == camera_touch_id:
				camera_touch_id = -1
	elif event is InputEventScreenDrag and camera_touch_id >= 0:
		var drag := event as InputEventScreenDrag
		if drag.index == camera_touch_id:
			var d: Vector2 = drag.position-camera_touch_last
			camera_touch_last = drag.position
			camera_yaw -= d.x*0.01
			camera_pitch = clamp(camera_pitch-d.y*0.01,-0.6,-0.05)

func _update_hud() -> void:
	if not is_instance_valid(player):
		return
	var index: int = clamp(stage-1,0,STAGE_NAMES.size()-1)
	stage_label.text = "SECTOR %02d / %s" % [stage,STAGE_NAMES[index]]
	wave_label.text = "WAVE %02d | THREATS %02d" % [wave,enemies.size()]
	score_label.text = "SCORE %06d" % score
	combo_label.text = "COMBO x%d" % combo_count
	var state: Dictionary = player.get_state()
	var reload_text: String = "RELOADING" if float(state["reloadTimer"]) > 0.0 else "RELOAD READY"
	var pulse_text: String = "PULSE %.1f" % float(state["pulseCooldown"]) if float(state["pulseCooldown"]) > 0.0 else "PULSE READY"
	var shield_text: String = "SHIELD %.1f" % float(state["shieldCooldown"]) if float(state["shieldCooldown"]) > 0.0 else "SHIELD READY"
	cooldown_label.text = "%s    %s    %s" % [reload_text,pulse_text,shield_text]
	profile_label.text = "%02d FPS | %04.1f ms | Q%d" % [int(fps_value),frame_ms,quality_level]

func _cleanup_enemies() -> void:
	for i in range(enemies.size()-1,-1,-1):
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

func _spawn_muzzle_fx(position: Vector3,tint: Color) -> void:
	if quality_level == 0:
		return
	var fx := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.22
	torus.material = _material(tint,0.08,tint,3.2)
	fx.mesh = torus
	fx.position = position
	add_child(fx)
	fx_nodes.append(fx)
	var tween := create_tween()
	tween.tween_property(fx,"scale",Vector3.ONE*2.4,0.1)
	tween.tween_callback(func() -> void:
		fx_nodes.erase(fx)
		if is_instance_valid(fx):
			fx.queue_free()
	)

func _spawn_impact_fx(position: Vector3,tint: Color,power: float) -> void:
	if quality_level == 0 and power < 2.0:
		return
	var fx := GPUParticles3D.new()
	fx.one_shot = true
	fx.amount = int(8+power*4)
	fx.lifetime = 0.28+power*0.05
	fx.explosiveness = 1.0
	fx.position = position
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0*power
	pm.initial_velocity_max = 4.8*power
	pm.scale_min = 0.025
	pm.scale_max = 0.09*power
	pm.color = tint
	fx.process_material = pm
	var particle := SphereMesh.new()
	particle.radius = 0.05
	particle.height = 0.1
	particle.material = _material(tint,0.05,tint,3.0)
	fx.draw_pass_1 = particle
	add_child(fx)
	fx_nodes.append(fx)
	fx.emitting = true

func _spawn_boost_fx() -> void:
	if quality_level == 0:
		return
	for i in range(3):
		var fx := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12,0.12,1.25)
		mesh.material = _material(Color("#72ddff"),0.12,Color("#66d6ff"),2.6)
		fx.mesh = mesh
		fx.position = player.global_position+Vector3(randf_range(-0.45,0.45),randf_range(0.2,1.2),0.6)
		add_child(fx)
		fx_nodes.append(fx)
		var tween := create_tween()
		tween.tween_property(fx,"scale",Vector3(0.2,0.2,2.2),0.22)
		tween.tween_callback(func() -> void:
			fx_nodes.erase(fx)
			if is_instance_valid(fx):
				fx.queue_free()
		)

func _flash_screen(tint: Color,alpha: float) -> void:
	screen_flash.modulate = Color(tint.r,tint.g,tint.b,0.0)
	var tween := create_tween()
	tween.tween_property(screen_flash,"modulate:a",alpha,0.04)
	tween.tween_property(screen_flash,"modulate:a",0.0,0.20)

func _set_message(value: String,duration: float) -> void:
	message_label.text = value
	message_timer = duration

func _play_sound(kind: String) -> void:
	if audio_manager and audio_manager.has_method("play_sound"):
		audio_manager.play_sound(kind)

func _force_fullscreen() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func get_runtime_state() -> Dictionary:
	return {
		"running":running,
		"gameOver":game_over,
		"paused":get_tree().paused,
		"stage":stage,
		"wave":wave,
		"score":score,
		"bestScore":best_score,
		"bossActive":boss_active,
		"enemyCount":enemies.size(),
		"projectileCount":projectiles.size(),
		"quality":quality_level,
		"map":MAP_NAMES[selected_map],
		"player":player.get_state() if is_instance_valid(player) else {}
	}

func get_ui_state() -> Dictionary:
	var controls: Array[Dictionary] = []
	for node in find_children("*","Control",true,false):
		var control := node as Control
		var value: String = ""
		if control is Button:
			value = (control as Button).text
		elif control is Label:
			value = (control as Label).text
		if value != "" or control.name in ["MainMenu","PauseMenu","TouchRoot"]:
			var rect: Rect2 = control.get_global_rect()
			controls.append({
				"name":control.name,
				"text":value,
				"visible":control.visible,
				"disabled":control is Button and (control as Button).disabled,
				"x":rect.position.x,
				"y":rect.position.y,
				"width":rect.size.x,
				"height":rect.size.y
			})
	return {"paused":get_tree().paused,"running":running,"controls":controls}
