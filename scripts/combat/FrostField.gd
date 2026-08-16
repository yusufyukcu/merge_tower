extends Node2D
class_name FrostField

const FxUtil = preload("res://scripts/fx/FxUtil.gd")
const Shockwave = preload("res://scripts/fx/Shockwave.gd")

# What an ice wizard opens on the ground. It deals no damage and cannot be
# attacked; everything of ours standing inside it simply swings slower.
#
# It is the shaman's totem read backwards, and it is built the same way on
# purpose: a flattened ring of light on the floor. The player has spent the
# whole run learning that a lit circle on the ground changes how fast the units
# inside it fight, so this one has only to be cold rather than warm to say that
# it changes it the other way.
#
# The one thing the totem does not have is an end. A circle the enemy owns has
# to run out, or a lane the wizards reached once is slow for the rest of the
# run: it fades up, holds, and closes.

const FADE_IN := 0.35
const FADE_OUT := 0.9
const BREATH := 2.2
const RING_COLOR := Color(0.42, 0.72, 1.0)

var aura_radius: float = 150.0
# Multiplies rate of attack, so below 1.0 is slower. The strongest field wins
# where two overlap -- see CombatManager._update_auras.
var slow: float = 0.55

var _sprite: Sprite2D = null
var _life: float = 0.0
var _age: float = 0.0

func setup(art_path: String, radius: float, p_slow: float, duration: float) -> void:
	aura_radius = radius
	slow = p_slow
	_life = duration

	# The ground inside the circle first, then the ring around its edge. Neither
	# is drawn additively, which is the whole difference between this reading as
	# a circle and reading as a smudge: added to snow, blue comes back out white,
	# and the ground this is fought on is snow from here to the end of the run.
	var wash := Polygon2D.new()
	wash.polygon = _ellipse(aura_radius)
	wash.color = Color(0.28, 0.56, 1.0, 0.18)
	add_child(wash)

	if art_path != "" and ResourceLoader.exists(art_path):
		_sprite = Sprite2D.new()
		_sprite.texture = load(art_path)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# The ring is painted already flattened onto the ground plane, so it is
		# scaled by its width alone and lands at the right rake on its own.
		var tex: Vector2 = _sprite.texture.get_size()
		var s: float = (aura_radius * 2.0) / maxf(tex.x, 1.0)
		_sprite.scale = Vector2(s, s)
		add_child(_sprite)

	_play_opening()

# Opens outward rather than appearing: a ring of cold runs out along the floor
# and the circle brightens behind it.
func _play_opening() -> void:
	var ring := Shockwave.new()
	ring.color = RING_COLOR
	add_child(ring)
	ring.scale = Vector2(1.0, 0.45)
	ring.run(8.0, aura_radius, 12.0, 1.6, 0.75, 0.5)

	var motes := FxUtil.burst(self, 12, 0.8, 40.0, 130.0,
		Color(0.80, 0.94, 1.0, 1.0), Color(0.30, 0.60, 1.0, 0.0))
	motes.direction = Vector2.UP
	motes.spread = 60.0
	motes.gravity = Vector2(0, -30)
	motes.scale_amount_curve = FxUtil.swell_curve()
	motes.emitting = true

	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, FADE_IN)

func covers(point: Vector2) -> bool:
	return global_position.distance_to(point) <= aura_radius

# The circle's footprint as a polygon, squashed onto the ground plane at the
# same rake the painted ring is drawn at (its own 192x87).
const FLATTEN := 0.45

func _ellipse(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(48):
		var a: float = TAU * i / 48.0
		pts.append(Vector2(cos(a) * radius, sin(a) * radius * FLATTEN))
	return pts

func _process(delta: float) -> void:
	_age += delta
	# A slow breath, so the ground reads as lit rather than as a decal someone
	# left on it.
	if _sprite != null:
		var wave: float = sin(_age * TAU / BREATH) * 0.5 + 0.5
		_sprite.modulate.a = 0.70 + 0.30 * wave

	if _age < _life:
		return
	set_process(false)
	# Stops counting the moment it starts closing: a circle that is fading out
	# should no longer be slowing anything standing in it.
	aura_radius = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	t.parallel().tween_property(self, "scale", Vector2(0.86, 0.86), FADE_OUT)
	t.tween_callback(queue_free)
