class_name Lighting
extends Node

# The light the field is standing in.
#
# The map is a painting of a bright afternoon, and for the first few waves that
# is exactly what the player gets. What this adds is everything after: the sun
# goes down across the run, the village lights come up one at a time, the
# signpost candles start to matter, and by the time winter lands the fight is
# being fought by firelight on snow. Nothing about the rules changes -- the only
# thing that changes is what the player is looking at while they play them.
#
# It is deliberately not a light rig hung over the painting. A real light on the
# map itself means drawing the whole picture again once per torch, which on a
# phone is not affordable, and on this art is not even wanted: the painting
# already knows where its own light is. So the work splits three ways.
#
#   The map is graded by a shader -- darkened, cooled and drained of colour by
#   however far the sun has gone down. One pass over the picture, no lights at
#   all, and it costs the same at midnight as at noon.
#
#   The lights on the map are additive glows hung where the painting has already
#   drawn something that burns: the twelve signpost candles, the two braziers,
#   the windows of the village, the crystal seam in the mine. They come up as
#   the map goes down, so the picture never simply gets darker -- it gets darker
#   in the places that have no fire in them.
#
#   The bodies are the only thing a real Light2D ever touches. A soldier is a
#   small sprite and lighting one costs nothing, and a soldier walking into the
#   pool of a signpost candle and catching its colour is the single thing that
#   says the fight and the map are in the same world.
#
# Everything here is static except the grade itself, so any node can ask what
# the world is doing without being handed a reference to anything.

# ------------------------------------------------------------------- the sun
#
# Which way the light travels. Read off the painting rather than picked: every
# tree, post and roof on the map throws its shadow down and to the right, so the
# sun is over the player's left shoulder. Everything that answers to a direction
# -- the shadow a body lays down, the edge of it that catches the light -- takes
# it from here, so the two can never disagree with each other or with the art.
const SUN := Vector2(0.5524, 0.8336)

# Which items a light is allowed to touch. Everything in the game defaults to
# layer 1; bodies are moved to layer 2 and every light culls to that. So no
# light ever has to consider the map, the tray, or the effects -- which is what
# keeps a dozen torches affordable.
const BODY_LAYER := 2

# ------------------------------------------------------------------- the day
#
# The run is one evening. These are the hours it passes through, hung on wave
# numbers, and everything else in the file is derived from `night` -- how far
# through that evening the player has got.
#
# `sky` is what an unlit surface is multiplied by, so it is the colour of the
# air rather than the colour of anything in the picture; `rim` is what the edge
# of a body catches, which early on is the sun and later is whatever fire is
# nearest.
const MOODS := [
	{"wave": 1,  "night": 0.00, "sky": Color(1.00, 1.00, 1.00), "rim": Color(1.00, 0.96, 0.88)},
	{"wave": 7,  "night": 0.20, "sky": Color(1.00, 0.96, 0.88), "rim": Color(1.00, 0.92, 0.74)},
	{"wave": 14, "night": 0.46, "sky": Color(0.95, 0.82, 0.70), "rim": Color(1.00, 0.82, 0.52)},
	{"wave": 21, "night": 0.70, "sky": Color(0.76, 0.65, 0.74), "rim": Color(1.00, 0.74, 0.46)},
	{"wave": 29, "night": 0.90, "sky": Color(0.54, 0.55, 0.80), "rim": Color(1.00, 0.70, 0.42)},
]

# Where the changeover leaves it. Colder than the dusk it comes out of, but
# left in daylight rather than pushed into night: a full night grade on top of
# the snow art read as two effects fighting each other instead of one place,
# so winter is a palette change and not a second sundown.
const WINTER_MOOD := {
	"night": 0.00, "sky": Color(0.82, 0.88, 1.00), "rim": Color(0.95, 0.97, 1.00)
}

# And where the second one does, past the dragon. Same rule as winter -- a
# palette change rather than another sundown -- but pulled the other way: the
# ember map lights itself from the ground, so the air over it is warm and the
# edge a body catches is the fire it is standing next to rather than the sun.
# `night` sits a little above zero so the map's own glows stay worth having,
# which on a field lit by lava is the whole of what the player sees.
const LAVA_MOOD := {
	"night": 0.28, "sky": Color(1.00, 0.82, 0.68), "rim": Color(1.00, 0.66, 0.34)
}

# Long enough that the player sees the light change rather than finding it
# changed, short enough to be over before the first enemy of the wave arrives.
const MOOD_FADE := 2.4

# ------------------------------------------------------------------- the state

static var _night: float = 0.0
static var _sky: Color = Color(1, 1, 1)
static var _body_tint: Color = Color(1, 1, 1)
static var _rim_color: Color = Color(1.0, 0.96, 0.88)
static var _fill_color: Color = Color(0.88, 0.92, 1.00)
static var _key_color: Color = Color(1.00, 0.99, 0.95)
static var _rim: float = 0.0
static var _form: float = 0.0
static var _ao: float = 0.0
# Bumped every time any of the above moves, so a body can tell in one integer
# comparison whether it needs to push seven parameters into its material again.
static var _version: int = 0

static func night() -> float:
	return _night

# What a body standing in the open is multiplied by. The map is graded by the
# shader below and the bodies on it have to come down with it, or the soldiers
# end up as bright cut-outs standing on a night-time field.
static func body_tint() -> Color:
	return _body_tint

# ------------------------------------------------------------------ the fires
#
# Where the light on the ground actually is, so a body can work out which way
# its shadow ought to fall. Only things that stay put are registered; a muzzle
# flash is over long before a shadow could answer to it.

static var _fires: Array = []

static func add_fire(at: Vector2, reach: float = 1.0, weight: float = 1.0) -> void:
	_fires.append({"at": at, "reach": maxf(reach, 0.05), "weight": weight})

# Called by Main before it builds anything. Statics outlive a scene, and a
# restarted run would otherwise start with the last run's fires still burning in
# a map that no longer exists.
static func reset() -> void:
	_fires.clear()
	_flashes = 0
	_apply_static(float(MOODS[0]["night"]), MOODS[0]["sky"] as Color, MOODS[0]["rim"] as Color)

# ---------------------------------------------------------------- the shadows

# How far a shadow is thrown, as a fraction of the body's own radius. At noon
# the sun is nearly overhead and a body sits on its own shadow; as it drops, the
# shadow comes out from under the feet and lies along the ground.
const THROW_NOON := 0.12
const THROW_NIGHT := 0.58
# How close a body has to be before a fire takes the shadow off the sky. Scaled
# per fire, so a brazier owns more ground than a candle.
const FIRE_REACH := 250.0

# The direction a body's shadow falls, times how hard it is thrown -- one vector
# because the two answers always come from the same light and a caller that had
# to ask twice could be handed one fire's direction and another's strength.
static func shadow_at(world: Vector2) -> Vector2:
	var throw: float = lerpf(THROW_NOON, THROW_NIGHT, _night)
	var dir: Vector2 = SUN
	# In daylight the sky wins everywhere, and there is no point walking the
	# list to find that out.
	if _night > 0.08 and not _fires.is_empty():
		var best: float = 0.0
		var away: Vector2 = Vector2.ZERO
		for f in _fires:
			var reach: float = FIRE_REACH * float(f["reach"])
			var d: Vector2 = world - (f["at"] as Vector2)
			var dist: float = d.length()
			if dist < 1.0 or dist > reach:
				continue
			var w: float = float(f["weight"]) * (1.0 - dist / reach)
			if w > best:
				best = w
				away = d / dist
		if best > 0.0:
			# Never all the way over to the fire: there is always some sky, and a
			# shadow that snaps from one light to another as a body walks past a
			# post is worse than one that never moved.
			var k: float = clampf(best * _night, 0.0, 0.8)
			dir = dir.lerp(away, k).normalized()
			throw = lerpf(throw, 0.9, k * 0.75)
	return dir * throw

# ------------------------------------------------------------------ the lights

static var _light_tex: GradientTexture2D = null

# A light does not fall away in a straight line. Five stops bent toward the
# middle give the tight core and the long thin edge a flame actually throws; the
# two-stop ramp the effects use for their blooms gives a flat disc with a rim
# you can see, which is fine for something that flashes and wrong for something
# that burns for the whole run.
static func light_texture() -> GradientTexture2D:
	if _light_tex != null:
		return _light_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.16, 0.40, 0.70, 1.0])
	g.colors = PackedColorArray([
		Color(1.00, 1.00, 1.00, 1.00),
		Color(0.84, 0.84, 0.84, 0.84),
		Color(0.46, 0.46, 0.46, 0.46),
		Color(0.15, 0.15, 0.15, 0.15),
		Color(0.00, 0.00, 0.00, 0.00),
	])
	_light_tex = GradientTexture2D.new()
	_light_tex.gradient = g
	_light_tex.fill = GradientTexture2D.FILL_RADIAL
	_light_tex.fill_from = Vector2(0.5, 0.5)
	_light_tex.fill_to = Vector2(1.0, 0.5)
	_light_tex.width = 256
	_light_tex.height = 256
	return _light_tex

const LIGHT_TEX_PX := 256.0

# A light that stays: hung on a fire and driven by whatever is making it
# flicker. Starts dark, because every one of them is lit by the evening rather
# than by being created.
static func fire_light(parent: Node, tint: Color, radius: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = radius * 2.0 / LIGHT_TEX_PX
	l.color = tint
	l.energy = 0.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.range_item_cull_mask = BODY_LAYER
	l.shadow_enabled = false
	parent.add_child(l)
	return l

# No more than this many blows can be lighting bodies at once. Past it the
# additive burst the effect already draws carries the moment on its own, which
# is what it did before any of this existed -- a dropped light is invisible,
# where a hundred of them at the wrong moment is a stutter.
const MAX_FLASHES := 10
static var _flashes: int = 0

# The light a blow throws for as long as it takes to land. Everything that hits
# hard enough to be worth looking at goes through here, and all of it is scaled
# by the hour: a sword striking sparks in daylight lights nothing, and the same
# blow at midnight lights the rank it is struck in.
static func flash(host: Node, at: Vector2, tint: Color, energy: float,
		radius: float, secs: float = 0.16) -> void:
	if host == null or not host.is_inside_tree() or _flashes >= MAX_FLASHES:
		return
	var l := fire_light(host, tint, radius)
	l.global_position = at
	l.energy = energy * (0.35 + 0.85 * _night)
	_flashes += 1
	l.tree_exited.connect(_flash_spent)

	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, secs) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)

static func _flash_spent() -> void:
	_flashes = maxi(0, _flashes - 1)

# ------------------------------------------------------------------ the bodies
#
# What a Light2D cannot do for a flat sprite is give it a shape. These three do:
# the body is shaded as a rough sphere so it has a lit side and a shaded one,
# the edge turned to the light is picked out of the alpha, and the bottom of it
# is dropped into the shadow it is standing in. All three are off at noon and
# come up with the evening, so the units the player merged in the first minute
# are exactly the art they were drawn as.

const BODY_SHADER := """
shader_type canvas_item;

uniform vec2 key = vec2(-0.5524, -0.8336);
uniform vec4 key_color : source_color = vec4(1.0, 0.99, 0.95, 1.0);
uniform vec4 fill_color : source_color = vec4(0.88, 0.92, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform float form : hint_range(0.0, 1.0) = 0.0;
uniform float rim : hint_range(0.0, 2.0) = 0.0;
uniform float ao : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ice : source_color = vec4(0.42, 0.68, 1.0, 1.0);
uniform float ice_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, ice.rgb * (0.25 + 0.75 * lum), ice_amount);

	// Treated as a sphere rather than a plane. It is the wrong shape for a
	// soldier and the right one for the silhouette of a soldier, which is all
	// the eye is reading at this size: the middle stays as painted and the
	// turn of the body toward the edges takes the light or loses it.
	vec2 d = UV - vec2(0.5);
	float r = length(d);
	vec2 n = r > 0.001 ? d / r : vec2(0.0);
	float lam = dot(n, key) * clamp(r * 2.2, 0.0, 1.0);
	COLOR.rgb *= mix(vec3(1.0), mix(fill_color.rgb, key_color.rgb, lam * 0.5 + 0.5), form);

	// The ground under a body never gets any light at all, and boots that are
	// the same brightness as a helmet are boots nobody believes are on soil.
	COLOR.rgb *= 1.0 - ao * smoothstep(0.58, 1.0, UV.y);

	// The lit edge, taken off the alpha: solid here and nothing a couple of
	// texels toward the light is, by definition, the silhouette facing it.
	float toward = texture(TEXTURE, UV + key * TEXTURE_PIXEL_SIZE * 2.5).a;
	COLOR.rgb += rim_color.rgb * (clamp(COLOR.a - toward, 0.0, 1.0) * rim * COLOR.a);
}
"""

static var _body_shader: Shader = null

static func body_shader() -> Shader:
	if _body_shader == null:
		_body_shader = Shader.new()
		_body_shader.code = BODY_SHADER
	return _body_shader

# One material per body rather than one shared by all of them: a frozen soldier
# has to be able to be frozen without every other soldier icing over with it.
static func body_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = body_shader()
	return mat

# What a body compares against to know whether its material is out of date. The
# flip is in it because a sprite drawn facing left is drawn mirrored, and a rim
# that did not know that would light the wrong side of half the army.
static func body_stamp(flip: bool) -> int:
	return _version * 2 + (1 if flip else 0)

static func tune_body(mat: ShaderMaterial, flip: bool, form_scale: float = 1.0) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("key", Vector2(SUN.x if flip else -SUN.x, -SUN.y))
	mat.set_shader_parameter("key_color", _key_color)
	mat.set_shader_parameter("fill_color", _fill_color)
	mat.set_shader_parameter("rim_color", _rim_color)
	mat.set_shader_parameter("form", _form * form_scale)
	mat.set_shader_parameter("rim", _rim)
	mat.set_shader_parameter("ao", _ao)

# --------------------------------------------------------------------- the map

const GRADE_SHADER := """
shader_type canvas_item;

uniform vec4 sky : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float desat : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	// Colour is the first thing to go as light does -- a field at dusk is not a
	// green field turned down, it is a grey field with a little green left.
	vec3 graded = mix(COLOR.rgb, vec3(lum), desat) * sky.rgb;
	COLOR.rgb = mix(COLOR.rgb, graded, strength);
}
"""

static var _grade_shader: Shader = null

static func grade_shader() -> Shader:
	if _grade_shader == null:
		_grade_shader = Shader.new()
		_grade_shader.code = GRADE_SHADER
	return _grade_shader

# ----------------------------------------------------------------- the corners

# The last thing, and the cheapest: the arena is a window and the light in it
# falls off toward the frame. It also does the job no amount of grading can,
# which is to hold the eye on the crossroads the whole fight happens around.
const VIGNETTE_SHADER := """
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.02, 0.02, 0.05, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Weighted, because the window is taller than it is wide and a round
	// falloff in a tall frame darkens the top and bottom and nothing else.
	vec2 d = (UV - vec2(0.5)) * vec2(1.22, 1.0);
	float v = smoothstep(0.34, 0.78, length(d));
	COLOR = vec4(tint.rgb, v * amount);
}
"""

# ------------------------------------------------------------------- the grade
#
# The instance side. It owns nothing but the animation: which hour the field is
# in, what is being carried there from, and the handful of materials that have
# to be told about it.

var _graded: Array[ShaderMaterial] = []
var _vignette: ShaderMaterial = null
var _cur: Dictionary = {}
var _tween: Tween = null
# Set the moment the first changeover lands, and left set through every one
# after it. Night no longer climbs high enough on its own to mark that a
# changeover happened, so this is what set_wave checks to know the daylight
# table is done owning the sky.
var _phase_locked: bool = false

func _init() -> void:
	# The light has to keep moving through the upgrade screen: the changeover at
	# wave 30 hands straight over to it, and a freeze that stops halfway is a bug
	# the player is left staring at.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cur = {
		"night": float(MOODS[0]["night"]),
		"sky": MOODS[0]["sky"] as Color,
		"rim": MOODS[0]["rim"] as Color,
	}

# Every canvas item that is part of the painted world rather than part of the
# fight. `strength` is how far into the evening that particular surface comes:
# the map goes all the way, the merge tray only part way, because the tray is
# what the player is working on and a tray at midnight is a tray nobody can
# read.
func add_graded(item: CanvasItem, strength: float = 1.0) -> void:
	if item == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = grade_shader()
	mat.set_shader_parameter("strength", strength)
	item.material = mat
	_graded.append(mat)
	_push()

func attach_vignette(parent: Control, rect: Rect2) -> void:
	var frame := ColorRect.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.color = Color(1, 1, 1, 1)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = ShaderMaterial.new()
	_vignette.shader = Shader.new()
	_vignette.shader.code = VIGNETTE_SHADER
	frame.material = _vignette
	parent.add_child(frame)
	_push()

# Called on every wave. The hour it lands on is a curve rather than a step, so
# most waves move the light a little and no wave announces that it did.
func set_wave(wave: int) -> void:
	# Past a changeover the phase's own mood owns the sky, and a wave counter
	# that kept walking the daylight table would start dragging it back to dusk.
	if _phase_locked:
		return
	_go(_mood_for_wave(wave), MOOD_FADE)

func to_winter(secs: float) -> void:
	_to_phase(WINTER_MOOD, secs)

func to_lava(secs: float) -> void:
	_to_phase(LAVA_MOOD, secs)

# Both changeovers do the same thing to the light -- take the sky off the
# daylight table for good and walk it to a fixed mood -- so they are one call
# with the mood as its only argument.
func _to_phase(mood: Dictionary, secs: float) -> void:
	_phase_locked = true
	_go({
		"night": float(mood["night"]),
		"sky": mood["sky"] as Color,
		"rim": mood["rim"] as Color,
	}, secs)

func _mood_for_wave(wave: int) -> Dictionary:
	var lo: Dictionary = MOODS[0]
	for m in MOODS:
		if wave >= int(m["wave"]):
			lo = m
		else:
			var t: float = float(wave - int(lo["wave"])) \
				/ maxf(1.0, float(int(m["wave"]) - int(lo["wave"])))
			return _blend(lo, m, clampf(t, 0.0, 1.0))
	return {"night": float(lo["night"]), "sky": lo["sky"] as Color, "rim": lo["rim"] as Color}

func _blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {
		"night": lerpf(float(a["night"]), float(b["night"]), t),
		"sky": (a["sky"] as Color).lerp(b["sky"] as Color, t),
		"rim": (a["rim"] as Color).lerp(b["rim"] as Color, t),
	}

func _go(target: Dictionary, secs: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if secs <= 0.0:
		_apply_mood(target)
		return
	var from: Dictionary = _cur.duplicate()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(
		func(t: float) -> void: _apply_mood(_blend(from, target, t)), 0.0, 1.0, secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _apply_mood(m: Dictionary) -> void:
	_cur = m
	_apply_static(float(m["night"]), m["sky"] as Color, m["rim"] as Color)
	_push()

# Everything derived from the hour. Kept in one place so that a mood is three
# numbers to author and thirty to use, rather than thirty to author.
static func _apply_static(night: float, sky: Color, rim: Color) -> void:
	_night = night
	_sky = sky
	# Bodies come down with the field but never quite as far: a soldier lit
	# exactly like the grass behind him is a soldier nobody can pick out, and
	# the point of the whole exercise is that the player can read the fight.
	_body_tint = Color(1, 1, 1).lerp(
		Color(minf(sky.r * 1.14, 1.0), minf(sky.g * 1.14, 1.0), minf(sky.b * 1.10, 1.0)),
		night)
	_rim_color = rim
	# The shaded side takes the colour of the sky above it, which by midnight is
	# the only light left that is not a fire.
	_fill_color = Color(0.88, 0.92, 1.00).lerp(Color(0.32, 0.40, 0.72), night)
	_key_color = Color(1.00, 0.99, 0.95).lerp(rim, night * 0.6)
	_rim = 0.06 + 0.52 * night
	_form = 0.08 + 0.34 * night
	_ao = 0.10 + 0.26 * night
	# The map's own light matters less as there is less of it: by night the
	# difference between standing on grass and standing on a road is nothing
	# next to the difference between standing in a torch pool and not.
	Ambient.set_strength(Ambient.BASE_STRENGTH * (1.0 - 0.5 * night))
	_version += 1

func _push() -> void:
	var desat: float = 0.58 * _night
	for mat in _graded:
		mat.set_shader_parameter("sky", _sky)
		mat.set_shader_parameter("desat", desat)
	if _vignette != null:
		_vignette.set_shader_parameter("amount", 0.10 + 0.42 * _night)
		_vignette.set_shader_parameter("tint",
			Color(0.02, 0.02, 0.05).lerp(Color(0.02, 0.03, 0.10), _night))
