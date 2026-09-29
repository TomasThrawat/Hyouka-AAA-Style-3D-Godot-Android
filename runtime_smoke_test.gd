extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool,label: String) -> void:
	if not condition:
		failures.append(label)

func _run() -> void:
	var scene := load("res://Main.tscn")
	_check(scene != null,"Main scene loads")
	if scene == null:
		quit(1)
		return

	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.35).timeout

	_check(game.player != null,"player exists")
	_check(game.start_button != null,"DEPLOY exists")
	_check(game.fire_button != null,"FIRE exists")
	_check(game.boost_button != null,"BOOST exists")
	_check(game.tactical_button != null,"PULSE exists")
	_check(game.shield_button != null,"SHIELD exists")
	_check(game.reload_button != null,"RELOAD exists")
	_check(game.pause_button != null,"PAUSE exists")
	_check(game.map_buttons.size() == 3,"three missions exist")

	game._start_game_pressed()
	await create_timer(0.35).timeout
	_check(game.running,"DEPLOY starts")
	_check(game.touch_root.visible,"touch controls visible")

	var ammo_before: int = game.player.ammo
	game.player.set_fire_input(true)
	await create_timer(0.16).timeout
	game.player.set_fire_input(false)
	_check(game.player.ammo < ammo_before or game.projectiles.size() > 0,"fire state changes")

	var energy_before: float = game.player.energy
	game.player.boost()
	_check(game.player.boost_time > 0.0,"boost activates")
	_check(game.player.energy < energy_before,"boost energy")

	game.player.energy = game.player.max_energy
	energy_before = game.player.energy
	game.player.tactical()
	_check(game.player.tactical_cooldown > 0.0,"pulse activates")
	_check(game.player.energy < energy_before,"pulse energy")

	game.player.energy = game.player.max_energy
	energy_before = game.player.energy
	game.player.shield()
	_check(game.player.shield_time > 0.0,"shield activates")
	_check(game.player.energy < energy_before,"shield energy")

	game.player.ammo = 5
	game.player.ammo_changed.emit(5,game.player.magazine_size)
	game.player.reload()
	await create_timer(1.2).timeout
	_check(game.player.ammo == game.player.magazine_size,"reload completes")

	game.stage = 3
	game.wave = 3
	game.transition_lock = false
	game.boss_active = false
	game._start_next_wave()
	await process_frame
	_check(game.boss_active,"boss activates")
	_check(game.boss_bar.visible,"boss bar visible")

	game.free()
	await process_frame
	await process_frame

	if failures.is_empty():
		print("SELF TEST PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("SELF TEST FAILURE: " + failure)
		quit(1)
