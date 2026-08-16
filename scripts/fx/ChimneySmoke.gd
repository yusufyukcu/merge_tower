extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# The smoke standing over the chimneys on the map.
#
# The painting has a pale wisp above each stack, which is the artist saying
# there is a fire lit down there -- but a wisp that never moves says the fire
# went out some while ago and this is what it left behind. So each pot gets a
# plume of its own, coming off the same lip and going the same way the paint
# leans.
#
# The direction matters more here than anywhere else in this file, because the
# map is drawn looking *down* at the village rather than across at it. Smoke
# genuinely rises, but almost all of that rise is straight at the camera and
# hardly moves on the screen at all; what the eye actually sees from up here is
# smoke being carried sideways across the ground by whatever wind is about.
# Sending it straight up the screen instead would draw a column standing on the
# roof like a tree -- and would push it off the top of the arena window, since
# every chimney on this map is near the upper edge of it. So `lean` is a ratio,
# how far the plume travels across the field for every step it climbs, and it
# is a big number on purpose.
#
# Smoke is also not fire and must not be built like it: it is matter, not light,
# so it blends normally. Added light over the bright sand by the farmhouse would
# read as a lamp. It fades *in* a moment after leaving the pot, because smoke at
# the lip is still clear hot gas and only thickens once it has cooled, and it
# keeps spreading the whole way out, which is the part that separates smoke from
# steam.

var _puffs: CPUParticles2D
var _sway: float = 0.0
var _phase: float = 0.0

# `lean` is signed: negative carries the plume left across the map, positive
# right. The painting says which way each chimney is blowing; this follows it.
func setup(s: float = 1.0, lean: float = -2.4) -> void:
	_phase = randf() * TAU
	# How hard the wind is allowed to wander, scaled off the lean so a strongly
	# blown plume wanders more than a lazy one.
	_sway = absf(lean) * 1.1 * s
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	_puffs = CPUParticles2D.new()
	_puffs.texture = FxUtil.dot_texture()
	_puffs.amount = 16
	_puffs.lifetime = 3.4
	_puffs.preprocess = 3.4          # the fire has been lit a good while
	_puffs.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_puffs.emission_sphere_radius = 1.8 * s
	_puffs.direction = Vector2(lean, -1.0).normalized()
	_puffs.spread = 13.0
	_puffs.initial_velocity_min = 15.0 * s
	_puffs.initial_velocity_max = 26.0 * s
	_puffs.gravity = Vector2(0, -3.0 * s)
	# Slows as it goes: a puff loses the push the flue gave it and then merely
	# hangs, which is why a plume leaves hard and drifts off soft.
	_puffs.damping_min = 1.5
	_puffs.damping_max = 4.5
	_puffs.scale_amount_min = 1.0 * s
	_puffs.scale_amount_max = 2.3 * s
	_puffs.scale_amount_curve = FxUtil.grow_curve()
	_puffs.color_ramp = FxUtil.ramp_stops(
		PackedFloat32Array([0.0, 0.16, 0.55, 1.0]),
		PackedColorArray([
			Color(0.88, 0.86, 0.82, 0.0),
			Color(0.87, 0.85, 0.81, 0.30),
			Color(0.82, 0.81, 0.79, 0.18),
			Color(0.78, 0.78, 0.77, 0.0)]))
	add_child(_puffs)

func _process(delta: float) -> void:
	if _puffs == null:
		return
	_phase += delta
	# Two slow sines out of step with one another, pushed in as sideways
	# acceleration so the whole plume bows rather than kinking. It is a fraction
	# of the lean and never reverses it: the wind here gusts, it does not turn
	# around and blow the smoke back over the roof it came from.
	_puffs.gravity.x = _sway * (0.62 * sin(_phase * 0.31) + 0.34 * sin(_phase * 0.53 + 2.1))
