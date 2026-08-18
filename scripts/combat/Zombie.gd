extends Node2D
class_name Zombie

const FxUtil = preload("res://scripts/fx/FxUtil.gd")
const SlashArc = preload("res://scripts/fx/SlashArc.gd")

# What the zombie lord's RISE OF THE DAMNED puts on the field: whatever he
# killed, back on its feet and fighting for us.
#
# It is deliberately not a Defender. Everything a defender is -- a lane, a slot,
# a place in the line something else can square up against -- is exactly what a
# zombie is not: it holds no ground, nothing queues against it, and clearing the
# lane it happens to be standing in does not become harder because it is there.
# What it is instead is a few seconds of damage that walks: it comes up where
# the body fell, goes to whatever is nearest, hits it until LIFE runs out, and
# rots back into the ground.
#
# That is also why nothing can kill one. Letting the enemies fight back would
# mean giving a zombie a place in the line, and a line the player cannot
# reinforce or reposition is one they cannot play around -- the ability would
# stop being a blow they throw and start being a wall that happens to them. A
# short leash and no health bar keeps it a blow.
#
# Three drawings cover every body in the game; see UnitDatabase.ZOMBIE_FORMS for
# which corpse comes back as which.

# ------------------------------------------------------------------- the forms
#
# Same contract as Defender.ANIM and Enemy.ANIM: "foot" is the stance centre of
# the pose on the row's shared ground line, and every frame is registered on it,
# so only the limbs move. "hit" is the beat of the attack row the blow actually
# lands on.
#
# "walk" loops for as long as the body is closing on something; "atk" plays once
# per swing; "atk"[0] doubles as the pose it stands in, which is why every
# attack row here starts from a neutral stance.
const FORMS := {
	# The armoured ranks come back as this: slow, heavy, and the only one of the
	# three whose blow the sheet drew its own arc for.
	"knight": {
		"radius": 46.0, "speed": 92.0, "range": 108.0, "interval": 1.15,
		"hit": 4, "tint": Color(0.68, 1.0, 0.52),
		"slash": "res://art/zombie_knight_slash.png",
		"walk": [
			{"tex": "res://art/zombie_knight_walk_0.png", "foot": Vector2(54, 128)},
			{"tex": "res://art/zombie_knight_walk_1.png", "foot": Vector2(55, 128)},
			{"tex": "res://art/zombie_knight_walk_2.png", "foot": Vector2(56, 128)},
			{"tex": "res://art/zombie_knight_walk_3.png", "foot": Vector2(56, 128)},
			{"tex": "res://art/zombie_knight_walk_4.png", "foot": Vector2(55, 128)},
			{"tex": "res://art/zombie_knight_walk_5.png", "foot": Vector2(55, 128)},
			{"tex": "res://art/zombie_knight_walk_6.png", "foot": Vector2(55, 128)},
		],
		"atk": [
			{"tex": "res://art/zombie_knight_atk_0.png", "foot": Vector2(57, 121), "hold": 0.0},
			{"tex": "res://art/zombie_knight_atk_1.png", "foot": Vector2(58, 120), "hold": 0.09},
			{"tex": "res://art/zombie_knight_atk_2.png", "foot": Vector2(68, 120), "hold": 0.09},
			{"tex": "res://art/zombie_knight_atk_3.png", "foot": Vector2(44, 120), "hold": 0.08},
			{"tex": "res://art/zombie_knight_atk_4.png", "foot": Vector2(71, 121), "hold": 0.20},
		],
	},
	# The heavies. Slowest of the three and the hardest hitter, with a club that
	# comes right over the top -- five beats of wind-up before it lands.
	"orc": {
		"radius": 50.0, "speed": 74.0, "range": 116.0, "interval": 1.45,
		"hit": 4, "tint": Color(0.74, 1.0, 0.46), "slash": "",
		"walk": [
			{"tex": "res://art/zombie_orc_walk_0.png", "foot": Vector2(54, 140)},
			{"tex": "res://art/zombie_orc_walk_1.png", "foot": Vector2(53, 141)},
			{"tex": "res://art/zombie_orc_walk_2.png", "foot": Vector2(54, 144)},
			{"tex": "res://art/zombie_orc_walk_3.png", "foot": Vector2(55, 143)},
			{"tex": "res://art/zombie_orc_walk_4.png", "foot": Vector2(55, 144)},
			{"tex": "res://art/zombie_orc_walk_5.png", "foot": Vector2(55, 143)},
		],
		"atk": [
			{"tex": "res://art/zombie_orc_atk_0.png", "foot": Vector2(76, 138), "hold": 0.0},
			{"tex": "res://art/zombie_orc_atk_1.png", "foot": Vector2(72, 136), "hold": 0.09},
			{"tex": "res://art/zombie_orc_atk_2.png", "foot": Vector2(66, 138), "hold": 0.09},
			{"tex": "res://art/zombie_orc_atk_3.png", "foot": Vector2(61, 139), "hold": 0.08},
			{"tex": "res://art/zombie_orc_atk_4.png", "foot": Vector2(91, 134), "hold": 0.12},
			{"tex": "res://art/zombie_orc_atk_5.png", "foot": Vector2(56, 173), "hold": 0.08},
			{"tex": "res://art/zombie_orc_atk_6.png", "foot": Vector2(63, 173), "hold": 0.08},
			{"tex": "res://art/zombie_orc_atk_7.png", "foot": Vector2(67, 172), "hold": 0.12},
		],
	},
	# The beasts. Half again as fast as anything else on the field and it bites
	# twice for every swing the others land -- a wolf raised on a lane crosses it
	# before the knight beside it has taken three steps.
	"wolf": {
		"radius": 52.0, "speed": 158.0, "range": 94.0, "interval": 0.72,
		"hit": 5, "tint": Color(0.58, 0.92, 1.0), "slash": "",
		"walk": [
			{"tex": "res://art/zombie_ice_wolf_walk_0.png", "foot": Vector2(84, 120)},
			{"tex": "res://art/zombie_ice_wolf_walk_1.png", "foot": Vector2(97, 117)},
			{"tex": "res://art/zombie_ice_wolf_walk_2.png", "foot": Vector2(77, 117)},
			{"tex": "res://art/zombie_ice_wolf_walk_3.png", "foot": Vector2(86, 109)},
			{"tex": "res://art/zombie_ice_wolf_walk_4.png", "foot": Vector2(81, 109)},
			{"tex": "res://art/zombie_ice_wolf_walk_5.png", "foot": Vector2(71, 109)},
		],
		"atk": [
			{"tex": "res://art/zombie_ice_wolf_atk_0.png", "foot": Vector2(74, 117), "hold": 0.0},
			{"tex": "res://art/zombie_ice_wolf_atk_1.png", "foot": Vector2(91, 115), "hold": 0.06},
			{"tex": "res://art/zombie_ice_wolf_atk_2.png", "foot": Vector2(50, 118), "hold": 0.06},
			{"tex": "res://art/zombie_ice_wolf_atk_3.png", "foot": Vector2(75, 116), "hold": 0.06},
			{"tex": "res://art/zombie_ice_wolf_atk_4.png", "foot": Vector2(81, 111), "hold": 0.06},
			{"tex": "res://art/zombie_ice_wolf_atk_5.png", "foot": Vector2(133, 125), "hold": 0.16},
		],
	},
}

# How long one stands before it goes back into the ground. Long enough to cross
# the arena and land a handful of blows, short enough that a second cast is
# spent on a fresh set rather than on doubling a standing army.
const LIFE := 13.0

# The share of the hero's own damage each of these hits for. Priced off him
# rather than off the corpse: the ability is his, so it has to grow with his
# levels and his upgrades, and a run that has kept the zombie lord alive since
# wave three should see the difference in what his dead hit for.
const DAMAGE_SHARE := 0.5

# The frame the body is drawn at, relative to the collision radius -- the same
# figure every other body on the field is drawn at, so a zombie knight stands
# the same height beside a real one.
const SPRITE_VISUAL_SCALE := 1.3

# How much bigger or smaller than the drawing's own size a zombie is allowed to
# be. The corpse it came out of decides, but a stone golem's zombie standing
# three times the height of a soldier would read as a boss rather than as a
# summon, so both ends are clamped hard.
const SIZE_MIN := 0.85
const SIZE_MAX := 1.25

var form: String = "orc"
var damage: float = 20.0
var attack_range: float = 110.0
var attack_interval: float = 1.2
var speed: float = 90.0

var _radius: float = 48.0
var _life_left: float = LIFE
var _attack_timer: float = 0.0
var _target: Enemy = null
var _retarget: float = 0.0
var _dying: bool = false

var _visual: Sprite2D = null
var _shadow: GroundShadow = null
var _lit: ShaderMaterial = null
var _shade_stamp: int = -1
var _light_timer: float = 0.0
var _facing: float = 1.0
var _tint: Color = Color(0.68, 1.0, 0.52)
var _slash_art: String = ""

var _walk: Array = []
var _atk: Array = []
var _hit_frame: int = 0
var _walk_index: int = 0
var _walk_timer: float = 0.0
var _frame_tween: Tween = null
# Whichever row is actually on screen and where it has got to, so turning mid
# swing redraws the pose the body is in rather than dropping it back to stance.
var _shown_set: Array = []
var _shown_index: int = 0

const LIGHT_INTERVAL := 0.20
const WALK_FRAME_TIME := 0.11

# `by` is the hero that called it up, and the only thing it is read for is what
# this body hits for; `enemy_id` is what fell here, which picks the drawing.
func setup(enemy_id: String, by: Defender, size: float) -> void:
	form = UnitDatabase.zombie_form(enemy_id)
	var d: Dictionary = FORMS.get(form, FORMS["orc"])

	var k: float = clampf(size, SIZE_MIN, SIZE_MAX)
	_radius = float(d["radius"]) * k
	speed = float(d["speed"])
	attack_range = float(d["range"])
	attack_interval = float(d["interval"])
	_hit_frame = int(d["hit"])
	_tint = d["tint"]
	_slash_art = String(d["slash"])
	damage = maxf(6.0, (by.damage if by != null and is_instance_valid(by) else 30.0) * DAMAGE_SHARE)
	_life_left = LIFE
	# Staggered so a row of six raised on the same frame does not swing as one.
	_attack_timer = randf() * 0.35
	_walk_timer = randf() * WALK_FRAME_TIME

	_build_frames(d)
	_build_visual()
	set_process(true)

# Registered against the stance -- atk[0] -- exactly as every other body in the
# game is: that frame is drawn centred on the node, and the rest are offset by
# however far their own stance centre differs from it. Align them by their
# bounding boxes instead and a raised club drags the whole body sideways.
func _build_frames(d: Dictionary) -> void:
	var atk: Array = d["atk"]
	var base: Texture2D = load(String(atk[0]["tex"]))
	var from_foot: Vector2 = base.get_size() * 0.5 - (atk[0]["foot"] as Vector2)
	_atk = _register(atk, from_foot)
	_walk = _register(d["walk"], from_foot)

func _register(list: Array, from_foot: Vector2) -> Array:
	var out: Array = []
	for f in list:
		var tex: Texture2D = load(String(f["tex"]))
		var anchor: Vector2 = (f["foot"] as Vector2) + from_foot
		out.append({
			"tex": tex,
			"offset": tex.get_size() * 0.5 - anchor,
			"hold": float(f.get("hold", WALK_FRAME_TIME)),
		})
	return out

func _build_visual() -> void:
	_visual = Sprite2D.new()
	_visual.texture = _atk[0]["tex"]
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex: Vector2 = _visual.texture.get_size()
	var fit: float = (_radius * 2.0 * SPRITE_VISUAL_SCALE) / maxf(tex.x, tex.y)
	_visual.scale = Vector2(fit, fit)
	# The same shape every other body carries: a lit side, a shaded one, an edge
	# that catches whatever is burning nearest. A summon that skipped it would be
	# the one thing on the field still drawn flat.
	_lit = Lighting.body_material()
	_visual.material = _lit
	_visual.light_mask = Lighting.BODY_LAYER

	_shadow = GroundShadow.new()
	_shadow.setup(_radius * 0.86,
		Vector2(0, GroundShadow.feet_offset(_visual.texture) * _visual.scale.y))
	add_child(_shadow)
	add_child(_visual)
	_apply_frame(_atk, 0)

	# Comes up out of the ground rather than appearing on it: DarkRise has
	# already opened the floor by the time this runs, and this is the body
	# climbing out of what it opened.
	_visual.modulate = Color(1, 1, 1, 0)
	_visual.position = Vector2(0, 14.0)
	var tw := create_tween()
	tw.tween_property(_visual, "modulate:a", 1.0, 0.22)
	tw.parallel().tween_property(_visual, "position:y", 0.0, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_light_timer = randf() * LIGHT_INTERVAL

func is_alive() -> bool:
	return not _dying

# ------------------------------------------------------------------ the fight
#
# Ticked by CombatManager along with everything else that fights, so a zombie
# stops the instant the run does. Everything about it is one rule: go to the
# nearest living body and hit it.

func tick(delta: float) -> void:
	if _dying:
		return
	_life_left -= delta
	if _life_left <= 0.0:
		rot_away()
		return

	_retarget -= delta
	if _target != null and (not is_instance_valid(_target) or not _target.is_alive()):
		_target = null
	if _target == null or _retarget <= 0.0:
		_retarget = 0.4
		_target = _nearest_enemy()
	if _target == null:
		_hold_still()
		return

	var to: Vector2 = _target.global_position - global_position
	var gap: float = to.length()
	if gap > attack_range:
		_walk_toward(to, delta)
		return

	_face(to)
	_hold_still()
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	_attack_timer = attack_interval
	_swing(_target, to)

func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for e in CombatManager.enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _walk_toward(to: Vector2, delta: float) -> void:
	_face(to)
	global_position += to.normalized() * speed * delta
	# The walk row runs only while the body is actually covering ground, which is
	# what keeps a zombie that has arrived from marching on the spot.
	if _frame_tween != null and _frame_tween.is_valid():
		return
	_walk_timer -= delta
	if _walk_timer > 0.0:
		return
	_walk_timer = WALK_FRAME_TIME
	_walk_index = (_walk_index + 1) % _walk.size()
	_apply_frame(_walk, _walk_index)

func _hold_still() -> void:
	if _frame_tween != null and _frame_tween.is_valid():
		return
	_apply_frame(_atk, 0)

func _face(dir: Vector2) -> void:
	if absf(dir.x) < 0.001:
		return
	var want: float = 1.0 if dir.x >= 0.0 else -1.0
	if want == _facing:
		return
	_facing = want
	if is_instance_valid(_visual):
		_visual.flip_h = _facing < 0.0
		_apply_frame(_shown_set, _shown_index)

func _apply_frame(list: Array, i: int) -> void:
	if not is_instance_valid(_visual) or i < 0 or i >= list.size():
		return
	_shown_set = list
	_shown_index = i
	_visual.texture = list[i]["tex"]
	var off: Vector2 = list[i]["offset"]
	_visual.offset = Vector2(off.x * _facing, off.y)

# The blow lands on the drawn contact frame rather than the instant the timer
# ran out, so the picture and the damage agree -- and the target is checked
# again then, because it is routinely dead by the time the club comes down.
func _swing(target: Enemy, aim: Vector2) -> void:
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	var dir: Vector2 = aim.normalized()
	_frame_tween = create_tween()
	for i in range(1, _atk.size()):
		# Bound rather than closed over, the way every other drawn attack in the
		# game does it: the beat has to remember which frame it was.
		_frame_tween.tween_callback(_enter_frame.bind(i, target, damage, dir))
		_frame_tween.tween_interval(float(_atk[i]["hold"]))
	_frame_tween.tween_callback(_hold_still)

# `target` is deliberately untyped. A swing outlives its target more often than
# not, and a bound argument that has been freed cannot be converted back to an
# Enemy -- Godot refuses the call outright, which would drop the frame as well
# as the blow and leave the body stuck mid-animation.
func _enter_frame(i: int, target, dealt: float, dir: Vector2) -> void:
	_apply_frame(_atk, i)
	if i == _hit_frame:
		_land(target, dealt, dir)

func _land(target, dealt: float, dir: Vector2) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	target.take_damage(dealt, global_position)
	_slash(dir)

# The knight's sheet drew the arc his sword leaves; the other two get the
# generic stroke tinted to match whatever raised them.
func _slash(dir: Vector2) -> void:
	if _slash_art != "" and ResourceLoader.exists(_slash_art):
		var arc := FxUtil.glow(self, load(_slash_art), 0.3, 0.95)
		arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		arc.position = dir * (_radius * 0.9) + Vector2(0, -_radius * 0.45)
		arc.rotation = dir.angle()
		arc.flip_v = _facing < 0.0
		arc.z_index = 6
		var k: float = _radius / 46.0
		var tw := arc.create_tween()
		tw.tween_property(arc, "scale", Vector2.ONE * 0.62 * k, 0.13) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(arc, "modulate:a", 0.0, 0.18)
		tw.tween_callback(arc.queue_free)
	else:
		var arc2 := SlashArc.new()
		add_child(arc2)
		arc2.position = Vector2(0, -_radius * 0.35)
		arc2.play(dir, _radius * 1.2, 1.7, _tint, 9.0)
	Lighting.flash(self, global_position + dir * _radius, _tint, 0.55, 120.0, 0.14)

# ------------------------------------------------------------------ the ending
#
# It does not die, it stops. Nothing on the field can kill one, so the only exit
# is the clock -- and the clock running out reads best as the body giving up and
# going back into the ground it came out of.

func rot_away() -> void:
	if _dying:
		return
	_dying = true
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	set_process(false)

	var motes := FxUtil.burst(self, 14, 0.75, 30.0, 110.0,
		Color(0.72, 1.0, 0.52, 1.0), Color(0.14, 0.34, 0.12, 0.0))
	motes.position = Vector2(0, -_radius * 0.5)
	motes.gravity = Vector2(0, -90)
	motes.scale_amount_curve = FxUtil.swell_curve()
	motes.emitting = true

	var tw := create_tween()
	# Sinks and flattens rather than shrinking to a point: it is going down into
	# the floor, and a body that scales away to nothing reads as being deleted.
	tw.tween_property(self, "position:y", position.y + 12.0, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", Vector2(1.06, 0.72), 0.55)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.55)
	tw.tween_callback(queue_free)

# Standing in the same light as everything else, sampled on the same slow timer:
# seven shader parameters is too many to push at a body that has not moved out
# of the patch it was in a fifth of a second ago.
func _process(delta: float) -> void:
	_light_timer -= delta
	if _light_timer > 0.0:
		return
	_light_timer = LIGHT_INTERVAL
	var tint: Color = Ambient.tint_at(global_position) * Lighting.body_tint()
	modulate = Color(tint.r, tint.g, tint.b, modulate.a)
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.set_light(Lighting.shadow_at(global_position))
	var stamp: int = Lighting.body_stamp(_facing < 0.0)
	if stamp != _shade_stamp:
		_shade_stamp = stamp
		Lighting.tune_body(_lit, _facing < 0.0)
