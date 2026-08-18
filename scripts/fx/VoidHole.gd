extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# One of the tears the void master's VOID COLLAPSE opens under a body.
#
# It is a telegraph and a blow in one. The ground darkens and a ring closes on
# the spot for the whole of `WIND`, which is long enough for the player to watch
# it happening to the whole field at once and short enough that nothing walks
# out of it; then it shuts, and everything standing on it takes the hit.
#
# The order matters: the damage is dealt on the collapse, not on the opening, so
# a hole that opened under something already dying does nothing rather than
# double-counting it. The caller hands the blow in as `on_close` for exactly
# that reason -- what it hits is decided when it shuts.

const WIND := 0.42
const AFTER := 0.34

const CORE := Color(0.06, 0.02, 0.12)
const RIM := Color(0.72, 0.40, 1.0)

var _plate: Node2D = null      # holds the flattening
var _disc: Polygon2D = null    # holds the spin, inside it
var _phase: float = 0.0

func play(radius: float, on_close: Callable = Callable()) -> void:
	z_index = 5

	# Flattened the way every other circle on this floor is: the field is seen at
	# an angle, and a true circle would read as standing up out of it.
	#
	# Two nodes rather than one because a Node2D scales before it rotates, and a
	# flattened ellipse spun about its own centre tumbles like a coin instead of
	# turning like a whirlpool. The squash goes on the outside and the spin on
	# the inside, which puts them in the order the eye expects.
	_plate = Node2D.new()
	add_child(_plate)
	_plate.scale = Vector2(0.15, 0.15)

	_disc = Polygon2D.new()
	_disc.polygon = _ellipse(radius, 22)
	_disc.color = Color(CORE.r, CORE.g, CORE.b, 0.0)
	_plate.add_child(_disc)

	# The rim, which is the only part of it that is light rather than the absence
	# of it -- a hole drawn in pure darkness over dark grass is invisible.
	var halo := FxUtil.bloom(self, 0.05, 0.0, RIM, 128)
	halo.scale = Vector2(0.05, 0.05 * 0.42)

	var ring := FxUtil.glow(self, FxUtil.ring_texture(RIM, 128), 0.05, 0.0)
	ring.scale = Vector2(1.6, 1.6 * 0.42) * (radius / 64.0)

	# Everything loose on the ground goes in rather than out. Reversed gravity
	# would only lift it; what says "pulled" is particles that start wide and
	# finish at the middle, which is what a negative radial pull is for.
	var dust := FxUtil.burst(self, 20, WIND, 0.0, 10.0,
		Color(0.86, 0.66, 1.0, 1.0), Color(0.28, 0.10, 0.52, 0.0))
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = radius * 1.15
	dust.gravity = Vector2.ZERO
	dust.radial_accel_min = -520.0
	dust.radial_accel_max = -260.0
	dust.damping_min = 0.0
	dust.damping_max = 0.0
	dust.scale_amount_curve = FxUtil.shrink_curve()
	dust.emitting = true

	var tw := create_tween()
	tw.tween_property(_plate, "scale", Vector2(1.0, 0.42), WIND) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_disc, "color", Color(CORE.r, CORE.g, CORE.b, 0.92), WIND * 0.6)
	tw.parallel().tween_property(halo, "scale", Vector2(radius / 64.0, radius / 64.0 * 0.42), WIND)
	tw.parallel().tween_property(halo, "modulate:a", 0.55, WIND * 0.6)
	# The ring closes inward on the spot, which is what makes the moment it
	# arrives at nothing the moment the hole shuts.
	tw.parallel().tween_property(ring, "scale", Vector2(0.06, 0.06), WIND) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ring, "modulate:a", 0.95, WIND * 0.35)

	tw.tween_callback(func() -> void:
		if on_close.is_valid():
			on_close.call()
		_collapse(radius))

	tw.tween_interval(AFTER)
	tw.tween_callback(queue_free)

	set_process(true)

# What the blow looks like: the hole snaps shut and throws back out everything
# it swallowed.
func _collapse(radius: float) -> void:
	set_process(false)
	Lighting.flash(self, global_position, RIM, 1.4, radius * 2.6, 0.22)

	var out := FxUtil.burst(self, 18, 0.42, 180.0, 420.0,
		Color(0.92, 0.78, 1.0, 1.0), Color(0.34, 0.10, 0.62, 0.0))
	out.gravity = Vector2(0, 160)
	out.emitting = true

	var flash := FxUtil.bloom(self, 0.1, 1.0, Color(0.88, 0.72, 1.0), 128)
	flash.scale = Vector2(0.1, 0.1)

	var tw := create_tween()
	tw.tween_property(flash, "scale",
		Vector2(radius / 46.0, radius / 46.0 * 0.7), 0.20) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.24)
	if _plate != null and is_instance_valid(_plate):
		tw.parallel().tween_property(_plate, "scale", Vector2(0.05, 0.02), 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

# The hole turns while it is open. A perfectly still black ellipse is a shadow;
# one that rotates is something with a direction of travel.
func _process(delta: float) -> void:
	_phase += delta
	if _disc != null and is_instance_valid(_disc):
		_disc.rotation = _phase * 2.4

func _ellipse(r: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a: float = TAU * i / segs
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts
