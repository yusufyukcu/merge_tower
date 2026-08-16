extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# The candles on the signposts at the mouth of each road.
#
# Twelve of them are painted onto the map, one per post, and every one is
# holding the same shape it was painted in. A candle is small enough that a
# still flame is not obviously wrong -- until the eye has been sitting on it for
# a wave or two, at which point the whole road reads as scenery rather than as a
# place somebody lit a light in.
#
# This is the brazier idea shrunk to candle size and nothing more: a body of
# light over the painted flame that breathes, a small pool of it on the signpost
# below, and a thread of sparks coming off the top. The painted flame keeps
# doing all the drawing -- what is added here is only what a real flame does
# that a painted one cannot, which is change.
#
# The flame body is an ellipse rather than a disc, because a candle flame is
# taller than it is wide and a round glow over it makes the post look like it is
# carrying a lamp. It also leans a little from side to side, which is the
# cheapest thing that reads as air moving past a flame.

# How far the real light reaches, in map pixels at full candle size. A signpost
# is not a bonfire: this is wide enough to take in the soldier standing at the
# mouth of the road it marks and little else, which is both what a candle does
# and what keeps a dozen of them costing nothing.
const LIGHT_RADIUS := 150.0

var _pool: Sprite2D = null
var _core: Sprite2D = null
var _light: PointLight2D = null
var _scale: float = 1.0
var _core_scale: float = 1.0
var _phase: float = 0.0

# The node's origin is the centre of the painted flame. `s` is the size tier:
# the posts by the crossing carry a taller candle than the ones set back.
func setup(s: float = 1.0) -> void:
	_scale = maxf(s, 0.01)
	_phase = randf() * TAU
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Warm rather than white. Added light is what this is, and white added to an
	# orange flame bleaches it out into a headlight.
	_pool = FxUtil.bloom(self, 0.32 * _scale, 0.11, Color(1.0, 0.55, 0.16), 128)
	_pool.position = Vector2(0, 5.0 * _scale)   # falls onto the signboard below

	_core_scale = 0.42 * _scale
	_core = Sprite2D.new()
	_core.texture = FxUtil.streak_texture(
		Color(1.0, 0.72, 0.28, 1.0), Color(1.0, 0.35, 0.05, 0.0), 30, 52)
	_core.material = FxUtil.additive()
	_core.scale = Vector2.ONE * _core_scale
	_core.modulate = Color(1, 1, 1, 0.5)
	add_child(_core)

	_build_sparks()

	# The one thing the painting cannot do for a body walking past it. The glows
	# above are laid over the picture and light nothing; this lights the soldier
	# standing at the mouth of the road, and only him -- see Lighting.BODY_LAYER.
	# It is dark until the evening asks for it, so nothing changes in daylight.
	_light = Lighting.fire_light(self, Color(1.0, 0.60, 0.24), LIGHT_RADIUS * _scale)
	_light.position = Vector2(0, 4.0 * _scale)
	Lighting.add_fire(global_position, 0.62 * _scale, 0.75)

func _build_sparks() -> void:
	var sparks := CPUParticles2D.new()
	sparks.texture = FxUtil.dot_texture()
	sparks.material = FxUtil.additive()
	sparks.amount = 4
	sparks.lifetime = 1.0
	sparks.preprocess = 1.0
	sparks.position = Vector2(0, -6.0 * _scale)   # off the tip, not the wick
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 1.6 * _scale
	sparks.direction = Vector2.UP
	sparks.spread = 14.0
	sparks.initial_velocity_min = 9.0 * _scale
	sparks.initial_velocity_max = 20.0 * _scale
	sparks.gravity = Vector2(0, -7.0 * _scale)    # hot air, so they climb
	sparks.damping_min = 5.0
	sparks.damping_max = 13.0
	sparks.scale_amount_min = 0.45 * _scale
	sparks.scale_amount_max = 1.0 * _scale
	sparks.scale_amount_curve = FxUtil.shrink_curve()
	sparks.color_ramp = FxUtil.ramp(
		Color(1.0, 0.84, 0.46, 0.85), Color(1.0, 0.28, 0.06, 0.0))
	add_child(sparks)

func _process(delta: float) -> void:
	if _core == null:
		return
	_phase += delta

	# Same sum-of-sines the braziers use, but a candle is a much smaller fire and
	# so a much twitchier one: the fast terms carry more of the total here, and
	# the slow gust underneath swings wider, because a draught that a fire bowl
	# shrugs off nearly puts a candle out.
	var gust: float = 0.80 + 0.20 * sin(_phase * 1.3 + 0.9)
	var f: float = clampf(gust * (0.66 \
		+ 0.26 * sin(_phase * 13.9) \
		+ 0.16 * sin(_phase * 21.3 + 1.7) \
		+ 0.09 * sin(_phase * 33.7 + 0.5)), 0.12, 1.3)

	# It stretches taller as it brightens and squats when it guts, which is the
	# shape a flame actually changes in -- it does not simply get bigger.
	_core.scale = Vector2(
		_core_scale * (0.86 + 0.20 * f),
		_core_scale * (0.72 + 0.52 * f))
	_core.modulate.a = clampf(0.22 + 0.48 * f, 0.0, 1.0)
	# A hair of lean, and the tip rides up as it lengthens.
	_core.position = Vector2(
		sin(_phase * 2.3) * 0.7 * _scale,
		-1.2 * _scale * f)

	# The light thrown on the post lags the flame that throws it and swings far
	# less; a pool of light flickering as hard as the flame reads as the whole
	# signpost being shaken.
	var slow: float = 0.72 + 0.20 * sin(_phase * 4.7 + 1.4) + 0.08 * sin(_phase * 7.9)
	var night: float = Lighting.night()
	_pool.scale = Vector2.ONE * 0.32 * _scale * (0.93 + 0.13 * slow) * (1.0 + 0.85 * night)
	# Kept low in daylight deliberately: these stand on a sunlit road, and a
	# candle that lights up the ground around it at noon reads as a bug rather
	# than as a candle. Once the sun is off the road it is the other way about --
	# a flame with no pool under it is a sticker, so the pool comes up with the
	# evening and by night it is the brightest thing on that stretch of road.
	_pool.modulate.a = (0.07 + 0.07 * slow) + (0.30 + 0.18 * slow) * night
	if _light != null:
		# Switched off outright in daylight rather than left burning at nothing:
		# a light with no energy in it still costs a pass over everything it
		# reaches, and for the first third of the run there are twelve of them.
		var burning: bool = night > 0.015
		if _light.enabled != burning:
			_light.enabled = burning
		if burning:
			# Driven by the flame rather than the pool: what falls on a body a
			# step away is the fire itself, with none of the lag the painted
			# stone has.
			_light.energy = (0.30 + 0.60 * f) * night
			_light.texture_scale = (LIGHT_RADIUS * _scale * (0.92 + 0.16 * f)) \
				* 2.0 / Lighting.LIGHT_TEX_PX
