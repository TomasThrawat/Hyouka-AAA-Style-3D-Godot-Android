extends Node

var applied: bool = false

func _process(_delta: float) -> void:
	if applied:
		return
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
	applied = true
	set_process(false)
