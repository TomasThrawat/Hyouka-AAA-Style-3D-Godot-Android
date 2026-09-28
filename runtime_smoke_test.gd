extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _run() -> void:
	var game_scene := load("res://Main.tscn")
	_check(game_scene != null, "Main.tscn load")
	if game_scene == null:
		quit(1)
		return

	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.45).timeout

	_check(game.player != null, "player exists")
	_check(game.joystick != null, "joystick exists")
	_check(game.fire_button != null, "fire button exists")
	_check(game.boost_button != null, "boost button exists")
	_check(game.tactical_button != null, "tactical button exists")
	_check(game.shield_button != null, "shield button exists")
	_check(game.pause_button != null, "pause button exists")
	_check(game.fire_button.text.find("FIRE") >= 0, "FIRE button label")
	_check(game.boost_button.text.find("BOOST") >= 0, "BOOST button label")
	_check(game.map_buttons.size() == 3, "three map buttons exist")

	for i in range(game.map_buttons.size()):
		game.map_buttons[i].pressed.emit()
		await process_frame
		_check(game.selected_map == i, "map button %d selects map" % i)

	game._start_game_pressed()
	await create_timer(0.8).timeout
	_check(game.running, "game starts")

	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 17
	touch_down.pressed = true
	touch_down.position = game.joystick.global_position + Vector2(100, 100)
	game.joystick._gui_input(touch_down)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 17
	touch_drag.position = touch_down.position + Vector2(0, 58)
	game.joystick._gui_input(touch_drag)
	_check(game.player.move_stick.y > 0.5, "touch joystick follows downward drag")
	var touch_up := InputEventScreenTouch.new()
	touch_up.index = 17
	touch_up.pressed = false
	touch_up.position = touch_drag.position
	game.joystick._gui_input(touch_up)
	_check(game.player.move_stick == Vector2.ZERO, "touch joystick releases")

	game.fire_button.button_down.emit()
	await create_timer(0.28).timeout
	game.fire_button.button_up.emit()
	_check(game.projectiles.size() > 0, "FIRE button spawns projectile")

	var energy_before := game.player.energy
	game.boost_button.pressed.emit()
	_check(game.player.boost_time > 0.0, "BOOST button activates")
	_check(game.player.energy < energy_before, "BOOST consumes energy")

	energy_before = game.player.energy
	game.tactical_button.pressed.emit()
	_check(game.player.tactical_cooldown > 0.0, "TACTICAL button activates")
	_check(game.player.energy < energy_before, "TACTICAL consumes energy")

	game.player.energy = game.player.max_energy
	game.player.energy_changed.emit(game.player.energy)
	energy_before = game.player.energy
	game.shield_button.pressed.emit()
	_check(game.player.shield_time > 0.0, "SHIELD button activates")
	_check(game.player.energy < energy_before, "SHIELD consumes energy")

	game.pause_button.pressed.emit()
	await process_frame
	_check(paused, "PAUSE button pauses")
	game.pause_button.pressed.emit()
	await process_frame
	_check(not paused, "PAUSE button resumes")

	game.stage = 3
	game.wave = 3
	game.final_boss_active = false
	game._start_wave()
	await process_frame
	_check(game.final_boss_active, "boss wave activates")
	_check(game.boss_bar.visible, "boss health bar appears")

	if failures.is_empty():
		print("SELF TEST PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("SELF TEST FAILURE: " + failure)
		quit(1)
