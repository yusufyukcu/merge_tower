class_name GroundShadow
extends Sprite2D

# The soft patch of dark a body puts on the ground it is standing on.
#
# Without one a sprite is a sticker: there is nothing saying where it meets the
# floor, so it reads as hanging in front of the map rather than standing on it.
# This is the single cheapest thing that fixes that, and every body on the field
# gets one.
#
# It is a radial falloff rather than a hard ellipse. A crisp edge reads as a
# painted decal on the ground; what a body actually casts on a diffusely lit
# field is dark under the feet fading to nothing a little way out -- and the
# soft edge is also what lets it sit over painted grass without cutting a hole
# in it.
#
# Everything about it answers to the body above: it tightens and darkens as the
# body settles onto its feet, spreads and pales as it lifts. A shadow that does
# not move is very nearly as dead as no shadow at all.
#
# It also answers to the light. At noon the sun is nearly overhead and this sits
# squarely under the boots, which is where it always used to sit; as the evening
# comes on it slides out from under them and lies along the ground away from
# whatever is lighting the body -- the sky, or the signpost candle it happens to
# be standing next to. Two soldiers either side of a torch throwing their
# shadows in opposite directions is the cheapest proof the game can offer that
# the torch is really there.

# Flatter than round: the field is seen at a slight angle, and every other
# circle drawn on this floor (totem rings, frost fields) is flattened to match.
const FLATTEN := 0.42
const BASE_ALPHA := 0.44

# Solid through the middle and soft only at the rim. A plain two-stop falloff is
# faint everywhere except its exact centre -- and its exact centre is the one
# part of it the body is standing on top of, so all that was left showing was
# the part that had already faded to nothing. What has to be dark is the
# crescent that clears the feet.
static var _disc_tex: GradientTexture2D = null

static func _disc() -> GradientTexture2D:
	if _disc_tex != null:
		return _disc_tex
	var dark := Color(0.03, 0.04, 0.07, 1.0)
	var grad := Gradient.new()
	grad.set_color(0, dark)
	grad.set_color(1, Color(dark.r, dark.g, dark.b, 0.0))
	grad.add_point(0.52, dark)
	grad.add_point(0.74, Color(dark.r, dark.g, dark.b, 0.55))

	_disc_tex = GradientTexture2D.new()
	_disc_tex.gradient = grad
	_disc_tex.fill = GradientTexture2D.FILL_RADIAL
	_disc_tex.fill_from = Vector2(0.5, 0.5)
	_disc_tex.fill_to = Vector2(1.0, 0.5)
	_disc_tex.width = 64
	_disc_tex.height = 64
	return _disc_tex
# How much the shadow answers to a body rising: at full lift it is this much
# wider and this much of its darkness is gone.
const LIFT_SPREAD := 0.30
const LIFT_FADE := 0.55

var _radius: float = 34.0
# Where under the body it belongs, which is under the boots rather than under
# the middle. Held here rather than in `position`, because position is now where
# the light has pushed it to and the two have to be kept apart.
var _anchor: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.DOWN
# Kept alongside the direction rather than taken from it: a walking body
# re-applies this every frame as it bobs, and the light it is standing in
# changes five times a second at most.
var _rot: float = 0.0
var _throw: float = 0.0
var _lift: float = 0.0

func setup(radius: float, anchor: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	_radius = radius
	_anchor = anchor
	texture = _disc()
	# Deliberately not additive: this is the one effect in the game that has to
	# subtract light rather than add it.
	centered = true
	modulate = Color(1, 1, 1, BASE_ALPHA * strength)
	_apply()

# Direction times distance, as Lighting hands it over: which way the light is
# pushing the shadow and how far. Asked for on the same slow timer the body's
# own colour is, since neither the sun nor a signpost moves in a hurry.
func set_light(throw: Vector2) -> void:
	var reach: float = throw.length()
	if reach > 0.001:
		_dir = throw / reach
		_rot = _dir.angle()
		_throw = minf(reach, 1.0)
	else:
		_throw = 0.0
	_apply()

# 0 is planted, 1 is as far off the ground as this body ever gets.
func set_lift(t: float) -> void:
	_lift = clampf(t, 0.0, 1.0)
	_apply()

func _apply() -> void:
	if texture == null:
		return
	var width: float = _radius * 2.1 * (1.0 + LIFT_SPREAD * _lift)
	var k: float = width / float(texture.get_width())
	# Turned to face along the light, so the flattening that makes it lie on the
	# floor also stretches it away from whatever is casting it.
	rotation = _rot
	scale = Vector2(k * (1.0 + 0.5 * _throw), k * FLATTEN)
	# A lifted body's shadow runs further out as well as wider -- it is further
	# from the ground, so the same light throws it further.
	position = _anchor + _dir * (_radius * 0.6 * _throw * (1.0 + _lift))
	self_modulate.a = 1.0 - LIFT_FADE * _lift

# ---------------------------------------------------------------- foot line
#
# Where a sprite's feet are, in its own pixels, measured from the middle of the
# picture. The shadow has to go under the boots and not under the middle of the
# body, and every unit's art puts them somewhere different.
#
# Measured off the alpha rather than guessed at per unit, and remembered: it is
# a property of the drawing, so it is worked out once for each picture in the
# game and never again.

static var _feet: Dictionary = {}
const FEET_STEP := 2

static func feet_offset(tex: Texture2D) -> float:
	if tex == null:
		return 0.0
	var key: String = tex.resource_path
	if key == "":
		return 0.0
	if _feet.has(key):
		return float(_feet[key])

	var img: Image = tex.get_image()
	if img == null:
		return 0.0
	if img.is_compressed():
		img.decompress()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var bottom: int = -1
	var y: int = h - 1
	while y >= 0 and bottom < 0:
		var x: int = 0
		while x < w:
			if img.get_pixel(x, y).a > 0.35:
				bottom = y
				break
			x += FEET_STEP
		y -= FEET_STEP
	if bottom < 0:
		bottom = h - 1
	var offset: float = float(bottom) - float(h) * 0.5
	_feet[key] = offset
	return offset
