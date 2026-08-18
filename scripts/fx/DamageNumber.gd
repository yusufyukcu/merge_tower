class_name DamageNumber
extends Node2D

# The number that jumps off an enemy when it is hit.
#
# Drawn rather than typeset. Every font in the project is the engine's default,
# which is a clean modern sans -- next to this art it reads as a debug overlay,
# and the one thing a damage number must never look like is instrumentation. So
# the digits below are a pixel face of their own, laid out cell by cell and
# painted with draw_rect: heavy two-pixel strokes, a black keyline all the way
# round, a lit top edge and a shaded bottom one, and a lean to the right.
#
# It is modelled on art/damage.png, which is a sheet of the same number drawn
# twenty-five times at twenty-five sizes of hit. Two things were taken from it.
# The first is that face. The second is the palette: the sheet runs white to
# gold to orange to red to rose to violet to blue to cyan to green and then
# starts round again, one step per band of damage, so a player learns the colour
# of a big hit long before they can read the digits on it -- see TIERS, which is
# that run of colours transcribed with the sheet's own numbers as its edges.
#
# Behind the digits is what the sheet draws behind them: a soft bloom in the
# same colour, and a handful of thin vertical streaks shooting out above and
# below. Both are children with a negative z so they sit under the text, and
# both are gone long before the number is.
#
# The whole thing is driven from _process rather than from a tween. A tween
# would be shorter, but a second hit landing on the same body 80ms after the
# first has to fold into the number already in the air (see `add`) instead of
# stacking a second one over it, and restarting half of a tween chain from the
# middle is worse than keeping two clocks.

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

enum { HIT, POISON }

# ------------------------------------------------------------------ the face
#
# Six cells across, eight down, strokes two cells thick. Anything thinner
# disappears at the size these are actually drawn at; anything fatter closes up
# the counters in the 8 and the 0.

const GW := 6    # cells across a glyph
const GH := 8    # cells down
const ADV := 7   # pen travel per glyph -- one clear column, which the keylines
                 # of the two neighbours then share, exactly as the sheet does
# How far the top of a glyph leans past its foot, in cells per row. Rounded to
# whole cells, so the lean comes out as the two or three steps a pixel face is
# allowed rather than as a smooth shear.
const SLANT := 0.34

const GLYPHS := {
	"0": [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
	"1": ["..##..", ".###..", "####..", "..##..", "..##..", "..##..", "..##..", "######"],
	"2": [".####.", "##..##", "....##", "...##.", "..##..", ".##...", "##....", "######"],
	"3": [".####.", "##..##", "....##", "..###.", "....##", "....##", "##..##", ".####."],
	"4": ["...##.", "..###.", ".####.", "##.##.", "######", "...##.", "...##.", "...##."],
	"5": ["######", "##....", "##....", "#####.", "....##", "....##", "##..##", ".####."],
	"6": [".####.", "##..##", "##....", "#####.", "##..##", "##..##", "##..##", ".####."],
	"7": ["######", "....##", "....##", "...##.", "...##.", "..##..", "..##..", "..##.."],
	"8": [".####.", "##..##", "##..##", ".####.", "##..##", "##..##", "##..##", ".####."],
	"9": [".####.", "##..##", "##..##", "##..##", ".#####", "....##", "##..##", ".####."],
	"-": ["......", "......", "......", "#####.", "#####.", "......", "......", "......"],
}

const OUTLINE := Color(0.04, 0.03, 0.05, 0.94)

# ----------------------------------------------------------------- the bands
#
# Transcribed straight off art/damage.png: each entry is one of the numbers the
# sheet drew and the colour it drew it in, and `up_to` is the point where that
# colour hands over to the next. Anything past the last one keeps the cyan the
# sheet ends on -- by then the digits are five long and the colour has said
# everything it can.
const TIERS := [
	{"up_to": 15.0, "col": Color(0.94, 0.95, 0.98)},      # -12    bone white
	{"up_to": 30.0, "col": Color(1.00, 0.83, 0.24)},      # -25    gold
	{"up_to": 45.0, "col": Color(1.00, 0.65, 0.16)},      # -37    amber
	{"up_to": 65.0, "col": Color(1.00, 0.47, 0.16)},      # -56    orange
	{"up_to": 90.0, "col": Color(1.00, 0.31, 0.24)},      # -78    ember
	{"up_to": 110.0, "col": Color(0.96, 0.19, 0.23)},     # -96    red
	{"up_to": 135.0, "col": Color(0.98, 0.24, 0.50)},     # -123   rose
	{"up_to": 170.0, "col": Color(0.78, 0.36, 0.98)},     # -150   violet
	{"up_to": 200.0, "col": Color(0.66, 0.36, 0.99)},     # -189   purple
	{"up_to": 235.0, "col": Color(0.49, 0.42, 0.99)},     # -214   indigo
	{"up_to": 285.0, "col": Color(0.35, 0.55, 1.00)},     # -256   blue
	{"up_to": 340.0, "col": Color(0.29, 0.80, 0.99)},     # -312   cyan
	{"up_to": 400.0, "col": Color(0.24, 0.88, 0.74)},     # -368   teal
	{"up_to": 470.0, "col": Color(0.42, 0.92, 0.42)},     # -425   green
	{"up_to": 560.0, "col": Color(0.68, 0.95, 0.30)},     # -512   spring
	{"up_to": 680.0, "col": Color(0.83, 0.97, 0.26)},     # -612   lime
	{"up_to": 820.0, "col": Color(1.00, 0.80, 0.22)},     # -750   gold again
	{"up_to": 960.0, "col": Color(1.00, 0.62, 0.18)},     # -896   orange
	{"up_to": 1150.0, "col": Color(1.00, 0.45, 0.18)},    # -1024  fire
	{"up_to": 1400.0, "col": Color(0.99, 0.24, 0.32)},    # -1280  red
	{"up_to": 1660.0, "col": Color(0.98, 0.18, 0.35)},    # -1536  crimson
	{"up_to": 1920.0, "col": Color(0.94, 0.28, 0.86)},    # -1792  magenta
	{"up_to": 2270.0, "col": Color(0.72, 0.34, 0.99)},    # -2048  purple
	{"up_to": 2750.0, "col": Color(0.45, 0.44, 0.99)},    # -2500  indigo
]
const TIER_TOP := Color(0.32, 0.83, 1.00)                 # -3000  and beyond
const POISON_COL := Color(0.55, 0.94, 0.42)

# ------------------------------------------------------------------- timing

const LIFE := 0.92
const FADE := 0.30
const RISE := 30.0        # how far up the screen it travels over its life
const POP_UP := 0.09      # snap out to its overshoot
const POP_BACK := 0.10    # and back down to size
const POP_OVER := 1.22

# How long after it appears a second hit on the same body may still fold into
# it. Wide enough to catch a volley of arrows landing together and an ability
# that hits every enemy twice, short enough that two separate blows a third of
# a second apart still read as two blows.
const MERGE_WINDOW := 0.30

# The size the digits are drawn at, before the punch multiplier. Small on
# purpose: this fires several times a second across a whole line of enemies, and
# a number big enough to be impressive once is illegible clutter forty times.
const PIXEL := 1.9
const PIXEL_PUNCH := 0.45   # extra size at a full-strength hit
const PIXEL_POISON := 0.78

var kind: int = HIT

var _total: float = 0.0
var _base_px: float = PIXEL
var _from: Vector2 = Vector2.ZERO
var _drift: float = 0.0
var _life: float = LIFE
var _t: float = 0.0        # life clock -- never rewound
var _pop_t: float = 99.0   # pop clock -- restarted every time the number grows
var _col: Color = Color.WHITE

# Cell lists, in glyph cells relative to the middle of the number. Rebuilt
# whenever the value changes, which is only ever on a merge.
var _edge: Array = []
var _body: Array = []
var _top: Array = []
var _low: Array = []
var _width: float = 30.0   # how wide the composed number is, in cells

var _glow: Sprite2D = null
var _streaks: Array = []

# Nothing happens until `play` has said what the number is. Without this the
# frame between add_child and that call is spent climbing away from the origin
# with no digits in it.
func _ready() -> void:
	set_process(false)

# `at` is the middle of the body that was hit and `radius` is how big it is;
# between them they decide where around it this lands. `punch` is the share of
# the enemy's own health the blow took, clamped to 0..1 by the caller -- it
# sizes the digits, so a hit that takes a quarter off something is visibly a
# bigger number than one that scratches it.
func play(amount: float, at: Vector2, radius: float, punch: float,
		of_kind: int = HIT) -> void:
	kind = of_kind
	_total = amount
	_base_px = PIXEL * (1.0 + PIXEL_PUNCH * clampf(punch, 0.0, 1.0))
	if kind == POISON:
		_base_px *= PIXEL_POISON
	_col = _tier_color()

	# Around the body rather than over it: a number planted on an enemy's face
	# hides the enemy, and forty of them stacked on one point is a smear. The
	# four corners keep them apart from each other and off the art.
	var spread: float = maxf(radius, 22.0)
	var side: float = -1.0 if randf() < 0.5 else 1.0
	_from = at + Vector2(
		side * randf_range(spread * 0.45, spread * 0.95),
		-radius * 0.55 + randf_range(-spread * 0.30, spread * 0.18))
	global_position = _from
	# Local, because `_from` is where the parent thinks we are, and the rise
	# below is measured from there.
	_from = position
	# Drifts further out the way it started, so two numbers that appear on the
	# same side still separate as they climb.
	_drift = side * randf_range(3.0, 11.0)

	_compose()
	_build_glow()
	_pop_t = 0.0
	set_process(true)

# A second blow inside the merge window. It is added to the number already in
# the air rather than given one of its own: a volley of six arrows landing
# together is one number that reads 138, not six overlapping numbers that
# cannot be read at all.
func can_merge(of_kind: int) -> bool:
	return of_kind == kind and _t < MERGE_WINDOW

func add(amount: float, punch: float) -> void:
	_total += amount
	_base_px = maxf(_base_px, PIXEL * (1.0 + PIXEL_PUNCH * clampf(punch, 0.0, 1.0)))
	if kind == POISON:
		_base_px = minf(_base_px, PIXEL * PIXEL_POISON * (1.0 + PIXEL_PUNCH))
	var was: Color = _col
	_col = _tier_color()
	_compose()
	if _col != was:
		_tint_glow()
	# Punched again and given the rest of its life back, so a number that is
	# still growing never starts fading in the middle of growing.
	_pop_t = 0.0
	_life = maxf(_life, _t + 0.70)

func _tier_color() -> Color:
	if kind == POISON:
		return POISON_COL
	for tier in TIERS:
		if _total < float(tier["up_to"]):
			return tier["col"]
	return TIER_TOP

# ------------------------------------------------------------------ the type
#
# The string is laid into one grid, and then three passes are read back out of
# it: the keyline is every empty cell touching an inked one, the lit edge is
# every inked cell with nothing above it, and the shaded edge every inked cell
# with nothing below. Doing it over the whole number rather than glyph by glyph
# is what lets the keylines of two neighbouring digits meet in the column
# between them instead of doubling up there.
func _compose() -> void:
	var text: String = "-" + str(maxi(1, int(round(_total))))
	var lean: int = int(round((GH - 1) * SLANT))
	var w: int = ADV * text.length() - (ADV - GW) + lean + 2
	var h: int = GH + 2

	var on := PackedByteArray()
	on.resize(w * h)
	on.fill(0)
	for gi in range(text.length()):
		var rows: Array = GLYPHS.get(text[gi], GLYPHS["0"])
		var ox: int = 1 + gi * ADV
		for gy in range(GH):
			var row: String = rows[gy]
			var shift: int = int(round(float(GH - 1 - gy) * SLANT))
			for gx in range(GW):
				if row[gx] == "#":
					on[(gy + 1) * w + (ox + gx + shift)] = 1

	_edge = []
	_body = []
	_top = []
	_low = []
	_width = float(w)
	var mid := Vector2(-w * 0.5, -h * 0.5)
	for y in range(h):
		for x in range(w):
			var here: bool = on[y * w + x] == 1
			var cell: Vector2 = Vector2(x, y) + mid
			if here:
				_body.append(cell)
				if y == 0 or on[(y - 1) * w + x] == 0:
					_top.append(cell)
				if y == h - 1 or on[(y + 1) * w + x] == 0:
					_low.append(cell)
				continue
			if _touches(on, w, h, x, y):
				_edge.append(cell)
	queue_redraw()

func _touches(on: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		var ny: int = y + dy
		if ny < 0 or ny >= h:
			continue
		for dx in range(-1, 2):
			var nx: int = x + dx
			if nx < 0 or nx >= w:
				continue
			if on[ny * w + nx] == 1:
				return true
	return false

func _draw() -> void:
	var one := Vector2.ONE
	for c in _edge:
		draw_rect(Rect2(c, one), OUTLINE)
	for c in _body:
		draw_rect(Rect2(c, one), _col)
	# The light on the number, and the weight under it. Painted after the body
	# so an isolated stroke -- the bar of the minus, the crossbar of the 4 --
	# gets both, which is what keeps a two-cell stroke from reading as a slab.
	var hi: Color = _col.lerp(Color(1, 1, 1), 0.55)
	var lo: Color = _col.lerp(Color(0.06, 0.02, 0.06), 0.42)
	for c in _low:
		draw_rect(Rect2(c, one), lo)
	for c in _top:
		draw_rect(Rect2(c, one), hi)

# ------------------------------------------------------------------ the light
#
# What the sheet paints behind the digits: a wide flat bloom and a scatter of
# thin vertical streaks going both ways out of it. Negative z so they sit under
# the type, and a life of their own so they are gone by the time the number is
# halfway up -- the flash belongs to the moment of the hit, the number belongs
# to reading it.
func _build_glow() -> void:
	# Sized off the number it sits behind rather than fixed, so a five-digit
	# reading is not lit by a bloom cut for a two-digit one. Both textures are
	# square-ish and scaled in glyph cells, hence the division by their own size.
	var wide: float = _width * 1.5 / 96.0

	_glow = Sprite2D.new()
	_glow.texture = FxUtil.radial_texture(Color(1, 1, 1, 1), Color(1, 1, 1, 0), 96)
	_glow.material = FxUtil.additive()
	_glow.z_index = -1
	_glow.scale = Vector2(wide * 0.45, 0.12)
	_glow.modulate = Color(_col.r, _col.g, _col.b, 0.0)
	add_child(_glow)

	var tg := _glow.create_tween()
	tg.tween_property(_glow, "modulate:a", 0.85, 0.06)
	tg.parallel().tween_property(_glow, "scale", Vector2(wide, 0.26), 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tg.tween_property(_glow, "modulate:a", 0.0, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var span: float = _width * 0.42
	for i in range(5):
		var up: bool = i % 2 == 0
		var s := Sprite2D.new()
		s.texture = FxUtil.streak_texture(Color(1, 1, 1, 1), Color(1, 1, 1, 0), 4, 64)
		s.material = FxUtil.additive()
		s.z_index = -1
		s.position = Vector2(randf_range(-span, span), 0.0)
		s.scale = Vector2(randf_range(0.35, 0.60), 0.04)
		s.modulate = Color(_col.r, _col.g, _col.b, 0.9)
		add_child(s)
		_streaks.append(s)

		var reach: float = randf_range(0.14, 0.26)
		var ts := s.create_tween()
		ts.tween_property(s, "scale:y", reach, 0.13) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		ts.parallel().tween_property(s, "position:y",
			(-1.0 if up else 1.0) * randf_range(3.0, 7.0), 0.13) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		ts.tween_property(s, "modulate:a", 0.0, 0.20) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ts.parallel().tween_property(s, "scale:y", reach * 0.3, 0.20)

func _tint_glow() -> void:
	if _glow != null and is_instance_valid(_glow):
		_glow.modulate = Color(_col.r, _col.g, _col.b, _glow.modulate.a)
	for s in _streaks:
		if is_instance_valid(s):
			s.modulate = Color(_col.r, _col.g, _col.b, s.modulate.a)

# ------------------------------------------------------------------ the climb

func _process(delta: float) -> void:
	_t += delta
	_pop_t += delta

	var k: float = clampf(_t / _life, 0.0, 1.0)
	# Fast off the mark and slowing the whole way, so the number is furthest
	# from the body in the first fifth of a second, where it is being read.
	position = _from + Vector2(_drift * k, -RISE * (1.0 - pow(1.0 - k, 2.4)))

	var fade: float = 0.0
	if _t > _life - FADE:
		fade = clampf((_t - (_life - FADE)) / FADE, 0.0, 1.0)
	modulate.a = minf(clampf(_t / 0.04, 0.0, 1.0), 1.0 - fade)
	scale = Vector2.ONE * _base_px * _pop() * (1.0 - 0.16 * fade)

	if _t >= _life:
		queue_free()

func _pop() -> float:
	if _pop_t < POP_UP:
		# Overshoots on the way out. The snap is the whole reason the number
		# reads as something that was struck rather than something that faded up.
		var a: float = _pop_t / POP_UP
		return lerpf(0.30, POP_OVER, 1.0 - pow(1.0 - a, 3.0))
	if _pop_t < POP_UP + POP_BACK:
		var b: float = (_pop_t - POP_UP) / POP_BACK
		return lerpf(POP_OVER, 1.0, b * b * (3.0 - 2.0 * b))
	return 1.0
