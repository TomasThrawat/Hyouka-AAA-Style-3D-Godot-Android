extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")
const ENEMY_SCRIPT = preload("res://enemy.gd")
const PROJECTILE_SCRIPT = preload("res://projectile.gd")
const SAVE_SCRIPT = preload("res://save_system.gd")
const AUDIO_SCRIPT = preload("res://audio_manager.gd")
const JOYSTICK_SCRIPT = preload("res://joystick.gd")

var player: CharacterBody3D
var camera: Camera3D
var world_environment: WorldEnvironment
var arena_root: Node3D
var rng := RandomNumberGenerator.new()

var enemies: Array[Node3D] = []
var projectiles: Array[Node3D] = []
var pickups: Array[Node3D] = []
var lod_nodes: Array[Node3D] = []
var particle_nodes: Array[GPUParticles3D] = []
var dynamic_lights: Array[Light3D] = []

var audio_manager: Node
var save_system: Node

var stage := 1
var wave := 0
var score := 0
var best_score := 0
var enemies_defeated := 0
var stage_time := 0.0
var wave_timer := 1.0
var pickup_timer := 3.0
var elapsed := 0.0
var profile_timer := 0.0
var fps_value := 0.0
var auto_quality_timer := 0.0
var lod_timer := 0.0
var hud_timer := 0.0
const MAX_PROJECTILES := 12
var spawn_position := Vector3.ZERO

var running := false
var game_over := false
var final_boss_active := false
var transition_lock := false
var quality_level := 2

var score_label: Label
var wave_label: Label
var stage_label: Label
var health_bar: ProgressBar
var energy_bar: ProgressBar
var ammo_label: Label
var objective_label: Label
var message_label: Label
var profile_label: Label
var menu_panel: PanelContainer
var pause_panel: PanelContainer
var pause_button: Button
var fire_button: Button
var boost_button: Button
var joystick: Control
var touch_controls: Array[Control] = []

func _ready() -> void:
	rng.randomize()
	Engine.max_fps = 60
	call_deferred("_force_android_fullscreen")
	get_viewport().set_embedding_subwindows(false)
	save_system = SAVE_SCRIPT.new()
	add_child(save_system)
	save_system.load_state()
	best_score = save_system.best_score
	stage = max(1, save_system.stage)
	audio_manager = AUDIO_SCRIPT.new()
	add_child(audio_manager)
	_build_environment()
	_build_arena()
	_create_player()
	_create_camera()
	_build_ui()
	_show_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		call_deferred("_force_android_fullscreen")

func _process(delta: float) -> void:
	elapsed += delta
	hud_timer -= delta
	_profile_performance(delta)
	_update_lod(delta)
	if running and not game_over and not get_tree().paused:
		stage_time += delta
		wave_timer -= delta
		pickup_timer -= delta
		_update_projectiles(delta)
		_update_pickups(delta)
		_update_camera(delta)
		if wave_timer <= 0.0 and not transition_lock:
			_start_wave()
		if pickup_timer <= 0.0:
			_spawn_pickup()
			pickup_timer = rng.randf_range(4.0, 7.0)
		_check_stage_completion()
	if hud_timer <= 0.0:
		hud_timer = 0.10
		_update_hud()

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#03050d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#526b92")
	environment.ambient_light_energy = 0.82
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(-53.0, -31.0, 0.0)
	sun.light_color = Color("#c5d9ff")
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	add_child(sun)
	dynamic_lights.append(sun)
	if DisplayServer.is_touchscreen_available():
		DisplayServer.screen_set_keep_on(true)

func _build_arena() -> void:
	arena_root = Node3D.new()
	arena_root.name = "World"
	add_child(arena_root)
	spawn_position = Vector3(0, 0.1, 15)
	_build_sector_geometry()
	_build_landmarks()
	_build_stage_gate()

func _build_sector_geometry() -> void:
	var arena_size := 76.0
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	arena_root.add_child(ground)

	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(arena_size, 0.8, arena_size)
	floor_box.material = _mat(Color("#071322"), 0.45, 0.32, Color("#08446a"), 0.82)
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -0.4
	ground.add_child(floor_mesh)
	lod_nodes.append(floor_mesh)

	var floor_outline := MeshInstance3D.new()
	var outline_box := BoxMesh.new()
	outline_box.size = Vector3(arena_size - 2.0, 0.05, arena_size - 2.0)
	outline_box.material = _mat(Color("#0a2132"), 0.05, 0.2, Color("#2cddff"), 1.8)
	floor_outline.mesh = outline_box
	floor_outline.position.y = 0.015
	arena_root.add_child(floor_outline)

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(arena_size, 0.8, arena_size)
	collider.shape = shape
	collider.position.y = -0.4
	ground.add_child(collider)

	for side in [-1.0, 1.0]:
		_create_wall(Vector3(side * arena_size * 0.5, 2.6, 0.0), Vector3(0.8, 5.2, arena_size))
		_create_wall(Vector3(0.0, 2.6, side * arena_size * 0.5), Vector3(arena_size, 5.2, 0.8))

	for i in range(18):
		var angle := float(i) * TAU / 34.0 + rng.randf_range(-0.06, 0.06)
		var distance := rng.randf_range(10.5, 31.0)
		var p := Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		if p.distance_to(spawn_position) < 8.0:
			continue
		_create_obstacle(p, rng.randf_range(0.8, 2.4), rng.randf_range(1.8, 6.5), i % 3 == 0)

	for i in range(28):
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(8.0, 35.0)
		_create_neon_marker(Vector3(cos(angle) * distance, 0.025, sin(angle) * distance))

func _create_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	arena_root.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = _mat(Color("#0c182a"), 0.32, 0.38, Color("#183d62"), 0.75)
	mesh.mesh = box
	body.add_child(mesh)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	lod_nodes.append(mesh)

func _create_obstacle(pos: Vector3, radius: float, height: float, emissive: bool) -> void:
	var body := StaticBody3D.new()
	body.position = pos + Vector3.UP * (height * 0.5)
	arena_root.add_child(body)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.72
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.material = _mat(Color("#14263a"), 0.48, 0.3, Color("#2a567c") if not emissive else Color("#734cff"), 0.85 if not emissive else 1.8)
	mesh.mesh = cyl
	body.add_child(mesh)
	lod_nodes.append(mesh)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.72
	torus.outer_radius = radius * 0.82
	torus.material = _mat(Color("#4de4ff") if not emissive else Color("#ff5caf"), 0.15, 0.18, Color("#4de4ff") if not emissive else Color("#ff4eaa"), 2.1)
	ring.mesh = torus
	ring.position.y = height * 0.47
	body.add_child(ring)
	lod_nodes.append(ring)
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collider.shape = shape
	body.add_child(collider)

func _create_neon_marker(pos: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.035, rng.randf_range(0.8, 1.8))
	box.material = _mat(Color("#38d9ff"), 0.05, 0.16, Color("#38d9ff"), 2.2)
	marker.mesh = box
	marker.position = pos
	marker.rotation.y = rng.randf_range(0.0, TAU)
	arena_root.add_child(marker)
	lod_nodes.append(marker)

func _build_landmarks() -> void:
	for side in [-1.0, 1.0]:
		var tower := Node3D.new()
		tower.position = Vector3(side * 27.0, 0.0, -27.0)
		arena_root.add_child(tower)
		for j in range(3):
			var beam := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.42, 9.0, 0.42)
			box.material = _mat(Color("#1a2b41"), 0.45, 0.25, Color("#744fff"), 1.4)
			beam.mesh = box
			beam.position = Vector3((j - 1.5) * 2.2, 4.5, 0)
			tower.add_child(beam)
			lod_nodes.append(beam)

func _build_stage_gate() -> void:
	var gate := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(12.0, 0.3, 0.7)
	mesh.material = _mat(Color("#172b44"), 0.5, 0.2, Color("#5eeaff"), 2.0)
	gate.mesh = mesh
	gate.position = Vector3(0, 5.0, -34.0)
	arena_root.add_child(gate)
	lod_nodes.append(gate)

func _create_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.name = "Player"
	player.position = spawn_position
	add_child(player)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.fire_requested.connect(_on_player_fire)
	player.boost_requested.connect(_on_boost)
	player.energy_changed.connect(_on_player_energy_changed)

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.name = "GameplayCamera"
	camera.current = true
	add_child(camera)
	camera.global_position = Vector3(0, 9.0, 19.0)
	camera.fov = 67.0
	camera.look_at(Vector3(0, 1.0, 4.0), Vector3.UP)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	var top_margin := MarginContainer.new()
	top_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 18)
	top_margin.custom_minimum_size.y = 124
	layer.add_child(top_margin)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top_margin.add_child(top)

	stage_label = _label("STAGE 01", 24)
	wave_label = _label("WAVE 00", 24)
	score_label = _label("SCORE 000000", 24)
	ammo_label = _label("BLASTER READY", 18)
	top.add_child(stage_label)
	top.add_child(wave_label)
	top.add_child(score_label)
	top.add_child(ammo_label)

	var bars := VBoxContainer.new()
	bars.custom_minimum_size = Vector2(250, 70)
	top.add_child(bars)
	health_bar = ProgressBar.new()
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(240, 27)
	bars.add_child(health_bar)
	energy_bar = ProgressBar.new()
	energy_bar.max_value = 100.0
	energy_bar.value = 100.0
	energy_bar.show_percentage = false
	energy_bar.custom_minimum_size = Vector2(240, 18)
	bars.add_child(energy_bar)

	profile_label = _label("FPS --  |  -- ms  |  Q3", 14)
	profile_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	profile_label.position = Vector2(-190, 18)
	profile_label.size = Vector2(175, 36)
	profile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layer.add_child(profile_label)

	objective_label = _label("OBJECTIVE: SURVIVE", 18)
	objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	objective_label.position = Vector2(0, 88)
	objective_label.custom_minimum_size = Vector2(0, 34)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(objective_label)

	message_label = _label("", 28)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-320, 132)
	message_label.size = Vector2(640, 70)
	layer.add_child(message_label)

	pause_button = _button("Ⅱ", Vector2(70, 54), 22)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-84, 54)
	pause_button.pressed.connect(_toggle_pause)
	layer.add_child(pause_button)

	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var menu_box := VBoxContainer.new()
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 14)
	menu_panel.add_child(menu_box)
	var title := _label("NEON FRONTIER", 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(title)
	var subtitle := _label("ANDROID CAMPAIGN  •  3 STAGES  •  COMBAT SURVIVAL", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(subtitle)
	var best := _label("BEST SCORE  %06d" % best_score, 17)
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(best)
	var new_run := _button("NEW RUN", Vector2(300, 62), 24)
	new_run.pressed.connect(func():
		stage = 1
		score = 0
		_begin_run(false)
	)
	menu_box.add_child(new_run)
	if save_system.has_save():
		var continue_button := _button("CONTINUE", Vector2(300, 56), 20)
		continue_button.pressed.connect(func(): _begin_run(true))
		menu_box.add_child(continue_button)
	var info := _label("Move  •  FIRE  •  BOOST    |    Auto-save at every stage", 16)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_box.add_child(info)
	layer.add_child(menu_panel)

	pause_panel = PanelContainer.new()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-190, -150)
	pause_panel.size = Vector2(380, 300)
	var pause_box := VBoxContainer.new()
	pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_box.add_theme_constant_override("separation", 14)
	pause_panel.add_child(pause_box)
	var pause_title := _label("PAUSED", 42)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(pause_title)
	var resume := _button("RESUME", Vector2(250, 56), 20)
	resume.pressed.connect(_toggle_pause)
	pause_box.add_child(resume)
	var menu := _button("MAIN MENU", Vector2(250, 52), 18)
	menu.pressed.connect(func():
		get_tree().paused = false
		_show_menu()
	)
	pause_box.add_child(menu)
	layer.add_child(pause_panel)
	pause_panel.hide()

	_create_touch_controls(layer)

func _create_touch_controls(layer: CanvasLayer) -> void:
	joystick = JOYSTICK_SCRIPT.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(24, -236)
	joystick.custom_minimum_size = Vector2(210, 210)
	joystick.size = joystick.custom_minimum_size
	joystick.value_changed.connect(func(value: Vector2): player.set_move_input(value))
	joystick.released.connect(func(): player.clear_move_input())
	layer.add_child(joystick)
	touch_controls.append(joystick)

	boost_button = _button("BOOST", Vector2(132, 62), 17)
	fire_button = _button("FIRE", Vector2(132, 96), 22)
	boost_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	boost_button.position = Vector2(-158, -98)
	fire_button.position = Vector2(-158, -214)
	layer.add_child(boost_button)
	layer.add_child(fire_button)
	touch_controls.append(boost_button)
	touch_controls.append(fire_button)

	boost_button.pressed.connect(_boost_pressed)
	fire_button.button_down.connect(func(): player.set_fire_input(true))
	fire_button.button_up.connect(func(): player.set_fire_input(false))
	_set_touch_controls_visible(DisplayServer.is_touchscreen_available() or OS.get_name() == "Android")

func _begin_run(continue_run: bool) -> void:
	if continue_run:
		save_system.load_state()
		stage = max(1, save_system.stage)
		score = max(0, save_system.score)
	else:
		score = 0
	wave = 0
	enemies_defeated = 0
	running = true
	game_over = false
	final_boss_active = false
	transition_lock = false
	stage_time = 0.0
	wave_timer = 1.0
	pickup_timer = 2.5
	get_tree().paused = false
	menu_panel.hide()
	pause_panel.hide()
	player.reset_for_run()
	player.position = spawn_position
	_clear_dynamic_entities()
	_rebuild_stage(stage)
	message_label.text = "STAGE %02d  •  DEPLOY" % stage
	_play_sound("stage")
	objective_label.text = _stage_objective()
	_update_hud()

func _show_menu() -> void:
	running = false
	game_over = false
	get_tree().paused = false
	_clear_dynamic_entities()
	pause_panel.hide()
	menu_panel.show()
	pause_button.hide()
	for b in touch_controls:
		b.hide()
	message_label.text = ""
	objective_label.text = ""
	_update_hud()

func _rebuild_stage(stage_id: int) -> void:
	arena_root.rotation.y = float(stage_id - 1) * 0.12
	var tint: Color = [
		Color("#38d9ff"),
		Color("#8c65ff"),
		Color("#ff4f9a")
	][clamp(stage_id - 1, 0, 2)]
	for light in dynamic_lights:
		if is_instance_valid(light) and light is OmniLight3D:
			light.light_color = tint
	for marker in lod_nodes:
		if is_instance_valid(marker) and marker is MeshInstance3D:
			var m: Mesh = marker.mesh
			if m and m is BoxMesh and m.material is StandardMaterial3D:
				var material: StandardMaterial3D = m.material
				material.emission = tint
	spawn_position = Vector3(0, 0.1, 15) if stage_id != 2 else Vector3(0, 0.1, -14)
	player.position = spawn_position

func _start_wave() -> void:
	wave += 1
	wave_timer = 16.0
	var count: int = min(20, 3 + stage * 2 + wave)
	var difficulty := 0.9 + stage * 0.55 + wave * 0.18
	if stage == 3 and wave == 4:
		_spawn_enemy("juggernaut", difficulty + 1.5, true)
		final_boss_active = true
		message_label.text = "WARDEN PRIME  •  BOSS"
		objective_label.text = "OBJECTIVE: DEFEAT THE WARDEN"
	else:
		for i in range(count):
			var kind := "drone"
			var roll := rng.randi_range(0, 99)
			if stage >= 2 and roll < 28:
				kind = "striker"
			if stage >= 3 and roll < 16:
				kind = "juggernaut"
			_spawn_enemy(kind, difficulty, false)
		message_label.text = "WAVE %02d" % wave
		objective_label.text = "OBJECTIVE: SURVIVE WAVE %02d" % wave
	_play_sound("stage")
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(func():
		if running and not game_over and not final_boss_active:
			message_label.text = ""
	)

func _spawn_enemy(kind: String, difficulty: float, boss: bool) -> void:
	var enemy: CharacterBody3D = ENEMY_SCRIPT.new()
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(25.0, 32.0)
	enemy.position = Vector3(cos(angle) * distance, 0.15, sin(angle) * distance)
	add_child(enemy)
	enemy.setup(player, difficulty, kind, boss)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.attack_requested.connect(_on_enemy_attack)
	enemies.append(enemy)

func _on_enemy_attack(origin: Vector3, direction: Vector3, damage: float) -> void:
	if game_over:
		return
	_spawn_projectile(origin, direction, false, damage, 10.0, 6.5, Color("#ff4a79"))

func _on_player_fire(origin: Vector3, direction: Vector3, damage: float) -> void:
	if not running or game_over or get_tree().paused:
		return
	_spawn_projectile(origin, direction, true, damage, 26.0, 4.2, Color("#55eaff"))
	score = max(score, 0)
	_play_sound("shoot")

func _spawn_projectile(origin: Vector3, direction: Vector3, friendly: bool, damage: float, speed: float, lifetime: float, color: Color) -> void:
	if projectiles.size() >= MAX_PROJECTILES:
		var oldest: Node3D = projectiles.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var shot: Node3D = PROJECTILE_SCRIPT.new()
	shot.position = origin
	add_child(shot)
	shot.setup(direction.normalized(), friendly, damage, speed, lifetime, color)
	projectiles.append(shot)

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var shot := projectiles[i]
		if not is_instance_valid(shot):
			projectiles.remove_at(i)
			continue
		shot.advance(delta)
		if shot.expired:
			shot.queue_free()
			projectiles.remove_at(i)
			continue
		if shot.friendly:
			var hit := false
			for enemy in enemies:
				if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
					continue
				if shot.global_position.distance_to(enemy.global_position + Vector3.UP * 0.75) < shot.hit_radius:
					enemy.take_damage(shot.damage)
					_spawn_hit_fx(shot.global_position, Color("#67eaff"), 1.0)
					_play_sound("hit")
					shot.queue_free()
					projectiles.remove_at(i)
					hit = true
					break
			if hit:
				continue
		elif is_instance_valid(player) and shot.global_position.distance_to(player.global_position + Vector3.UP * 0.8) < shot.hit_radius:
			player.take_damage(shot.damage)
			_spawn_hit_fx(shot.global_position, Color("#ff5b85"), 0.9)
			_play_sound("hurt")
			shot.queue_free()
			projectiles.remove_at(i)
			continue
		if abs(shot.global_position.x) > 40.0 or abs(shot.global_position.z) > 40.0:
			shot.queue_free()
			projectiles.remove_at(i)

func _spawn_pickup() -> void:
	var orb := Area3D.new()
	orb.name = "EnergyPickup"
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	sphere.material = _mat(Color("#48ffd2"), 0.05, 0.12, Color("#2effd1"), 3.5)
	mesh.mesh = sphere
	orb.add_child(mesh)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.58
	torus.material = _mat(Color("#c1fff4"), 0.05, 0.08, Color("#3affd9"), 2.7)
	ring.mesh = torus
	ring.rotation_degrees.x = 90
	orb.add_child(ring)
	orb.position = Vector3(rng.randf_range(-27.0, 27.0), 0.8, rng.randf_range(-27.0, 27.0))
	add_child(orb)
	pickups.append(orb)

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var p := pickups[i]
		if not is_instance_valid(p):
			pickups.remove_at(i)
			continue
		p.rotation.y += delta * 2.4
		p.position.y = 0.8 + sin(elapsed * 4.0 + float(i)) * 0.15
		if player.global_position.distance_to(p.global_position) < 1.7:
			score += 90
			player.heal(11.0)
			player.restore_energy(28.0)
			_spawn_hit_fx(p.global_position, Color("#4effd4"), 1.2)
			_play_sound("pickup")
			p.queue_free()
			pickups.remove_at(i)

func _check_stage_completion() -> void:
	if transition_lock or not running:
		return
	if final_boss_active:
		return
	if wave >= 3 and enemies.is_empty() and wave_timer > 3.0:
		transition_lock = true
		_complete_stage()

func _complete_stage() -> void:
	score += 1000 * stage
	best_score = max(best_score, score)
	save_system.save_state(stage + 1, score, best_score)
	if stage >= 3:
		_win_game()
		return
	message_label.text = "STAGE %02d COMPLETE" % stage
	objective_label.text = "AUTO-SAVING  •  NEXT SECTOR UNLOCKED"
	_play_sound("stage")
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_callback(func():
		stage += 1
		wave = 0
		stage_time = 0.0
		transition_lock = false
		final_boss_active = false
		_clear_dynamic_entities()
		_rebuild_stage(stage)
		wave_timer = 1.2
		message_label.text = "SECTOR %02d" % stage
		objective_label.text = _stage_objective()
	)

func _stage_objective() -> String:
	if stage == 3:
		return "OBJECTIVE: REACH WARDEN PRIME"
	return "OBJECTIVE: CLEAR 3 WAVES"

func _on_enemy_defeated(enemy: Node3D, boss: bool) -> void:
	enemies.erase(enemy)
	enemies_defeated += 1
	var reward := 220 + stage * 75 + wave * 20
	if boss:
		reward = 3500
		final_boss_active = false
		score += reward
		save_system.save_state(4, score, max(best_score, score))
		message_label.text = "WARDEN PRIME DEFEATED"
		objective_label.text = "OBJECTIVE COMPLETE  •  CAMPAIGN CLEAR"
	else:
		score += reward
	_spawn_hit_fx(enemy.global_position + Vector3.UP * 0.7, Color("#ff5fa5") if not boss else Color("#ffd466"), 2.8 if boss else 1.5)
	_play_sound("explode" if boss else "hit")

	if boss:
		var tween := create_tween()
		tween.tween_interval(2.8)
		tween.tween_callback(_win_game)

func _win_game() -> void:
	if game_over:
		return
	game_over = true
	running = false
	best_score = max(best_score, score)
	save_system.save_state(4, score, best_score)
	message_label.text = "CAMPAIGN COMPLETE  •  %06d" % score
	objective_label.text = "ALL 3 STAGES CLEARED"
	for b in touch_controls:
		b.hide()
	pause_button.hide()
	_play_sound("stage")

func _on_player_health_changed(value: float) -> void:
	if health_bar:
		health_bar.value = value
	if value <= 30.0 and running:
		message_label.text = "CRITICAL HEALTH"

func _on_player_energy_changed(value: float) -> void:
	if energy_bar:
		energy_bar.value = value

func _on_player_died() -> void:
	game_over = true
	running = false
	best_score = max(best_score, score)
	save_system.save_state(stage, score, best_score)
	message_label.text = "RUN ENDED  •  SCORE %06d" % score
	objective_label.text = "PROGRESS SAVED  •  STAGE %02d" % stage
	for b in touch_controls:
		b.hide()
	pause_button.hide()
	_play_sound("hurt")

func _on_boost() -> void:
	if not running or game_over:
		return
	message_label.text = "BOOST ENGAGED"
	_spawn_hit_fx(player.global_position, Color("#63ecff"), 1.5)
	_play_sound("dash")
	var tween := create_tween()
	tween.tween_interval(0.45)
	tween.tween_callback(func():
		if running and not game_over:
			message_label.text = ""
	)

func _boost_pressed() -> void:
	if running and not game_over and not get_tree().paused:
		player.boost()

func _toggle_pause() -> void:
	if not running or game_over:
		return
	get_tree().paused = not get_tree().paused
	pause_panel.visible = get_tree().paused
	message_label.text = ""
	_play_sound("hit" if not get_tree().paused else "stage")

func _clear_dynamic_entities() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for p in projectiles:
		if is_instance_valid(p):
			p.queue_free()
	projectiles.clear()
	for p in pickups:
		if is_instance_valid(p):
			p.queue_free()
	pickups.clear()

func _spawn_hit_fx(pos: Vector3, color: Color, scale_value: float) -> void:
	if quality_level <= 0 and scale_value < 1.4:
		return
	var fx := GPUParticles3D.new()
	fx.one_shot = true
	fx.amount = int(7 + 5 * scale_value) if quality_level >= 2 else int(5 + 3 * scale_value)
	fx.lifetime = 0.34 + scale_value * 0.06
	fx.explosiveness = 1.0
	fx.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0 * scale_value
	pm.initial_velocity_max = 5.0 * scale_value
	pm.scale_min = 0.035
	pm.scale_max = 0.09 * scale_value
	pm.color = color
	fx.process_material = pm
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	sphere.material = _mat(color, 0.0, 0.12, color, 3.0)
	fx.draw_pass_1 = sphere
	add_child(fx)
	particle_nodes.append(fx)
	fx.emitting = true
	get_tree().create_timer(fx.lifetime + 0.15).timeout.connect(func():
		if is_instance_valid(fx):
			particle_nodes.erase(fx)
			fx.queue_free()
	)

func _profile_performance(delta: float) -> void:
	profile_timer += delta
	auto_quality_timer += delta
	if profile_timer >= 0.5:
		profile_timer = 0.0
		fps_value = Engine.get_frames_per_second()
		var frame_ms: float = 1000.0 / max(1.0, fps_value)
		if profile_label:
			profile_label.text = "FPS %d  |  %.1f ms  |  Q%d" % [int(fps_value), frame_ms, quality_level + 1]
	if auto_quality_timer >= 5.0:
		auto_quality_timer = 0.0
		if fps_value > 0.0 and fps_value < 42.0 and quality_level > 0:
			quality_level -= 1
			_apply_quality()
			message_label.text = "PERFORMANCE MODE Q%d" % (quality_level + 1)
		elif fps_value > 57.0 and quality_level < 2:
			quality_level += 1
			_apply_quality()

func _apply_quality() -> void:
	# Mobile profile: keep realtime shadow/light work disabled.
	for light in dynamic_lights:
		if is_instance_valid(light):
			light.shadow_enabled = false
	for fx in particle_nodes:
		if is_instance_valid(fx):
			fx.amount = max(4, int(float(fx.amount) * 0.8))

func _update_lod(delta: float) -> void:
	lod_timer += delta
	if lod_timer < 0.5 or not player:
		return
	lod_timer = 0.0
	var origin := player.global_position
	for node in lod_nodes:
		if is_instance_valid(node):
			var distance := node.global_position.distance_to(origin)
			node.visible = distance < 58.0

func _update_camera(delta: float) -> void:
	if not player or not camera:
		return
	var look_dir := -player.global_transform.basis.z
	var desired := player.global_position + Vector3(0, 7.8, 12.5)
	var side_offset := look_dir.cross(Vector3.UP).normalized() * 2.2
	desired += side_offset
	camera.global_position = camera.global_position.lerp(desired, min(1.0, delta * 5.0))
	camera.look_at(player.global_position + Vector3.UP * 0.95 - look_dir * 2.0, Vector3.UP)

func _update_hud() -> void:
	if not player:
		return
	if stage_label:
		stage_label.text = "STAGE %02d" % stage
	if wave_label:
		wave_label.text = "WAVE %02d" % wave
	if score_label:
		score_label.text = "SCORE %06d" % score
	if ammo_label:
		ammo_label.text = "BLASTER  •  %.1fs" % player.fire_cooldown
	if health_bar:
		health_bar.value = player.health
	if energy_bar:
		energy_bar.value = player.energy
	if pause_button:
		pause_button.visible = running and not game_over
	if running and not game_over and not get_tree().paused:
		for b in touch_controls:
			b.show()

func _play_sound(kind: String) -> void:
	if is_instance_valid(audio_manager) and audio_manager.has_method("play_sound"):
		audio_manager.play_sound(kind)

func _force_android_fullscreen() -> void:
	if OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayServer.screen_set_keep_on(true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _set_touch_controls_visible(visible_value: bool) -> void:
	for control in touch_controls:
		if is_instance_valid(control):
			control.visible = visible_value

func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#eaf8ff"))
	return label

func _button(text_value: String, size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font_size)
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
