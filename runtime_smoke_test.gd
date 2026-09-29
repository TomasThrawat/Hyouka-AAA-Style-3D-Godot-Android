extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _run() -> void:
	var scene := load("res://Main.tscn")
	_check(scene != null, "Main.tscn loads")
	if scene == null:
		quit(1)
		return

	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.45).timeout

	_check(game.player != null, "player exists")
	_check(game.start_button != null, "DEPLOY exists")
	_check(game.fire_button != null, "FIRE exists")
	_check(game.boost_button != null, "BOOST exists")
	_check(game.tactical_button != null, "PULSE exists")
	_check(game.shield_button != null, "SHIELD exists")
	_check(game.reload_button != null, "RELOAD exists")
	_check(game.pause_button != null, "PAUSE exists")
	_check(game.map_buttons.size() == 3, "three mission buttons exist")
	_check(game.get_ui_state().controls.size() > 8, "native UI state enumerates controls")

	for i in range(3):
		game._select_map(i)
		await process_frame
		_check(game.selected_map == i, "mission selection %d" % (i + 1))

	game._start_game_pressed()
	await create_timer(0.35).timeout
	_check(game.running, "game starts")
	_check(not game.menu_panel.visible, "menu closes")
	_check(game.touch_root.visible, "touch controls show")

	var before_ammo: int = game.player.ammo
	game.fire_button.button_down.emit()
	await create_timer(0.16).timeout
	game.fire_button.button_up.emit()
	_check(game.player.ammo < before_ammo or game.projectiles.size() > 0, "FIRE changes combat state")

	var before_energy: float = game.player.energy
	game.boost_button.pressed.emit()
	_check(game.player.boost_time > 0.0, "BOOST activates")
	_check(game.player.energy < before_energy, "BOOST consumes energy")

	game.player.energy = game.player.max_energy
	before_energy = game.player.energy
	game.tactical_button.pressed.emit()
	_check(game.player.tactical_cooldown > 0.0, "PULSE activates")
	_check(game.player.energy < before_energy, "PULSE consumes energy")

	game.player.energy = game.player.max_energy
	before_energy = game.player.energy
	game.shield_button.pressed.emit()
	_check(game.player.shield_time > 0.0, "SHIELD activates")
	_check(game.player.energy < before_energy, "SHIELD consumes energy")

	game.player.ammo = 5
	game.player.ammo_changed.emit(5, game.player.magazine_size)
	game.reload_button.pressed.emit()
	_check(game.player.reload_timer > 0.0, "RELOAD activates")
	await create_timer(1.2).timeout
	_check(game.player.ammo == game.player.magazine_size, "RELOAD completes")

	game.pause_button.pressed.emit()
	await process_frame
	_check(paused, "PAUSE activates")
	_check(game.pause_panel.visible, "pause panel visible")
	game.pause_panel.get_node("VBoxContainer/ResumeButton").pressed.emit()
	await process_frame
	_check(not paused, "RESUME activates")

	var state := game.get_runtime_state()
	_check(state.running, "runtime state reports running")
	_check(state.player.has("health"), "runtime player state exists")

	game.stage = 3
	game.wave = 3
	game.boss_active = false
	game._start_next_wave()
	await process_frame
	_check(game.boss_active, "boss activates")
	_check(game.boss_bar.visible, "boss bar visible")

	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("SELF TEST PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("SELF TEST FAILURE: " + failure)
		quit(1)
