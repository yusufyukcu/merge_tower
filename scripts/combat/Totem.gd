extends Node2D
class_name Totem

const FxUtil = preload("res://scripts/fx/FxUtil.gd")
const Shockwave = preload("res://scripts/fx/Shockwave.gd")

# A carved post a shaman plants beside itself. It never fights and cannot be
# hurt; everything of ours standing inside its circle simply swings faster.
#
# The circle has to be readable without being a wall of light on top of the
# fight, so it is drawn as a ring of small dots rather than a filled disc or a
# solid outline: the dots turn slowly around the post, breathe in and out of
# brightness one after another rather than all together, and a few motes drift
# up off the ground inside it. At a glance it reads as ground that is lit;
# looked at directly, it reads as a boundary.

const DOT_COUNT := 30
const DOT_RADIUS := 4.4
# The ring does not turn. It is not decoration -- it is the boundary of the
# ground this totem covers, and a boundary that slides around is a boundary the
# player cannot read. All that moves is a slow breath of brightness.
const BREATH := 2.6             # seconds for one pass of the shimmer
const FLATTEN := 0.42           # squashed onto the ground plane, like every ring here
# Kept well away from white: added on top of bright sand, anything with green in
# it comes back out as a pale spark rather than as a blue one.
const RING_COLOR := Color(0.26, 0.58, 1.0)
# A wash this faint is invisible looked at directly and unmistakable at a
# glance: it is what tells the player where the circle's edge actually is on
# the stretches between two dots.
const WASH_ALPHA := 0.035

var aura_radius: float = 190.0
var haste: float = 1.25

var _sprite: Sprite2D = null
var _ring: Node2D = null
var _phase: float = 0.0

func setup(art_path: String, radius: float, p_haste: float, art_scale: float = 1.0) -> void:
	aura_radius = radius
	haste = p_haste

	_ring = _Ring.new()
	_ring.aura_radius = aura_radius
	add_child(_ring)

	if art_path != "" and ResourceLoader.exists(art_path):
		_sprite = Sprite2D.new()
		_sprite.texture = load(art_path)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex: Vector2 = _sprite.texture.get_size()
		var s: float = (86.0 * art_scale) / maxf(tex.x, tex.y)
		_sprite.scale = Vector2(s, s)
		# Seated on its base rather than its middle, so the post stands on the
		# ground the circle is drawn on.
		_sprite.offset = Vector2(0, -tex.y * 0.5)
		add_child(_sprite)

	_play_planting()

# Comes up out of the ground: the post pushes through, the circle opens out
# from nothing, and a ring of light runs out along the floor with it.
func _play_planting() -> void:
	var ring := Shockwave.new()
	ring.color = RING_COLOR
	add_child(ring)
	ring.scale = Vector2(1.0, 0.42)
	ring.run(8.0, aura_radius, 12.0, 2.0, 0.8, 0.55)

	var motes := FxUtil.burst(self, 14, 0.7, 60.0, 170.0,
		Color(0.78, 0.94, 1.0, 1.0), Color(0.25, 0.55, 1.0, 0.0))
	motes.direction = Vector2.UP
	motes.spread = 60.0
	motes.gravity = Vector2(0, -40)
	motes.scale_amount_curve = FxUtil.swell_curve()
	motes.emitting = true

	if _sprite != null:
		_sprite.scale.y *= 0.1
		_sprite.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_sprite, "modulate:a", 1.0, 0.14)
		t.parallel().tween_property(_sprite, "scale:y", _sprite.scale.y * 10.0, 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_ring.modulate.a = 0.0
	var tr := create_tween()
	tr.tween_property(_ring, "modulate:a", 1.0, 0.45)

# Taken down with the shaman that raised it: the circle closes, the post sinks.
func dissolve() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	if _sprite != null:
		t.parallel().tween_property(_sprite, "scale:y", 0.0, 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

func covers(point: Vector2) -> bool:
	return global_position.distance_to(point) <= aura_radius

func _process(delta: float) -> void:
	if _ring == null:
		return
	_phase += delta
	_ring.phase = _phase
	_ring.queue_redraw()

# The ring itself, drawn rather than built out of nodes: 26 dots is 26 draw
# calls one way and 26 Node2Ds with their own tweens the other, and there can be
# several of these on the field at once.
class _Ring extends Node2D:
	var aura_radius: float = 190.0
	var phase: float = 0.0

	func _init() -> void:
		material = FxUtil.additive()

	func _draw() -> void:
		var wash := RING_COLOR
		wash.a = WASH_ALPHA
		draw_colored_polygon(_ellipse(1.0), wash)

		for i in range(DOT_COUNT):
			var a: float = TAU * i / DOT_COUNT
			# The shimmer runs around the ring instead of pulsing as one, so the
			# circle always has brighter and dimmer parts and never blinks. The
			# dots themselves stay exactly where they are.
			var wave: float = sin(phase * TAU / BREATH - a * 2.0) * 0.5 + 0.5
			var p := Vector2(cos(a) * aura_radius, sin(a) * aura_radius * FLATTEN)
			var r: float = DOT_RADIUS * (0.8 + 0.3 * wave)

			# Halo first, then a core inside it: one flat disc of colour washes
			# out to nothing against bright ground when added to it.
			var halo := RING_COLOR
			halo.a = 0.06 + 0.12 * wave
			draw_circle(p, r * 2.0, halo)

			var core := RING_COLOR.lerp(Color(1, 1, 1), 0.15)
			core.a = 0.34 + 0.30 * wave
			draw_circle(p, r, core)

	# The ring's own footprint, as a polygon, since draw_circle cannot be
	# squashed onto the ground plane.
	func _ellipse(scale: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in range(48):
			var a: float = TAU * i / 48.0
			pts.append(Vector2(cos(a) * aura_radius,
				sin(a) * aura_radius * FLATTEN) * scale)
		return pts
