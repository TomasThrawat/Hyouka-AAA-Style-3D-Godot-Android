extends Control

signal value_changed(value: Vector2)
signal released

@export var stick_radius := 82.0
@export var knob_radius := 32.0

var active_pointer := -1
var mouse_active := false
var stick_value := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(210, 210)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, stick_radius + 8.0, Color(0.03, 0.08, 0.14, 0.44))
	draw_circle(center, stick_radius, Color(0.05, 0.16, 0.24, 0.70))
	draw_arc(center, stick_radius, 0.0, TAU, 48, Color(0.28, 0.86, 1.0, 0.72), 3.0)
	var knob_center := center + stick_value * stick_radius
	draw_circle(knob_center, knob_radius + 6.0, Color(0.08, 0.42, 0.62, 0.35))
	draw_circle(knob_center, knob_radius, Color(0.25, 0.84, 1.0, 0.88))
	draw_circle(knob_center - Vector2(8, 8), knob_radius * 0.28, Color(0.86, 0.98, 1.0, 0.85))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_pointer == -1 and get_global_rect().has_point(event.position):
			active_pointer = event.index
			_set_value_from_screen(event.position)
			accept_event()
		elif not event.pressed and event.index == active_pointer:
			_reset_stick()
			accept_event()
	elif event is InputEventScreenDrag and event.index == active_pointer:
		_set_value_from_screen(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not mouse_active and get_global_rect().has_point(event.position):
			mouse_active = true
			_set_value_from_screen(event.position)
			accept_event()
		elif not event.pressed and mouse_active:
			mouse_active = false
			_reset_stick()
			accept_event()
	elif event is InputEventMouseMotion and mouse_active:
		_set_value_from_screen(event.position)
		accept_event()

func _set_value_from_screen(screen_position: Vector2) -> void:
	var local := screen_position - global_position
	var center := size * 0.5
	var offset := local - center
	if offset.length() > stick_radius:
		offset = offset.normalized() * stick_radius
	stick_value = offset / stick_radius
	if stick_value.length() < 0.12:
		stick_value = Vector2.ZERO
	queue_redraw()
	value_changed.emit(stick_value)

func _reset_stick() -> void:
	active_pointer = -1
	mouse_active = false
	stick_value = Vector2.ZERO
	queue_redraw()
	value_changed.emit(Vector2.ZERO)
	released.emit()
