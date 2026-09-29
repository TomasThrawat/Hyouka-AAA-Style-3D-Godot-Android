extends Node

var patched: bool = false

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pause := scene.find_child("PauseButton", true, false) as Button
	var touch_root := scene.find_child("TouchRoot", true, false) as Control
	if pause == null or touch_root == null:
		return
	if pause.get_parent() != touch_root:
		pause.reparent(touch_root, true)
	var viewport_size: Vector2 = scene.get_viewport().get_visible_rect().size
	pause.position = Vector2(max(24.0, viewport_size.x - 100.0), 55.0)
	pause.z_index = 1000
	pause.mouse_filter = Control.MOUSE_FILTER_STOP
	patched = true
	set_process(false)

func _input(event: InputEvent) -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("get_runtime_state"):
		return
	if not bool(scene.running) or bool(scene.game_over) or scene.get_tree().paused:
		return
	var pause := scene.find_child("PauseButton", true, false) as Button
	if pause == null or not pause.visible:
		return

	var hit: bool = false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		hit = mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed and pause.get_global_rect().has_point(mouse.position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		hit = touch.pressed and pause.get_global_rect().has_point(touch.position)

	if hit and scene.has_method("_toggle_pause"):
		scene._toggle_pause()
		get_viewport().set_input_as_handled()
