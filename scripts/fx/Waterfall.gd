extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# The waterfall painted into the north-west corner of the map.
#
# The painting already has the fall in it -- pale ribbons down the rock face and
# a bright patch of foam where they meet the pool -- but painted water is the
# one thing an eye never accepts, because water is only water while it moves.
# Nothing here redraws the fall, then. It lays motion over what is already
# there and lets the paint keep doing the drawing.
#
# Falling water is three separate things at once and needs all three to read:
#
#   the ribbons  long soft streaks coming down the same lines the painting
#                drew, thinning out as they reach the surface
#   the spray    droplets thrown back up off the impact and falling again --
#                the only part of this with real weight to it
#   the mist     which rises rather than falls, and is what makes a fall read
#                as heavy instead of as a trickle
#
# Plus the ripples the impact pushes out across the pool, squashed flat because
# the map is drawn from above and at an angle rather than straight down.
#
# All of it is additive over dark water, so the colours below are what gets
# *added* to the painting, not what water looks like.

# Where the ribbons come down, as offsets from the fall's centre line, in map
# pixels. Read off the painting: two strong ribbons with thinner water between
# them. Water coming down evenly across the whole lip reads as a curtain.
const RIBBONS := [-11.0, -6.5, 0.0, 6.0, 10.0]

# How long a ripple takes to cross the pool and fade, and how many are on their
# way out at any moment. Three is enough that one is always young.
const RING_LIFE := 2.8
const RING_COUNT := 3

var _fall: CPUParticles2D
var _spray: CPUParticles2D
var _mist: CPUParticles2D
var _foam: Sprite2D
var _rings: Array = []
var _scale: float = 1.0
var _phase: float = 0.0

# The node's origin is the water line -- the point the fall lands on -- because
# that is the one place in the painting every part of this effect is measured
# from. `drop` is how far above it the ribbons start.
func setup(drop: float = 86.0, s: float = 1.0) -> void:
	_scale = maxf(s, 0.01)
	_phase = randf() * TAU
	# Soft light over a painting, so it is sampled smoothly rather than with the
	# project's nearest default; children inherit this.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	_build_rings()
	_build_fall(drop)
	_build_mist()
	_build_spray()

	# A standing glow on the foam the painting already shows, so the impact has
	# a bright centre for the spray to come off.
	_foam = FxUtil.bloom(self, 0.30 * _scale, 0.30, Color(0.72, 0.90, 1.0), 128)
	_foam.position = Vector2(0, -2.0 * _scale)

# --------------------------------------------------------------- the ribbons

func _build_fall(drop: float) -> void:
	var points := PackedVector2Array()
	for x in RIBBONS:
		points.append(Vector2(float(x) * _scale, 0.0))

	_fall = CPUParticles2D.new()
	# Tall and narrow: one particle is a length of falling water, not a droplet.
	_fall.texture = FxUtil.streak_texture(
		Color(0.86, 0.95, 1.0, 1.0), Color(0.5, 0.75, 1.0, 0.0), 6, 40)
	_fall.material = FxUtil.additive()
	_fall.amount = 34
	# Long enough to carry a streak the whole way down at the speed below; the
	# colour ramp puts it out just as it arrives, so nothing swims on into the
	# pool.
	_fall.lifetime = 0.72
	_fall.preprocess = 1.2           # already falling when the map comes up
	_fall.position = Vector2(0, -drop)
	_fall.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_fall.emission_points = points
	_fall.direction = Vector2.DOWN
	_fall.spread = 2.0
	_fall.initial_velocity_min = drop * 1.18
	_fall.initial_velocity_max = drop * 1.34
	_fall.gravity = Vector2(0, 40.0 * _scale)
	_fall.scale_amount_min = 0.55 * _scale
	_fall.scale_amount_max = 1.15 * _scale
	# Thin as it goes: water leaving the lip is a sheet and arrives as threads.
	var thin := Curve.new()
	thin.add_point(Vector2(0.0, 1.0))
	thin.add_point(Vector2(0.7, 0.78))
	thin.add_point(Vector2(1.0, 0.42))
	_fall.scale_amount_curve = thin
	_fall.color_ramp = FxUtil.ramp_stops(
		PackedFloat32Array([0.0, 0.15, 0.72, 1.0]),
		PackedColorArray([
			Color(0.70, 0.86, 1.0, 0.0),
			Color(0.78, 0.92, 1.0, 0.52),
			Color(0.72, 0.88, 1.0, 0.40),
			Color(0.62, 0.82, 1.0, 0.0)]))
	add_child(_fall)

# ------------------------------------------------------------------ the spray

func _build_spray() -> void:
	_spray = CPUParticles2D.new()
	_spray.texture = FxUtil.dot_texture()
	_spray.material = FxUtil.additive()
	_spray.amount = 18
	_spray.lifetime = 0.6
	_spray.preprocess = 0.6
	_spray.position = Vector2(0, -3.0 * _scale)
	_spray.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_spray.emission_rect_extents = Vector2(9.0 * _scale, 2.0 * _scale)
	_spray.direction = Vector2.UP
	_spray.spread = 68.0
	_spray.initial_velocity_min = 34.0 * _scale
	_spray.initial_velocity_max = 88.0 * _scale
	# Thrown up and pulled straight back down -- the arc is the whole point.
	_spray.gravity = Vector2(0, 300.0 * _scale)
	_spray.scale_amount_min = 0.7 * _scale
	_spray.scale_amount_max = 1.9 * _scale
	_spray.scale_amount_curve = FxUtil.shrink_curve()
	_spray.color_ramp = FxUtil.ramp(
		Color(0.92, 0.98, 1.0, 0.75), Color(0.62, 0.84, 1.0, 0.0))
	add_child(_spray)

# ------------------------------------------------------------------- the mist

func _build_mist() -> void:
	_mist = CPUParticles2D.new()
	_mist.texture = FxUtil.dot_texture()
	_mist.material = FxUtil.additive()
	_mist.amount = 14
	_mist.lifetime = 1.9
	_mist.preprocess = 1.9
	_mist.position = Vector2(0, -4.0 * _scale)
	_mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_mist.emission_sphere_radius = 11.0 * _scale
	_mist.direction = Vector2.UP
	_mist.spread = 55.0
	_mist.initial_velocity_min = 6.0 * _scale
	_mist.initial_velocity_max = 24.0 * _scale
	_mist.gravity = Vector2(0, -7.0 * _scale)   # it hangs and climbs
	_mist.damping_min = 4.0
	_mist.damping_max = 11.0
	_mist.scale_amount_min = 3.0 * _scale
	_mist.scale_amount_max = 6.5 * _scale
	_mist.scale_amount_curve = FxUtil.grow_curve()
	_mist.color_ramp = FxUtil.ramp_stops(
		PackedFloat32Array([0.0, 0.25, 1.0]),
		PackedColorArray([
			Color(0.78, 0.90, 1.0, 0.0),
			Color(0.74, 0.88, 1.0, 0.17),
			Color(0.68, 0.84, 1.0, 0.0)]))
	add_child(_mist)

# ---------------------------------------------------------------- the ripples

func _build_rings() -> void:
	# Behind everything else, because a ripple is on the water and the spray is
	# above it.
	for _i in range(RING_COUNT):
		var ring := Sprite2D.new()
		ring.texture = FxUtil.ring_texture(Color(0.80, 0.93, 1.0, 1.0), 128)
		ring.material = FxUtil.additive()
		ring.position = Vector2(0, 5.0 * _scale)
		ring.modulate = Color(1, 1, 1, 0)
		add_child(ring)
		_rings.append(ring)

func _process(delta: float) -> void:
	_phase += delta

	# The foam is where the fall is loudest, so it is also where it is least
	# steady. Sines whose rates do not divide into one another, so the brightness
	# never settles into a loop the eye can pick out.
	if _foam != null:
		var f: float = 0.72 \
			+ 0.16 * sin(_phase * 5.3) \
			+ 0.09 * sin(_phase * 8.9 + 1.1) \
			+ 0.06 * sin(_phase * 13.7 + 2.4)
		_foam.modulate.a = clampf(0.18 + 0.22 * f, 0.0, 1.0)
		_foam.scale = Vector2.ONE * 0.30 * _scale * (0.90 + 0.18 * f)

	# Each ripple runs the same course a third of a cycle behind the last. Flat
	# in Y because the pool is seen from above and at an angle: a round ripple
	# would look like a hoop standing up out of the water.
	for i in range(_rings.size()):
		var ring: Sprite2D = _rings[i]
		var t: float = fposmod(_phase / RING_LIFE + float(i) / float(RING_COUNT), 1.0)
		var r: float = lerpf(0.09, 0.60, t) * _scale
		ring.scale = Vector2(r, r * 0.38)
		# Snaps in with the impact, then thins out the further it gets.
		ring.modulate.a = 0.24 * (1.0 - t) * minf(1.0, t * 7.0)

# The snow does not stop the fall -- the winter painting still has it running --
# but it puts it in colder water. 0 is the green map, 1 the frozen one.
func set_frost(t: float) -> void:
	modulate = Color(1, 1, 1).lerp(Color(0.74, 0.88, 1.06), clampf(t, 0.0, 1.0))
