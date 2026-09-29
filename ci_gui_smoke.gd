extends Node

var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_environment("CI_GUI_SMOKE") != "1":
		return
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)

func _click(control: Control) -> void:
	if control == null:
		_check(false, "control exists")
		return
	var point := control.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = point
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	Input.parse_input_event(up)
	await get_tree().process_frame

func _run() -> void:
	var game = get_tree().current_scene
	var deadline := Time.get_ticks_msec() + 5000
	while game == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		game = get_tree().current_scene
	_check(game != null, "Main scene running")
	if game == null:
		push_error("GUI SMOKE TEST FAILURE: Main scene did not become available within 5 seconds")
		get_tree().quit(1)
		return
	game.process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(0.7).timeout

	var display_backend := DisplayServer.get_name()
	_check(display_backend == "headless" or display_backend == "Wayland", "supported native Godot display backend")
	_check(game.start_button != null, "DEPLOY exists")
	_check(game.map_buttons.size() == 3, "three missions exist")
	_check(game.fire_button != null, "FIRE exists")
	_check(game.boost_button != null, "BOOST exists")
	_check(game.pulse_button != null, "PULSE exists")
	_check(game.shield_button != null, "SHIELD exists")
	_check(game.reload_button != null, "RELOAD exists")
	_check(game.pause_button != null, "PAUSE exists")

	await _click(game.map_buttons[0])
	_check(game.selected_map == 0, "mission 1")
	await _click(game.map_buttons[1])
	_check(game.selected_map == 1, "mission 2")
	await _click(game.map_buttons[2])
	_check(game.selected_map == 2, "mission 3")

	await _click(game.start_button)
	await get_tree().create_timer(0.5).timeout
	_check(game.running, "DEPLOY starts")
	_check(game.touch_root.visible, "touch controls visible")

	var ammo_before: int = game.player.ammo
	await _click(game.fire_button)
	await get_tree().create_timer(0.18).timeout
	_check(game.player.ammo < ammo_before or game.projectiles.size() > 0, "FIRE changes state")

	var energy_before: float = game.player.energy
	await _click(game.boost_button)
	_check(game.player.boost_time > 0.0, "BOOST activates")
	_check(game.player.energy < energy_before, "BOOST spends energy")

	game.player.energy = game.player.max_energy
	energy_before = game.player.energy
	await _click(game.pulse_button)
	_check(game.player.tactical_cooldown > 0.0, "PULSE activates")
	_check(game.player.energy < energy_before, "PULSE spends energy")

	game.player.energy = game.player.max_energy
	energy_before = game.player.energy
	await _click(game.shield_button)
	_check(game.player.shield_time > 0.0, "SHIELD activates")
	_check(game.player.energy < energy_before, "SHIELD spends energy")

	game.player.ammo = 5
	game.player.ammo_changed.emit(5, game.player.magazine_size)
	await _click(game.reload_button)
	await get_tree().create_timer(1.2).timeout
	_check(game.player.ammo == game.player.magazine_size, "RELOAD completes")
	_check(game.fx_nodes.is_empty(), "temporary VFX cleaned")

	await _click(game.pause_button)
	await get_tree().process_frame
	_check(get_tree().paused, "PAUSE pauses")
	_check(game.pause_panel.visible, "pause panel visible")

	await _click(game.resume_button)
	await get_tree().process_frame
	_check(not get_tree().paused, "RESUME resumes")

	game.stage = 3
	game.wave = 3
	game._start_wave()
	await get_tree().process_frame
	_check(game.boss_active, "boss activates")
	_check(game.boss_bar.visible, "boss bar visible")

	get_tree().paused = false
	game.queue_free()
	game = null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	if failures.is_empty():
		print("GUI SMOKE TEST PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("GUI SMOKE TEST FAILURE: " + failure)
	get_tree().quit(1)
