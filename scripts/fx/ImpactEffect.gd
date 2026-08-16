extends Node2D

# Combat impact effects, each choreographed around what the moment should feel
# like rather than all three sharing one fade-out:
#
# ENEMY HIT (~0.32s) — sharp and cheap, fires many times a second.
#   0.00  white-hot core + red bloom snap in, sparks spray along the hit vector
#   0.07  bloom peaks; a small ring snaps outward
#   0.32  gone
#
# ENEMY DEATH (~0.68s) — a magical poof that comes apart in layers.
#   0.00  violet bloom flash, puff cluster punches in, shards spray outward
#   0.18  cluster starts drifting up and dissolving while a second, larger
#         copy counter-rotates through it, so the cloud thins unevenly
#   0.20  soul motes peel upward and outlive the cluster
#   0.68  gone
#
# CASTLE HIT (~0.58s) — heavy, and the only one where debris obeys gravity.
#   0.00  gold spark flash at the point of impact, rubble sprite punches in
#   0.09  rubble begins settling downward as stone chips arc out and fall
#   0.12  low dust ring rolls outward
#   0.58  gone
#
# Hit and castle-hit take the direction the blow came from and bias themselves
# toward that side, so damage visibly lands on the struck face.

const FxUtil = preload("res://scripts/fx/FxUtil.gd")
const Shockwave = preload("res://scripts/fx/Shockwave.gd")

const TEX_HIT := "res://art/fx_enemy_hit.png"
const TEX_DEATH := "res://art/fx_enemy_death.png"
const TEX_CASTLE := "res://art/fx_castle_hit.png"
const TEX_BOSS := "res://art/fx_boss_entrance.png"


# ------------------------------------------------------------- enemy hit

func play_enemy_hit(from_dir: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	z_index = 60
	var size_mult: float = clampf(strength, 0.75, 1.6)

	# Sit slightly toward the incoming blow so the flash reads as contact.
	if from_dir != Vector2.ZERO:
		position += from_dir.normalized() * 9.0

	var burst_sprite := FxUtil.glow(self, load(TEX_HIT), 0.35 * size_mult, 1.0)
	burst_sprite.rotation = randf() * TAU
	var core := FxUtil.bloom(self, 0.2, 0.9, Color(1.0, 0.86, 0.78), 64)

	# The two above are light painted on the picture. This is the same light
	# falling on the bodies standing around it -- nothing at noon, and by night
	# the reason a fight in the dark is worth watching.
	Lighting.flash(self, global_position, Color(1.0, 0.72, 0.52),
		0.70 * size_mult, 140.0 * size_mult, 0.17)

	# red flash: fast snap out, immediate decay
	var t := create_tween()
	t.tween_property(burst_sprite, "scale", Vector2.ONE * 1.0 * size_mult, 0.07) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(burst_sprite, "rotation",
		burst_sprite.rotation + deg_to_rad(14.0), 0.32)
	t.tween_property(burst_sprite, "modulate:a", 0.0, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

	# white-hot centre, gone almost immediately
	var t_core := create_tween()
	t_core.tween_property(core, "scale", Vector2.ONE * 0.95 * size_mult, 0.09) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_core.parallel().tween_property(core, "modulate:a", 0.0, 0.13)
	t_core.tween_callback(core.queue_free)

	# sparks: cone back along the hit vector when we know it, else radial
	var sparks := FxUtil.burst(self, 9, 0.30, 130.0, 290.0,
		Color(1.0, 0.85, 0.62, 1.0), Color(0.95, 0.22, 0.12, 0.0))
	sparks.gravity = Vector2(0, 320)
	if from_dir != Vector2.ZERO:
		sparks.direction = -from_dir.normalized()
		sparks.spread = 62.0
	sparks.emitting = true

	var ring := Shockwave.new()
	ring.color = Color(1.0, 0.45, 0.28)
	add_child(ring)
	ring.run(4.0, 34.0 * size_mult, 6.0, 1.0, 0.7, 0.20)


# ----------------------------------------------------------- enemy death

func play_enemy_death(size_mult: float = 1.0) -> void:
	z_index = 60
	var tex: Texture2D = load(TEX_DEATH)
	var spin: float = 1.0 if randf() < 0.5 else -1.0

	# violet flash under the cloud
	Lighting.flash(self, global_position, Color(0.72, 0.45, 1.0),
		0.95 * size_mult, 200.0 * size_mult, 0.26)
	var flash := FxUtil.bloom(self, 0.3, 0.8, Color(0.72, 0.45, 1.0), 128)
	var t_flash := create_tween()
	t_flash.tween_property(flash, "scale", Vector2.ONE * 1.0 * size_mult, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_flash.parallel().tween_property(flash, "modulate:a", 0.0, 0.22)
	t_flash.tween_callback(flash.queue_free)

	# main puff cluster: punches in, then drifts up as it dissolves.
	# Peak size stays a shade over the enemy's own silhouette — the cloud
	# should read as the enemy coming apart, not as a separate explosion.
	var cluster := FxUtil.glow(self, tex, 0.30 * size_mult, 1.0, false)
	cluster.rotation = deg_to_rad(randf_range(-12.0, 12.0))
	var t_cluster := create_tween()
	t_cluster.tween_property(cluster, "scale", Vector2.ONE * 0.80 * size_mult, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_cluster.parallel().tween_property(cluster, "rotation",
		cluster.rotation + deg_to_rad(16.0 * spin), 0.68)
	t_cluster.parallel().tween_property(cluster, "position",
		cluster.position + Vector2(0, -10.0), 0.68) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t_cluster.tween_property(cluster, "modulate:a", 0.0, 0.44) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# a slightly larger ghost of the same cloud counter-rotating through it, so
	# the silhouette breaks up instead of shrinking as one piece
	var ghost := FxUtil.glow(self, tex, 0.40 * size_mult, 0.40, false)
	ghost.rotation = deg_to_rad(randf_range(-20.0, 20.0))
	var t_ghost := create_tween()
	t_ghost.tween_property(ghost, "scale", Vector2.ONE * 1.15 * size_mult, 0.68) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_ghost.parallel().tween_property(ghost, "rotation",
		ghost.rotation - deg_to_rad(30.0 * spin), 0.68)
	t_ghost.parallel().tween_property(ghost, "position",
		ghost.position + Vector2(0, -16.0), 0.68)
	t_ghost.parallel().tween_property(ghost, "modulate:a", 0.0, 0.68) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t_ghost.tween_callback(queue_free)

	# shards flung outward
	var shards := FxUtil.burst(self, 12, 0.38, 95.0, 200.0,
		Color(0.92, 0.78, 1.0, 1.0), Color(0.45, 0.18, 0.72, 0.0))
	shards.gravity = Vector2(0, 260)
	shards.scale_amount_min = 1.6
	shards.scale_amount_max = 3.2
	shards.emitting = true

	# souls peeling upward, the part that lingers
	var motes := FxUtil.burst(self, 8, 0.58, 20.0, 58.0,
		Color(0.88, 0.72, 1.0, 0.95), Color(0.55, 0.28, 0.95, 0.0))
	motes.direction = Vector2.UP
	motes.spread = 34.0
	motes.gravity = Vector2(0, -70)
	motes.explosiveness = 0.4
	motes.emission_sphere_radius = 13.0
	motes.scale_amount_min = 1.4
	motes.scale_amount_max = 2.6
	motes.scale_amount_curve = FxUtil.swell_curve()
	motes.emitting = true

	var ring := Shockwave.new()
	ring.color = Color(0.72, 0.42, 1.0)
	add_child(ring)
	ring.run(5.0, 38.0 * size_mult, 7.0, 1.0, 0.7, 0.28)


# ------------------------------------------------------- weapon sparks

# Thrown off a blade as it comes through. The drawn frames already carry the
# arc; this is the light coming off the steel, in whatever colour that body's
# weapon is, and it is deliberately small -- it fires several times a second
# across a whole line of enemies.
func play_weapon_sparks(dir: Vector2, tint: Color, size_mult: float = 1.0) -> void:
	z_index = 58
	var aim: Vector2 = dir.normalized()

	var sparks := FxUtil.burst(self, 8, 0.24, 130.0 * size_mult, 280.0 * size_mult,
		Color(tint.r, tint.g, tint.b, 1.0),
		Color(tint.r * 0.6, tint.g * 0.6, tint.b, 0.0))
	sparks.direction = aim
	sparks.spread = 46.0
	sparks.gravity = Vector2(0, 240)
	sparks.emitting = true

	Lighting.flash(self, global_position, tint, 0.50 * size_mult, 120.0 * size_mult, 0.13)

	var glint := FxUtil.bloom(self, 0.06 * size_mult, 0.85, tint, 64)
	var t := create_tween()
	t.tween_property(glint, "scale", Vector2.ONE * 0.30 * size_mult, 0.11) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(glint, "modulate:a", 0.0, 0.13)
	t.tween_callback(queue_free)


# --------------------------------------------------------- ground slam

# Something very heavy landing. Everything here hugs the floor -- a flattened
# ring rolling out, chips thrown up and falling back, dust dragging behind them
# -- because the blow went downward and the ground is what it hit.
func play_ground_slam(tint: Color, size_mult: float = 1.0) -> void:
	z_index = 57

	# Everything within reach of a landing that heavy gets lit by it.
	Lighting.flash(self, global_position, tint, 1.40 * size_mult, 320.0 * size_mult, 0.32)

	var flash := FxUtil.bloom(self, 0.2 * size_mult, 0.9, tint, 128)
	flash.scale.y *= 0.5
	var t := create_tween()
	t.tween_property(flash, "scale", Vector2(1.5, 0.6) * size_mult, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(flash, "modulate:a", 0.0, 0.22)
	t.tween_callback(flash.queue_free)

	var chips := FxUtil.burst(self, 14, 0.5, 140.0 * size_mult, 290.0 * size_mult,
		Color(0.82, 0.74, 0.62, 1.0), Color(0.42, 0.36, 0.30, 0.0), false)
	chips.direction = Vector2.UP
	chips.spread = 82.0
	chips.gravity = Vector2(0, 620)
	chips.scale_amount_min = 2.2
	chips.scale_amount_max = 4.6
	chips.emitting = true

	var dust := FxUtil.burst(self, 10, 0.62, 60.0 * size_mult, 170.0 * size_mult,
		Color(0.78, 0.70, 0.58, 0.7), Color(0.5, 0.45, 0.38, 0.0), false)
	dust.spread = 180.0
	dust.gravity = Vector2(0, -20)
	dust.damping_min = 60.0
	dust.damping_max = 120.0
	dust.scale_amount_min = 3.0
	dust.scale_amount_max = 6.0
	dust.scale_amount_curve = FxUtil.swell_curve()
	dust.emitting = true

	var ring := Shockwave.new()
	ring.color = tint
	add_child(ring)
	ring.scale = Vector2(1.0, 0.42)   # flat to the ground plane
	ring.run(7.0, 96.0 * size_mult, 12.0, 2.0, 0.7, 0.36)

	var life := create_tween()
	life.tween_interval(0.75)
	life.tween_callback(queue_free)


# -------------------------------------------------------- boss entrance

# A boss does not walk on; the ground opens and puts it there. Slower and louder
# than anything else here, because it plays once a run and has to be worth
# looking up for.
#
#   0.00  violet ground flash, crystals erupt upward out of nothing
#   0.10  shards fling out, a ring rolls along the ground
#   0.20  motes peel up around the crystals and keep drifting the whole time
#   0.95  crystals sink back and dissolve
#   1.60  gone
const BOSS_VIOLET := Color(0.62, 0.32, 1.0)
const BOSS_PALE := Color(0.86, 0.72, 1.0)

func play_boss_entrance(size_mult: float = 1.0) -> void:
	# Belongs under the boss, which is why the caller puts it on the ground
	# layer. A negative z_index would not do it -- that buries it under the
	# arena art as well.

	# The arrival lights the whole quarter of the field it happens in, and holds
	# it longer than any blow does: this is an announcement, not an impact.
	Lighting.flash(self, global_position, BOSS_VIOLET, 2.10 * size_mult,
		480.0 * size_mult, 0.55)

	var flash := FxUtil.bloom(self, 0.2, 0.95, BOSS_VIOLET, 160)
	var t_flash := create_tween()
	t_flash.tween_property(flash, "scale", Vector2.ONE * 2.2 * size_mult, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_flash.parallel().tween_property(flash, "modulate:a", 0.0, 0.35)
	t_flash.tween_callback(flash.queue_free)

	# The crystals themselves: alpha-keyed art, so drawn normally rather than
	# added. They come up out of the floor -- squashed flat and sunk, then
	# springing to full height -- and the sprite is seated so its base, not its
	# middle, sits on the spawn point.
	var crystals := FxUtil.glow(self, load(TEX_BOSS), 0.1, 0.0, false)
	var base_scale: float = 1.5 * size_mult
	var lift: float = crystals.texture.get_height() * 0.5 * base_scale
	crystals.position = Vector2(0, -lift * 0.55)
	crystals.scale = Vector2(base_scale * 0.55, 0.0)

	var t_c := create_tween()
	t_c.tween_property(crystals, "modulate:a", 1.0, 0.10)
	t_c.parallel().tween_property(crystals, "scale",
		Vector2(base_scale, base_scale), 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_c.tween_interval(0.5)
	t_c.tween_property(crystals, "scale", Vector2(base_scale * 1.06, 0.0), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t_c.parallel().tween_property(crystals, "modulate:a", 0.0, 0.5) \
		.set_delay(0.15)
	t_c.tween_interval(0.3)   # lets the last motes finish before the node goes
	t_c.tween_callback(queue_free)

	# Shards thrown clear of the break.
	var shards := FxUtil.burst(self, 18, 0.55, 150.0, 330.0,
		BOSS_PALE, Color(0.38, 0.12, 0.80, 0.0))
	shards.direction = Vector2.UP
	shards.spread = 78.0
	shards.gravity = Vector2(0, 520)
	shards.scale_amount_min = 2.0
	shards.scale_amount_max = 4.4
	shards.emitting = true

	# The purple glitter that hangs around it afterwards: two passes at
	# different speeds, so the air keeps moving for the whole entrance instead
	# of flashing once and stopping.
	_boss_motes(0.9, 26.0, 70.0, 14, 62.0 * size_mult, 0.0)
	_boss_motes(1.3, 12.0, 44.0, 16, 96.0 * size_mult, 0.18)

	var ring := Shockwave.new()
	ring.color = BOSS_VIOLET
	add_child(ring)
	ring.scale = Vector2(1.0, 0.45)   # rolls out along the ground plane
	ring.run(7.0, 120.0 * size_mult, 12.0, 2.0, 0.75, 0.5)

# One drift of glitter rising off the break. Slow, barely falling, and spread
# across a wide patch rather than issuing from a point.
func _boss_motes(life: float, vel_min: float, vel_max: float, amount: int,
		spread_radius: float, delay: float) -> void:
	var motes := FxUtil.burst(self, amount, life, vel_min, vel_max,
		BOSS_PALE, Color(0.55, 0.22, 1.0, 0.0))
	motes.direction = Vector2.UP
	motes.spread = 42.0
	motes.gravity = Vector2(0, -55.0)
	motes.explosiveness = 0.35
	motes.emission_sphere_radius = spread_radius
	motes.scale_amount_min = 1.6
	motes.scale_amount_max = 3.4
	motes.scale_amount_curve = FxUtil.swell_curve()
	motes.damping_min = 8.0
	motes.damping_max = 26.0
	if delay > 0.0:
		motes.emitting = false
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_callback(func() -> void: motes.emitting = true)
	else:
		motes.emitting = true


# ----------------------------------------------------------- castle hit

func play_castle_hit(from_dir: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	z_index = 60
	var size_mult: float = clampf(strength, 0.8, 1.7)
	# Placement is the caller's call here: the fortress seats this on its own
	# masonry, so nudging it further toward the attacker would drift it out to
	# where the enemy is standing and read as the enemy erupting instead.

	# gold spark flash at the point of contact
	Lighting.flash(self, global_position, Color(1.0, 0.80, 0.40),
		1.10 * size_mult, 260.0 * size_mult, 0.24)
	var flash := FxUtil.bloom(self, 0.3, 0.9, Color(1.0, 0.84, 0.42), 96)
	var t_flash := create_tween()
	t_flash.tween_property(flash, "scale", Vector2.ONE * 1.4 * size_mult, 0.20) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_flash.parallel().tween_property(flash, "modulate:a", 0.0, 0.20)
	t_flash.tween_callback(flash.queue_free)

	# rubble: snaps in, then settles downward under its own weight
	var rubble := FxUtil.glow(self, load(TEX_CASTLE), 0.5 * size_mult, 1.0, false)
	rubble.rotation = deg_to_rad(randf_range(-8.0, 8.0))
	if from_dir.x < 0.0:
		rubble.flip_h = true
	var t_rubble := create_tween()
	t_rubble.tween_property(rubble, "scale", Vector2.ONE * 1.15 * size_mult, 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_rubble.tween_property(rubble, "position", rubble.position + Vector2(0, 18.0), 0.42) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t_rubble.parallel().tween_property(rubble, "modulate:a", 0.0, 0.42) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t_rubble.tween_callback(queue_free)

	# stone chips: heavy, so they arc up and fall back rather than flying flat
	var chips := FxUtil.burst(self, 12, 0.55, 120.0, 250.0,
		Color(0.78, 0.70, 0.58, 1.0), Color(0.42, 0.36, 0.30, 0.0), false)
	chips.gravity = Vector2(0, 620)
	chips.direction = Vector2.UP
	chips.spread = 85.0
	chips.scale_amount_min = 2.5
	chips.scale_amount_max = 5.0
	chips.emitting = true

	# a few bright sparks off the strike itself
	var sparks := FxUtil.burst(self, 8, 0.28, 150.0, 320.0,
		Color(1.0, 0.94, 0.70, 1.0), Color(1.0, 0.58, 0.12, 0.0))
	sparks.gravity = Vector2(0, 380)
	sparks.emitting = true

	# low dust ring rolling out along the ground
	var ring := Shockwave.new()
	ring.color = Color(0.80, 0.72, 0.58)
	add_child(ring)
	ring.scale = Vector2(1.0, 0.45)   # flattened, so it hugs the ground plane
	ring.run(8.0, 74.0 * size_mult, 14.0, 2.0, 0.55, 0.35, 0.02)
