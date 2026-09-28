extends Control

@export var stick_radius: float = 82.0
@export var knob_radius: float = 32.0

var stick_value := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(216, 216)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_virtual_value(value: Vector2) -> void:
	stick_value = value.limit_length(1.0)
	if stick_value.length() < 0.10:
		stick_value = Vector2.ZERO
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
