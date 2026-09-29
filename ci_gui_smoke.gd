extends SceneTree

var failures: Array[String] = []
var game: Node = null

func _init() -> void:
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
	await process_frame

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	Input.parse_input_event(up)
	await process_frame

func _run() -> void:
	print("GUI SMOKE TEST START")

	var packed := load("res://Main.tscn") as PackedScene
	_check(packed != null, "Main scene loads")
	if packed == null:
		push_error("GUI SMOKE TEST FAILURE: Main scene failed to load")
		quit(1)
		return

	game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.7).timeout

	_check(game != null, "game instance exists")
	_check(game.start_button != null, "DEPLOY exists")
	_check(game.map_buttons.size() == 3, "three missions exist")
	_check(game.fire_button != null, "FIRE exists")
	_check(game.boost_button != null, "BOOST exists")
	_check(game.pulse_button != null, "PULSE exists")
	_check(game.shield_button != null, "SHIELD exists")
	_check(game.reload_button != null, "RELOAD exists")
	_check(game.pause_button != null, "PAUSE exists")
	_check(game.resume_button != null, "RESUME exists")
	_check(game.get_ui_state().controls.size() > 8, "native UI introspection")

	await _click(game.map_buttons[0])
	_check(game.selected_map == 0, "mission 1")
	await _click(game.map_buttons[1])
	_check(game.selected_map == 1, "mission 2")
	await _click(game.map_buttons[2])
	_check(game.selected_map == 2, "mission 3")

	await _click(game.start_button)
	await create_timer(0.5).timeout
	_check(game.running, "DEPLOY starts")
	_check(game.touch_root.visible, "touch controls visible")

	var ammo_before: int = game.player.ammo
	await _click(game.fire_button)
	await create_timer(0.18).timeout
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
	await create_timer(1.2).timeout
	_check(game.player.ammo == game.player.magazine_size, "RELOAD completes")
	_check(game.fx_nodes.is_empty(), "temporary VFX cleaned")

	await _click(game.pause_button)
	await process_frame
	_check(paused, "PAUSE pauses")
	_check(game.pause_panel.visible, "pause menu visible")

	await _click(game.resume_button)
	await process_frame
	_check(not paused, "RESUME resumes")

	game.stage = 3
	game.wave = 3
	game._start_wave()
	await process_frame
	_check(game.boss_active, "boss activates")
	_check(game.boss_bar.visible, "boss bar visible")

	paused = false
	if is_instance_valid(game):
		game.free()
	game = null
	await process_frame
	await process_frame

	if failures.is_empty():
		print("GUI SMOKE TEST PASS")
		quit(0)
		return

	for failure in failures:
		push_error("GUI SMOKE TEST FAILURE: " + failure)
	quit(1)
