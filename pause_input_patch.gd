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
	var pause_panel := scene.find_child("PauseMenu", true, false) as Control
	var resume := scene.find_child("ResumeButton", true, false) as Button
	var home := scene.find_child("MainMenuButton", true, false) as Button
	if pause == null:
		return
	pause.process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_panel != null:
		pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	if resume != null:
		resume.process_mode = Node.PROCESS_MODE_ALWAYS
	if home != null:
		home.process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func _input(_event: InputEvent) -> void:
	# Pause/resume are handled by the game's own native _input method.
	pass
