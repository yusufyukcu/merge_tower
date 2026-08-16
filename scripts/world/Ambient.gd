class_name Ambient
extends RefCounted

# What the ground under a body is doing to the light on it.
#
# The map is one painted image and the units are drawn on top of it at full
# strength, which is why they read as stickers: a knight standing in the mine
# is lit exactly like a knight standing on sunlit grass, and nothing in the
# picture agrees with anything else.
#
# There is no light rig here to fix that with, but there is a painting -- and
# the painting already knows where it is dark, where the torches are and what
# colour the ground is. So the map is its own light map: it is shrunk right
# down, which averages each patch of it into one colour, and a body is tinted
# by whatever it is standing on.
#
# The tint is relative rather than absolute. Multiplying by the ground colour
# outright would drown everything, so each patch is measured against the map's
# own average brightness: darker than average darkens the body, brighter lifts
# it, and a torch's warm patch pulls it warm. On a map with even light this
# does nothing at all, which is the correct answer for an evenly lit map.

# Coarse on purpose. Each texel of this is an average of some seventeen pixels
# square of the painting, which is about the size of the pool of light a torch
# throws -- fine enough to pick that up, coarse enough that a unit crossing a
# pebble does not flicker.
const GRID := 72

# How far a body is allowed to be pushed from its painted colours. Past this it
# stops reading as the same unit the player merged.
const FLOOR := 0.62
const CEIL := 1.28

static var _map: Image = null
static var _origin: Vector2 = Vector2.ZERO   # world position of the map's top-left
static var _span: Vector2 = Vector2.ONE      # how much world the map covers
static var _average: Color = Color(1, 1, 1)
static var _strength: float = 0.0

# How far the ground is allowed to speak by default. Named rather than left as
# a literal because Lighting winds it down as the evening comes on -- see
# set_strength.
const BASE_STRENGTH := 0.42

# `origin` and `span` are where the painting actually landed in the world, so
# this follows the map however Main chose to hang it.
static func setup(tex: Texture2D, origin: Vector2, span: Vector2,
		strength: float = BASE_STRENGTH) -> void:
	_strength = 0.0
	_map = null
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(GRID, GRID, Image.INTERPOLATE_LANCZOS)
	_map = img

	# The map's own average, taken by shrinking it the rest of the way.
	var one: Image = img.duplicate()
	one.resize(1, 1, Image.INTERPOLATE_LANCZOS)
	_average = one.get_pixel(0, 0)
	# A black map would divide everything by nothing.
	if _average.r + _average.g + _average.b < 0.03:
		return

	_origin = origin
	_span = Vector2(maxf(span.x, 1.0), maxf(span.y, 1.0))
	_strength = strength

static func is_ready() -> bool:
	return _map != null and _strength > 0.0

# The map's own light is the whole story at noon and very little of it at
# midnight: by then the difference between grass and road is nothing next to the
# difference between standing in a torch pool and standing outside one, and
# leaving this at full strength only fights the grade the evening is applying.
# Ignored until a map has been handed over, so the order of the two calls in
# Main cannot matter.
static func set_strength(value: float) -> void:
	if _map == null:
		return
	_strength = clampf(value, 0.0, 1.0)

# The multiplier to hang on a body standing here. White when there is no map,
# so everything works exactly as before until one is handed over.
static func tint_at(world: Vector2) -> Color:
	if not is_ready():
		return Color(1, 1, 1)
	var c: Color = light_at(world)
	return Color(
		clampf(c.r / _average.r, FLOOR, CEIL),
		clampf(c.g / _average.g, FLOOR, CEIL),
		clampf(c.b / _average.b, FLOOR, CEIL)
	).lerp(Color(1, 1, 1), 1.0 - _strength)

# The ground's own colour here, unweighted -- what dust kicked up off it should
# be coloured, so a boot on snow throws snow and a boot on dirt throws dirt.
static func light_at(world: Vector2) -> Color:
	if _map == null:
		return Color(1, 1, 1)
	var u: float = (world.x - _origin.x) / _span.x
	var v: float = (world.y - _origin.y) / _span.y
	var x: int = clampi(int(u * GRID), 0, GRID - 1)
	var y: int = clampi(int(v * GRID), 0, GRID - 1)
	return _map.get_pixel(x, y)
