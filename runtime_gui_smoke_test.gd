extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(value: bool,label: String) -> void:
	if not value:
		failures.append(label)

func _click(control: Control) -> void:
	if control == null:
		_check(false,"control exists")
		return
	var center := control.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
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
	await create_timer(0.5).timeout

	_check(game.start_button != null,"DEPLOY exists")
	_check(game.map_buttons.size() == 3,"three missions exist")
	_check(game.fire_button != null,"FIRE exists")
	_check(game.boost_button != null,"BOOST exists")
	_check(game.pulse_button != null,"PULSE exists")
	_check(game.shield_button != null,"SHIELD exists")
	_check(game.reload_button != null,"RELOAD exists")
	_check(game.pause_button != null,"PAUSE exists")
	_check(game.get_ui_state().controls.size() > 8,"native UI introspection")

	await _click(game.map_buttons[0])
	_check(game.selected_map == 0,"mission one")
	await _click(game.map_buttons[1])
	_check(game.selected_map == 1,"mission two")
	await _click(game.map_buttons[2])
	_check(game.selected_map == 2,"mission three")

	await _click(game.start_button)
	await create_timer(0.5).timeout
	_check(game.running,"DEPLOY starts")
	_check(game.touch_root.visible,"touch controls visible")

	var ammo: int = game.player.ammo
	await _click(game.fire_button)
	await create_timer(0.16).timeout
	_check(game.player.ammo < ammo or game.shots.size() > 0,"FIRE changes combat")

	var energy: float = game.player.energy
	await _click(game.boost_button)
	_check(game.player.boost_time > 0.0,"BOOST activates")
	_check(game.player.energy < energy,"BOOST spends energy")

	game.player.energy = game.player.max_energy
	energy = game.player.energy
	await _click(game.pulse_button)
	_check(game.player.tactical_cooldown > 0.0,"PULSE activates")
	_check(game.player.energy < energy,"PULSE spends energy")

	game.player.energy = game.player.max_energy
	energy = game.player.energy
	await _click(game.shield_button)
	_check(game.player.shield_time > 0.0,"SHIELD activates")
	_check(game.player.energy < energy,"SHIELD spends energy")

	game.player.ammo = 5
	game.player.ammo_changed.emit(5,game.player.magazine_size)
	await _click(game.reload_button)
	await create_timer(1.2).timeout
	_check(game.player.ammo == game.player.magazine_size,"RELOAD completes")

	await _click(game.pause_button)
	await process_frame
	_check(paused,"PAUSE changes SceneTree")
	_check(game.pause_panel.visible,"pause menu visible")

	var resume := game.resume_button
	await _click(resume)
	await process_frame
	_check(not paused,"RESUME changes SceneTree")

	game.stage = 3
	game.wave = 3
	game._spawn_wave()
	await process_frame
	_check(game.boss_active,"boss activates")

	game.free()
	await process_frame
	await process_frame

	if failures.is_empty():
		print("GUI SMOKE TEST PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("GUI SMOKE TEST FAILURE: "+failure)
		quit(1)
