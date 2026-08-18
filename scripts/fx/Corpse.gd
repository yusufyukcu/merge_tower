class_name Corpse
extends Node2D

# What is left of an enemy after the last blow lands.
#
# Everything else in the game dies by dissolving: a violet puff goes up, the
# body shrinks into it, and a second later there is no evidence anything was
# ever standing there. That reads as magic, which is right for a boss made of
# rock and wrong for a goblin somebody just hit with an axe -- and it throws
# away the only thing a fight leaves behind that the player can look at.
#
# So the seven bodies with drawn remains come apart instead. Each of them has a
# sheet in art/<id>_dead.png: the creature laid out in pieces, painted as an
# exploded view -- head here, an arm there, its weapon on the floor between
# them. Those sheets were cut into one file per piece (art/<id>_gib_N.png) and
# the layout they were drawn in is the table below, so the heap a body settles
# into is the arrangement the artist actually composed rather than a scatter
# this file invented.
#
# The whole thing runs in three beats:
#
#   0.00  the body is gone and the pieces are where it was, clustered small and
#         overlapping. They are thrown out along the drawn layout, spinning,
#         while a spray of blood goes with them and a flash covers the swap.
#   0.34  the pieces land, bounce once, and stop. The pool they fell in has
#         soaked into the ground under them by now.
#   2.55  the heap fades out over two thirds of a second, sinking very slightly
#         as it goes, and takes itself off the field.
#
# It lives on the ground layer rather than in the fight, so a corpse is never
# something a living soldier can hide behind.

const FxUtil = preload("res://scripts/fx/FxUtil.gd")
const Shockwave = preload("res://scripts/fx/Shockwave.gd")

# ------------------------------------------------------------------ the sheets
#
# One entry per body that has remains drawn for it. The three bosses have none
# and keep the old dissolve -- a stone golem does not bleed, and nothing was
# ever painted for what a dragon leaves.
#
#   "scale"  how far the sheet is shrunk to sit on the field. Not picked by eye:
#            each one is sqrt(A_live / A_sheet) times the scale the living
#            sprite is drawn at, where the two areas are the pixels each
#            actually covers. That makes the heap carry the same amount of
#            body the standing creature did, which is the only definition of
#            "the right size" that holds across a bat and an orc.
#   "at"     where the piece sits in the heap, in sheet pixels from the middle
#            of the drawn layout. Measured off the sheet, not authored.
#   "gore"   what it sprays and what soaks into the ground under it.
#   "grit"   the second, slower cloud: dust off armour, bone off a skeleton,
#            ice off anything the winter made.
#
# The order is the order they were cut in, which is largest piece first -- the
# torso is always index 0. That matters: the parts are re-sorted by where they
# land before they are added, so a hand that comes to rest in front of the body
# is drawn in front of it, but the torso is what the flash is sized against.
const SHEETS := {
	"goblin": {
		"scale": 0.108, "gore": Color(0.55, 0.09, 0.10), "grit": Color(0.36, 0.42, 0.20),
		"parts": [
			Vector2(-23, 142), Vector2(19, -195), Vector2(368, -218), Vector2(-356, 258),
			Vector2(-318, -256), Vector2(351, 23), Vector2(-380, 27), Vector2(272, 309),
			Vector2(-247, -86), Vector2(231, 174),
		],
	},
	"orc": {
		"scale": 0.130, "gore": Color(0.50, 0.08, 0.07), "grit": Color(0.42, 0.34, 0.22),
		"parts": [
			Vector2(-15, -50), Vector2(58, -308), Vector2(-29, 348), Vector2(350, 107),
			Vector2(235, 281), Vector2(-325, 214), Vector2(322, -259), Vector2(-397, -40),
			Vector2(-298, -303), Vector2(-92, 186), Vector2(353, -97),
		],
	},
	# Hollow. The sheet is armour and nothing else -- there is no body inside any
	# of those plates -- so what comes out of it is mostly the dark of whatever
	# was in there, with only as much red as the trim already carries.
	"armored_knight": {
		"scale": 0.146, "gore": Color(0.44, 0.07, 0.09), "grit": Color(0.34, 0.34, 0.38),
		"parts": [
			Vector2(-45, -40), Vector2(354, 29), Vector2(-237, 176), Vector2(216, 252),
			Vector2(17, -332), Vector2(-318, 342), Vector2(-262, -278), Vector2(284, -216),
			Vector2(-381, -106), Vector2(-5, 183),
		],
	},
	# The one that dies in the air. The pieces still fall to the ground it was
	# hovering over, because that is where the heap has to be for the shadow the
	# rest of the field agrees on to mean anything.
	"bat": {
		"scale": 0.082, "gore": Color(0.42, 0.09, 0.17), "grit": Color(0.30, 0.22, 0.34),
		"parts": [
			Vector2(344, 20), Vector2(-452, -55), Vector2(-3, -148), Vector2(-97, 155),
			Vector2(-346, 192), Vector2(235, 273), Vector2(-318, -286), Vector2(128, 147),
			Vector2(-459, 125), Vector2(202, -318),
		],
	},
	# Flesh under the frost: it bleeds like an animal and throws the ice it was
	# wearing with it, which is why this is the only one whose two clouds are
	# nothing like each other.
	"ice_wolf": {
		"scale": 0.120, "gore": Color(0.52, 0.10, 0.14), "grit": Color(0.62, 0.86, 1.00),
		"parts": [
			Vector2(4, 113), Vector2(122, -226), Vector2(-236, -229), Vector2(410, 78),
			Vector2(-483, -51), Vector2(413, -272), Vector2(-420, 127), Vector2(-172, 293),
			Vector2(291, 302), Vector2(552, 7), Vector2(459, 317), Vector2(-350, 312),
		],
	},
	# Nothing in it to bleed. What comes off a skeleton coming apart is the ice
	# holding it together and the bone it was holding, so the "gore" here is
	# meltwater blue and the pool it leaves is frost rather than red.
	"ice_soldier": {
		"scale": 0.135, "gore": Color(0.58, 0.84, 1.00), "grit": Color(0.84, 0.82, 0.74),
		"parts": [
			Vector2(-33, -1), Vector2(-345, -60), Vector2(86, -313), Vector2(288, 226),
			Vector2(1, 317), Vector2(417, 140), Vector2(-204, -298), Vector2(297, -223),
			Vector2(-362, 261), Vector2(191, -58), Vector2(408, -68), Vector2(-238, 107),
			Vector2(136, 260),
		],
	},
	"ice_wizard": {
		"scale": 0.130, "gore": Color(0.52, 0.78, 1.00), "grit": Color(0.62, 0.56, 0.92),
		"parts": [
			Vector2(-81, 62), Vector2(45, -363), Vector2(-310, -180), Vector2(367, 99),
			Vector2(200, 223), Vector2(-242, 365), Vector2(206, -169), Vector2(37, 360),
			Vector2(287, -28), Vector2(-389, 45), Vector2(558, -222), Vector2(369, -208),
			Vector2(437, 173), Vector2(356, 340),
		],
	},
}

# How much of the drawn layout survives the landing. The sheets are exploded
# views with air between every piece; a body that came apart on the ground is a
# heap, so the arrangement is kept and pulled in.
#
# The y is pulled in much harder than the x for the same reason every circle
# painted on this floor is flattened: the field is seen at an angle, and things
# lying on it spread sideways rather than up the screen.
const SPREAD := Vector2(0.92, 0.62)

const THROW := 0.34       # how long the pieces are in the air
const HOLD := 2.20        # how long the heap lies there once it has settled
const FADE := 0.70        # and how long it takes to leave

# A late wave kills a great many things very quickly. Past this many heaps on
# the floor the oldest is told to start leaving early, so a bad minute silts the
# ground layer up with corpses instead of grinding on them.
const MAX_CORPSES := 14

static var _live: Array = []

static func has_art(enemy_id: String) -> bool:
	return SHEETS.has(enemy_id)

# Pulls a body's pieces into the resource cache before anything needs them.
# Called when the first of that kind is built rather than when the first of them
# dies: a dozen textures loading on the frame an enemy explodes is a stutter on
# exactly the frame the player is looking hardest at.
static var _warmed := {}

static func warm(enemy_id: String) -> void:
	if _warmed.has(enemy_id) or not SHEETS.has(enemy_id):
		return
	_warmed[enemy_id] = true
	var count: int = (SHEETS[enemy_id]["parts"] as Array).size()
	for i in range(count):
		load(_tex_path(enemy_id, i))

static func _tex_path(enemy_id: String, i: int) -> String:
	return "res://art/%s_gib_%d.png" % [enemy_id, i]

# The splat under the heap, worked out once and drawn once: a scatter of pixels
# rather than a smooth blob, because a soft ellipse of red on this art reads as
# a light being shone on the floor rather than as something spilt on it.
var _pool: Array = []
var _pool_color: Color = Color(0.5, 0.08, 0.08)

# `radius` is the body's own, and it sizes everything that is not the pieces
# themselves -- the pool, the spray, the flash. `facing` mirrors the layout for
# a body that died walking the other way, so the heap faces the way it fell.
func play(enemy_id: String, radius: float, facing: float = 1.0) -> void:
	var def: Dictionary = SHEETS.get(enemy_id, {})
	if def.is_empty():
		queue_free()
		return

	var scale_to: float = float(def["scale"])
	var gore: Color = def["gore"]
	var grit: Color = def["grit"]
	var flip: bool = facing < 0.0

	# The light the ground is throwing back here, taken once and worn by every
	# piece: a heap on a snowfield and a heap in the mine are lit by what they
	# are lying on, exactly as the body was a moment ago.
	var lit: Color = Ambient.tint_at(global_position) * Lighting.body_tint()

	_pool_color = Color(gore.r * 0.62, gore.g * 0.62, gore.b * 0.62, 0.85)
	_build_pool(radius)
	self_modulate.a = 0.0
	queue_redraw()

	var list: Array = def["parts"]
	# Sorted by where each piece comes to rest, so the ones nearest the viewer
	# are added last and therefore drawn over the ones behind them.
	var order: Array = []
	for i in range(list.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return (list[a] as Vector2).y < (list[b] as Vector2).y)

	for entry in order:
		var i: int = int(entry)
		_add_part(enemy_id, i, (list[i] as Vector2), scale_to, flip, lit)

	_burst(radius, gore, grit)

	var life := create_tween()
	life.tween_property(self, "self_modulate:a", 1.0, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	life.tween_interval(THROW + HOLD - 0.26)
	life.tween_callback(dismiss)

	_live.append(self)
	while _live.size() > MAX_CORPSES:
		var old = _live.pop_front()
		if old != null and is_instance_valid(old):
			old.dismiss()

# Starts the fade, from wherever the heap has got to. Safe to call twice: the
# second call finds the flag already set and leaves the first fade running.
var _leaving: bool = false

func dismiss() -> void:
	if _leaving:
		return
	_leaving = true
	_live.erase(self)
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, FADE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Sinks into the floor as it goes rather than simply thinning out. A few
	# pixels is all it takes for "soaking away" instead of "switching off".
	out.parallel().tween_property(self, "position",
		position + Vector2(0, 3.0), FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	out.tween_callback(queue_free)

# One piece: dropped where the body was, thrown out to its place in the layout,
# and left there. The three tweens are deliberately separate -- the sideways
# throw slows the whole way out, the height arcs up and comes back down twice,
# and the spin runs longer than either -- because a single tween over all three
# is a piece sliding, and three that disagree is a piece tumbling.
func _add_part(enemy_id: String, index: int, at: Vector2, scale_to: float,
		flip: bool, lit: Color) -> void:
	var s := Sprite2D.new()
	s.texture = load(_tex_path(enemy_id, index))
	if s.texture == null:
		return
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.flip_h = flip
	s.modulate = lit

	var to: Vector2 = Vector2(at.x * (-1.0 if flip else 1.0), at.y) \
		* scale_to * SPREAD
	# Everything starts inside the silhouette the body filled a frame ago, small
	# and piled on itself, so the first thing the eye sees is the shape it was
	# already looking at rather than a dozen sprites appearing.
	s.position = Vector2(randf_range(-4.0, 4.0), randf_range(-5.0, 1.0))
	s.scale = Vector2.ONE * scale_to * 0.55
	s.rotation = randf_range(-0.7, 0.7)
	add_child(s)

	# How high it is thrown: whatever is going furthest goes highest, with
	# enough of a floor under it that a piece landing on the spot still hops.
	var hop: float = 6.0 + to.length() * 0.42
	var settle: float = randf_range(-0.42, 0.42)

	var out := s.create_tween()
	out.tween_property(s, "position:x", to.x, THROW) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	out.parallel().tween_property(s, "rotation", settle, THROW + 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	out.parallel().tween_property(s, "scale", Vector2.ONE * scale_to, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var arc := s.create_tween()
	arc.tween_property(s, "position:y", to.y - hop, THROW * 0.42) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(s, "position:y", to.y, THROW * 0.58) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	arc.tween_property(s, "position:y", to.y - hop * 0.20, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(s, "position:y", to.y, 0.11) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# ------------------------------------------------------------------ the spray
#
# Three passes, none of which is the same shape as the others: the wet spray
# that leaves the wound fast and falls hard, a slower cloud of whatever the body
# was wearing, and a fine mist that hangs after both. Every one of them is drawn
# with square particles -- see FxUtil.pixel_texture -- because a soft round dot
# painted red is smoke, not blood.
func _burst(radius: float, gore: Color, grit: Color) -> void:
	var size: float = clampf(radius / 30.0, 0.7, 2.0)

	# The flash that covers the swap. The body is taken off the field on the
	# same frame these pieces appear, and without something bright over the join
	# the eye catches one sprite being replaced by twelve.
	var flash := FxUtil.bloom(self, 0.12 * size, 0.85,
		Color(gore.r + 0.35, gore.g + 0.18, gore.b + 0.18), 96)
	var tf := flash.create_tween()
	tf.tween_property(flash, "scale", Vector2.ONE * 0.62 * size, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tf.parallel().tween_property(flash, "modulate:a", 0.0, 0.20)
	tf.tween_callback(flash.queue_free)

	Lighting.flash(self, global_position, gore, 0.85 * size, 190.0 * size, 0.22)

	var spray := _pixels(16, 0.42, 150.0 * size, 340.0 * size,
		Color(gore.r * 1.5, gore.g * 1.3, gore.b * 1.3, 1.0),
		Color(gore.r * 0.5, gore.g * 0.45, gore.b * 0.45, 0.0))
	spray.gravity = Vector2(0, 780)
	spray.emission_sphere_radius = radius * 0.28
	spray.scale_amount_min = 1.0
	spray.scale_amount_max = 2.6
	spray.emitting = true

	# Thrown up rather than out, and heavier: the drops that go straight over
	# the body and come back down on top of the heap.
	var arc := _pixels(9, 0.55, 190.0 * size, 330.0 * size,
		Color(gore.r * 1.35, gore.g * 1.15, gore.b * 1.15, 1.0),
		Color(gore.r * 0.45, gore.g * 0.4, gore.b * 0.4, 0.0))
	arc.direction = Vector2.UP
	arc.spread = 46.0
	arc.gravity = Vector2(0, 900)
	arc.scale_amount_min = 1.2
	arc.scale_amount_max = 3.0
	arc.emitting = true

	var dust := _pixels(11, 0.60, 60.0 * size, 175.0 * size,
		Color(grit.r, grit.g, grit.b, 0.9),
		Color(grit.r * 0.6, grit.g * 0.6, grit.b * 0.65, 0.0))
	dust.gravity = Vector2(0, 240)
	dust.damping_min = 70.0
	dust.damping_max = 150.0
	dust.scale_amount_min = 1.4
	dust.scale_amount_max = 3.4
	dust.scale_amount_curve = FxUtil.swell_curve()
	dust.emitting = true

	var ring := Shockwave.new()
	ring.color = Color(gore.r + 0.22, gore.g + 0.10, gore.b + 0.10)
	add_child(ring)
	ring.scale = Vector2(1.0, 0.45)
	ring.run(4.0, 40.0 * size, 7.0, 1.5, 0.55, 0.26)

func _pixels(amount: int, life: float, vel_min: float, vel_max: float,
		from_col: Color, to_col: Color) -> CPUParticles2D:
	var p := FxUtil.burst(self, amount, life, vel_min, vel_max,
		from_col, to_col, false)
	p.texture = FxUtil.pixel_texture()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.angular_velocity_min = 0.0
	p.angular_velocity_max = 0.0
	return p

# ------------------------------------------------------------------- the pool
#
# What soaked into the ground while the pieces were still in the air. Squares
# scattered on a flattened disc, thickest in the middle and sparse at the rim,
# with a handful thrown further out as the odd fleck that carried.
#
# Drawn on this node itself rather than on a child, which is what lets it fade
# in on its own clock (self_modulate) while the heap above it fades out on the
# shared one (modulate).
func _build_pool(radius: float) -> void:
	var spread: float = radius * 1.05
	var count: int = int(clampf(radius * 1.1, 22.0, 54.0))
	for i in range(count):
		# Square-rooted so the scatter is even over the area rather than
		# crowding the middle, then biased back inward a little by hand.
		var a: float = randf() * TAU
		var r: float = sqrt(randf()) * spread * (1.35 if randf() < 0.12 else 1.0)
		var px: float = clampf(radius * 0.10, 1.0, 3.0)
		if randf() < 0.35:
			px *= 1.8
		_pool.append([
			Vector2(cos(a) * r, sin(a) * r * 0.46),
			px,
			randf_range(0.45, 1.0),
		])

func _draw() -> void:
	for cell in _pool:
		var at: Vector2 = cell[0]
		var px: float = cell[1]
		var col := _pool_color
		col.a *= float(cell[2])
		draw_rect(Rect2(at - Vector2(px, px) * 0.5, Vector2(px, px)), col)
