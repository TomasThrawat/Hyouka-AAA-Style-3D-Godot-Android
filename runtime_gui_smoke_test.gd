extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _click_control(control: Control) -> void:
	var center := control.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	root.get_viewport().push_input(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	root.get_viewport().push_input(up)
	await process_frame

func _run() -> void:
	var scene := load("res://Main.tscn")
	_check(scene != null, "scene loads")
	if scene == null:
		quit(1)
		return

	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.8).timeout

	_check(game.start_button != null, "DEPLOY exists")
	_check(game.map_buttons.size() == 3, "mission selection exists")
	_check(not game.running, "menu state")

	for i in range(3):
		await _click_control(game.map_buttons[i])
		_check(game.selected_map == i, "mission selector %d" % (i + 1))

	await _click_control(game.start_button)
	await create_timer(0.6).timeout
	_check(game.running, "DEPLOY starts")
	_check(game.touch_root.visible, "touch controls visible")

	var before_ammo: int = game.player.ammo
	await _click_control(game.fire_button)
	await create_timer(0.16).timeout
	_check(game.player.ammo < before_ammo or game.projectiles.size() > 0, "FIRE click changes state")

	var before_energy: float = game.player.energy
	await _click_control(game.boost_button)
	_check(game.player.boost_time > 0.0, "BOOST click activates")
	_check(game.player.energy < before_energy, "BOOST click consumes energy")

	game.player.energy = game.player.max_energy
	before_energy = game.player.energy
	await _click_control(game.tactical_button)
	_check(game.player.tactical_cooldown > 0.0, "PULSE click activates")
	_check(game.player.energy < before_energy, "PULSE click consumes energy")

	game.player.energy = game.player.max_energy
	before_energy = game.player.energy
	await _click_control(game.shield_button)
	_check(game.player.shield_time > 0.0, "SHIELD click activates")
	_check(game.player.energy < before_energy, "SHIELD click consumes energy")

	game.player.ammo = 5
	game.player.ammo_changed.emit(5, game.player.magazine_size)
	await _click_control(game.reload_button)
	await create_timer(1.2).timeout
	_check(game.player.ammo == game.player.magazine_size, "RELOAD click completes")

	await _click_control(game.pause_button)
	await process_frame
	_check(paused, "PAUSE click pauses")
	_check(game.pause_panel.visible, "pause menu visible")

	var resume := game.pause_panel.get_node("VBoxContainer/ResumeButton") as Button
	await _click_control(resume)
	_check(not paused, "RESUME click resumes")

	var runtime_state: Dictionary = game.get_runtime_state()
	_check(runtime_state.running, "runtime state says running")
	_check(runtime_state.player.has("health"), "runtime player state exists")

	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("GUI SMOKE TEST PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("GUI SMOKE TEST FAILURE: " + failure)
		quit(1)
