extends SceneTree

var failures: Array[String] = []

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _capture(game, filename: String) -> void:
	await process_frame
	await create_timer(0.35).timeout
	var image := game.get_viewport().get_texture().get_image()
	image.save_png(filename)

func _click_control(control: Control) -> void:
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
	_check(scene != null, "Main.tscn loads")
	if scene == null:
		quit(1)
		return

	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(1.0).timeout

	_check(game.fire_button != null, "FIRE button exists")
	_check(game.boost_button != null, "BOOST button exists")
	_check(game.tactical_button != null, "TACTICAL button exists")
	_check(game.shield_button != null, "SHIELD button exists")
	_check(game.pause_button != null, "PAUSE button exists")

	await _capture(game, "build/gui/menu.png")
	_check(game.running == false, "menu starts stopped")

	await _click_control(game.fire_button)
	await create_timer(0.25).timeout
	_check(game.projectiles.size() > 0, "visual FIRE click spawns projectile")

	var energy_before: float = game.player.energy
	await _click_control(game.boost_button)
	_check(game.player.boost_time > 0.0, "visual BOOST click activates")
	_check(game.player.energy < energy_before, "visual BOOST click consumes energy")

	game.player.energy = game.player.max_energy
	game.player.energy_changed.emit(game.player.energy)
	energy_before = game.player.energy
	await _click_control(game.tactical_button)
	_check(game.player.tactical_cooldown > 0.0, "visual TACTICAL click activates")
	_check(game.player.energy < energy_before, "visual TACTICAL click consumes energy")

	game.player.energy = game.player.max_energy
	game.player.energy_changed.emit(game.player.energy)
	energy_before = game.player.energy
	await _click_control(game.shield_button)
	_check(game.player.shield_time > 0.0, "visual SHIELD click activates")
	_check(game.player.energy < energy_before, "visual SHIELD click consumes energy")

	await _capture(game, "build/gui/running.png")
	
	await _click_control(game.pause_button)
	await process_frame
	_check(paused, "visual PAUSE click pauses")
	await _capture(game, "build/gui/paused.png")

	await _click_control(game.pause_button)
	await process_frame
	_check(not paused, "visual PAUSE click resumes")

	var exit_code := 0
	if failures.is_empty():
		print("GUI SMOKE TEST PASS")
	else:
		for failure in failures:
			push_error("GUI SMOKE TEST FAILURE: " + failure)
		exit_code = 1

	game.queue_free()
	await process_frame
	quit(exit_code)
