extends Node2D

# Merge bursts, choreographed so the beats land in sequence rather than
# everything cross-fading at once.
#
# Ordinary merge (~0.62s):
#   0.00  bloom flash + core star punches in + shockwave leaves + sparks fire
#   0.07  core hits its overshoot, halo is already expanding past it
#   0.18  bloom is gone, core settles back to rest
#   0.34  shockwave has thinned out
#   0.46  core fades
#   0.62  halo fades, node frees itself
#
# Topping out a branch (knight / master archer / mage) runs a grander version
# (~1.15s) that earns its moment by *withholding* first:
#   0.00  light gathers — a ring collapses inward, nothing else on screen
#   0.12  impact: big star, white bloom, sparks, first shockwave, `impact` fires
#   0.12  radiant beams sweep outward, rotating
#   0.21  second shockwave chases the first, reaching further
#   0.20  golden motes drift upward for the rest of the beat
#   0.55  star settles, beams begin retracting
#   1.15  everything dissipates, node frees itself
#
# The star art is a soft light bloom painted on the sheet's dark field, so it
# draws additively (see FxUtil). This node's own material is additive too, so
# the beams it draws in _draw glow as well. Core and halo counter-rotate so the
# spokes shimmer against each other.

signal impact  # the frame the burst lands, for screen-level effects

const FxUtil = preload("res://scripts/fx/FxUtil.gd")
const Shockwave = preload("res://scripts/fx/Shockwave.gd")

const TEX_NORMAL := "res://art/fx_merge.png"
const TEX_CRITICAL := "res://art/fx_merge_critical.png"

const CORE_REST_SCALE := 0.95
const BEAM_COLOR := Color(1.0, 0.85, 0.42)
const BEAM_COUNT := 8

var _beam_rot: float = 0.0
var _beam_len: float = 0.0
var _beam_alpha: float = 0.0
var _beam_width: float = 15.0

var _spin: float = 1.0


func play(critical: bool = false) -> void:
	z_index = 100
	material = FxUtil.additive()
	_spin = 1.0 if randf() < 0.5 else -1.0
	if critical:
		_play_critical()
	else:
		_play_normal()


# --------------------------------------------------------- ordinary merge

func _play_normal() -> void:
	var tex: Texture2D = load(TEX_NORMAL)

	var halo := FxUtil.glow(self, tex, 0.5, 0.55)
	var core := FxUtil.glow(self, tex, 0.25, 1.0)
	var bloom := FxUtil.bloom(self, 0.6, 0.7)
	_sparks(16, 300.0)
	# The pieces resting around the merge catch it, which is the one thing the
	# glows above cannot do for them.
	Lighting.flash(self, global_position, Color(1.0, 0.90, 0.62), 1.10, 260.0, 0.28)

	core.rotation = deg_to_rad(-18.0 * _spin)
	halo.rotation = deg_to_rad(10.0 * _spin)
	impact.emit()

	# core: snap out past its rest size, settle, then fade
	var t_core := create_tween()
	t_core.tween_property(core, "scale", Vector2.ONE * 1.25, 0.07) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_core.tween_property(core, "scale", Vector2.ONE * CORE_REST_SCALE, 0.11) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_core.tween_interval(0.10)
	t_core.parallel().tween_property(core, "rotation", core.rotation + deg_to_rad(26.0 * _spin), 0.30)
	t_core.tween_property(core, "modulate:a", 0.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# halo: keeps expanding the whole time; owns tearing the effect down
	var t_halo := create_tween()
	t_halo.tween_property(halo, "scale", Vector2.ONE * 2.4, 0.62) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_halo.parallel().tween_property(halo, "rotation", halo.rotation - deg_to_rad(34.0 * _spin), 0.62)
	t_halo.parallel().tween_property(halo, "modulate:a", 0.0, 0.62) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t_halo.tween_callback(queue_free)

	_flash_bloom(bloom, 1.9, 0.18)
	_wave(10.0, 95.0, 12.0, 1.0, 0.95, 0.34, 0.0)


# -------------------------------------------------- topping out a branch

func _play_critical() -> void:
	var tex: Texture2D = load(TEX_CRITICAL)

	# --- 0.00 anticipation: a ring collapses inward, gathering the light ---
	var gather := Shockwave.new()
	gather.color = Color(1.0, 0.9, 0.55)
	add_child(gather)
	gather.run_inward(130.0, 14.0, 3.0, 9.0, 0.85, 0.12)

	# Everything below is held back until the gather completes.
	var t_main := create_tween()
	t_main.tween_interval(0.12)
	t_main.tween_callback(func() -> void: _critical_impact(tex))


func _critical_impact(tex: Texture2D) -> void:
	var halo := FxUtil.glow(self, tex, 0.6, 0.6)
	var core := FxUtil.glow(self, tex, 0.3, 1.0)
	var bloom := FxUtil.bloom(self, 0.7, 0.85)
	_sparks(30, 380.0)
	_motes()
	Lighting.flash(self, global_position, Color(1.0, 0.86, 0.55), 1.70, 340.0, 0.38)

	core.rotation = deg_to_rad(-22.0 * _spin)
	halo.rotation = deg_to_rad(12.0 * _spin)
	impact.emit()

	# core: bigger punch, holds longer at rest before letting go
	var t_core := create_tween()
	t_core.tween_property(core, "scale", Vector2.ONE * 1.85, 0.09) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_core.tween_property(core, "scale", Vector2.ONE * 1.4, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_core.tween_interval(0.28)
	t_core.parallel().tween_property(core, "rotation", core.rotation + deg_to_rad(40.0 * _spin), 0.55)
	t_core.tween_property(core, "modulate:a", 0.0, 0.34) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# halo: slow grand expansion; owns tearing the effect down
	var t_halo := create_tween()
	t_halo.tween_property(halo, "scale", Vector2.ONE * 3.6, 1.03) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t_halo.parallel().tween_property(halo, "rotation", halo.rotation - deg_to_rad(52.0 * _spin), 1.03)
	t_halo.parallel().tween_property(halo, "modulate:a", 0.0, 1.03) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t_halo.tween_callback(queue_free)

	_flash_bloom(bloom, 2.6, 0.22)

	# --- radiant beams sweeping outward ----------------------------------
	_beam_rot = randf() * TAU
	var t_beam := create_tween()
	t_beam.tween_method(_set_beam_len, 0.0, 210.0, 0.30) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_beam.parallel().tween_method(_set_beam_alpha, 0.0, 0.75, 0.12)
	t_beam.parallel().tween_method(_set_beam_rot, _beam_rot, _beam_rot + deg_to_rad(46.0 * _spin), 0.9)
	t_beam.parallel().tween_method(_set_beam_width, 15.0, 4.0, 0.9)
	t_beam.tween_interval(0.16)
	t_beam.tween_method(_set_beam_alpha, 0.75, 0.0, 0.42) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# --- two shockwaves, the second chasing the first --------------------
	_wave(14.0, 150.0, 14.0, 1.0, 0.95, 0.40, 0.0)
	_wave(14.0, 230.0, 10.0, 1.0, 0.70, 0.52, 0.09)


# ------------------------------------------------------------------ layers

func _flash_bloom(bloom: Sprite2D, to_scale: float, dur: float) -> void:
	var t := create_tween()
	t.tween_property(bloom, "scale", Vector2.ONE * to_scale, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(bloom, "modulate:a", 0.0, dur)
	t.tween_callback(bloom.queue_free)


func _sparks(amount: int, vel_max: float) -> void:
	var p := FxUtil.burst(self, amount, 0.5, 170.0, vel_max,
		Color(1.0, 0.97, 0.75, 1.0), Color(1.0, 0.62, 0.15, 0.0))
	p.gravity = Vector2(0, 420)
	p.emitting = true


func _motes() -> void:
	# Slow golden embers drifting up — reads as the unit ascending a tier, and
	# keeps the moment alive after the hard flash is gone.
	var p := FxUtil.burst(self, 18, 0.95, 30.0, 85.0,
		Color(1.0, 0.92, 0.6, 0.9), Color(1.0, 0.75, 0.3, 0.0))
	p.direction = Vector2.UP
	p.spread = 32.0
	p.gravity = Vector2(0, -60)
	p.explosiveness = 0.35
	p.emission_sphere_radius = 46.0
	p.damping_min = 8.0
	p.damping_max = 20.0
	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.4
	p.scale_amount_curve = FxUtil.swell_curve()
	p.emitting = true


func _wave(r_from: float, r_to: float, w_from: float, w_to: float,
		alpha: float, dur: float, delay: float) -> void:
	var ring := Shockwave.new()
	add_child(ring)
	ring.run(r_from, r_to, w_from, w_to, alpha, dur, delay)


# ------------------------------------------------------------------- beams

func _set_beam_rot(v: float) -> void:
	_beam_rot = v
	queue_redraw()


func _set_beam_len(v: float) -> void:
	_beam_len = v
	queue_redraw()


func _set_beam_alpha(v: float) -> void:
	_beam_alpha = v
	queue_redraw()


func _set_beam_width(v: float) -> void:
	_beam_width = v
	queue_redraw()


func _draw() -> void:
	if _beam_alpha <= 0.01 or _beam_len <= 1.0:
		return
	var col := BEAM_COLOR
	col.a = _beam_alpha
	for i in range(BEAM_COUNT):
		var a: float = _beam_rot + TAU * i / BEAM_COUNT
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x) * (_beam_width * 0.5)
		# tapered spike: wide at the core, meeting at a point outward
		draw_colored_polygon(PackedVector2Array([
			dir * 8.0 + side,
			dir * 8.0 - side,
			dir * _beam_len,
		]), col)
