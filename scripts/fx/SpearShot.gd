extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# The hoplite's blow. The damage is dealt the moment the spear leaves the hand
# -- it is a frontline unit fighting whatever is standing in front of it, not a
# shooter -- so this is what the player sees rather than what the player gets:
# the shaft crossing the gap, and the ground it buries itself in.
#
#   0.00  the spear leaves, flat and fast
#   0.13  it lands; the shaft fades and the impact is left behind it
#   0.45  gone
#
# The gold coming off it is the only thing separating the three tiers at a
# glance, so `spark` scales everything about it: how many motes, how bright the
# flare, whether there is a trail at all.

const FLIGHT := 0.13
const GOLD := Color(1.0, 0.84, 0.32)

func play(dir: Vector2, distance: float, spear_tex: String, impact_tex: String,
		spark: float = 0.0, size: float = 1.0) -> void:
	z_index = 56
	var aim: Vector2 = dir.normalized()
	rotation = aim.angle()

	var spear: Sprite2D = null
	if spear_tex != "" and ResourceLoader.exists(spear_tex):
		spear = Sprite2D.new()
		spear.texture = load(spear_tex)
		spear.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spear.scale = Vector2.ONE * size
		add_child(spear)

	var tw := create_tween()
	if spear != null:
		tw.tween_property(spear, "position", Vector2(distance, 0), FLIGHT)
	else:
		tw.tween_interval(FLIGHT)

	# Gold shed along the flight, and only above the plain tier: a hoplite
	# throws a spear, a veteran throws a spear that glitters.
	if spark > 0.0 and spear != null:
		var wake := FxUtil.burst(spear, int(6 + 8 * spark), 0.30,
			20.0, 70.0 * spark, GOLD, Color(GOLD.r, GOLD.g * 0.55, 0.10, 0.0))
		wake.explosiveness = 0.0
		wake.gravity = Vector2(0, 60)
		wake.emission_sphere_radius = 10.0 * size
		wake.scale_amount_min = 1.2 * size
		wake.scale_amount_max = 2.8 * size * spark
		wake.emitting = true

	tw.tween_callback(_land.bind(Vector2(distance, 0), impact_tex, spark, size))
	if spear != null:
		tw.tween_property(spear, "modulate:a", 0.0, 0.12)
	tw.tween_interval(0.32)
	tw.tween_callback(queue_free)

func _land(at: Vector2, impact_tex: String, spark: float, size: float) -> void:
	if impact_tex != "" and ResourceLoader.exists(impact_tex):
		var hit := Sprite2D.new()
		hit.texture = load(impact_tex)
		hit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hit.position = at
		# Drawn against the ground rather than along the throw, so the dirt it
		# kicks up does not end up sideways when a unit faces along a lane.
		hit.rotation = -rotation
		hit.scale = Vector2.ONE * size * 0.85
		add_child(hit)

		var t := create_tween()
		t.tween_property(hit, "scale", Vector2.ONE * size, 0.10) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.10)
		t.tween_property(hit, "modulate:a", 0.0, 0.2)

	if spark <= 0.0:
		return

	var flare := FxUtil.bloom(self, 0.06 * size, 0.0, GOLD, 96)
	flare.position = at
	var tf := create_tween()
	tf.tween_property(flare, "modulate:a", 0.35 + 0.35 * spark, 0.05)
	tf.parallel().tween_property(flare, "scale",
		Vector2.ONE * (0.22 + 0.16 * spark) * size, 0.20) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tf.tween_property(flare, "modulate:a", 0.0, 0.16)

	var sparks := FxUtil.burst(self, int(5 + 7 * spark), 0.36,
		70.0, 90.0 + 110.0 * spark, GOLD, Color(GOLD.r, GOLD.g * 0.5, 0.08, 0.0))
	sparks.position = at
	sparks.direction = Vector2.UP
	sparks.spread = 70.0
	sparks.gravity = Vector2(0, 420)
	sparks.scale_amount_min = 1.4 * size
	sparks.scale_amount_max = 3.2 * size
	sparks.emitting = true
