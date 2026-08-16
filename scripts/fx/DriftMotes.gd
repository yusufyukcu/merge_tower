extends CPUParticles2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# What the air over the field is doing.
#
# The map has weather in it for exactly one part of the run: the snow, which
# arrives at wave 30 and says the season has turned. Before that the air over
# the crossroads is perfectly still and perfectly empty, which is the one thing
# outdoor air never is -- and an empty sky is most obvious in the half hour
# either side of sunset, which is precisely where this run spends its middle.
#
# So the field gets motes. Nothing at noon, because there is nothing to see in
# flat daylight; dust catching the low sun through the afternoon; and by dusk
# they have warmed and slowed into what the eye reads as fireflies over the
# grass. They are gone before the snow starts -- one lot of weather at a time.
#
# It costs one emitter for the whole arena and answers to nothing but the hour,
# so nothing has to remember to tell it anything.

const DUST := Color(1.00, 0.94, 0.80)
const FIREFLY := Color(1.00, 0.82, 0.38)

func setup(area: Rect2) -> void:
	texture = FxUtil.dot_texture()
	material = FxUtil.additive()
	amount = 34
	lifetime = 7.0
	# Already drifting when the arena opens, so the first thing the player sees
	# is air that has always been there rather than air starting up.
	preprocess = 7.0
	position = area.position + area.size * 0.5
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = area.size * 0.5

	# Up and to the right, the way the smoke over the chimneys leans, and slowly
	# enough that the eye follows one rather than reading a shower.
	direction = Vector2(0.55, -1.0)
	spread = 46.0
	initial_velocity_min = 5.0
	initial_velocity_max = 20.0
	gravity = Vector2(3.0, -6.0)
	damping_min = 0.0
	damping_max = 2.0
	scale_amount_min = 1.3
	scale_amount_max = 3.2
	scale_amount_curve = FxUtil.swell_curve()
	# In out of nothing and back into it: a mote that appears at full brightness
	# reads as a dead pixel, and one that vanishes at full brightness reads as a
	# bug. Fading both ends is also what gives the drift its twinkle, since no
	# two of them are at the same point of their life.
	color_ramp = FxUtil.ramp_stops(
		PackedFloat32Array([0.0, 0.22, 0.72, 1.0]),
		PackedColorArray([
			Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.75),
			Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.0)]))

	modulate = Color(1, 1, 1, 0.0)
	emitting = false

func _process(_delta: float) -> void:
	var night: float = Lighting.night()
	# Held off until the light has actually started to go, and taken away again
	# before the snow arrives: two kinds of weather in the air at once reads as
	# confetti rather than as either of them.
	var showing: float = smoothstep(0.14, 0.58, night) * (1.0 - smoothstep(0.90, 1.0, night))
	modulate.a = showing
	self_modulate = DUST.lerp(FIREFLY, clampf(night * 1.2, 0.0, 1.0))
	var want: bool = showing > 0.01
	if want != emitting:
		emitting = want
