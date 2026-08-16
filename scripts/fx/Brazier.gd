extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# Brings the two fire bowls either side of SEND to life. They are painted into
# the panel art and sit perfectly still, which is the one thing a fire never
# does, so this lays living light over the top of the painting: a core that
# gutters, a pool of light on the stone around it, and embers coming off.
#
# The flicker is a sum of sines whose rates do not divide into one another, so
# it never settles into the obvious loop a single sine gives. Each bowl also
# gets its own phase -- two fires flickering in step read as one animation
# played twice rather than as two fires.

# The bowls stand at the foot of the well the pieces pile up in, so their light
# reaches the bottom of the pile and nothing above it. That is the right answer
# for a fire on the floor and it is also the whole of the cost.
const LIGHT_RADIUS := 250.0

var _core: Sprite2D = null
var _pool: Sprite2D = null
var _light: PointLight2D = null
var _core_scale: float = 0.30
var _pool_scale: float = 0.95
var _phase: float = 0.0

func setup(core_scale: float = 0.30, pool_scale: float = 0.95) -> void:
	_core_scale = core_scale
	_pool_scale = pool_scale
	_phase = randf() * TAU

	# Wide, dim light on the surrounding stonework, then the hot centre.
	_pool = FxUtil.bloom(self, pool_scale, 0.24, Color(1.0, 0.52, 0.16), 128)
	_core = FxUtil.bloom(self, core_scale, 0.85, Color(1.0, 0.76, 0.32), 64)
	_build_embers()

	# Unlike the candles these burn at every hour: they stand on a stone panel in
	# shadow rather than on a road in the sun, so warm light on the pieces
	# resting nearest them is right at noon and only gets righter after dark.
	_light = Lighting.fire_light(self, Color(1.0, 0.56, 0.20), LIGHT_RADIUS * pool_scale)
	_light.position = Vector2(0, -4.0)

func _build_embers() -> void:
	var embers := CPUParticles2D.new()
	embers.texture = FxUtil.dot_texture()
	embers.material = FxUtil.additive()
	embers.amount = 10
	embers.lifetime = 1.6
	embers.preprocess = 1.6          # already burning when the scene opens
	embers.position = Vector2(0, -6)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 7.0
	embers.direction = Vector2.UP
	embers.spread = 20.0
	embers.initial_velocity_min = 24.0
	embers.initial_velocity_max = 54.0
	embers.gravity = Vector2(0, -16.0)   # they rise rather than fall
	embers.damping_min = 6.0
	embers.damping_max = 16.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.4
	embers.scale_amount_curve = FxUtil.shrink_curve()
	embers.color_ramp = FxUtil.ramp(
		Color(1.0, 0.86, 0.48, 1.0), Color(1.0, 0.24, 0.05, 0.0))
	add_child(embers)

func _process(delta: float) -> void:
	if _core == null:
		return
	_phase += delta

	# Fast and irregular: the flame itself. A slow gust rides on top of the
	# fast flicker, so the fire occasionally swells and gutters instead of
	# vibrating evenly around one brightness.
	var gust: float = 0.86 + 0.14 * sin(_phase * 1.7 + 0.4)
	var f: float = clampf(gust * (0.70 \
		+ 0.24 * sin(_phase * 11.3) \
		+ 0.14 * sin(_phase * 17.7 + 1.3) \
		+ 0.08 * sin(_phase * 29.1 + 2.2)), 0.15, 1.25)
	_core.scale = Vector2.ONE * _core_scale * (0.74 + 0.46 * f)
	_core.modulate.a = clampf(0.30 + 0.72 * f, 0.0, 1.0)

	# Slower and shallower: light on the wall lags behind the flame that casts
	# it, and a pool of light swinging as hard as the flame looks like a lamp
	# being shaken rather than a fire burning.
	var slow: float = 0.70 + 0.22 * sin(_phase * 4.1 + 0.7) + 0.08 * sin(_phase * 7.3)
	var night: float = Lighting.night()
	_pool.scale = Vector2.ONE * _pool_scale * (0.92 + 0.15 * slow) * (1.0 + 0.35 * night)
	_pool.modulate.a = (0.16 + 0.14 * slow) * (1.0 + 0.7 * night)
	if _light != null:
		_light.energy = (0.20 + 0.85 * night) * (0.55 + 0.55 * f)
