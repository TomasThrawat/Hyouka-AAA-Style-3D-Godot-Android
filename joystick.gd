extends Control

signal value_changed(value: Vector2)
signal released

@export var stick_radius := 82.0
@export var knob_radius := 32.0

var active_pointer := -1
var mouse_active := false
var stick_value := Vector2.ZERO

func _ready() -> void:
\tcustom_minimum_size = Vector2(210, 210)
\tsize = custom_minimum_size
\tmouse_filter = Control.MOUSE_FILTER_STOP
\tqueue_redraw()

func _notification(what: int) -> void:
\tif what == NOTIFICATION_RESIZED:
\t\tqueue_redraw()

func _draw() -> void:
\tvar center := size * 0.5
\tdraw_circle(center, stick_radius + 8.0, Color(0.03, 0.08, 0.14, 0.44))
\tdraw_circle(center, stick_radius, Color(0.05, 0.16, 0.24, 0.70))
\tdraw_arc(center, stick_radius, 0.0, TAU, 48, Color(0.28, 0.86, 1.0, 0.72), 3.0)
\tvar knob_center := center + stick_value * stick_radius
\tdraw_circle(knob_center, knob_radius + 6.0, Color(0.08, 0.42, 0.62, 0.35))
\tdraw_circle(knob_center, knob_radius, Color(0.25, 0.84, 1.0, 0.88))
\tdraw_circle(knob_center - Vector2(8, 8), knob_radius * 0.28, Color(0.86, 0.98, 1.0, 0.85))

func _input(event: InputEvent) -> void:
\tif event is InputEventScreenTouch:
\t\tif event.pressed and active_pointer == -1 and get_global_rect().has_point(event.position):
\t\t\tactive_pointer = event.index
\t\t\t_set_value_from_screen(event.position)
\t\t\taccept_event()
\t\telif not event.pressed and event.index == active_pointer:
\t\t\t_reset_stick()
\t\t\taccept_event()
\telif event is InputEventScreenDrag and event.index == active_pointer:
\t\t_set_value_from_screen(event.position)
\t\taccept_event()
\telif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
\t\tif event.pressed and not mouse_active and get_global_rect().has_point(event.position):
\t\t\tmouse_active = true
\t\t\t_set_value_from_screen(event.position)
\t\t\taccept_event()
\t\telif not event.pressed and mouse_active:
\t\t\tmouse_active = false
\t\t\t_reset_stick()
\t\t\taccept_event()
\telif event is InputEventMouseMotion and mouse_active:
\t\t_set_value_from_screen(event.position)
\t\taccept_event()

func _set_value_from_screen(screen_position: Vector2) -> void:
\tvar local := screen_position - global_position
\tvar center := size * 0.5
\tvar offset := local - center
\tif offset.length() > stick_radius:
\t\toffset = offset.normalized() * stick_radius
\tstick_value = offset / stick_radius
\tif stick_value.length() < 0.12:
\t\tstick_value = Vector2.ZERO
\tqueue_redraw()
\tvalue_changed.emit(stick_value)

func _reset_stick() -> void:
\tactive_pointer = -1
\tmouse_active = false
\tstick_value = Vector2.ZERO
\tqueue_redraw()
\tvalue_changed.emit(Vector2.ZERO)
\treleased.emit()
