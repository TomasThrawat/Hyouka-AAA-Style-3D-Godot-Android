extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(value: bool,label: String) -> void:
	if not value:
		failures.append(label)

func _input_click(control: Control) -> void:
	if control == null:
		_check(false,"control exists")
		return
	var p := control.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p
	Input.parse_input_event(up)
	await process_frame

func _run() -> void:
	var scene := load("res://Main.tscn")
	_check(scene != null,"Main scene loads")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.7).timeout

	_check(DisplayServer.get_name() == "Wayland","Wayland display backend")
	_check(game.start_button != null,"DEPLOY exists")
	_check(game.map_buttons.size() == 3,"three missions exist")
	_check(game.fire_button != null,"FIRE exists")
	_check(game.boost_button != null,"BOOST exists")
	_check(game.pulse_button != null,"PULSE exists")
	_check(game.shield_button != null,"SHIELD exists")
	_check(game.reload_button != null,"RELOAD exists")
	_check(game.pause_button != null,"PAUSE exists")

	await _input_click(game.map_buttons[0])
	_check(game.selected_map == 0,"mission 1")
	await _input_click(game.map_buttons[1])
	_check(game.selected_map == 1,"mission 2")
	await _input_click(game.map_buttons[2])
	_check(game.selected_map == 2,"mission 3")

	await _input_click(game.start_button)
	await create_timer(0.5).timeout
	_check(game.running,"DEPLOY starts")
	_check(game.touch_root.visible,"touch controls visible")

	var ammo_before: int = game.player.ammo
	await _input_click(game.fire_button)
	await create_timer(0.18).timeout
	_check(game.player.ammo < ammo_before or game.projectiles.size() > 0,"FIRE changes state")

	var energy_before: float = game.player.energy
	await _input_click(game.boost_button)
	_check(game.player.boost_time > 0.0,"BOOST activates")
	_check(game.player.energy < energy_before,"BOOST spends energy")

	game.player.energy = game.player.max_energy
	energy_before = game.player.energy
	await _input_click(game.pulse_button)
	_check(game.player.tactical_cooldown > 0.0,"PULSE activates")
	_check(game.player.energy < energy_before,"PULSE spends energy")

	game.player.energy = game.player.max_energy
	energy_before = game.player.energy
	await _input_click(game.shield_button)
	_check(game.player.shield_time > 0.0,"SHIELD activates")
	_check(game.player.energy < energy_before,"SHIELD spends energy")

	game.player.ammo = 5
	game.player.ammo_changed.emit(5,game.player.magazine_size)
	await _input_click(game.reload_button)
	await create_timer(1.2).timeout
	_check(game.player.ammo == game.player.magazine_size,"RELOAD completes")
	_check(game.fx_nodes.is_empty(),"temporary VFX cleaned")

	await _input_click(game.pause_button)
	await process_frame
	_check(paused,"PAUSE pauses")
	_check(game.pause_panel.visible,"pause panel visible")
	await _input_click(game.resume_button)
	await process_frame
	_check(not paused,"RESUME resumes")

	game.stage = 3
	game.wave = 3
	game._start_wave()
	await process_frame
	_check(game.boss_active,"boss activates")
	_check(game.boss_bar.visible,"boss bar visible")

	paused = false
	Input.flush_buffered_events()
	game.queue_free()
	game = null
	scene = null
	await process_frame
	await process_frame
	await process_frame
	Input.flush_buffered_events()
	await process_frame

	if failures.is_empty():
		print("GUI SMOKE TEST PASS")
		quit(0)
	for failure in failures:
		push_error("GUI SMOKE TEST FAILURE: "+failure)
	quit(1)
