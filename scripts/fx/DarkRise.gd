extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# The column of green fire the zombie lord's sheet calls DARK ENERGY RISES, cut
# out of art/zombie_lord_upgrade.png.
#
# One effect, two jobs, and it is the same drawing for both on purpose. It is
# what plays over the hero himself the moment he comes into his power, and it is
# what plays over every skull that stands up as a zombie. A player who has seen
# the first one happen already knows what the second one means, which is worth
# more than two effects that each have to be learnt separately.
#
# The plume is drawn additively so it lights whatever it is standing over rather
# than hiding it, and the body it is announcing is handed in as `on_peak` so it
# appears at the brightest instant rather than before or after.

const ART := "res://art/fx_dark_rise.png"
const TINT := Color(0.62, 1.0, 0.42)

# The beat the thing being raised actually arrives on: late enough that the
# plume has swallowed the ground first, early enough that it is still bright
# when the body is there to be lit by it.
const PEAK := 0.34
const HOLD := 0.16
const FALL := 0.46

# What one unit of `size` is worth in pixels of plume height. Measured off a
# skull mark, which is the smallest thing this ever plays over.
const BASE_HEIGHT := 190.0

func play(size: float = 1.0, on_peak: Callable = Callable()) -> void:
	z_index = 30

	# The ground opens before anything comes out of it.
	var ring := FxUtil.glow(self, FxUtil.ring_texture(TINT, 128), 0.10, 0.0)
	ring.scale = Vector2(0.10, 0.10 * 0.42)
	var floor_glow := FxUtil.bloom(self, 0.05, 0.0, TINT, 128)
	floor_glow.scale = Vector2(0.05, 0.05 * 0.5)

	var plume: Sprite2D = null
	var full: Vector2 = Vector2.ONE
	if ResourceLoader.exists(ART):
		plume = FxUtil.glow(self, load(ART), 0.0, 0.0)
		plume.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Anchored at its own foot rather than its middle, so the fire grows up
		# out of the spot it was played on instead of expanding around it.
		var tex: Vector2 = plume.texture.get_size()
		plume.offset = Vector2(0, -tex.y * 0.5)
		var k: float = (BASE_HEIGHT * size) / maxf(tex.y, 1.0)
		# Rises rather than swells: it starts squat and stretches upward, which is
		# the difference between fire climbing and a picture being zoomed.
		full = Vector2(k, k)
		plume.scale = Vector2(k, k * 0.35)
		plume.modulate = Color(1, 1, 1, 0.0)

	var embers := FxUtil.burst(self, 22, 0.7, 90.0, 300.0,
		Color(0.86, 1.0, 0.62, 1.0), Color(0.18, 0.52, 0.14, 0.0))
	embers.direction = Vector2.UP
	embers.spread = 34.0
	embers.gravity = Vector2(0, -120)
	embers.scale_amount_curve = FxUtil.swell_curve()
	embers.emitting = true

	# Lights the bodies standing around it for as long as it burns. This is the
	# one thing that says the plume is in the world rather than drawn over it.
	Lighting.flash(self, global_position, TINT, 1.15, 210.0 * size, PEAK + HOLD)

	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(0.9, 0.9 * 0.42) * size, PEAK) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.85, PEAK * 0.4)
	tw.parallel().tween_property(floor_glow, "scale",
		Vector2(0.75, 0.38) * size, PEAK)
	tw.parallel().tween_property(floor_glow, "modulate:a", 0.75, PEAK * 0.5)
	if plume != null:
		tw.parallel().tween_property(plume, "scale", full, PEAK) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(plume, "modulate:a", 1.0, PEAK * 0.55)

	tw.tween_callback(func() -> void:
		if on_peak.is_valid():
			on_peak.call())
	tw.tween_interval(HOLD)

	tw.tween_property(self, "modulate:a", 0.0, FALL) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if plume != null:
		# Burns out upward as it goes, so the last thing seen is the fire leaving
		# rather than the fire dimming where it stood.
		tw.parallel().tween_property(plume, "scale",
			full * Vector2(0.7, 1.25), FALL)
	tw.tween_callback(queue_free)
