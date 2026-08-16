extends Node2D

# A self-drawing expanding ring. Radius, thickness and opacity animate on
# independent curves — the ring races outward on a quint ease while thinning
# and fading on a quad, which is what makes it read as a pressure wave rather
# than a circle being scaled up.
#
# Draws additively by default so it glows against the arena art.

var radius: float = 0.0
var width: float = 10.0
var color: Color = Color(1.0, 0.88, 0.45)
var alpha: float = 0.0


func _ready() -> void:
	material = load("res://scripts/fx/FxUtil.gd").additive()


func run(r_from: float, r_to: float, w_from: float, w_to: float,
		peak_alpha: float, dur: float, delay: float = 0.0) -> void:
	radius = r_from
	width = w_from
	alpha = 0.0
	queue_redraw()

	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_callback(func() -> void: _set_alpha(peak_alpha))
	t.parallel().tween_method(_set_radius, r_from, r_to, dur) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_set_width, w_from, w_to, dur)
	t.parallel().tween_method(_set_alpha, peak_alpha, 0.0, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


# Collapses inward instead of expanding: used to gather light before a burst.
func run_inward(r_from: float, r_to: float, w_from: float, w_to: float,
		peak_alpha: float, dur: float) -> void:
	radius = r_from
	width = w_from
	alpha = 0.0
	queue_redraw()

	var t := create_tween()
	t.tween_method(_set_radius, r_from, r_to, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(_set_width, w_from, w_to, dur)
	t.parallel().tween_method(_set_alpha, 0.0, peak_alpha, dur)
	t.tween_callback(queue_free)


func _set_radius(v: float) -> void:
	radius = v
	queue_redraw()


func _set_width(v: float) -> void:
	width = v
	queue_redraw()


func _set_alpha(v: float) -> void:
	alpha = v
	queue_redraw()


func _draw() -> void:
	if alpha <= 0.01 or radius <= 0.5 or width <= 0.1:
		return
	var col := color
	col.a = alpha
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, col, width, true)
