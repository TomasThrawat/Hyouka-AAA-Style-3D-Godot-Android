extends Control

signal value_changed(value: Vector2)
signal released

@export var stick_radius := 82.0
@export var knob_radius := 32.0

var active_pointer := -1
var mouse_active := false
var touch_start_time := 0.0
var stick_value := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(216, 216)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, stick_radius + 14.0, Color(0.0, 0.0, 0.0, 0.68))
	draw_circle(center, stick_radius + 8.0, Color(0.09, 0.085, 0.075, 0.94))
	draw_circle(center, stick_radius, Color(0.16, 0.15, 0.13, 0.90))
	draw_arc(center, stick_radius + 1.0, 0.0, TAU, 64, Color(0.76, 0.62, 0.40, 0.98), 4.0)
	draw_arc(center, stick_radius - 11.0, 0.0, TAU, 64, Color(0.46, 0.40, 0.33, 0.90), 2.0)
	var tick_color := Color(0.88, 0.83, 0.74, 0.78)
	draw_line(center + Vector2(0, -58), center + Vector2(0, -44), tick_color, 4.0, true)
	draw_line(center + Vector2(58, 0), center + Vector2(44, 0), tick_color, 4.0, true)
	draw_line(center + Vector2(0, 58), center + Vector2(0, 44), tick_color, 4.0, true)
	draw_line(center + Vector2(-58, 0), center + Vector2(-44, 0), tick_color, 4.0, true)
	var knob_center := center + stick_value * stick_radius
	draw_circle(knob_center, knob_radius + 8.0, Color(0.0, 0.0, 0.0, 0.58))
	draw_circle(knob_center, knob_radius, Color(0.69, 0.58, 0.40, 0.99))
	draw_circle(knob_center - Vector2(9, 9), knob_radius * 0.27, Color(0.96, 0.94, 0.88, 0.94))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_pointer == -1:
			active_pointer = event.index
			_set_value_from_local(event.position)
			accept_event()
		elif not event.pressed and event.index == active_pointer:
			_reset_stick()
			accept_event()
	elif event is InputEventScreenDrag and event.index == active_pointer:
		_set_value_from_local(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not mouse_active:
			mouse_active = true
			_set_value_from_local(event.position)
			accept_event()
		elif not event.pressed and mouse_active:
			_reset_stick()
			accept_event()
	elif event is InputEventMouseMotion and mouse_active:
		_set_value_from_local(event.position)
		accept_event()

func _set_value_from_local(local: Vector2) -> void:
	var center := size * 0.5
	var offset := local - center
	if offset.length() > stick_radius:
		offset = offset.normalized() * stick_radius
	stick_value = offset / stick_radius
	if stick_value.length() < 0.10:
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
