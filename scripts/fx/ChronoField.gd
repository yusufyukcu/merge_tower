extends Node2D
class_name ChronoField

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# The dome the cronomancer stands inside for as long as his hour is open, and
# the ring of hours it opens over.
#
# It is a child of the hero rather than of the ground layer on purpose: an hour
# nobody is holding should not stay open over an empty patch of road, so if he
# is picked up mid-cast it travels with him, and if he is cut down it goes with
# him. That is also the honest reading of the ability -- the field is his, not
# the ground's.
#
# Two pieces, drawn in the order a dome is actually seen: the clock ring lies
# flat on the floor under him, and the shell stands over it. Both are additive,
# because the sheet paints them as light on its own dark field, and both are
# below the body in tree order so he is inside the dome rather than pasted onto
# the front of it.

const TEX_DOME := "res://art/fx_chrono_dome.png"
const TEX_RING := "res://art/fx_chrono_ring.png"

# How wide the shell stands relative to the body it is covering, and how flat
# the floor ring is drawn -- the same flattening every other circle on this
# floor uses, so the field lies on the same ground the shadows do.
const DOME_SPAN := 5.0
const RING_SPAN := 4.2
const RING_FLATTEN := 0.42
const RING_SPIN := 0.35        # radians a second: an hour hand, not a fan

const BREATH_RATE := 1.9

var _dome: Sprite2D = null
var _ring: Sprite2D = null
var _phase: float = 0.0
var _dome_scale: float = 1.0
var _closing: bool = false

# `feet` is where the body meets the ground in the hero's own local space --
# the dome has to stand on that line and not on the node's origin, which is up
# around the chest on most of these drawings.
func play(radius: float, feet_y: float, tint: Color = Color(0.46, 0.72, 1.0)) -> void:
	# Behind the body: the parent adds this after the sprite, so it is pushed to
	# the front of the child list to get underneath it again.
	var host := get_parent()
	if host != null and host.get_child_count() > 0:
		host.move_child(self, 0)

	if ResourceLoader.exists(TEX_RING):
		_ring = Sprite2D.new()
		_ring.texture = load(TEX_RING)
		_ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_ring.material = FxUtil.additive()
		var rk: float = (radius * RING_SPAN) / maxf(float(_ring.texture.get_width()), 1.0)
		_ring.scale = Vector2(rk, rk * RING_FLATTEN)
		_ring.position = Vector2(0, feet_y)
		_ring.modulate = Color(tint.r, tint.g, tint.b, 0.0)
		add_child(_ring)
		var tr := create_tween()
		tr.tween_property(_ring, "modulate:a", 0.85, 0.26) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if ResourceLoader.exists(TEX_DOME):
		_dome = Sprite2D.new()
		_dome.texture = load(TEX_DOME)
		_dome.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_dome.material = FxUtil.additive()
		var size: Vector2 = _dome.texture.get_size()
		_dome_scale = (radius * DOME_SPAN) / maxf(size.x, 1.0)
		_dome.scale = Vector2(_dome_scale, _dome_scale)
		# The shell is drawn resting on its own bottom edge, so it is lifted by
		# half its height to stand on the floor line rather than sink into it.
		_dome.position = Vector2(0, feet_y - size.y * 0.5 * _dome_scale)
		_dome.modulate = Color(1, 1, 1, 0.0)
		add_child(_dome)
		# Rises out of the floor: flat at first and pushed up to full height,
		# which is the one thing that makes a dome read as being *raised* rather
		# than as a picture of a dome being faded in.
		_dome.scale.y = _dome_scale * 0.15
		var td := create_tween()
		td.tween_property(_dome, "scale:y", _dome_scale, 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		td.parallel().tween_property(_dome, "modulate:a", 0.9, 0.22)

	# The hours themselves, drifting up the inside of the shell for as long as it
	# stands. Slow and few: this is a held note, not a burst.
	var motes := FxUtil.burst(self, 14, 2.4, 10.0, 34.0,
		Color(tint.r, tint.g, tint.b, 0.85), Color(tint.r, tint.g, tint.b, 0.0))
	motes.position = Vector2(0, feet_y)
	motes.one_shot = false
	motes.explosiveness = 0.0
	motes.direction = Vector2.UP
	motes.spread = 26.0
	motes.gravity = Vector2(0, -22)
	motes.emission_sphere_radius = radius * 1.5
	motes.scale_amount_min = 1.4
	motes.scale_amount_max = 3.0
	motes.scale_amount_curve = FxUtil.swell_curve()
	motes.emitting = true

func _process(delta: float) -> void:
	if _closing:
		return
	_phase += delta
	if _ring != null and is_instance_valid(_ring):
		_ring.rotation += RING_SPIN * delta
	if _dome != null and is_instance_valid(_dome):
		# Breathing on the width alone. Pulsing the height as well would lift the
		# shell off the floor and put it back down, and a dome that does not stay
		# on the ground stops reading as a dome.
		_dome.scale.x = _dome_scale * (1.0 + 0.035 * sin(_phase * BREATH_RATE))
		_dome.modulate.a = 0.78 + 0.14 * sin(_phase * BREATH_RATE * 0.7)

# The hour closing. The shell drops back into the floor the way it came out of
# it, and the node takes itself away once it has.
func close() -> void:
	if _closing:
		return
	_closing = true
	set_process(false)
	for p in get_children():
		if p is CPUParticles2D:
			(p as CPUParticles2D).emitting = false
	var tw := create_tween()
	if _dome != null and is_instance_valid(_dome):
		tw.tween_property(_dome, "scale:y", _dome_scale * 0.1, 0.26) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_dome, "modulate:a", 0.0, 0.26)
	if _ring != null and is_instance_valid(_ring):
		tw.parallel().tween_property(_ring, "modulate:a", 0.0, 0.30)
	# Long enough for the last motes to finish falling out of a shell that is
	# already gone, rather than blinking out with it.
	tw.tween_interval(0.4)
	tw.tween_callback(queue_free)
