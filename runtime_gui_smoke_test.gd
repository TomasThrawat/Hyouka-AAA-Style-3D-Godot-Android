extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool,label: String) -> void:
	if not condition:
		failures.append(label)

func _click(control: Control) -> void:
	if control == null:
		_check(false,"click target exists")
		return
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
	_check(scene != null,"Main.tscn loads")
	if scene == null:
		quit(1)
		return

	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.7).timeout

	_check(game.start_button != null,"DEPLOY exists")
	_check(game.map_buttons.size() == 3,"three mission buttons exist")
	_check(game.fire_button != null,"FIRE exists")
	_check(game.boost_button != null,"BOOST exists")
	_check(game.tactical_button != null,"PULSE exists")
	_check(game.shield_button != null,"SHIELD exists")
	_check(game.reload_button != null,"RELOAD exists")
	_check(game.pause_button != null,"PAUSE exists")
	_check(game.get_ui_state().controls.size() > 8,"native UI state enumerates controls")

	for i in range(3):
		await _click(game.map_buttons[i])
		_check(game.selected_map == i,"mission selector %d" % (i+1))

	await _click(game.start_button)
	await create_timer(0.5).timeout
	_check(game.running,"DEPLOY starts")
	_check(game.touch_root.visible,"touch controls visible")

	var ammo_before: int = game.player.ammo
	await _click(game.fire_button)
	await create_timer(0.16).timeout
	_check(game.player.ammo < ammo_before or game.projectiles.size() > 0,"FIRE changes state")

	var energy_before: float = game.player.energy
	await _click(game.boost_button)
	_check(game.player.boost_time > 0.0,"BOOST activates")
	_check(game.player.energy < energy_before,"BOOST consumes energy")

	game.player.energy = game.player.max_energy
	energy_before = game.player.energy
	await _click(game.tactical_button)
	_check(game.player.tactical_cooldown > 0.0,"PULSE activates")
	_check(game.player.energy < energy_before,"PULSE consumes energy")

	game.player.energy = game.player.max_energy
	energy_before = game.player.energy
	await _click(game.shield_button)
	_check(game.player.shield_time > 0.0,"SHIELD activates")
	_check(game.player.energy < energy_before,"SHIELD consumes energy")

	game.player.ammo = 5
	game.player.ammo_changed.emit(5,game.player.magazine_size)
	await _click(game.reload_button)
	await create_timer(1.2).timeout
	_check(game.player.ammo == game.player.magazine_size,"RELOAD completes")

	await _click(game.pause_button)
	await process_frame
	_check(paused,"PAUSE pauses")
	_check(game.pause_panel.visible,"pause menu visible")
	var resume := game.pause_panel.find_child("ResumeButton",true,false) as Button
	_check(resume != null,"RESUME exists")
	if resume != null:
		await _click(resume)
		_check(not paused,"RESUME resumes")

	var runtime_state: Dictionary = game.get_runtime_state()
	_check(bool(runtime_state["running"]),"runtime state running")
	_check(runtime_state["player"].has("health"),"player state exists")

	game.stage = 3
	game.wave = 3
	game.transition_lock = false
	game.boss_active = false
	game._start_next_wave()
	await process_frame
	_check(game.boss_active,"boss activates")
	_check(game.boss_bar.visible,"boss bar visible")

	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("GUI SMOKE TEST PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("GUI SMOKE TEST FAILURE: " + failure)
		quit(1)
