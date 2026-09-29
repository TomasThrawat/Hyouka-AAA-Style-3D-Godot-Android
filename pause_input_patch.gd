extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)

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
	var size: Vector2 = scene.get_viewport().get_visible_rect().size
	pause.position = Vector2(max(24.0, size.x - 100.0), 55.0)
	pause.z_index = 1000
	pause.mouse_filter = Control.MOUSE_FILTER_STOP
	var resume := scene.find_child("ResumeButton", true, false) as Button
	var home := scene.find_child("MainMenuButton", true, false) as Button
	if resume != null:
		resume.process_mode = Node.PROCESS_MODE_ALWAYS
	if home != null:
		home.process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func _input(event: InputEvent) -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("get_runtime_state"):
		return

	var point := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		point = mouse.position
		pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		point = touch.position
		pressed = touch.pressed

	if not pressed:
		return

	if scene.get_tree().paused:
		var resume := scene.find_child("ResumeButton", true, false) as Button
		var home := scene.find_child("MainMenuButton", true, false) as Button
		if resume != null and resume.visible and resume.get_global_rect().has_point(point):
			scene._toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if home != null and home.visible and home.get_global_rect().has_point(point):
			scene._show_menu()
			get_viewport().set_input_as_handled()
			return
		return

	if bool(scene.running) and not bool(scene.game_over):
		var pause := scene.find_child("PauseButton", true, false) as Button
		if pause != null and pause.visible and pause.get_global_rect().has_point(point):
			scene._toggle_pause()
			get_viewport().set_input_as_handled()
