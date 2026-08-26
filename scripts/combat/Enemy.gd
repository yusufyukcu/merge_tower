extends Node2D
class_name Enemy

const ImpactEffect = preload("res://scripts/fx/ImpactEffect.gd")
const SlashArc = preload("res://scripts/fx/SlashArc.gd")
const MagicBolt = preload("res://scripts/fx/MagicBolt.gd")
const VineBind = preload("res://scripts/fx/VineBind.gd")
const IceBeam = preload("res://scripts/fx/IceBeam.gd")
const FxUtil = preload("res://scripts/fx/FxUtil.gd")

signal died(enemy: Enemy)

enum State { MOVING, ENGAGING, ATTACKING_FORTRESS }

# ------------------------------------------------------------ attack frames
#
# Drawn attack poses, cut one file per frame out of
# art/enemy_attack_animations.png. Same contract as the defenders':
#
#   "foot"  the point the frames are registered on, so only the arms move.
#           Feet on the ground line for anything that walks; for the bat it is
#           the eyes, because a flyer never touches the ground, and for the
#           golem the glowing core, because its poses are too different for its
#           feet to mean the same thing twice.
#   "hold"  how long the frame stays up
#   "hit"   the frame the blow lands on -- damage is dealt from there
#   "fx"    an effect hung on that frame, on top of what the art already draws
#
# The orc has no row on the sheet and keeps the procedural swing.
const ANIM := {
	"goblin": {
		"hit": 2, "tint": Color(0.92, 0.96, 1.0),
		"frames": [
			{"tex": "res://art/goblin_atk_0.png", "foot": Vector2(106, 144), "hold": 0.0, "fx": ""},
			{"tex": "res://art/goblin_atk_1.png", "foot": Vector2(84, 126), "hold": 0.09, "fx": ""},
			{"tex": "res://art/goblin_atk_2.png", "foot": Vector2(103, 163), "hold": 0.09, "fx": "sparks"},
			{"tex": "res://art/goblin_atk_3.png", "foot": Vector2(86, 128), "hold": 0.12, "fx": ""},
		],
	},
	"bat": {
		"hit": 2, "tint": Color(0.78, 0.55, 1.0),
		"frames": [
			{"tex": "res://art/bat_atk_0.png", "foot": Vector2(131, 74), "hold": 0.0, "fx": ""},
			{"tex": "res://art/bat_atk_1.png", "foot": Vector2(110, 62), "hold": 0.08, "fx": ""},
			{"tex": "res://art/bat_atk_2.png", "foot": Vector2(93, 141), "hold": 0.12, "fx": "sparks"},
		],
	},
	"armored_knight": {
		"hit": 2, "tint": Color(1.0, 0.62, 0.58),
		"frames": [
			{"tex": "res://art/armored_knight_atk_0.png", "foot": Vector2(113, 189), "hold": 0.0, "fx": ""},
			{"tex": "res://art/armored_knight_atk_1.png", "foot": Vector2(139, 217), "hold": 0.11, "fx": ""},
			{"tex": "res://art/armored_knight_atk_2.png", "foot": Vector2(121, 192), "hold": 0.11, "fx": "sparks"},
			{"tex": "res://art/armored_knight_atk_3.png", "foot": Vector2(114, 163), "hold": 0.14, "fx": ""},
		],
	},
	# The slam frame draws its own gold burst on the floor; the bolt it throws
	# and the ground shaking under it are hung on the same frame.
	"stone_golem": {
		"hit": 2, "tint": Color(1.0, 0.80, 0.45),
		"frames": [
			{"tex": "res://art/stone_golem_atk_0.png", "foot": Vector2(179, 277), "hold": 0.0, "fx": ""},
			{"tex": "res://art/stone_golem_atk_1.png", "foot": Vector2(183, 276), "hold": 0.16, "fx": ""},
			{"tex": "res://art/stone_golem_atk_2.png", "foot": Vector2(145, 262), "hold": 0.22, "fx": "slam"},
		],
	},
	# The wolf's attack row, cut out of art/ice_wolf_sheet.png. It is a pounce
	# rather than a swing: the animal runs the last of the gap down and lands on
	# the soldier, so the blow is on the last frame and not the middle one. The
	# ice it throws up is drawn into that frame; the sparks hung on it are the
	# flash of the impact, which the drawing cannot do.
	#
	# The feet come off the sheet rather than off a screenshot: all five frames
	# were painted on one ground line (y=614 of the sheet), so each "foot" is
	# that line in the frame's own pixels and the paw centre of that pose.
	"ice_wolf": {
		"hit": 4, "tint": Color(0.72, 0.92, 1.0),
		"frames": [
			{"tex": "res://art/ice_wolf_atk_0.png", "foot": Vector2(124, 126), "hold": 0.0, "fx": ""},
			{"tex": "res://art/ice_wolf_atk_1.png", "foot": Vector2(100, 128), "hold": 0.07, "fx": ""},
			{"tex": "res://art/ice_wolf_atk_2.png", "foot": Vector2(91, 138), "hold": 0.07, "fx": ""},
			{"tex": "res://art/ice_wolf_atk_3.png", "foot": Vector2(91, 136), "hold": 0.08, "fx": ""},
			{"tex": "res://art/ice_wolf_atk_4.png", "foot": Vector2(123, 135), "hold": 0.16, "fx": "sparks"},
		],
	},
	# The skeleton's swing, cut out of art/ice_soldier_sheet.png. Six drawings
	# for one stroke, so it is the slowest wind-up in the game and the easiest to
	# see coming -- which is the point of a body that walks this slowly.
	#
	# Feet off the sheet again: one ground line at y=605 for the whole row, and
	# each "foot" is that line at the middle of that pose's stance. The swing
	# frame's had to be read off the drawing rather than measured -- the arc it
	# throws sweeps along the ground and drags any measurement to the right of
	# where the skeleton is actually standing.
	"ice_soldier": {
		"hit": 4, "tint": Color(0.70, 0.88, 1.0),
		"frames": [
			{"tex": "res://art/ice_soldier_atk_0.png", "foot": Vector2(73, 133), "hold": 0.0, "fx": ""},
			{"tex": "res://art/ice_soldier_atk_1.png", "foot": Vector2(53, 131), "hold": 0.10, "fx": ""},
			{"tex": "res://art/ice_soldier_atk_2.png", "foot": Vector2(62, 131), "hold": 0.10, "fx": ""},
			{"tex": "res://art/ice_soldier_atk_3.png", "foot": Vector2(67, 131), "hold": 0.12, "fx": ""},
			{"tex": "res://art/ice_soldier_atk_4.png", "foot": Vector2(45, 145), "hold": 0.16, "fx": "sparks"},
			{"tex": "res://art/ice_soldier_atk_5.png", "foot": Vector2(63, 131), "hold": 0.14, "fx": ""},
		],
	},
	# The wizard's cast. Nothing lands on the contact frame here -- no damage is
	# ever dealt by this body -- but the frame the orb comes up on is still where
	# the blow "arrives", because that is the frame the circle opens under the
	# line. One ground line for the row again, at y=589.
	"ice_wizard": {
		"hit": 4, "tint": Color(0.62, 0.84, 1.0),
		"frames": [
			{"tex": "res://art/ice_wizard_cast_0.png", "foot": Vector2(69, 146), "hold": 0.0, "fx": ""},
			{"tex": "res://art/ice_wizard_cast_1.png", "foot": Vector2(62, 146), "hold": 0.14, "fx": ""},
			{"tex": "res://art/ice_wizard_cast_2.png", "foot": Vector2(56, 146), "hold": 0.14, "fx": ""},
			{"tex": "res://art/ice_wizard_cast_3.png", "foot": Vector2(64, 146), "hold": 0.16, "fx": ""},
			{"tex": "res://art/ice_wizard_cast_4.png", "foot": Vector2(62, 161), "hold": 0.34, "fx": ""},
		],
	},
}

# ---------------------------------------------------------------- ice dash
#
# The wolf's charge, drawn as three frames on the same sheet: the crouch, the
# streak crossing the gap, and the landing inside a burst of ice. They carry no
# holds of their own -- play_dash paces them, because the middle frame has to
# last exactly as long as the body takes to cross.
#
# Registered against the attack frames rather than against each other, so the
# animal does not jump the instant it switches from one set to the other.
const DASH := {
	"ice_wolf": [
		{"tex": "res://art/ice_wolf_dash_0.png", "foot": Vector2(93, 114)},
		{"tex": "res://art/ice_wolf_dash_1.png", "foot": Vector2(141, 147)},
		{"tex": "res://art/ice_wolf_dash_2.png", "foot": Vector2(163, 178)},
	],
}

# --------------------------------------------------------------- flight loop
#
# A body with a row here is never still: it cycles this the whole time it is
# alive and not doing something else, which for the dragon is what makes it read
# as flying rather than as hanging in the air.
#
# These feet are not feet. A flying animal's lowest pixel is the tip of its
# tail, and a tail swings -- registering on it would throw the whole dragon from
# side to side. The sheet drew this row on a regular grid, so each frame is
# registered by where it sat in its own cell instead, which reproduces the
# animation exactly as it was drawn.
const FLY := {
	"ice_dragon": [
		{"tex": "res://art/ice_dragon_fly_0.png", "foot": Vector2(70, 185)},
		{"tex": "res://art/ice_dragon_fly_1.png", "foot": Vector2(73, 177)},
		{"tex": "res://art/ice_dragon_fly_2.png", "foot": Vector2(73, 196)},
		{"tex": "res://art/ice_dragon_fly_3.png", "foot": Vector2(72, 202)},
		{"tex": "res://art/ice_dragon_fly_4.png", "foot": Vector2(73, 197)},
		{"tex": "res://art/ice_dragon_fly_5.png", "foot": Vector2(71, 202)},
		{"tex": "res://art/ice_dragon_fly_6.png", "foot": Vector2(68, 180)},
		{"tex": "res://art/ice_dragon_fly_7.png", "foot": Vector2(70, 204)},
	],
}
const FLY_FRAME_TIME := 0.085

# --------------------------------------------------------------- ice breath
#
# Inhale, charge, the first of the stream, and then the pose it holds for as
# long as it is burning. The fifth is the only one it may never reach: the
# breath stops when there is nothing left in range and not before.
#
# The beam is not in these frames -- it is drawn separately (see IceBeam) so it
# can be aimed -- so frame 3 is the dragon alone, mouth open.
const BREATH := {
	"ice_dragon": [
		{"tex": "res://art/ice_dragon_breath_0.png", "foot": Vector2(74, 180)},
		{"tex": "res://art/ice_dragon_breath_1.png", "foot": Vector2(74, 182)},
		{"tex": "res://art/ice_dragon_breath_2.png", "foot": Vector2(74, 181)},
		{"tex": "res://art/ice_dragon_breath_3.png", "foot": Vector2(74, 172)},
		{"tex": "res://art/ice_dragon_breath_4.png", "foot": Vector2(74, 169)},
	],
}

var enemy_id: String
var hp: float
var max_hp: float
var damage: float
var speed: float
var attack_interval: float
var damage_reduction: float = 0.0
var state: int = State.MOVING
var target_defender: Defender = null

# Enemies march radially inward toward the fortress at the arena center:
# `angle` is fixed at spawn (one of the four compass lanes) and
# `current_radius` shrinks over time as they close in.
var angle: float = 0.0
var current_radius: float = 0.0

# Which of the four lanes this one walks down. It decides who is allowed to
# stop it: only units standing on the same lane, and while any of them lives,
# nothing on this lane reaches the fortress.
var lane: int = 0

# The middle of that lane. `angle` drifts off it as the enemy picks a defender
# to square up on, and this is what it walks back toward once the lane is clear.
var lane_angle: float = 0.0

# Goblins. They never stop for the line -- soldiers and shooters are simply
# walked past, straight to the fortress.
var ignores_line: bool = false

# How far back this enemy waits when the lane ahead is held but every soldier
# on it is already busy -- keeps the queue a column instead of a pile.
var queue_offset: float = 0.0

# Seconds this one stays put after spawning, before it starts marching. Only a
# boss uses it, so its entrance can play out before it moves.
var entry_timer: float = 0.0

# What a vine leaves behind. Rooted bodies cannot close the distance but can
# still fight whatever is already in front of them -- being tied to the ground
# is not the same as being helpless. The rot afterwards is what actually kills.
var root_timer: float = 0.0
var poison_timer: float = 0.0
var poison_dps: float = 0.0
var _poison_tick: float = 0.0
var _bind: Node2D = null
# Who to credit if the rot is what finishes this body off. Held weakly in the
# sense that it is always checked with is_instance_valid -- a mage is routinely
# cut down while what it threw is still working.
var _vine_source: Defender = null

func is_rooted() -> bool:
	return root_timer > 0.0

# Knocked off its feet rather than tied down. The same hold a vine puts on a
# body, without the creepers: a war slam breaks the ground under the line and
# the effect that sells it is already on the floor, so a second one growing out
# of every body would only muddy it.
func stagger(seconds: float) -> void:
	if hp <= 0.0 or seconds <= 0.0:
		return
	root_timer = maxf(root_timer, seconds)

# How long the rot outlives the creeper. The hold is the setup and the poison is
# the payoff, so the poison is always the hold plus this -- a longer vine is a
# longer poisoning too, without a second number to keep in step with the first.
const POISON_TAIL := 2.0

# Re-applied rather than stacked: a second vine on the same body renews the hold
# and takes the stronger rot, so two mages on one target are worth more coverage
# rather than an unkillable multiplier.
func apply_vine(root_time: float, dps: float, by: Defender = null) -> void:
	if hp <= 0.0:
		return
	if root_time > 0.0:
		root_timer = maxf(root_timer, root_time)
	if dps > 0.0:
		poison_dps = maxf(poison_dps, dps)
		poison_timer = maxf(poison_timer, root_time + POISON_TAIL)
		# Whoever threw the strongest rot is the one it kills for. Most of a vine
		# mage's work is done after the vine lands rather than by it, so without
		# this the whole branch would never earn a level.
		_vine_source = by
	if _bind == null or not is_instance_valid(_bind):
		_bind = VineBind.new()
		add_child(_bind)
		_bind.setup(_radius)
	_bind.refresh(root_timer, poison_timer)

# Ticked by CombatManager rather than by _process: a dead body stops processing,
# and rot has to stop with it.
func tick_vine(delta: float) -> void:
	if root_timer > 0.0:
		root_timer = maxf(0.0, root_timer - delta)
	if poison_timer <= 0.0:
		return
	poison_timer = maxf(0.0, poison_timer - delta)
	_poison_tick -= delta
	if _poison_tick <= 0.0:
		_poison_tick = POISON_INTERVAL
		# Fed through take_damage so the health bar, the flash and the death all
		# behave exactly as they do for anything else that hurts.
		take_damage(poison_dps * POISON_INTERVAL, Vector2.INF, true, _vine_source)
	if poison_timer <= 0.0:
		poison_dps = 0.0
		_vine_source = null

const POISON_INTERVAL := 0.5

# The dartmaster's rot, which is a vine's poison without the vine: no hold on the
# body, no creepers laid over it, just the bubbles and the ticking. Re-applied
# rather than stacked, exactly as a vine is -- a second dart in the same body
# renews the clock and keeps the stronger of the two rots.
func apply_poison(seconds: float, dps: float, by: Defender = null) -> void:
	if hp <= 0.0 or dps <= 0.0 or seconds <= 0.0:
		return
	poison_dps = maxf(poison_dps, dps)
	poison_timer = maxf(poison_timer, seconds)
	_vine_source = by
	if _bind == null or not is_instance_valid(_bind):
		_bind = VineBind.new()
		add_child(_bind)
		_bind.setup(_radius, false)
	_bind.refresh(0.0, poison_timer)

# ------------------------------------------------------------------- slowed
#
# What the void master's ball leaves on whatever it hits. It multiplies both
# halves of what a body does with its time -- the ground it covers and the rate
# it swings at -- so a slowed enemy is behind on the walk in and behind again
# once it arrives, which is what makes one hero worth a slot on a lane he is not
# even holding.
#
# Deepened rather than stacked: two balls into the same body take the slower of
# the two and renew the clock, the same rule every other lasting effect here
# follows.

const SLOW_TINT := Color(0.62, 0.34, 1.0)
const SLOW_AMOUNT := 0.5

var slow_mult: float = 1.0
var slow_timer: float = 0.0
# Which colour the current slow paints with. A bolt carries its own -- the void
# master's is violet and the cronomancer's is blue -- so the wash on the body
# names what put it there instead of every slow in the game looking like the
# first one that was written.
var slow_tint: Color = SLOW_TINT

func apply_slow(mult: float, seconds: float, tint: Color = SLOW_TINT) -> void:
	if hp <= 0.0 or seconds <= 0.0 or mult >= 1.0:
		return
	slow_mult = minf(slow_mult, maxf(mult, 0.1))
	slow_timer = maxf(slow_timer, seconds)
	slow_tint = tint
	_paint_slow()

func is_slowed() -> bool:
	return slow_timer > 0.0

func tick_slow(delta: float) -> void:
	if slow_timer <= 0.0:
		return
	slow_timer = maxf(0.0, slow_timer - delta)
	if slow_timer > 0.0:
		return
	slow_mult = 1.0
	_paint_slow()

# ------------------------------------------------------------- the hour held
#
# The cronomancer's cast, kept in a slot of its own rather than deepening the
# one above. Three reasons, all of them the same reason: it is a different
# effect. It is not thrown at a body, it lands on every body at once; it carries
# an hourglass over each of them that has to appear and leave with it exactly;
# and an ordinary bolt landing on a held enemy must not be able to cut its clock
# short by renewing the shared one underneath it.
#
# The two multiply. A body caught by the hour *and* hit by a bolt is slower than
# either would leave it, which is the right answer -- and both are bounded well
# above zero, so the product can never stop anything outright.

const CHRONO_TINT := Color(0.38, 0.62, 1.0)
const CHRONO_AMOUNT := 0.42

var chrono_mult: float = 1.0
var chrono_timer: float = 0.0
var _chrono_mark: ChronoMark = null

func apply_chrono(mult: float, seconds: float) -> void:
	if hp <= 0.0 or seconds <= 0.0 or mult >= 1.0:
		return
	chrono_mult = minf(chrono_mult, maxf(mult, 0.1))
	chrono_timer = maxf(chrono_timer, seconds)
	if _chrono_mark == null or not is_instance_valid(_chrono_mark):
		_chrono_mark = ChronoMark.new()
		add_child(_chrono_mark)
		_chrono_mark.setup(_radius)
	_paint_slow()

func is_chrono_held() -> bool:
	return chrono_timer > 0.0

func tick_chrono(delta: float) -> void:
	if chrono_timer <= 0.0:
		return
	chrono_timer = maxf(0.0, chrono_timer - delta)
	if chrono_timer > 0.0:
		return
	chrono_mult = 1.0
	_release_chrono()
	_paint_slow()

func _release_chrono() -> void:
	if _chrono_mark != null and is_instance_valid(_chrono_mark):
		_chrono_mark.close()
	_chrono_mark = null

# How fast this body actually crosses ground right now, and how long it actually
# waits between blows. Everything that moves or times an enemy goes through
# these two rather than through `speed` and `attack_interval`.
func _pace() -> float:
	return slow_mult * chrono_mult

func move_speed() -> float:
	return speed * _pace()

func effective_interval() -> float:
	return attack_interval / maxf(_pace(), 0.1)

# The same two lines in the body shader the freeze uses on our own soldiers --
# a blend toward a colour that keeps the pixel's own brightness, so a slowed
# goblin and a slowed golem read the same however they are painted.
#
# The hour wins the colour while it is open. It is the heavier of the two and
# the one with an icon standing over the body announcing it, so the wash under
# that icon had better be the one it belongs to.
func _paint_slow() -> void:
	if _lit == null:
		return
	if chrono_timer > 0.0:
		_lit.set_shader_parameter("ice", CHRONO_TINT)
		_lit.set_shader_parameter("ice_amount", CHRONO_AMOUNT)
	elif slow_timer > 0.0:
		_lit.set_shader_parameter("ice", slow_tint)
		_lit.set_shader_parameter("ice_amount", SLOW_AMOUNT)
	else:
		_lit.set_shader_parameter("ice_amount", 0.0)

# ---------------------------------------------------------------- knocked back
#
# The windmaster's gale. A body is thrown straight back out along the lane it
# walked in on -- its angle never changes, only how far out it is standing -- so
# a rank blown back is a rank that has to walk the ground again rather than one
# scattered somewhere the lane rules cannot account for.
#
# Bosses do not move. That is the deal: everything else on the field can be held
# off a wall for a few seconds and the thing the wave was actually about cannot.

const KNOCK_SPEED := 700.0
const KNOCK_MAX_RADIUS := 560.0

var knock_left: float = 0.0

func can_be_knocked() -> bool:
	return not is_boss

func knock_back(distance: float) -> void:
	if hp <= 0.0 or distance <= 0.0 or not can_be_knocked():
		return
	knock_left = maxf(knock_left, distance)
	var dust := FxUtil.burst(self, 9, 0.34, 90.0, 240.0,
		Color(0.92, 1.0, 0.72, 1.0), Color(0.45, 0.60, 0.24, 0.0))
	dust.position = Vector2(0, -_radius * 0.3)
	dust.direction = -_forward()
	dust.spread = 42.0
	dust.gravity = Vector2(0, 240)
	dust.emitting = true
	# Taken off the body once it has burnt out. A soldier throws a handful of
	# sparks in a whole run and can afford to leave the emitters lying about; a
	# body the windmaster is holding off a lane is thrown back every second and
	# a half for as long as it lives.
	var life := dust.create_tween()
	life.tween_interval(dust.lifetime + 0.2)
	life.tween_callback(dust.queue_free)

func is_knocked() -> bool:
	return knock_left > 0.0

# Answers with whether the body is still in the air, which is also what tells the
# caller to skip its walk this frame. The position is set straight rather than
# through update_position: that is what feeds the heading, and a body blown
# backwards should still be facing the fortress it was walking toward.
func tick_knock(delta: float, center: Vector2) -> bool:
	if knock_left <= 0.0:
		return false
	var step: float = minf(knock_left, KNOCK_SPEED * delta)
	knock_left -= step
	current_radius = minf(current_radius + step, KNOCK_MAX_RADIUS)
	global_position = center + Vector2(cos(angle), sin(angle)) * current_radius
	return true

var is_boss: bool = false
var slam_interval: float = 0.0
var slam_damage: float = 0.0
var _slam_timer: float = 0.0

# The charge. `_dash_timer` runs from the moment the body appears, so a wolf
# that walks in with it already full opens the fight with it; CombatManager is
# what decides there is something in front of it worth charging.
var dash_cooldown: float = 0.0
var dash_damage_mult: float = 1.0
var dash_freeze: float = 0.0
var _dash_timer: float = 0.0
var _dashing: bool = false
# How far forward the charge has carried the body, in pixels. Added to the
# gait's own throw in _process, so the wolf really does arrive on top of what it
# hit and slides back to its standoff afterwards.
var _dash_offset: float = 0.0

# The circle a wizard opens. Its timer runs from the moment the body appears,
# the same way the wolf's charge does, so the first one comes soon after it
# arrives and the rest are spaced by its attack interval.
var field_radius: float = 0.0
var field_slow: float = 1.0
var field_time: float = 0.0
var field_range: float = 0.0
var field_art: String = ""
var _cast_timer: float = 0.0

# A body that opens circles never picks a soldier to fight and never joins the
# melee: it stops behind whatever is holding the lane and works from there.
func has_field() -> bool:
	return field_radius > 0.0

func cast_ready(delta: float) -> bool:
	_cast_timer -= delta
	return _cast_timer <= 0.0

func start_cast_cooldown() -> void:
	_cast_timer = effective_interval()

var _attack_timer: float = 0.0

var _visual: Node2D = null
var _visual_base_scale: Vector2 = Vector2.ONE

# Resolved attack frames: [{ "tex", "offset", "hold", "fx" }]. Empty for anything
# without drawn poses, which is what sends it down the procedural swing instead.
var _frames: Array = []
var _dash_frames: Array = []
var _fly_frames: Array = []
var _breath_frames: Array = []
var _hit_frame: int = 0
var _frame_index: int = 0
# Whatever is actually on screen right now. Kept so a body that turns mid-move
# redraws the frame it is in rather than dropping back to its standing pose --
# there are four sets of frames a body can be showing.
var _shown_set: Array = []
var _shown_index: int = 0
var _frame_tween: Tween = null
var _fx_tint: Color = Color(1, 1, 1)
var _facing: float = 1.0

# Where the last step actually took the body, smoothed over a few of them. This
# is the difference between something walking east and something facing east:
# a body crossing its lane to reach the next soldier is moving sideways for
# several seconds, and drawn facing the castle the whole way it moonwalks.
#
# Steps longer than MAX_STEP are placements rather than walks -- the one at spawn
# above all, which comes in from the origin -- and say nothing about a heading.
const MAX_STEP := 40.0
const TRAVEL_SMOOTH := 0.3
# Below this much ground per step -- 0.05px, as a squared length -- the body is
# standing rather than walking. The slowest thing in the game is the golem at 25
# a second, which still covers eight times it in a frame, and a body held at its
# place in the queue falls under it within a few.
const TRAVEL_STILL := 0.0025

var _travel: Vector2 = Vector2.ZERO

func update_position(center: Vector2) -> void:
	var to: Vector2 = center + Vector2(cos(angle), sin(angle)) * current_radius
	var step: Vector2 = to - global_position
	if step.length() <= MAX_STEP:
		_travel = _travel.lerp(step, TRAVEL_SMOOTH)
	global_position = to

func setup(id: String) -> void:
	enemy_id = id
	var d: Dictionary = UnitDatabase.get_enemy_def(id)
	max_hp = d.get("hp", 50.0)
	hp = max_hp
	damage = d.get("damage", 5.0)
	speed = d.get("speed", 60.0)
	attack_interval = d.get("attack_interval", 1.0)
	damage_reduction = d.get("damage_reduction", 0.0)
	is_boss = d.get("is_boss", false)
	ignores_line = d.get("ignores_line", false)
	slam_interval = d.get("slam_interval", 0.0)
	slam_damage = d.get("slam_damage", 0.0)
	_slam_timer = slam_interval
	dash_cooldown = d.get("dash_cooldown", 0.0)
	dash_damage_mult = d.get("dash_damage_mult", 1.0)
	dash_freeze = d.get("dash_freeze", 0.0)
	# The first charge comes sooner than the rest: it is ready a beat after the
	# body lands rather than a full cooldown later.
	_dash_timer = d.get("dash_delay", dash_cooldown)
	field_radius = d.get("field_radius", 0.0)
	field_slow = d.get("field_slow", 1.0)
	field_time = d.get("field_time", 0.0)
	field_range = d.get("field_range", 0.0)
	field_art = String(d.get("field_art", ""))
	_cast_timer = d.get("field_delay", attack_interval)
	breath_radius = d.get("breath_radius", 0.0)
	breath_range = d.get("breath_range", 0.0)
	breath_interval = d.get("breath_interval", 0.3)
	_radius = d.get("radius", 28.0)
	_melee_style = String(d.get("melee", "swing"))
	_slash_tint = d.get("slash_tint", Color(0, 0, 0, 0))
	_build_visual(d)

func apply_wave_scaling(hp_mult: float, damage_mult: float) -> void:
	max_hp *= hp_mult
	hp = max_hp
	damage *= damage_mult

func _build_visual(d: Dictionary) -> void:
	var radius: float = d.get("radius", 28.0)
	_altitude = d.get("altitude", 0.0)
	_build_frames()
	# Pulls this body's remains into the cache now, on a frame that is already
	# loading textures, rather than on the frame it dies -- which is the one
	# frame of its life the player is watching closely.
	Corpse.warm(enemy_id)
	# A body with drawn frames stands in the first of them, so the pose it holds
	# and the pose it attacks out of are the same drawing.
	var art_path: String = ""
	if not _frames.is_empty():
		art_path = String(ANIM[enemy_id]["frames"][0]["tex"])
	elif not _fly_frames.is_empty():
		art_path = String(FLY[enemy_id][0]["tex"])
	else:
		art_path = UnitDatabase.get_art_path(enemy_id)
	if art_path != "":
		_visual = _build_sprite(art_path, radius)
		# Under the feet, and added before the body so it draws beneath it. A
		# flyer keeps the same shadow -- it simply hangs a long way above it,
		# which is what the altitude and the gap between the two are saying.
		_build_shadow(radius, (_visual as Sprite2D))
		add_child(_visual)
		# Registered as a frame rather than left as a loose texture, even though
		# the drawing is the one _build_sprite just put up and the offset works
		# out to zero. Turning is refused while nothing is registered, so a body
		# that was never told which frame it is standing in walks the whole way
		# in without ever facing its heading -- and then snaps around the first
		# time it swings, which is when the attack row finally registers one.
		# Invisible on anything drawn front-on; on the wolf, which is drawn in
		# pure profile, it is the animal running in backwards.
		if not _frames.is_empty():
			_apply_frame(_frames, 0)
		elif not _fly_frames.is_empty():
			_apply_frame(_fly_frames, 0)
	else:
		var poly := Polygon2D.new()
		poly.polygon = _circle_points(radius, 12)
		poly.color = d.get("color", Color.RED)
		add_child(poly)
		_visual = poly

		var label := Label.new()
		label.text = str(d.get("name", "")).left(4)
		label.add_theme_font_size_override("font_size", 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(-radius, -radius)
		label.size = Vector2(radius * 2.0, radius * 2.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

	_visual_base_scale = _visual.scale
	_build_health_bar(radius)
	_gait = GAITS.get(String(d.get("gait", "scurry")), GAITS["scurry"])
	# Offset phase and tempo per body, so a row of goblins neither marches in
	# lockstep nor drifts back into it a few seconds later.
	_cycle = randf() * TAU
	_rate = randf_range(0.90, 1.10)

# Registers every frame on the first one, exactly as the defenders do: the first
# frame is drawn centred on the node, where a single-frame body sits, and the
# rest are offset by however far their anchor differs from that. The offset goes
# on the sprite rather than its position, because the gait owns the position.
func _build_frames() -> void:
	var def: Dictionary = ANIM.get(enemy_id, {})
	var fly: Array = FLY.get(enemy_id, [])
	# The set everything else is registered against: the attack row where there
	# is one, and the flight loop for a body that has no attack at all.
	var base_list: Array = def.get("frames", fly)
	if base_list.is_empty():
		return

	var base: Texture2D = load(String(base_list[0]["tex"]))
	# Where the first frame's centre sits, measured from its own stance centre.
	# Everything is registered against this one point -- the special moves
	# included -- which is what keeps the feet planted across all of it.
	var from_anchor: Vector2 = base.get_size() * 0.5 - (base_list[0]["foot"] as Vector2)
	if not def.is_empty():
		_hit_frame = int(def["hit"])
		_fx_tint = def["tint"]
		_frames = _register(def["frames"], from_anchor)
	_dash_frames = _register(DASH.get(enemy_id, []), from_anchor)
	_fly_frames = _register(fly, from_anchor)
	_breath_frames = _register(BREATH.get(enemy_id, []), from_anchor)

func _register(list: Array, from_anchor: Vector2) -> Array:
	var out: Array = []
	for f in list:
		var tex: Texture2D = load(String(f["tex"]))
		var anchor: Vector2 = (f["foot"] as Vector2) + from_anchor
		out.append({
			"tex": tex,
			"offset": tex.get_size() * 0.5 - anchor,
			"hold": float(f.get("hold", 0.0)),
			"fx": String(f.get("fx", "")),
		})
	return out

# The frames are painted facing right; a body walking in from the east has to be
# mirrored, offsets included, or its sword swings back the way it came.
func _update_facing() -> void:
	# Asked of whatever is on screen, not of the attack row: a dragon has no
	# attack frames at all and still has to turn to face the way it is going.
	if _shown_set.is_empty() or not (_visual is Sprite2D):
		return
	# The way it is going while it is going anywhere, and the way it is squared up
	# once it has stopped -- which is at whatever it is about to fight.
	var dir: Vector2 = _travel if _travel.length_squared() > TRAVEL_STILL else _aim_dir()
	# It has to be going somewhere sideways before it turns: a step that is two
	# per cent east of straight down is not a body walking east, and flipping a
	# whole sprite for it reads as a twitch.
	if absf(dir.normalized().x) < 0.25:
		return
	var want: float = 1.0 if dir.x >= 0.0 else -1.0
	if want == _facing:
		return
	_facing = want
	(_visual as Sprite2D).flip_h = _facing < 0.0
	# Redraws whichever frame is actually up: turning mid-charge must not drop
	# the body back into its standing pose.
	_apply_frame(_shown_set, _shown_index)

func _show_frame(i: int) -> void:
	_frame_index = i
	_apply_frame(_frames, i)

func _show_dash_frame(i: int) -> void:
	_apply_frame(_dash_frames, i)

func _apply_frame(list: Array, i: int) -> void:
	if not (_visual is Sprite2D) or i < 0 or i >= list.size():
		return
	_shown_set = list
	_shown_index = i
	var sprite := _visual as Sprite2D
	sprite.texture = list[i]["tex"]
	var off: Vector2 = list[i]["offset"]
	sprite.offset = Vector2(off.x * _facing, off.y)

# ---------------------------------------------------------------- health bar

# A small plate above the head: dark frame, sunken track, then two bars -- the
# live fill, and a pale "chip" bar behind it that lags a beat before catching
# up, so every hit reads as a bite taken out of the enemy rather than a number
# quietly changing. Hidden until the first hit lands (a screen full of full
# bars is just noise); bosses carry theirs from the start.

const BAR_HEIGHT := 10.0
const BAR_BOSS_HEIGHT := 16.0
const BAR_CHIP_DELAY := 0.18

# The empty part of the track is a dark maroon rather than black: at this size
# a black slab with a small coloured square in it reads as a black slab, while
# a red trough reads as missing health at a glance.
const BAR_TRACK := Color(0.30, 0.11, 0.13, 0.92)
const BAR_FRAME := Color(0.02, 0.02, 0.03, 0.80)
const BAR_FRAME_BOSS := Color(0.62, 0.47, 0.20, 0.95)
const BAR_CHIP := Color(0.99, 0.80, 0.52, 0.95)

var _bar_root: Node2D = null
var _bar_fill: Polygon2D = null
var _bar_chip: Polygon2D = null
var _chip_tween: Tween = null

func _build_health_bar(radius: float) -> void:
	var h: float = BAR_BOSS_HEIGHT if is_boss else BAR_HEIGHT
	var w: float = maxf(46.0, radius * 2.1)

	_bar_root = Node2D.new()
	# Above the body as it is drawn, which for a flyer is well above the ground
	# it is standing on as far as the lane rules are concerned.
	_bar_root.position = Vector2(0, -radius * SPRITE_VISUAL_SCALE - 12.0 - _altitude)
	_bar_root.visible = is_boss
	add_child(_bar_root)

	_bar_root.add_child(_bar_rect(w + 3.0, h + 3.0, BAR_FRAME_BOSS if is_boss else BAR_FRAME))
	_bar_root.add_child(_bar_rect(w, h, BAR_TRACK))

	_bar_chip = _bar_rect(w, h, BAR_CHIP)
	_bar_root.add_child(_bar_chip)

	_bar_fill = _bar_rect(w, h, _bar_color(1.0))
	_bar_root.add_child(_bar_fill)

	# Gloss along the top of the fill. Child of the fill, so it shortens with it.
	var gloss := Polygon2D.new()
	gloss.polygon = _rect_points(w, h * 0.4)
	gloss.color = Color(1, 1, 1, 0.26)
	gloss.position = Vector2(0, h * 0.1)
	_bar_fill.add_child(gloss)

# Anchored on its own left edge, so the bar empties by scaling x instead of
# having its geometry rebuilt on every hit.
func _bar_rect(w: float, h: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = _rect_points(w, h)
	poly.color = color
	poly.position = Vector2(-w * 0.5, -h * 0.5)
	return poly

func _rect_points(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])

func _bar_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.36, 0.80, 0.46)
	if ratio > 0.25:
		return Color(0.97, 0.78, 0.30)
	return Color(0.90, 0.28, 0.34)

func _update_health_bar() -> void:
	if _bar_root == null or not is_instance_valid(_bar_fill):
		return
	var ratio: float = clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	_bar_root.visible = true
	_bar_fill.scale.x = ratio
	_bar_fill.color = _bar_color(ratio)

	if _chip_tween != null and _chip_tween.is_valid():
		_chip_tween.kill()
	_chip_tween = create_tween()
	_chip_tween.tween_interval(BAR_CHIP_DELAY)
	_chip_tween.tween_property(_bar_chip, "scale:x", ratio, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------ animation

# The art is one still frame per enemy -- there are no animation sheets to
# play -- so the motion is built from the sprite's own transform each frame,
# per enemy type. A goblin scurries, an orc plods, a bat never touches the
# ground. Everything below is driven off one phase value, so a body is always
# in a consistent pose instead of several tweens fighting over the transform.
#
#   speed     how fast the cycle runs (radians per second)
#   bob       vertical travel of the step or hover, in pixels
#   squash    how much the body compresses as a foot lands
#   flap      horizontal stretch of a wingbeat (flyers only)
#   lean      body roll through the cycle, in radians
#   idle_amp  how much of the cycle survives when standing and fighting
#   lunge     how far the body throws itself forward on an attack

const GAITS := {
	# quick, light, springy: lots of bounce for very little weight
	"scurry": {"speed": 9.0, "bob": 6.0, "squash": 0.10, "flap": 0.0, "lean": 0.06,
		"idle_amp": 0.40, "lunge": 17.0, "wind": 0.10, "hit": 0.07, "recover": 0.20},
	# heavy and deliberate: slow cycle, hard landings
	"plod": {"speed": 4.6, "bob": 4.5, "squash": 0.14, "flap": 0.0, "lean": 0.04,
		"idle_amp": 0.40, "lunge": 15.0, "wind": 0.16, "hit": 0.08, "recover": 0.26},
	# armoured: stiff, barely bobs, almost no roll
	"march": {"speed": 3.8, "bob": 3.0, "squash": 0.07, "flap": 0.0, "lean": 0.02,
		"idle_amp": 0.35, "lunge": 13.0, "wind": 0.18, "hit": 0.07, "recover": 0.24},
	# airborne: hovers on the spot, wings beating twice per hover cycle, and
	# keeps flapping while it fights because it never lands
	"flit": {"speed": 11.0, "bob": 9.0, "squash": 0.0, "flap": 0.17, "lean": 0.11,
		"idle_amp": 0.85, "lunge": 24.0, "wind": 0.07, "hit": 0.06, "recover": 0.16},
	# enormous: a slow sway with a heavy drop, and a wind-up you can see coming
	"lumber": {"speed": 2.3, "bob": 7.0, "squash": 0.16, "flap": 0.0, "lean": 0.03,
		"idle_amp": 0.55, "lunge": 22.0, "wind": 0.34, "hit": 0.10, "recover": 0.32},
	# four-legged: a long low stride that barely leaves the ground, and a body
	# that rolls into the turn rather than bouncing on it
	"lope": {"speed": 7.6, "bob": 4.0, "squash": 0.09, "flap": 0.0, "lean": 0.07,
		"idle_amp": 0.45, "lunge": 20.0, "wind": 0.09, "hit": 0.06, "recover": 0.18},
	# something enormous holding itself up: a long slow rise and fall with only
	# the faintest pulse to it, because the wings are drawn beating and the body
	# does not need to mime it as well
	"soar": {"speed": 2.9, "bob": 20.0, "squash": 0.0, "flap": 0.05, "lean": 0.02,
		"idle_amp": 0.9, "lunge": 18.0, "wind": 0.20, "hit": 0.08, "recover": 0.28},
}

var _gait: Dictionary = GAITS["scurry"]
var _cycle: float = 0.0
var _amp: float = 1.0     # smoothed gait amplitude, eased between walk and stance
var _tempo: float = 1.0   # smoothed gait tempo
var _rate: float = 1.0    # per-body variation, so a crowd never pulses as one
var _lunge: float = 0.0   # -1 wound up, +1 fully committed forward
var _swing: float = 0.0   # body roll through a weapon stroke, in radians
var _radius: float = 28.0
var _melee_style: String = "swing"
# Fully transparent means "no override" -- the style's own tint is used.
var _slash_tint: Color = Color(0, 0, 0, 0)

# How far the body turns back and then through the blow, and what the weapon
# leaves behind. A club and a sword both swing; a bat has nothing in its hands
# and just snaps forward, so it gets the motion without the steel.
const MELEE_STYLES := {
	"swing": {"back": 0.30, "through": 0.44, "reach": 1.30, "span": 1.9,
		"width": 10.0, "tint": Color(0.92, 0.96, 1.0)},
	"smash": {"back": 0.42, "through": 0.56, "reach": 1.15, "span": 2.3,
		"width": 20.0, "tint": Color(1.0, 0.74, 0.42)},
	"bite": {"back": 0.10, "through": 0.16, "reach": 0.0, "span": 0.0,
		"width": 0.0, "tint": Color(1, 1, 1)},
	# No steel at all: the body turns through the throw and a bolt crosses the
	# gap instead of an arc opening beside it. "reach" here is how far the bolt
	# travels, in body radii, rather than the length of a blade.
	"magic": {"back": 0.26, "through": 0.40, "reach": 1.9, "span": 0.0,
		"width": 0.0, "tint": Color(0.80, 0.66, 1.0)},
}

# Which way the body is squared up: toward whatever it has picked out to fight,
# and toward the fortress when it has picked out nothing. For almost everything
# on the field those are the same direction, since a body stops on its target's
# own angle and its target is the thing between it and the castle. They stop
# being the same for one that broke through the line and is now fighting a
# soldier dropped in behind it -- that one is standing inside the ring, and what
# it is swinging at is back out the way it came.
func _aim_dir() -> Vector2:
	if target_defender != null and is_instance_valid(target_defender):
		var to: Vector2 = target_defender.global_position - global_position
		if to.length_squared() > 1.0:
			return to.normalized()
	return _forward()

# Toward the fortress: attacks are thrown along the lane the enemy walked in on.
func _forward() -> Vector2:
	return -Vector2(cos(angle), sin(angle))

func _process(delta: float) -> void:
	if not is_instance_valid(_visual):
		return

	# update_position is the only thing that feeds the heading, and it is only
	# called while a body is actually walking -- so every other case has to let go
	# of it here, or a body that crossed its lane would stand facing the way it
	# came for the rest of its life, and one held by a vine would keep marching on
	# the spot while the creepers had it.
	if state != State.MOVING or is_rooted():
		_travel = _travel.lerp(Vector2.ZERO, minf(1.0, 8.0 * delta))

	_update_facing()
	_update_flight(delta)
	_update_breath(delta)

	var flyer: bool = float(_gait["flap"]) > 0.0
	# Asked of the ground the body is actually covering, not of the state it is
	# in. A body waiting its turn behind a fight it cannot join is still MOVING as
	# far as the lane rules are concerned, and used to march on the spot the whole
	# time it stood there.
	var moving: bool = state == State.MOVING and _travel.length_squared() > TRAVEL_STILL

	# Eased rather than switched. Snapping the amplitude the frame an enemy
	# stops to fight made the whole body jump; a body slows into a stance.
	var want_amp: float = 1.0 if moving else float(_gait["idle_amp"])
	var want_tempo: float = 1.0 if moving or flyer else 0.55
	_amp = lerpf(_amp, want_amp, 1.0 - exp(-7.0 * delta))
	_tempo = lerpf(_tempo, want_tempo, 1.0 - exp(-5.0 * delta))

	# The gait runs at whatever pace the body is actually keeping. Without this a
	# slowed enemy crosses the ground at half speed while its legs go on working
	# at full, which reads as ice underfoot rather than as a body held back.
	_cycle += delta * float(_gait["speed"]) * _tempo * _rate * slow_mult

	var bob: float
	var squash: float
	var sway: float
	if flyer:
		# Hover: rides up and down through the whole cycle rather than pushing
		# off the ground, wings beating twice per pass, and drifting sideways
		# on the slower half-cycle the way something holding itself up does.
		bob = sin(_cycle) * float(_gait["bob"]) * _amp
		squash = -cos(_cycle * 2.0) * float(_gait["flap"]) * _amp
		sway = cos(_cycle * 0.5) * float(_gait["bob"]) * 0.30 * _amp
	else:
		# Step. The rise is shaped rather than a plain sine: a body leaves the
		# ground quickly off the push and hangs at the top of the step, which
		# is the difference between walking and bobbing on a spring.
		var lift: float = pow(absf(sin(_cycle)), 0.68)
		bob = -lift * float(_gait["bob"]) * _amp
		squash = cos(_cycle * 2.0) * float(_gait["squash"]) * _amp
		# One sway per stride (two steps): weight shifting hip to hip.
		sway = sin(_cycle * 0.5) * float(_gait["bob"]) * 0.22 * _amp

	var punch: float = 1.0 + 0.12 * _lunge
	# The lunge and the charge go where the blow is going, which is at whatever
	# this body is fighting rather than at the castle behind it.
	_visual.position = Vector2(sway, bob - _altitude) \
		+ _aim_dir() * (_lunge * float(_gait["lunge"]) + _dash_offset)
	# The shadow stays on the ground while the body rides above it, and tightens
	# as the body climbs -- which is most of what says the thing is in the air.
	if _shadow != null:
		# Tightens and darkens as the body drops and spreads as it climbs. This
		# is what actually says "in the air": a still shadow under a still body
		# is just a mark on the snow.
		_shadow.set_lift(clampf(-bob / maxf(float(_gait["bob"]), 1.0), 0.0, 1.0))

	_update_grounding(delta, moving)
	_visual.scale = _visual_base_scale * Vector2(
		(1.0 + squash) * punch, (1.0 - squash) * punch)
	# The lean leads the step slightly: weight commits before the foot lands.
	_visual.rotation = sin(_cycle + 0.55) * float(_gait["lean"]) * _amp + _swing

# One entry point for every attack this body makes. A body with drawn poses
# plays them and lands its blow on the contact frame; anything without them
# keeps the procedural wind-up and strikes at once.
func play_attack(aim: Vector2, on_hit: Callable) -> void:
	if _frames.is_empty():
		_play_attack_animation()
		if on_hit.is_valid():
			on_hit.call()
		return

	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()

	var dir: Vector2 = aim.normalized() if aim.length() > 0.001 else _forward()
	_frame_tween = create_tween()
	for i in range(1, _frames.size()):
		_frame_tween.tween_callback(_enter_frame.bind(i, dir, on_hit))
		_frame_tween.tween_interval(float(_frames[i]["hold"]))
	_frame_tween.tween_callback(_show_frame.bind(0))

func _enter_frame(i: int, dir: Vector2, on_hit: Callable) -> void:
	_show_frame(i)
	_frame_fx(i, dir)
	if i == _hit_frame and on_hit.is_valid():
		on_hit.call()

# ------------------------------------------------------------------ ice dash
#
# The charge, and the one attack in the game that moves the body that makes it.
# It crouches, crosses the gap as a streak, and lands inside a burst of ice --
# and then slides back to where it was standing, because the standoff it fights
# from is owned by CombatManager and a body that simply stopped on top of its
# target would be dragged back a pixel at a time by the lane rules.

const DASH_REACH := 88.0
const DASH_CROUCH := 0.26
const DASH_TRAVEL := 0.14
const DASH_LAND := 0.30
const DASH_RETURN := 0.24
# What the whole move costs, so an ordinary bite is not thrown in the middle of it.
const DASH_TOTAL := DASH_CROUCH + DASH_TRAVEL + DASH_LAND + DASH_RETURN

func has_dash() -> bool:
	return dash_cooldown > 0.0 and not _dash_frames.is_empty()

func dash_ready(delta: float) -> bool:
	if _dashing:
		return false
	_dash_timer -= delta
	return _dash_timer <= 0.0

func start_dash_cooldown() -> void:
	_dash_timer = dash_cooldown

func play_dash(aim: Vector2, on_hit: Callable) -> void:
	if _dash_frames.is_empty():
		play_attack(aim, on_hit)
		return
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()

	_dashing = true
	var dir: Vector2 = aim.normalized() if aim.length() > 0.001 else _forward()

	_frame_tween = create_tween()
	_frame_tween.tween_callback(_show_dash_frame.bind(0))
	_frame_tween.tween_interval(DASH_CROUCH)
	# The streak and the travel are one beat: the middle frame is up for exactly
	# as long as the body takes to cross, so the blur is never seen standing still.
	_frame_tween.tween_callback(_show_dash_frame.bind(1))
	_frame_tween.parallel().tween_property(self, "_dash_offset", DASH_REACH, DASH_TRAVEL) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_frame_tween.tween_callback(_land_dash.bind(dir, on_hit))
	_frame_tween.tween_interval(DASH_LAND)
	_frame_tween.tween_property(self, "_dash_offset", 0.0, DASH_RETURN) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_frame_tween.tween_callback(_end_dash)

func _land_dash(dir: Vector2, on_hit: Callable) -> void:
	_show_dash_frame(2)
	_ice_burst(dir)
	if on_hit.is_valid():
		on_hit.call()

# Where the charge arrives, not where it started -- the body is drawn a full
# reach forward by then and the ice has to break under it.
func _ice_burst(dir: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var fx := ImpactEffect.new()
	host.add_child(fx)
	fx.global_position = global_position + dir * DASH_REACH + Vector2(0, _radius * 0.3)
	fx.play_ground_slam(_fx_tint, clampf(_radius / 64.0, 0.7, 1.6))

func _end_dash() -> void:
	_dashing = false
	_dash_offset = 0.0
	_show_frame(0)

# ------------------------------------------------------------------- flight
#
# A flyer is never on a still frame: the loop runs whenever it is not doing
# something that owns the body instead. It is the only animation in the game
# that plays without being asked for, because wings that stop beating read as a
# dead animal rather than a hovering one.

func _update_flight(delta: float) -> void:
	if _fly_frames.is_empty() or _breath_state != BREATH_OFF or _dashing:
		return
	if _frame_tween != null and _frame_tween.is_valid():
		return
	_fly_timer += delta
	if _fly_timer < FLY_FRAME_TIME:
		return
	_fly_timer = 0.0
	_fly_index = (_fly_index + 1) % _fly_frames.size()
	_apply_frame(_fly_frames, _fly_index)

# ---------------------------------------------------------------- ice breath
#
# The dragon's whole fight. Once it starts it does not stop for anything short
# of running out of things to burn -- killing what it was pointed at is not an
# interruption, it simply carries the stream on to whatever is next, burning
# everything the beam crosses on the way.
#
# The aim is eased rather than moved, which is what makes that sweep visible:
# `_breath_target` is where CombatManager wants the stream, `_breath_aim` is
# where it has actually got to.

enum { BREATH_OFF, BREATH_WINDUP, BREATH_LIVE }

const BREATH_WIND := [0.55, 0.42, 0.26]   # inhale, charge, first of the stream
const BREATH_SWEEP := 3.4                 # how fast the stream follows the aim
const BREATH_END_HOLD := 0.35

var breath_radius: float = 0.0
var breath_range: float = 0.0
var breath_interval: float = 0.3
var _breath_state: int = BREATH_OFF
var _breath_tick: float = 0.0
var _breath_target: Vector2 = Vector2.ZERO
var _breath_aim: Vector2 = Vector2.ZERO
# Who the stream is on. Deliberately not `target_defender`: that one carries the
# melee's claim on a soldier, and a dragon burning somebody from across the
# arena has not claimed a place in front of him.
var _breath_focus: Defender = null
var _beam: IceBeam = null
var _altitude: float = 0.0
var _fly_index: int = 0
var _fly_timer: float = 0.0

# ---------------------------------------------------------------- grounding
#
# What ties a body to the field: the shadow it lays on the ground, the light the
# ground throws back on it, and the dirt it kicks loose walking over it. None of
# it changes what an enemy does -- all of it is what stops the enemy reading as
# a picture sliding across a painting.

const LIGHT_INTERVAL := 0.12

var _shadow: GroundShadow = null
var _light_timer: float = 0.0
# The material carrying the light on this body, and the last state of the world
# it was told about. See Lighting.
var _lit: ShaderMaterial = null
var _shade_stamp: int = -1
# Which half-stride the body is in. A foot lands every time this changes.
var _step_phase: int = 0

func _build_shadow(radius: float, sprite: Sprite2D) -> void:
	_shadow = GroundShadow.new()
	_shadow.setup(radius * 0.9,
		Vector2(0, GroundShadow.feet_offset(sprite.texture) * sprite.scale.y))
	add_child(_shadow)

func _update_grounding(delta: float, moving: bool) -> void:
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = LIGHT_INTERVAL
		# Where on the map it is standing, and then how late in the run it is.
		var tint: Color = Ambient.tint_at(global_position) * Lighting.body_tint()
		modulate = Color(tint.r, tint.g, tint.b, modulate.a)
		# Which way the light is pushing its shadow -- the sky's, or the candle
		# on the signpost it is walking past.
		if _shadow != null:
			_shadow.set_light(Lighting.shadow_at(global_position))
		var stamp: int = Lighting.body_stamp(_facing < 0.0)
		if stamp != _shade_stamp:
			_shade_stamp = stamp
			Lighting.tune_body(_lit, _facing < 0.0)

	# Flyers kick nothing loose, and a body standing still is not walking.
	if not moving or _altitude > 0.0 or float(_gait["flap"]) > 0.0:
		return
	# One foot down per half turn of the cycle.
	var phase: int = int(floor(_cycle / PI))
	if phase == _step_phase:
		return
	_step_phase = phase
	_kick_dust()

# Coloured off the ground it is kicked from rather than a fixed brown, so the
# same code throws dirt on the roads, snow on the winter map and grit in the
# mine without anybody choosing which.
func _kick_dust() -> void:
	var host := get_parent()
	if host == null:
		return
	var ground: Color = Ambient.light_at(global_position)
	var puff := FxUtil.burst(host, 4, 0.36, 18.0, 52.0,
		Color(ground.r, ground.g, ground.b, 0.75),
		Color(ground.r * 0.7, ground.g * 0.7, ground.b * 0.75, 0.0), false)
	puff.global_position = global_position + Vector2(0, _radius * 0.42)
	puff.direction = Vector2.UP
	puff.spread = 62.0
	puff.gravity = Vector2(0, 70)
	puff.scale_amount_min = 1.6
	puff.scale_amount_max = 3.4
	puff.scale_amount_curve = FxUtil.swell_curve()
	puff.emitting = true
	# Every other burst in the game hangs off an effect node that takes itself
	# away when it is done. These do not: they are thrown onto the field itself
	# by a body that will still be walking minutes later, so each one has to
	# clear up after itself or a long wave silts the layer up with dead emitters.
	puff.finished.connect(puff.queue_free)

func has_breath() -> bool:
	return breath_radius > 0.0 and not _breath_frames.is_empty()

func is_breathing() -> bool:
	return _breath_state != BREATH_OFF

# True only once the stream is actually out of its mouth; the wind-up frames
# burn nothing.
func breath_live() -> bool:
	return _breath_state == BREATH_LIVE

# Where the stream is landing right now -- which is what the damage is dealt
# around, so a sweep burns what it passes over rather than only where it ends.
func breath_point() -> Vector2:
	return _breath_aim

func set_breath_target(at: Vector2) -> void:
	_breath_target = at
	if _breath_state == BREATH_OFF:
		_breath_aim = at

func start_breath() -> void:
	if _breath_state != BREATH_OFF or _breath_frames.is_empty():
		return
	_breath_state = BREATH_WINDUP
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	_frame_tween = create_tween()
	for i in range(BREATH_WIND.size()):
		_frame_tween.tween_callback(_apply_frame.bind(_breath_frames, i))
		_frame_tween.tween_interval(BREATH_WIND[i])
	_frame_tween.tween_callback(_open_breath)

func _open_breath() -> void:
	_breath_state = BREATH_LIVE
	_apply_frame(_breath_frames, 3)
	if _beam == null or not is_instance_valid(_beam):
		_beam = IceBeam.new()
		add_child(_beam)

func stop_breath() -> void:
	if _breath_state == BREATH_OFF:
		return
	_breath_state = BREATH_OFF
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	if _beam != null and is_instance_valid(_beam):
		_beam.fade_out()
	_beam = null
	# The one frame it may go a whole fight without reaching.
	_apply_frame(_breath_frames, 4)
	_frame_tween = create_tween()
	_frame_tween.tween_interval(BREATH_END_HOLD)

# Where the stream leaves the body: the mouth, out in front and up at the
# height the dragon is actually drawn at.
func _mouth_offset() -> Vector2:
	return Vector2(0, -_altitude - _radius * 0.22) + _forward() * (_radius * 0.62)

func _update_breath(delta: float) -> void:
	if _breath_state == BREATH_OFF:
		return
	# Eased, not snapped: the gap between where the stream is and where it is
	# wanted is the sweep, and it is the whole point of the attack.
	_breath_aim = _breath_aim.lerp(_breath_target, 1.0 - exp(-BREATH_SWEEP * delta))
	if _beam == null or not is_instance_valid(_beam):
		return
	var mouth: Vector2 = _mouth_offset()
	_beam.aim(mouth, to_local(_breath_aim), clampf(_radius / 110.0, 0.6, 1.4))

# What the drawing cannot carry: the sparks off the blade, and the ground going
# out from under a slam.
func _frame_fx(i: int, dir: Vector2) -> void:
	match String(_frames[i]["fx"]):
		"sparks":
			_attack_sparks(dir)
		"slam":
			_slam_shock(dir)

func _attack_sparks(dir: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var fx := ImpactEffect.new()
	host.add_child(fx)
	fx.global_position = global_position + dir * (_radius * 0.9) \
		+ Vector2(0, -_radius * 0.4)
	fx.play_weapon_sparks(dir, _fx_tint, clampf(_radius / 28.0, 0.8, 2.0))

# The golem's blow: the floor jumps, and the crystal in its chest is thrown at
# whatever it was aiming at.
func _slam_shock(dir: Vector2) -> void:
	_spawn_bolt(float(MELEE_STYLES["magic"]["reach"]))
	var host := get_parent()
	if host == null:
		return
	var fx := ImpactEffect.new()
	host.add_child(fx)
	fx.global_position = global_position + Vector2(0, _radius * 0.35)
	fx.play_ground_slam(_fx_tint, clampf(_radius / 72.0, 0.8, 2.2))

# Wind up against the direction of the blow, turn through it, then settle --
# the pause before the strike is what makes the strike land. The weapon is
# painted into the sprite, so the body turning is the swing; the arc that goes
# with it is spawned at the exact moment the blow arrives.
func _play_attack_animation() -> void:
	if not is_instance_valid(_visual):
		return
	var style: Dictionary = MELEE_STYLES.get(_melee_style, MELEE_STYLES["swing"])

	var tw := create_tween()
	tw.tween_property(self, "_lunge", -0.4, float(_gait["wind"])) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_swing", -float(style["back"]), float(_gait["wind"])) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.tween_property(self, "_lunge", 1.0, float(_gait["hit"])) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "_swing", float(style["through"]), float(_gait["hit"])) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	tw.tween_callback(_spawn_slash.bind(style))

	tw.tween_property(self, "_lunge", 0.0, float(_gait["recover"])) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_swing", 0.0, float(_gait["recover"])) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _spawn_slash(style: Dictionary) -> void:
	var reach: float = float(style["reach"])
	if reach <= 0.0:
		return   # nothing in its hands
	if _melee_style == "magic":
		_spawn_bolt(reach)
		return
	var tint: Color = _slash_tint if _slash_tint.a > 0.0 else style["tint"]
	var arc := SlashArc.new()
	add_child(arc)
	arc.position = Vector2(0, -_radius * 0.35)
	arc.play(_aim_dir(), _radius * reach, float(style["span"]),
		tint, float(style["width"]))

# Thrown from the chest rather than from the feet, and parented to our host: the
# bolt outlives its thrower often enough (a boss can die mid-throw) that hanging
# it off this node would cut the flight short.
func _spawn_bolt(reach: float) -> void:
	var host := get_parent()
	if host == null:
		return
	var bolt := MagicBolt.new()
	host.add_child(bolt)
	bolt.global_position = global_position + Vector2(0, -_radius * 0.55)
	bolt.play(_aim_dir(), _radius * reach, clampf(_radius / 60.0, 0.7, 2.2))

func _play_hit_flash(tint: Color = Color(1, 0.4, 0.4)) -> void:
	if not is_instance_valid(_visual):
		return
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", tint, 0.08)
	tw.tween_property(_visual, "modulate", Color(1, 1, 1), 0.15)

const SPRITE_VISUAL_SCALE := 1.3 # art renders relative to the physics collision circle for readability

func _build_sprite(art_path: String, radius: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(art_path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex_size: Vector2 = sprite.texture.get_size()
	var target_diameter := radius * 2.0 * SPRITE_VISUAL_SCALE
	var scale_factor: float = target_diameter / max(tex_size.x, tex_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	# The same shape the defenders are given, for the same reason and by the same
	# shader: a lit side, a shaded one, an edge that catches whatever is burning
	# nearest, and boots that stand in shadow. An enemy walking up the road out
	# of the dark and into the light of a signpost candle is the whole point.
	_lit = Lighting.body_material()
	sprite.material = _lit
	sprite.light_mask = Lighting.BODY_LAYER
	return sprite

func _ellipse_points(rx: float, ry: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a := TAU * i / segs
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _circle_points(r: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a := TAU * i / segs
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func is_alive() -> bool:
	return hp > 0

# ------------------------------------------------------------------ picked out
#
# Where a finger has to land to mean this body, and where the middle of it is on
# screen. The two are not the same thing as `global_position`: that is the patch
# of ground the enemy is standing on, and a dragon is drawn a hundred and thirty
# pixels above its own feet. A player aiming at a dragon aims at the dragon.

const TAP_MIN_RADIUS := 46.0

func tap_radius() -> float:
	return maxf(_radius * 1.05, TAP_MIN_RADIUS)

func tap_point() -> Vector2:
	return global_position + Vector2(0, -_altitude - _radius * 0.35)

# `poison` swaps what the hit looks like, not what it does: rot has no direction
# to spark off and reads green rather than red, or a poisoned body spends the
# whole four seconds flashing as though it were being stabbed.
#
# `by` is the soldier that landed it, and it is carried the whole way down only
# so that the kill can be credited to a body rather than to the player. It is
# optional and routinely null -- the fortress and the rot both deal damage that
# belongs to nobody -- and always checked, because a shot in the air outlives
# the shooter often enough to matter.
func take_damage(amount: float, from_position: Vector2 = Vector2.INF,
		poison: bool = false, by: Defender = null) -> void:
	if hp <= 0:
		return
	var final_amount: float = amount * (1.0 - damage_reduction)
	hp = max(0.0, hp - final_amount)
	_update_health_bar()
	_show_damage(final_amount, poison)

	# Points from the impact back toward whatever landed the blow, so the
	# effect can sit on the struck side and throw sparks the other way.
	var from_dir := Vector2.ZERO
	if from_position.is_finite():
		from_dir = (from_position - global_position).normalized()

	if hp <= 0:
		# Stop driving the gait, so the corpse collapses instead of walking
		# its way through the death animation.
		set_process(false)
		# Credited before the signal goes out: `died` is what takes this body out
		# of every list it is in, and half of those handlers let go of it.
		# The spot is carried along with the credit: a hero that marks its kills
		# has to mark them where the body actually fell, and by the time the
		# signal below has run there is nothing left to ask.
		if by != null and is_instance_valid(by):
			by.record_kill(UnitDatabase.get_enemy_xp(enemy_id), global_position,
				clampf(_radius / 32.0, 0.7, 1.8), enemy_id)
		died.emit(self)
		_play_death()
	elif poison:
		# A tint rather than a wash: this fires twice a second for seconds on
		# end, and a body that turns solid green every tick stops reading as a
		# body at all.
		_play_hit_flash(Color(0.72, 1.0, 0.70))
	else:
		_play_hit_flash()
		_spawn_hit_fx(from_dir, final_amount)

# Effects are parented to our host, not to us: this node shrinks to nothing and
# frees itself on death, which would drag a child effect down with it.
func _new_fx() -> Node2D:
	var host := get_parent()
	if host == null:
		return null
	var fx := ImpactEffect.new()
	host.add_child(fx)
	fx.global_position = global_position
	return fx

func _spawn_hit_fx(from_dir: Vector2, dealt: float) -> void:
	var fx := _new_fx()
	if fx == null:
		return
	# Chunky hits flash bigger than chip damage, measured against this
	# enemy's own health so a boss doesn't erupt on every scratch.
	var strength: float = dealt / maxf(1.0, max_hp * 0.15)
	fx.play_enemy_hit(from_dir, strength)

func _spawn_death_fx() -> void:
	var fx := _new_fx()
	if fx == null:
		return
	var radius: float = UnitDatabase.get_enemy_def(enemy_id).get("radius", 28.0)
	fx.play_enemy_death(clampf(radius / 28.0, 0.85, 2.2))

# ------------------------------------------------------------------- the end
#
# Two ways out of a fight. A body with remains drawn for it comes apart where it
# stood and leaves them lying on the floor for a few seconds -- see Corpse,
# which owns everything about that. Everything without them keeps the dissolve
# the game has always used, which today means the three bosses: nothing was ever
# painted for what a stone golem or a dragon leaves behind, and a magical poof
# is anyway the better answer for a thing made of rock.
func _play_death() -> void:
	if not Corpse.has_art(enemy_id):
		_spawn_death_fx()
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ZERO, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
		return

	var host: Node2D = CombatManager.ground_layer
	if host == null or not is_instance_valid(host):
		host = get_parent()
	if host != null:
		var remains := Corpse.new()
		host.add_child(remains)
		# On the ground it was standing on rather than on the body: the sprite
		# rides a bob above its own feet and a bat is drawn a good way further,
		# and what is left of either of them falls to the floor.
		remains.global_position = global_position + Vector2(0, -_radius * 0.12)
		remains.play(enemy_id, _radius, _facing)
	# Taken off the field on the same frame the pieces appear. queue_free only
	# lands at the end of it, and one frame of a whole body standing inside its
	# own remains is one frame too many.
	hide()
	queue_free()

# ---------------------------------------------------------------- the number
#
# What the blow was worth, put up beside the body that took it. Everything that
# hurts an enemy comes through take_damage, so this is the one place it is done.
#
# Merged rather than stacked. Several blows landing inside a fraction of a
# second is not unusual -- a volley of arrows arriving together, an ability that
# touches the whole field, the rot ticking away while a sword is working -- and
# six numbers drawn on top of each other is six numbers nobody can read. A hit
# that arrives while the last one is still climbing is added into it instead.
var _dmg_num: DamageNumber = null

func _show_damage(dealt: float, poison: bool) -> void:
	if dealt < 0.5:
		return
	var host: Node2D = CombatManager.fx_layer
	if host == null or not is_instance_valid(host):
		host = get_parent()
	if host == null:
		return

	var kind: int = DamageNumber.POISON if poison else DamageNumber.HIT
	# How much of this particular body the blow took, which is what sizes the
	# digits -- measured the same way the hit effect is, so a scratch on a boss
	# and a scratch on a goblin both read as scratches.
	var punch: float = clampf(dealt / maxf(max_hp * 0.20, 1.0), 0.0, 1.0)

	if _dmg_num != null and is_instance_valid(_dmg_num) and _dmg_num.can_merge(kind):
		_dmg_num.add(dealt, punch)
		return

	var num := DamageNumber.new()
	host.add_child(num)
	num.play(dealt, tap_point(), _radius, punch, kind)
	_dmg_num = num
