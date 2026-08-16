extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# The golem's blow. It has no weapon to swing -- the crystal in its chest is the
# weapon -- so where every other body leaves a sword arc, this throws a bolt of
# light across the gap and bursts on the far side.
#
#   0.00  the bolt appears at the chest, small and bright
#   0.02  it stretches away along the line of the blow, spitting motes behind it
#   0.20  it arrives, flares, and comes apart in a violet burst
#   0.45  gone
#
# The sprite is painted head-right with its tail streaming left, so the whole
# node is simply rotated onto the direction of travel.

const TEX_BOLT := "res://art/fx_magic_projectile.png"

const FLIGHT_TIME := 0.20
const CORE := Color(0.86, 0.78, 1.0)
const TRAIL_FROM := Color(0.82, 0.68, 1.0, 1.0)
const TRAIL_TO := Color(0.42, 0.16, 0.85, 0.0)

func play(dir: Vector2, distance: float, size: float = 1.0) -> void:
	z_index = 59
	var aim: Vector2 = dir.normalized()
	rotation = aim.angle()

	# Everything below is built in the bolt's own frame -- x runs along the line
	# of travel -- so the flight is a single tween on one local position.
	var bolt := FxUtil.glow(self, load(TEX_BOLT), 0.55 * size, 0.0)
	var glare := FxUtil.bloom(self, 0.22 * size, 0.0, CORE, 96)

	# Motes shed along the flight path. Parented to the bolt so they are laid
	# down where it actually passes, and left un-emitting until it launches.
	var wake := FxUtil.burst(bolt, 14, 0.34, 30.0, 90.0, TRAIL_FROM, TRAIL_TO)
	wake.gravity = Vector2.ZERO
	wake.explosiveness = 0.0
	wake.emission_sphere_radius = 9.0
	wake.scale_amount_min = 1.4
	wake.scale_amount_max = 3.0
	wake.lifetime = FLIGHT_TIME + 0.14

	var tw := create_tween()
	tw.tween_property(bolt, "modulate:a", 1.0, 0.04)
	tw.parallel().tween_property(glare, "modulate:a", 0.85, 0.04)
	tw.parallel().tween_property(bolt, "scale", Vector2.ONE * 0.85 * size, 0.06) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_callback(func() -> void: wake.emitting = true)

	# Out along the blow, quickening as it goes: a thrown thing accelerates away
	# from the hand rather than sliding at one speed.
	tw.parallel().tween_property(bolt, "position", Vector2(distance, 0), FLIGHT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(glare, "position", Vector2(distance, 0), FLIGHT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tw.tween_callback(_impact.bind(Vector2(distance, 0), size))
	tw.tween_property(bolt, "modulate:a", 0.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(bolt, "scale", Vector2.ONE * 1.25 * size, 0.12)
	tw.parallel().tween_property(glare, "modulate:a", 0.0, 0.12)
	tw.tween_interval(0.24)   # lets the burst finish before the node goes
	tw.tween_callback(queue_free)

func _impact(at: Vector2, size: float) -> void:
	var flash := FxUtil.bloom(self, 0.18 * size, 0.9, CORE, 96)
	flash.position = at
	var t := create_tween()
	t.tween_property(flash, "scale", Vector2.ONE * 0.62 * size, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(flash, "modulate:a", 0.0, 0.16)

	# Sprayed forward, the way something bursting on impact throws its pieces on
	# past whatever stopped it.
	var shards := FxUtil.burst(self, 12, 0.30, 120.0, 260.0, TRAIL_FROM, TRAIL_TO)
	shards.position = at
	shards.direction = Vector2.RIGHT
	shards.spread = 96.0
	shards.gravity = Vector2(0, 180)
	shards.emitting = true
