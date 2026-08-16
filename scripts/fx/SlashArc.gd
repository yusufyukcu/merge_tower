extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# The stroke a weapon leaves behind.
#
# Every unit is a single painted frame with its weapon fixed in its hands, so
# there is no arm to animate: the swing is carried by the body turning through
# the blow and by this arc sweeping across the target.
#
# Three things keep it from reading as a drawn crescent:
#
#   the blade path opens outward through the stroke rather than tracing a
#   perfect circle, because an arm extends as it swings;
#
#   the arc is brightest a little behind its leading tip and dissolves toward
#   the tail, so the eye reads a direction of travel instead of a shape;
#
#   two dimmer, thinner echoes trail behind the leading edge, which is what a
#   fast blade actually leaves on the eye.
#
# It finishes with a spark thrown off the tip, so the stroke ends on contact
# rather than simply fading.

const SWEEP_TIME := 0.14
const FADE_TIME := 0.13
const ECHOES := [
	# lag behind the leading edge (radians), alpha, width scale
	[0.16, 0.45, 0.72],
	[0.34, 0.20, 0.48],
]

func play(dir: Vector2, reach: float, span: float = 1.9,
		tint: Color = Color(0.92, 0.96, 1.0), width: float = 10.0) -> void:
	z_index = 58

	for e in ECHOES:
		var echo := _build_arc(reach, span, width * float(e[2]), tint, float(e[1]))
		echo.rotation = -float(e[0])
		add_child(echo)
	add_child(_build_arc(reach, span, width, tint, 1.0))

	var spark := FxUtil.bloom(self, 0.16, 0.0, tint, 48)
	spark.position = Vector2(cos(span * 0.5), sin(span * 0.5)) * reach * 1.08

	var aim: float = dir.angle()
	rotation = aim - span * 0.35
	modulate.a = 0.0

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, SWEEP_TIME * 0.3)
	# Quint-out: fastest at the start of the stroke, easing as it follows
	# through, which is how a swing loses speed against its own weight.
	tw.parallel().tween_property(self, "rotation", aim + span * 0.35, SWEEP_TIME) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	# Spark flares as the tip passes through where the blow lands.
	tw.parallel().tween_property(spark, "modulate:a", 0.9, SWEEP_TIME * 0.75) \
		.set_delay(SWEEP_TIME * 0.25)
	tw.parallel().tween_property(spark, "scale", Vector2.ONE * 0.42, SWEEP_TIME) \
		.set_delay(SWEEP_TIME * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.tween_property(self, "modulate:a", 0.0, FADE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

# One blade path. `alpha` scales the whole arc down for the trailing echoes.
func _build_arc(reach: float, span: float, width: float, tint: Color,
		alpha: float) -> Line2D:
	var line := Line2D.new()
	var segs := 20
	for i in range(segs + 1):
		var t: float = float(i) / segs
		var a: float = -span * 0.5 + span * t
		# The path opens outward as the stroke follows through.
		line.add_point(Vector2(cos(a), sin(a)) * reach * (0.80 + 0.30 * t))

	line.width = width
	line.default_color = Color(tint.r, tint.g, tint.b, 1.0)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.material = FxUtil.additive()

	# Thin entering the stroke, full through the middle, drawn out to nothing
	# at the tip -- the fastest part of the blade is the part that blurs away.
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.06))
	taper.add_point(Vector2(0.40, 1.0))
	taper.add_point(Vector2(1.0, 0.10))
	line.width_curve = taper

	# Brightest just behind the tip, dissolving toward the tail.
	var grad := Gradient.new()
	grad.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	grad.set_color(1, Color(tint.r, tint.g, tint.b, 0.35 * alpha))
	grad.add_point(0.55, Color(tint.r, tint.g, tint.b, 0.85 * alpha))
	grad.add_point(0.82, Color(
		minf(tint.r * 1.25, 1.0), minf(tint.g * 1.25, 1.0), minf(tint.b * 1.25, 1.0),
		1.0 * alpha))
	line.gradient = grad
	return line
