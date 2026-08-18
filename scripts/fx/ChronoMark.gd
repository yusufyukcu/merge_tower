extends Node2D
class_name ChronoMark

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# The hourglass that stands over a body the cronomancer has caught, and the one
# thing on screen that says *why* a goblin is suddenly walking through treacle.
#
# The blue wash on the body alone is not enough. A colour change reads as
# lighting -- the map already turns the whole field blue when winter lands --
# and what the player actually needs off this effect is a count: how many of the
# things coming up the road are still held, answered from across the screen
# without reading anything. A row of hourglasses answers that; a row of bodies
# in a slightly different blue does not.
#
# It turns rather than spins. The drawing is a flat glass seen from the front,
# so its width is squeezed to nothing and let back out on a slow beat, which is
# what a body turning end-on looks like without a second drawing for it.

const TEX := "res://art/fx_chrono_mark.png"

# How tall the glass stands, and how far over the body's own top edge it floats.
const HEIGHT := 34.0
const CLEARANCE := 16.0

const TURN_RATE := 2.1
const BOB_RATE := 2.6
const BOB_PX := 3.0

var _sprite: Sprite2D = null
var _glow: Sprite2D = null
var _phase: float = 0.0
var _rest_y: float = 0.0
var _scale: float = 1.0
var _closing: bool = false

func setup(radius: float, tint: Color = Color(0.62, 0.82, 1.0)) -> void:
	z_index = 2   # over the body and over anything wound round it
	_rest_y = -radius - CLEARANCE - HEIGHT * 0.5
	# A random start, so a rank caught by one cast does not turn as one object.
	_phase = randf() * TAU

	# The soft light behind it, which is what keeps the glass readable over a
	# dark body without the drawing itself having to be brightened.
	_glow = FxUtil.bloom(self, 0.0, 0.0, tint, 64)
	_glow.position = Vector2(0, _rest_y)

	if not ResourceLoader.exists(TEX):
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEX)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_scale = HEIGHT / maxf(float(_sprite.texture.get_height()), 1.0)
	_sprite.scale = Vector2(_scale, _scale)
	_sprite.position = Vector2(0, _rest_y)
	add_child(_sprite)

	# Dropped in rather than faded in: the hour arrives on the body, it does not
	# resolve onto it.
	_sprite.modulate.a = 0.0
	_sprite.position.y = _rest_y - 22.0
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 1.0, 0.14)
	tw.parallel().tween_property(_sprite, "position:y", _rest_y, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tg := create_tween()
	tg.tween_property(_glow, "scale", Vector2.ONE * 0.62, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tg.parallel().tween_property(_glow, "modulate:a", 0.5, 0.22)

func _process(delta: float) -> void:
	if _closing or _sprite == null or not is_instance_valid(_sprite):
		return
	_phase += delta
	_sprite.position.y = _rest_y + sin(_phase * BOB_RATE) * BOB_PX
	# Never quite edge-on: a glass squeezed to nothing for a frame reads as the
	# sprite blinking out rather than as it turning.
	_sprite.scale.x = _scale * maxf(0.16, cos(_phase * TURN_RATE))
	if _glow != null and is_instance_valid(_glow):
		_glow.modulate.a = 0.38 + 0.16 * sin(_phase * 1.7)

# The hour closing on this body. Lifted away and thinned out rather than cut,
# so a rank coming back up to speed is something the player sees leave.
func close() -> void:
	if _closing:
		return
	_closing = true
	set_process(false)
	var tw := create_tween()
	if _sprite != null and is_instance_valid(_sprite):
		tw.tween_property(_sprite, "modulate:a", 0.0, 0.22)
		tw.parallel().tween_property(_sprite, "position:y", _rest_y - 26.0, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_sprite, "scale", Vector2(_scale, _scale) * 0.7, 0.22)
	if _glow != null and is_instance_valid(_glow):
		tw.parallel().tween_property(_glow, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)
