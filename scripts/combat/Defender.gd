extends Node2D
class_name Defender

const SlashArc = preload("res://scripts/fx/SlashArc.gd")
const SpearShot = preload("res://scripts/fx/SpearShot.gd")
const FxUtil = preload("res://scripts/fx/FxUtil.gd")
const Shockwave = preload("res://scripts/fx/Shockwave.gd")

# ------------------------------------------------------------ attack frames
#
# Every player unit is drawn through its attack rather than animated out of one
# still frame: art/level_1_animations.png and level_2_animations.png hold the
# poses, cut out here one file per frame. Anything without an entry below still
# gets the procedural squash-and-swing.
#
# "foot" is the stance centre of that pose -- the middle of the feet, on the
# ground line -- and it is the point the frames are registered on. Align them by
# their bounding boxes instead and a raised sword drags the whole body sideways;
# align them by the feet and only the arms move.
#
# "hold" is how long each frame stays up, and "hit" is the frame the blow
# actually lands on: the damage, or the shot leaving the bow, is fired from
# there rather than at the start, so the drawing and the effect agree.
#
# "fx" hangs one of the effects further down on a frame, "tint" is the colour
# that unit's magic or steel throws off, and "shot" is the streak left at the
# weapon as something leaves it.
#
# "lean" shifts the body along the line of the blow while a frame is up, in
# pixels. The level 3 sheet has only a standing pose and a striking one, so
# their four beats are built out of two drawings: the body settles back on the
# wind-up, drives through on the strike, and recovers. Without it two frames
# read as a flicker rather than a swing.
#
# "dirs" is optional, and it is what turns a unit into a drawn one rather than a
# mirrored one. Without it a unit has the single row above and is flipped to
# hold the west lane, which is all a body painted from one camera can do. With
# it the unit carries five rows -- "e", "se", "s", "ne", "n" -- and the one that
# gets drawn is chosen off the direction the unit is looking. The other three
# headings are those five mirrored, so the art only ever draws the right-hand
# half of the compass. Each row takes exactly the same frames as the default
# row, in the same order, because "hit" and the beat count are one number for
# the whole unit:
#
#   "knight": {
#       "hit": 2, "tint": ..., "shot": "",
#       "frames": [ ... ],                    # still the fallback and the portrait
#       "dirs": {
#           "s":  [ {"tex": "res://art/knight_s_atk_0.png",  "foot": ...}, ... ],
#           "se": [ ... ], "e": [ ... ], "ne": [ ... ], "n": [ ... ],
#       },
#   },
const ANIM := {
	"warrior": {
		"hit": 2, "tint": Color(0.94, 0.97, 1.0), "shot": "",
		"frames": [
			{"tex": "res://art/warrior_atk_0.png", "foot": Vector2(83, 193), "hold": 0.0, "fx": ""},
			{"tex": "res://art/warrior_atk_1.png", "foot": Vector2(86, 206), "hold": 0.10, "fx": ""},
			{"tex": "res://art/warrior_atk_2.png", "foot": Vector2(82, 222), "hold": 0.10, "fx": "swing"},
			{"tex": "res://art/warrior_atk_3.png", "foot": Vector2(85, 171), "hold": 0.13, "fx": "dust"},
		],
	},
	"archer": {
		"hit": 3, "tint": Color(0.66, 1.0, 0.58), "shot": "res://art/fx_arrow_shot.png",
		"frames": [
			{"tex": "res://art/archer_atk_0.png", "foot": Vector2(70, 205), "hold": 0.0, "fx": ""},
			{"tex": "res://art/archer_atk_1.png", "foot": Vector2(74, 221), "hold": 0.08, "fx": ""},
			{"tex": "res://art/archer_atk_2.png", "foot": Vector2(87, 209), "hold": 0.14, "fx": "charge"},
			{"tex": "res://art/archer_atk_3.png", "foot": Vector2(87, 206), "hold": 0.14, "fx": "release"},
		],
	},
	"apprentice_mage": {
		"hit": 2, "tint": Color(0.55, 0.80, 1.0), "shot": "res://art/fx_mage_bolt.png",
		"frames": [
			{"tex": "res://art/apprentice_mage_atk_0.png", "foot": Vector2(65, 222), "hold": 0.0, "fx": ""},
			{"tex": "res://art/apprentice_mage_atk_1.png", "foot": Vector2(82, 274), "hold": 0.16, "fx": "raise"},
			{"tex": "res://art/apprentice_mage_atk_2.png", "foot": Vector2(78, 229), "hold": 0.18, "fx": "release"},
		],
	},

	# Level 2. The knight's arc is gold rather than steel-white and its thrust
	# ends on a lit blade, so its sparks are gold to match; the master archer
	# and the mage keep their branch colours.
	"knight": {
		"hit": 2, "tint": Color(1.0, 0.86, 0.52), "shot": "",
		"frames": [
			{"tex": "res://art/knight_atk_0.png", "foot": Vector2(121, 201), "hold": 0.0, "fx": ""},
			{"tex": "res://art/knight_atk_1.png", "foot": Vector2(107, 262), "hold": 0.11, "fx": ""},
			{"tex": "res://art/knight_atk_2.png", "foot": Vector2(176, 226), "hold": 0.11, "fx": "swing"},
			{"tex": "res://art/knight_atk_3.png", "foot": Vector2(128, 179), "hold": 0.15, "fx": "dust"},
		],
		# Cut out of art/knight_view.png. That sheet draws only the rear half of
		# the compass, so these are the two headings it can serve: north, where
		# the knight holds the lane with his back to the camera, and the quarter
		# turn off it, which covers north-west as well once it is mirrored. The
		# three southern headings have no drawing on that sheet at all and fall
		# through to the row above -- a unit facing the camera keeps the front
		# pose it has always had.
		#
		# Two drawings worked into four beats with "lean", the way the level 3
		# units do it: the sheet paints one wind-up and one strike where the row
		# above has four, and a heading whose beat count does not match the
		# default row is skipped outright, because "hit" is one number for the
		# whole unit and a short row would run past it without dealing damage.
		#
		# "scale" is what holds that sheet's body at the size the level 2 sheet
		# draws it, which is much larger. Measured helmet top to foot anchor, the
		# front stance is 200 px tall, the northern one 135 and the quarter turn
		# 136, so 1.48 and 1.47 stand all three at the same height. 1.28 was short
		# of that and the knight still visibly shrank as he turned away.
		"dirs": {
			"n": [
				{"tex": "res://art/knight_n_walk_0.png", "foot": Vector2(67, 135), "hold": 0.0, "fx": "", "scale": 1.48, "lean": 0.0},
				{"tex": "res://art/knight_n_atk_0.png", "foot": Vector2(60, 182), "hold": 0.11, "fx": "", "scale": 1.48, "lean": -8.0},
				{"tex": "res://art/knight_n_atk_1.png", "foot": Vector2(60, 168), "hold": 0.11, "fx": "swing", "scale": 1.48, "lean": 9.0},
				{"tex": "res://art/knight_n_walk_0.png", "foot": Vector2(67, 135), "hold": 0.15, "fx": "dust", "scale": 1.48, "lean": 3.0},
			],
			"ne": [
				{"tex": "res://art/knight_ne_walk_0.png", "foot": Vector2(52, 136), "hold": 0.0, "fx": "", "scale": 1.47, "lean": 0.0},
				{"tex": "res://art/knight_ne_atk_0.png", "foot": Vector2(62, 169), "hold": 0.11, "fx": "", "scale": 1.47, "lean": -8.0},
				{"tex": "res://art/knight_ne_atk_1.png", "foot": Vector2(66, 163), "hold": 0.11, "fx": "swing", "scale": 1.47, "lean": 9.0},
				{"tex": "res://art/knight_ne_walk_0.png", "foot": Vector2(52, 136), "hold": 0.15, "fx": "dust", "scale": 1.47, "lean": 3.0},
			],
		},
	},
	"master_archer": {
		"hit": 2, "tint": Color(0.60, 1.0, 0.44), "shot": "res://art/fx_arrow_shot_l2.png",
		"frames": [
			{"tex": "res://art/master_archer_atk_0.png", "foot": Vector2(148, 212), "hold": 0.0, "fx": ""},
			{"tex": "res://art/master_archer_atk_1.png", "foot": Vector2(161, 228), "hold": 0.09, "fx": "charge"},
			{"tex": "res://art/master_archer_atk_2.png", "foot": Vector2(146, 228), "hold": 0.15, "fx": "release"},
		],
	},
	"mage": {
		"hit": 2, "tint": Color(0.80, 0.52, 1.0), "shot": "res://art/fx_mage_bolt_l2.png",
		"frames": [
			{"tex": "res://art/mage_atk_0.png", "foot": Vector2(73, 230), "hold": 0.0, "fx": ""},
			{"tex": "res://art/mage_atk_1.png", "foot": Vector2(123, 283), "hold": 0.16, "fx": "raise"},
			{"tex": "res://art/mage_atk_2.png", "foot": Vector2(143, 228), "hold": 0.20, "fx": "release"},
		],
	},

	# Level 3. Two drawings each, worked into four beats with "lean", and the
	# loudest effects in the game: these are the units a whole run is spent
	# building toward, so their blows are meant to be seen from anywhere on the
	# field. Gold off the paladin's sword, a bright green line off the ranger's
	# string, violet off the archmage's hand.
	"paladin": {
		"hit": 2, "tint": Color(1.0, 0.84, 0.30), "shot": "",
		"frames": [
			{"tex": "res://art/paladin.png", "foot": Vector2(189, 297), "hold": 0.0, "fx": "", "lean": 0.0},
			{"tex": "res://art/paladin.png", "foot": Vector2(189, 297), "hold": 0.13, "fx": "", "lean": -10.0},
			{"tex": "res://art/paladin_atk.png", "foot": Vector2(284, 312), "hold": 0.17, "fx": "swing_big", "lean": 11.0},
			{"tex": "res://art/paladin.png", "foot": Vector2(189, 297), "hold": 0.13, "fx": "dust", "lean": 4.0},
		],
	},
	"elite_ranger": {
		"hit": 2, "tint": Color(0.66, 1.0, 0.42), "shot": "res://art/fx_arrow_shot_l2.png",
		"frames": [
			{"tex": "res://art/elite_ranger.png", "foot": Vector2(163, 286), "hold": 0.0, "fx": "", "lean": 0.0},
			{"tex": "res://art/elite_ranger.png", "foot": Vector2(163, 286), "hold": 0.11, "fx": "charge", "lean": -8.0},
			{"tex": "res://art/elite_ranger_atk.png", "foot": Vector2(207, 317), "hold": 0.15, "fx": "release_big", "lean": 7.0},
			{"tex": "res://art/elite_ranger.png", "foot": Vector2(163, 286), "hold": 0.10, "fx": "", "lean": 2.0},
		],
	},
	# The vine mage branch. One set of frames serves all three tiers -- the sheet
	# draws the cast once -- so what separates an ancient vine mage from a young
	# one on the field is how big it is drawn and how long what it throws holds.
	# Frame 0 is the merge portrait, not the first pose of the animation row:
	# that is the drawing the piece has in the tray and the one the unit should
	# be standing in on the field, and the sheet draws its action poses at about
	# two thirds the size. "scale" brings those back up to the portrait, which is
	# what stops the mage from shrinking every time it casts.
	"vine_mage": {
		"hit": 1, "tint": Color(0.58, 1.0, 0.42), "shot": "",
		"frames": [
			{"tex": "res://art/vine_mage.png", "foot": Vector2(45, 165), "hold": 0.0, "fx": ""},
			{"tex": "res://art/vine_mage_atk_1.png", "foot": Vector2(44, 108), "hold": 0.14, "fx": "charge", "scale": 1.47},
			{"tex": "res://art/vine_mage_atk_2.png", "foot": Vector2(71, 98), "hold": 0.12, "fx": "", "scale": 1.47},
			{"tex": "res://art/vine_mage_atk_3.png", "foot": Vector2(34, 102), "hold": 0.12, "fx": "", "scale": 1.47},
		],
	},
	"elder_vine_mage": {
		"hit": 1, "tint": Color(0.54, 1.0, 0.40), "shot": "",
		"frames": [
			{"tex": "res://art/elder_vine_mage.png", "foot": Vector2(67, 190), "hold": 0.0, "fx": ""},
			{"tex": "res://art/vine_mage_atk_1.png", "foot": Vector2(44, 108), "hold": 0.14, "fx": "charge", "scale": 1.70},
			{"tex": "res://art/vine_mage_atk_2.png", "foot": Vector2(71, 98), "hold": 0.12, "fx": "", "scale": 1.70},
			{"tex": "res://art/vine_mage_atk_3.png", "foot": Vector2(34, 102), "hold": 0.12, "fx": "", "scale": 1.70},
		],
	},
	"ancient_vine_mage": {
		"hit": 1, "tint": Color(0.50, 1.0, 0.38), "shot": "",
		"frames": [
			{"tex": "res://art/ancient_vine_mage.png", "foot": Vector2(67, 204), "hold": 0.0, "fx": ""},
			{"tex": "res://art/vine_mage_atk_1.png", "foot": Vector2(44, 108), "hold": 0.14, "fx": "charge", "scale": 1.82},
			{"tex": "res://art/vine_mage_atk_2.png", "foot": Vector2(71, 98), "hold": 0.12, "fx": "", "scale": 1.82},
			{"tex": "res://art/vine_mage_atk_3.png", "foot": Vector2(34, 102), "hold": 0.12, "fx": "", "scale": 1.82},
		],
	},

	# The hoplite branch. Three frames only -- stance, throw, recover -- because
	# the spear itself carries the middle of the movement. The blow lands on the
	# throw, and the tiers are told apart by how much gold comes off it.
	"hoplite": {
		"hit": 1, "tint": Color(1.0, 0.86, 0.42), "shot": "",
		"frames": [
			{"tex": "res://art/hoplite_atk_0.png", "foot": Vector2(31, 77), "hold": 0.0, "fx": ""},
			{"tex": "res://art/hoplite_atk_1.png", "foot": Vector2(37, 73), "hold": 0.16, "fx": "throw"},
			{"tex": "res://art/hoplite_atk_2.png", "foot": Vector2(26, 81), "hold": 0.14, "fx": ""},
		],
	},
	"veteran_hoplite": {
		"hit": 1, "tint": Color(1.0, 0.86, 0.42), "shot": "",
		"frames": [
			{"tex": "res://art/veteran_hoplite_atk_0.png", "foot": Vector2(36, 78), "hold": 0.0, "fx": ""},
			{"tex": "res://art/veteran_hoplite_atk_1.png", "foot": Vector2(50, 76), "hold": 0.16, "fx": "throw"},
			{"tex": "res://art/veteran_hoplite_atk_2.png", "foot": Vector2(39, 88), "hold": 0.14, "fx": ""},
		],
	},
	"elite_hoplite": {
		"hit": 1, "tint": Color(1.0, 0.88, 0.45), "shot": "",
		"frames": [
			{"tex": "res://art/elite_hoplite_atk_0.png", "foot": Vector2(59, 86), "hold": 0.0, "fx": ""},
			{"tex": "res://art/elite_hoplite_atk_1.png", "foot": Vector2(54, 77), "hold": 0.17, "fx": "throw"},
			{"tex": "res://art/elite_hoplite_atk_2.png", "foot": Vector2(56, 95), "hold": 0.15, "fx": ""},
		],
	},

	# The shaman branch. These frames are a ritual rather than an attack: the
	# staff comes down, the ground opens, and the totem is what is left standing
	# when it is over. The blow lands on frame 2 -- that is the frame the post
	# comes up on.
	"shaman": {
		"hit": 2, "tint": Color(0.45, 0.92, 0.85), "shot": "",
		"frames": [
			{"tex": "res://art/shaman.png", "foot": Vector2(63, 157), "hold": 0.0, "fx": ""},
			{"tex": "res://art/shaman_atk_1.png", "foot": Vector2(49, 90), "hold": 0.16, "fx": "charge", "scale": 1.28},
			{"tex": "res://art/shaman_atk_2.png", "foot": Vector2(36, 84), "hold": 0.18, "fx": "", "scale": 1.28},
			{"tex": "res://art/shaman_atk_3.png", "foot": Vector2(35, 81), "hold": 0.16, "fx": "", "scale": 1.28},
		],
	},
	"elder_shaman": {
		"hit": 2, "tint": Color(0.40, 0.95, 0.88), "shot": "",
		"frames": [
			{"tex": "res://art/elder_shaman.png", "foot": Vector2(73, 163), "hold": 0.0, "fx": ""},
			{"tex": "res://art/elder_shaman_atk_1.png", "foot": Vector2(49, 89), "hold": 0.16, "fx": "charge", "scale": 1.35},
			{"tex": "res://art/elder_shaman_atk_2.png", "foot": Vector2(34, 92), "hold": 0.18, "fx": "", "scale": 1.35},
			{"tex": "res://art/elder_shaman_atk_3.png", "foot": Vector2(17, 92), "hold": 0.16, "fx": "", "scale": 1.35},
		],
	},
	"great_shaman": {
		"hit": 2, "tint": Color(0.38, 1.0, 0.92), "shot": "",
		"frames": [
			{"tex": "res://art/great_shaman.png", "foot": Vector2(69, 171), "hold": 0.0, "fx": ""},
			{"tex": "res://art/great_shaman_atk_1.png", "foot": Vector2(55, 105), "hold": 0.16, "fx": "charge", "scale": 1.31},
			{"tex": "res://art/great_shaman_atk_2.png", "foot": Vector2(58, 121), "hold": 0.20, "fx": "", "scale": 1.31},
			{"tex": "res://art/great_shaman_atk_3.png", "foot": Vector2(36, 114), "hold": 0.16, "fx": "", "scale": 1.31},
		],
	},

	"archmage": {
		"hit": 2, "tint": Color(0.86, 0.46, 1.0), "shot": "res://art/fx_mage_bolt_l2.png",
		"frames": [
			{"tex": "res://art/archmage.png", "foot": Vector2(110, 325), "hold": 0.0, "fx": "", "lean": 0.0},
			{"tex": "res://art/archmage.png", "foot": Vector2(110, 325), "hold": 0.16, "fx": "raise", "lean": -9.0},
			{"tex": "res://art/archmage_atk.png", "foot": Vector2(213, 319), "hold": 0.20, "fx": "release_big", "lean": 9.0},
			{"tex": "res://art/archmage.png", "foot": Vector2(110, 325), "hold": 0.12, "fx": "", "lean": 3.0},
		],
	},
}

signal died(defender: Defender)

var unit_id: String
var hp: float
var max_hp: float
var damage: float
var attack_interval: float
var attack_range: float
# "melee" blocks the defense line; "ranged" attacks from the backline; "support"
# never attacks at all and works through what it plants.
var role: String = "melee"
var aoe_radius: float = 0.0

# What a support unit puts on the ground, and how fast the ground it lit makes
# everything standing on it.
# What a hoplite throws, what it leaves where the throw lands, and how much
# gold comes off the two together.
var spear_art: String = ""
var impact_art: String = ""
var spear_spark: float = 0.0

# What a vine leaves on whatever it lands on.
var root_time: float = 0.0
var poison_dps: float = 0.0

var totem_art: String = ""
var totem_radius: float = 0.0
var totem_haste: float = 1.0
var totem: Node2D = null
var has_planted: bool = false

# Set by CombatManager each frame from whatever circles this unit is standing
# in: the shaman's totems speed it up, an ice wizard's fields slow it down.
# 1.0 on both means it is standing on plain ground.
var aura_haste: float = 1.0
var aura_slow: float = 1.0

# The gap between blows as it actually is right now, rather than as the unit
# database wrote it down. The two circles multiply rather than one overriding
# the other, so a shaman standing his ground inside a wizard's field claws back
# some of what it takes -- and neither one ever cancels the other outright.
func effective_interval() -> float:
	return attack_interval / maxf(aura_haste * rally_haste * aura_slow, 0.05)
var engaged_enemy: Enemy = null

# Set the moment an approaching enemy picks this unit out, well before it
# arrives, so two of them never walk into the same slot. `engaged_enemy`
# follows only once the walk is finished and the fight actually starts.
var claimed_by: Enemy = null

# How this unit's attack reads: the colour of the stroke it leaves, and the
# colour and size of what it fires. Defaults are plain steel at normal size.
var slash_tint: Color = Color(0.95, 0.97, 1.0)
var shot_tint: Color = Color(1, 1, 1)
var shot_scale: float = 1.0
var shot_sparkle: bool = false

# Which of the four lanes this unit holds. Melee stand on the ring across their
# lane and are the first thing that stops what walks down it; ranged sit behind
# them, inside the ring, safe only for as long as that line survives. A lane is
# open once every unit on it -- of either kind -- is dead.
var lane: int = 0

# Which standing spot on that lane this unit holds. Assigned when the unit is
# dispatched, and changed only when the player picks the unit up and sets it
# down somewhere else -- nothing recomputes it, so nobody is ever placed on top
# of anyone and a gap left by a death stays a gap until something is put in it.
var slot: int = 0

# Off the board in the player's hand. It still holds its lane and its slot --
# picking a soldier up does not open the road he was standing on -- but it takes
# no turn and nothing new squares up against it until it is set back down.
var held: bool = false

var _attack_timer: float = 0.0

var _visual: Node2D = null
var _visual_base_scale: Vector2 = Vector2.ONE
# How much larger than that the frame on screen is drawn -- the "scale" of the
# frame `_show_frame` last put up. The size a body rests at is the two
# multiplied, and everything that owns scale has to swell from that rather than
# from the built size alone.
#
# Until the knight's rear headings, every pose a unit *stood* in was drawn at
# 1.0: only the action frames carried a scale, and those are replaced beat by
# beat while an attack runs, so the built size was also the resting size and the
# breath loop could pull a standing body back to it and be right. A heading
# whose standing frame carries a scale of its own broke that -- the knight
# turned his back, stood at 1.48 for as long as it took the breath to come
# round, and then shrank to 1.0 and stayed there until he swung again.
var _frame_scale: float = 1.0
var _radius: float = 34.0
var _idle_tween: Tween = null
var _shoot_tween: Tween = null

# Resolved attack frames: [{ "tex": Texture2D, "offset": Vector2, "hold": float }].
# Empty for anything without drawn frames, which is what sends those units down
# the old squash-and-swing path instead.
var _frames: Array = []
var _hit_frame: int = 0
var _fx_tint: Color = Color(1, 1, 1)
var _fx_shot: String = ""
var _frame_tween: Tween = null
var _facing: float = 1.0   # +1 drawn as painted, -1 mirrored to face the other way

# The five drawn headings, in DIR_KEYS order, each registered against the same
# foot as the default row so a unit turning stays standing where it stood. Empty
# for every unit whose ANIM entry has no "dirs", and that emptiness is the thing
# that keeps those units on the old mirror-only path.
var _dir_sets: Array = []
var _default_frames: Array = []
var _dir_index: int = -1

func setup(id: String) -> void:
	unit_id = id
	var d: Dictionary = UnitDatabase.get_def(id)
	max_hp = d.get("hp", 100.0)
	damage = d.get("damage", 10.0)
	attack_interval = d.get("attack_interval", 1.0)
	attack_range = d.get("range", 60.0)
	role = d.get("role", "melee")
	aoe_radius = d.get("aoe_radius", 0.0)
	slash_tint = d.get("slash_tint", Color(0.95, 0.97, 1.0))
	shot_tint = d.get("shot_tint", Color(1, 1, 1))
	shot_scale = d.get("shot_scale", 1.0)
	shot_sparkle = d.get("shot_sparkle", false)
	root_time = d.get("root_time", 0.0)
	poison_dps = d.get("poison_dps", 0.0)
	spear_art = String(d.get("spear_art", ""))
	impact_art = String(d.get("impact_art", ""))
	spear_spark = d.get("spear_spark", 0.0)
	totem_art = String(d.get("totem_art", ""))
	totem_radius = d.get("totem_radius", 0.0)
	totem_haste = d.get("totem_haste", 1.0)
	_apply_upgrades(id)
	# Everything above is what this kind of unit is worth; everything this
	# particular body goes on to earn is measured off it. See the experience
	# section below.
	_base_damage = damage
	_base_interval = attack_interval
	_base_range = attack_range
	_base_max_hp = max_hp
	_apply_level(false)
	hp = max_hp
	_build_visual(d)
	# A shaman starts its ritual a beat after it lands rather than the instant
	# it appears, so the walk in and the planting read as two separate things.
	if role == "support":
		_attack_timer = 0.45

func _apply_upgrades(id: String) -> void:
	var m: Dictionary = UpgradeManager.mult
	match id:
		# The hoplites take over the wood line's slot on the ring, so they take
		# over its upgrade cards too rather than stranding them.
		"warrior", "hoplite":
			max_hp *= m.get("warrior_hp", 1.0)
			damage *= m.get("warrior_damage", 1.0)
			attack_interval /= m.get("warrior_aspd", 1.0)
		"veteran_hoplite", "elite_hoplite":
			max_hp *= m.get("knight_hp", 1.0)
			damage *= m.get("knight_damage", 1.0)
		"knight":
			max_hp *= m.get("knight_hp", 1.0)
			damage *= m.get("knight_damage", 1.0)
		# The top tier inherits the tier below it: there are no upgrade cards of
		# its own, and a run that invested in knights should see that investment
		# survive the last merge rather than be thrown away by it.
		"paladin":
			max_hp *= m.get("knight_hp", 1.0)
			damage *= m.get("knight_damage", 1.0)
		"archer":
			damage *= m.get("archer_damage", 1.0)
			attack_interval /= m.get("archer_aspd", 1.0)
			attack_range *= m.get("archer_range", 1.0)
		"master_archer":
			damage *= m.get("master_archer_damage", 1.0)
			attack_range *= m.get("archer_range", 1.0)
		"elite_ranger":
			damage *= m.get("master_archer_damage", 1.0)
			attack_interval /= m.get("archer_aspd", 1.0)
			attack_range *= m.get("archer_range", 1.0)
		"apprentice_mage":
			damage *= m.get("mage_damage", 1.0)
			aoe_radius *= m.get("mage_aoe", 1.0)
			attack_interval /= m.get("mage_aspd", 1.0)
		"mage", "archmage":
			damage *= m.get("mage_damage", 1.0)
			aoe_radius *= m.get("mage_aoe", 1.0)
			attack_interval /= m.get("mage_aspd", 1.0)
	damage *= m.get("defender_damage", 1.0)

# --------------------------------------------------------------- experience
#
# A soldier on the field is not the same soldier as the one standing beside it.
# Every kill is credited to the body that landed it and to nothing else -- not
# to the unit type, not to the branch, not to the player -- so an archer that
# has held the north road since wave three is measurably better than one dropped
# this minute, and selling it costs the player everything it learned.
#
# What grows is what the player can read off its card: what it hits for, how
# fast, how far and how much it can take. Merging still matters more -- a level
# eight archer is not a master archer -- but a unit left standing where it is
# earning its keep is now a decision rather than an oversight.

const MAX_LEVEL := 30

# What one level is worth, as a fraction of that unit's own base stat. Damage
# leads because it is the one the player feels; range trails because a shooter
# that outranges the whole map stops having a position at all.
const LEVEL_DAMAGE := 0.08
const LEVEL_ASPD := 0.04
const LEVEL_RANGE := 0.02
const LEVEL_HP := 0.06

# The merge tier a unit has to be before it has a special at all, and the level
# that unlocks it. A level 2 unit is a stepping stone and is merged away long
# before twenty levels of anything, so the top two tiers are the only ones this
# can ever apply to.
const ABILITY_TIER := 3
const ABILITY_LEVEL := 20

var unit_level: int = 1
var xp: int = 0
var kills: int = 0

# The stats as the database and the run's upgrade cards left them, before this
# body's own levels are counted. Every level recomputes off these rather than
# compounding what is already there -- twenty roundings on top of one another
# land somewhere nobody can predict.
var _base_damage: float = 0.0
var _base_interval: float = 1.0
var _base_range: float = 0.0
var _base_max_hp: float = 1.0

# What the next level costs. Cheap at the start so a fresh unit shows progress
# inside its first wave, and steep enough by the twenties that ABILITY_LEVEL is
# most of a run's work rather than an afternoon's.
static func xp_for_level(level: int) -> int:
	return 2 + level

func xp_to_next() -> int:
	return 0 if is_max_level() else xp_for_level(unit_level)

func is_max_level() -> bool:
	return unit_level >= MAX_LEVEL

# Credited by whatever landed the killing blow; see Enemy.take_damage.
func record_kill(xp_value: int) -> void:
	kills += 1
	gain_xp(xp_value)

func gain_xp(amount: int) -> void:
	if amount <= 0 or hp <= 0.0 or is_max_level():
		return
	xp += amount
	var gained: int = 0
	while not is_max_level() and xp >= xp_for_level(unit_level):
		xp -= xp_for_level(unit_level)
		unit_level += 1
		gained += 1
	if is_max_level():
		xp = 0
	if gained > 0:
		_apply_level()
		_play_level_up()

# Rebuilt from the base stats every time, which is also how a unit arrives at
# the numbers it is created with.
func _apply_level(heal_up: bool = true) -> void:
	var n: float = float(unit_level - 1)
	damage = _base_damage * (1.0 + LEVEL_DAMAGE * n)
	attack_interval = _base_interval / (1.0 + LEVEL_ASPD * n)
	attack_range = _base_range * (1.0 + LEVEL_RANGE * n)
	var grown: float = _base_max_hp * (1.0 + LEVEL_HP * n)
	# A level heals by exactly what it added to the ceiling. Growing the bar and
	# leaving the fill where it was would read as the unit being wounded by its
	# own promotion.
	if heal_up:
		hp = minf(grown, hp + maxf(0.0, grown - max_hp))
	max_hp = grown

func heal(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp = minf(max_hp, hp + amount)

# ---------------------------------------------------------- special ability
#
# The one thing no merge can hand a unit: a blow the player throws by hand.
# Everything about what it does is in UnitDatabase.ABILITY_DEFS; what lives here
# is whether this body has earned it and whether it is off cooldown.
# CombatManager owns what actually happens, because that is where the enemies
# are.

var _ability_timer: float = 0.0

func ability_def() -> Dictionary:
	if int(UnitDatabase.get_def(unit_id).get("level", 0)) < ABILITY_TIER:
		return {}
	return UnitDatabase.get_ability(unit_id)

func has_ability() -> bool:
	return not ability_def().is_empty()

func ability_unlocked() -> bool:
	return has_ability() and unit_level >= ABILITY_LEVEL

func ability_ready() -> bool:
	return ability_unlocked() and _ability_timer <= 0.0 and is_alive() and not held

func ability_cooldown_left() -> float:
	return maxf(0.0, _ability_timer)

func ability_cooldown_total() -> float:
	return float(ability_def().get("cooldown", 20.0))

func start_ability_cooldown() -> void:
	_ability_timer = ability_cooldown_total()

# Ticked by CombatManager along with everything else. It runs while the unit is
# frozen or up in the player's hand as well: the wait is the price of the last
# cast, and standing still is punishment enough on its own.
func tick_ability(delta: float) -> void:
	if _ability_timer > 0.0:
		_ability_timer = maxf(0.0, _ability_timer - delta)

# ------------------------------------------------------------------- rally
#
# A shaman's ability is the only one aimed at our own line, so it is the only
# one that leaves anything behind on a unit. It multiplies rate of attack the
# way a totem's circle does, and it is kept out of `aura_haste` for the same
# reason a totem is kept in it: that field is rewritten from the circles on the
# ground every frame, and anything stored there would be gone by the next one.
var rally_haste: float = 1.0
var rally_timer: float = 0.0

const RALLY_COLOR := Color(0.42, 0.95, 0.85)

func apply_rally(haste: float, seconds: float, heal_fraction: float) -> void:
	if not is_alive():
		return
	rally_haste = maxf(rally_haste, haste)
	rally_timer = maxf(rally_timer, seconds)
	if heal_fraction > 0.0:
		heal(max_hp * heal_fraction)

	# Every unit it reaches lights up briefly. One ring from the shaman would say
	# a rally happened; this is what says who is in it, which is the part the
	# player is deciding about when they press the button.
	var motes := FxUtil.burst(self, 9, 0.45, 40.0, 120.0,
		Color(0.80, 1.0, 0.96, 1.0), Color(RALLY_COLOR.r, RALLY_COLOR.g, RALLY_COLOR.b, 0.0))
	motes.position = Vector2(0, -_radius * 0.3)
	motes.gravity = Vector2(0, -120)
	motes.emitting = true

func tick_rally(delta: float) -> void:
	if rally_timer <= 0.0:
		return
	rally_timer = maxf(0.0, rally_timer - delta)
	if rally_timer <= 0.0:
		rally_haste = 1.0

# ------------------------------------------------------------- promotion fx
#
# Loud enough to be seen from across the field with a fight going on over it,
# short enough that a wave in which four units level does not turn into a light
# show. The same gold as the merge effect: a promotion is the same kind of good
# news as a merge, and it should read as one without a caption.

const LEVEL_UP_COLOR := Color(1.0, 0.86, 0.36)

func _play_level_up() -> void:
	var host: Node = get_parent()
	if host == null or not is_instance_valid(host):
		return

	var ring := Shockwave.new()
	host.add_child(ring)
	ring.global_position = global_position
	ring.color = LEVEL_UP_COLOR
	ring.z_index = 40
	ring.run(_radius * 0.5, _radius * 2.4, 12.0, 2.0, 0.85, 0.5)

	# Upward rather than outward: gravity is inverted so the sparks climb the
	# body instead of falling off it, which is what separates this from a hit.
	var motes := FxUtil.burst(self, 16, 0.6, 60.0, 180.0,
		Color(1.0, 0.96, 0.76, 1.0), Color(1.0, 0.72, 0.24, 0.0))
	motes.position = Vector2(0, -_radius * 0.4)
	motes.gravity = Vector2(0, -150)
	motes.emitting = true

	float_text("LEVEL %d" % unit_level, LEVEL_UP_COLOR)

	if not is_instance_valid(_visual):
		return
	# The body takes a beat of it too. The breath owns scale, so it is stopped
	# for the swell and handed back at the end.
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	var tw := create_tween()
	tw.tween_property(_visual, "scale", _rest_scale() * Vector2(1.22, 1.22), 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "scale", _rest_scale(), 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_start_idle_animation)

# A word thrown up off the unit and left to drift. Parented to the layer rather
# than to the body, because the body can be sold or cut down while it is still
# rising and the word should finish either way.
const FLOAT_TEXT_WIDTH := 300.0

func float_text(text: String, color: Color) -> void:
	var host: Node = get_parent()
	if host == null or not is_instance_valid(host):
		return

	var lbl := Label.new()
	lbl.text = text
	lbl.size = Vector2(FLOAT_TEXT_WIDTH, 60.0)
	lbl.pivot_offset = Vector2(FLOAT_TEXT_WIDTH * 0.5, 30.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 9)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The layer it lands in is y-sorted; a high z puts the word over the fight
	# rather than behind whichever body happens to stand lower on the screen.
	lbl.z_index = 90
	host.add_child(lbl)
	# Nudged sideways at random. Three units on one lane stand 150px apart and a
	# blow that levels all three at once puts three of these up on the same
	# frame; without the jitter they land on top of one another and none of them
	# can be read.
	lbl.global_position = global_position + Vector2(
		-FLOAT_TEXT_WIDTH * 0.5 + randf_range(-40.0, 40.0), -_radius - 78.0)

	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 70.0, 0.95) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "scale", Vector2(1.12, 1.12), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.95) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(lbl.queue_free)

func _build_visual(d: Dictionary) -> void:
	var radius: float = d.get("radius", 34.0)
	_radius = radius
	_build_frames()
	# A unit with drawn frames stands in the first of them, so the pose it holds
	# and the pose it attacks out of are the same drawing.
	var art_path: String = String(_anim_def()["frames"][0]["tex"]) if not _frames.is_empty() \
		else UnitDatabase.get_art_path(unit_id)
	if art_path != "":
		_visual = _build_sprite(art_path, radius)
		# Under the boots, and added before the body so it is drawn beneath it.
		_build_shadow(radius, (_visual as Sprite2D))
		add_child(_visual)
	else:
		var poly := Polygon2D.new()
		poly.polygon = _circle_points(radius, 16)
		poly.color = d.get("color", Color.WHITE)
		# Carries the same material as a drawn body, for the one thing the stand-in
		# still has to be able to do: freeze.
		_lit = Lighting.body_material()
		poly.material = _lit
		add_child(poly)
		_visual = poly

		var label := Label.new()
		label.text = str(d.get("name", "")).left(3)
		label.add_theme_font_size_override("font_size", 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(-radius, -radius)
		label.size = Vector2(radius * 2.0, radius * 2.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

	_visual_base_scale = _visual.scale
	_start_idle_animation()
	# Sampled off the map straight away rather than on the first frame, so a
	# unit is never seen at full brightness before the ground gets to it.
	set_process(true)
	_light_timer = randf() * LIGHT_INTERVAL

# ------------------------------------------------------------------- grounding
#
# Two things tie a unit to the field it is standing on: what it puts on the
# ground (the shadow) and what the ground puts on it (the light). Neither
# existed -- every unit was drawn at full strength over a painting, which is
# most of why they read as stickers laid on the map rather than as bodies in it.

const LIGHT_INTERVAL := 0.22

var _shadow: GroundShadow = null
var _light_timer: float = 0.0
# The material carrying the shape of the light on this body, and the last state
# of the world it was told about. See Lighting.
var _lit: ShaderMaterial = null
var _shade_stamp: int = -1

func _build_shadow(radius: float, sprite: Sprite2D) -> void:
	_shadow = GroundShadow.new()
	_shadow.setup(radius * 0.86,
		Vector2(0, GroundShadow.feet_offset(sprite.texture) * sprite.scale.y))
	add_child(_shadow)

# A unit that never moves still has to be re-lit: the map itself changes when
# winter lands, a green-lit knight standing in the snow is the same fault as
# before only backwards, and the sun goes down over the whole run besides.
func _process(delta: float) -> void:
	_light_timer -= delta
	if _light_timer > 0.0:
		return
	_light_timer = LIGHT_INTERVAL
	# What the ground is doing to it, and then what the hour is: the first is
	# where on the map it stands, the second is how late it has got.
	var tint: Color = Ambient.tint_at(global_position) * Lighting.body_tint()
	modulate = Color(tint.r, tint.g, tint.b, modulate.a)
	if _shadow != null:
		_shadow.set_light(Lighting.shadow_at(global_position))
	# Seven parameters is too many to push at a body that is standing in the
	# same light it was standing in a fifth of a second ago.
	var stamp: int = Lighting.body_stamp(_facing < 0.0)
	if stamp != _shade_stamp:
		_shade_stamp = stamp
		Lighting.tune_body(_lit, _facing < 0.0)

# Registers every frame on the first one. The first frame is drawn centred on
# the node, exactly where a single-frame unit sits, so a unit that gains frames
# does not move; the rest are offset by however far their stance centre differs
# from that, which is what keeps the feet planted while the arms work.
# Tiers that share another's drawn frames. The vine sheet draws the cast once
# and all three mages perform it; they are told apart by size and by what the
# vine does after it lands.
func _anim_def() -> Dictionary:
	return ANIM.get(unit_id, {})

func _build_frames() -> void:
	var def: Dictionary = _anim_def()
	if def.is_empty():
		return
	_hit_frame = int(def["hit"])
	_fx_tint = def["tint"]
	_fx_shot = String(def["shot"])

	var list: Array = def["frames"]
	var base: Texture2D = load(String(list[0]["tex"]))
	var base_size: Vector2 = base.get_size()
	var base_foot: Vector2 = list[0]["foot"]
	# Where the first frame's centre sits, measured from its own stance centre.
	var from_foot: Vector2 = base_size * 0.5 - base_foot

	_frames = _register(list, from_foot)
	_default_frames = _frames

	# Every heading registers against the default row's foot rather than against
	# its own first frame. Re-registering per heading would leave each row with
	# its own idea of where the ground is, and the unit would hop sideways the
	# moment it turned -- which is the one thing the foot anchors exist to stop.
	var dirs: Dictionary = def.get("dirs", {})
	if dirs.is_empty():
		return
	for key in DIR_KEYS:
		var rows: Array = dirs.get(key, [])
		# A heading that is missing, or that draws a different number of beats
		# than the default row, falls back to that row. The counts have to match
		# because "hit" -- the beat the blow lands on -- is one number for the
		# whole unit: a short row would run past it and the attack would play
		# through without ever dealing its damage.
		if rows.size() != list.size():
			if not rows.is_empty():
				push_warning("%s: heading '%s' has %d frames, default row has %d -- heading skipped"
					% [unit_id, key, rows.size(), list.size()])
			_dir_sets.append(_default_frames)
		else:
			_dir_sets.append(_register(rows, from_foot))

func _register(list: Array, from_foot: Vector2) -> Array:
	var out: Array = []
	for f in list:
		var tex: Texture2D = load(String(f["tex"]))
		# "scale" draws a frame larger than the one it is registered against.
		# Some sheets draw the standing portrait big and the action poses small;
		# without this a unit shrinks the moment it does anything. Dividing the
		# registration by it keeps the feet planted while the body grows.
		var k: float = maxf(float(f.get("scale", 1.0)), 0.01)
		var anchor: Vector2 = (f["foot"] as Vector2) + from_foot / k
		out.append({
			"tex": tex,
			"offset": tex.get_size() * 0.5 - anchor,
			"scale": k,
			"hold": float(f["hold"]),
			"fx": String(f["fx"]),
			"lean": float(f.get("lean", 0.0)),
		})
	return out

# --------------------------------------------------------------------- headings
#
# Where a unit stands is which way it is drawn. Every defender holds a spot on
# the ring, so the vector out from the fortress is also the way it is looking,
# and Main.gd already hands that vector over on both the drop and the carry
# (`d.set_facing(d.global_position - ARENA_CENTER)`). An attack overrides it for
# as long as the swing lasts with the line to whatever is being hit, which is
# what turns a unit to meet something that came in off its lane.
#
# Eight headings, five drawings. West is east mirrored and the two off-axis
# pairs mirror the same way, so the art never has to draw the left-hand half of
# the compass -- and the mirror is the flip the unit already had.
#
#           6 N
#      5 NW  |  7 NE
#     4 W ---+--- 0 E
#      3 SW  |  1 SE
#           2 S
const DIR_KEYS := ["e", "se", "s", "ne", "n"]
#                    E   SE    S   SW    W   NW    N   NE
const DIR_SET  := [   0,   1,   2,   1,   0,   3,   4,   3]
const DIR_FLIP := [ 1.0, 1.0, 1.0,-1.0,-1.0,-1.0, 1.0, 1.0]

# Which of the eight a vector points at. Screen space, so +y is south and the
# ring runs clockwise from east.
static func heading_of(v: Vector2) -> int:
	return int(round(v.angle() / (PI / 4.0))) & 7

# Which way the unit is drawn.
#
# With no directional art this is the old rule and the only one a body painted
# from a single camera can follow: the frames are painted facing right, so a
# unit holding the west lane is mirrored, offsets included, or its sword ends up
# swinging at the fortress behind it.
#
# With directional art the heading picks the row and the mirror both, and the
# row is swapped into `_frames` so everything downstream -- the attack tween,
# the frame effects, the held pose -- goes on reading one array and never has to
# know a unit can turn.
func set_facing(dir: Vector2) -> void:
	if _dir_sets.is_empty():
		if absf(dir.x) < 0.001:
			return
		_facing = 1.0 if dir.x >= 0.0 else -1.0
		if _visual is Sprite2D:
			(_visual as Sprite2D).flip_h = _facing < 0.0
			_show_frame(0)
		return

	# A zero vector has no angle to read, and it turns up whenever something asks
	# a unit to face the point it is already standing on.
	if dir.length_squared() < 0.000001:
		return
	var slot: int = heading_of(dir)
	var set_index: int = DIR_SET[slot]
	var want_facing: float = DIR_FLIP[slot]
	if set_index == _dir_index and want_facing == _facing:
		return
	_dir_index = set_index
	_facing = want_facing
	_frames = _dir_sets[set_index]
	if _visual is Sprite2D:
		(_visual as Sprite2D).flip_h = _facing < 0.0
		_show_frame(0)

func _show_frame(i: int) -> void:
	if not (_visual is Sprite2D) or i < 0 or i >= _frames.size():
		return
	var f: Dictionary = _frames[i]
	var sprite := _visual as Sprite2D
	sprite.texture = f["tex"]
	var off: Vector2 = f["offset"]
	sprite.offset = Vector2(off.x * _facing, off.y)
	var k: float = float(f["scale"])
	if k != _frame_scale:
		_frame_scale = k
		# The breath was built around the size of the frame that was up when it
		# started, and it would drag the body back to that one. It runs only while
		# a unit is standing, which is exactly when a turn can land on it, so this
		# is where a heading drawn at a different size gets it rebuilt.
		if _idle_tween != null and _idle_tween.is_valid():
			_start_idle_animation()
	sprite.scale = _rest_scale()
	# The idle loop owns scale and nothing else touches position while frames
	# are running, so the lean can live here rather than in a tween of its own.
	sprite.position = Vector2(float(f["lean"]) * _facing, 0.0)

# ------------------------------------------------------------------ animation

# The size the body sits at with nothing playing: what it was built at, times
# what the frame it is standing in is drawn at. Every swell and squash below is
# measured off this rather than off `_visual_base_scale`, so that a frame drawn
# larger than the sheet it was registered against keeps that through the breath,
# the swing, the shot and the carry.
func _rest_scale() -> Vector2:
	return _visual_base_scale * _frame_scale

func _start_idle_animation() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	var rest: Vector2 = _rest_scale()
	_idle_tween = create_tween()
	_idle_tween.set_loops()
	_idle_tween.tween_property(_visual, "scale", rest * Vector2(1.05, 0.95), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(_visual, "scale", rest * Vector2(0.95, 1.05), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(_visual, "scale", rest, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# One entry point for both kinds of attack. A unit with drawn frames plays them;
# everything else falls back to the procedural swing or draw. Either way `on_hit`
# is called on the beat the blow lands -- immediately for the procedural ones,
# and on the drawn contact frame for the rest.
func play_attack(aim: Vector2, on_hit: Callable) -> void:
	set_facing(aim)
	if _frames.is_empty():
		if role == "melee":
			play_melee_swing(aim)
		elif role == "ranged":
			play_shoot_animation(aim)
		if on_hit.is_valid():
			on_hit.call()
		return

	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	# The looping idle owns scale; leave it running and the two fight over it.
	_visual.scale = _rest_scale()

	var dir: Vector2 = aim.normalized()
	_frame_tween = create_tween()
	for i in range(1, _frames.size()):
		_frame_tween.tween_callback(_enter_frame.bind(i, dir, on_hit))
		_frame_tween.tween_interval(float(_frames[i]["hold"]))
	_frame_tween.tween_callback(_show_frame.bind(0))
	_frame_tween.tween_callback(_start_idle_animation)

func _enter_frame(i: int, dir: Vector2, on_hit: Callable) -> void:
	_show_frame(i)
	_frame_fx(i, dir)
	if i == _hit_frame and on_hit.is_valid():
		on_hit.call()

# ------------------------------------------------------------- frame effects
#
# The frames carry the pose and, for the warrior, the sword's own arc. What they
# cannot carry is the light: the glow gathering on a nocked arrowhead, the flare
# off a staff, the sparks a blade throws as it comes through. Those are hung on
# the frames here, one hook per frame that needs one.

# Out in front at about chest height. The blade, the bowstring and the staff
# head are in slightly different places frame to frame, but at this size one
# point in front of the body reads as all three.
func _weapon_point(dir: Vector2) -> Vector2:
	return dir * (_radius * 1.05) + Vector2(0, -_radius * 0.5)

func _frame_fx(i: int, dir: Vector2) -> void:
	match String(_frames[i]["fx"]):
		"swing":
			_swing_sparks(_weapon_point(dir), dir)
		"swing_big":
			_swing_big(_weapon_point(dir), dir)
		"dust":
			_foot_dust(dir)
		"charge":
			_charge_glow(_weapon_point(dir), _fx_tint, 0.30)
		"raise":
			# Overhead, where the staff actually is on the wind-up.
			_charge_glow(Vector2(-dir.x * _radius * 0.3, -_radius * 1.5), _fx_tint, 0.44)
		"release":
			_release_streak(_weapon_point(dir), dir, _fx_shot, _fx_tint)
		"release_big":
			_release_big(_weapon_point(dir), dir)
		"throw":
			_throw_spear(dir)

func _swing_sparks(at: Vector2, dir: Vector2) -> void:
	var sparks := FxUtil.burst(self, 9, 0.26, 140.0, 300.0,
		Color(_fx_tint.r, _fx_tint.g, _fx_tint.b, 1.0),
		Color(_fx_tint.r * 0.75, _fx_tint.g * 0.8, _fx_tint.b, 0.0))
	sparks.position = at
	sparks.direction = dir
	sparks.spread = 44.0
	sparks.gravity = Vector2(0, 260)
	sparks.emitting = true

	var glint := FxUtil.bloom(self, 0.08, 0.9, _fx_tint, 64)
	glint.position = at
	var t := create_tween()
	t.tween_property(glint, "scale", Vector2.ONE * 0.34, 0.12) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(glint, "modulate:a", 0.0, 0.14)
	t.tween_callback(glint.queue_free)

	# The glint above is a light drawn on the picture; this is the same light
	# falling on the bodies standing around the blow. In daylight it comes to
	# nothing, which is correct -- a struck spark lights nothing at noon.
	Lighting.flash(self, to_global(at), _fx_tint, 0.60, 130.0, 0.15)

# Parented to our host rather than to us: the shaft is still in the air well
# after the frame that threw it, and often after the thrower has been cut down.
func _throw_spear(dir: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var shot := SpearShot.new()
	host.add_child(shot)
	shot.global_position = global_position + Vector2(0, -_radius * 0.45)
	# Far enough to reach the rank it is fighting: the two lines stand about a
	# body and a half apart.
	shot.play(dir, _radius * 3.1, spear_art, impact_art, spear_spark,
		clampf(_radius / 44.0, 0.85, 1.6))

# The level 3 stroke. Everything the ordinary swing throws off, and then a flare
# on the blade, a ring off the arc and embers hanging in the air behind it -- a
# paladin's blow is supposed to be the thing you look at.
func _swing_big(at: Vector2, dir: Vector2) -> void:
	_swing_sparks(at, dir)

	var flare := FxUtil.bloom(self, 0.10, 0.0, _fx_tint, 128)
	flare.position = at
	var t := create_tween()
	t.tween_property(flare, "modulate:a", 0.95, 0.05)
	t.parallel().tween_property(flare, "scale", Vector2.ONE * 0.78, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(flare, "modulate:a", 0.0, 0.16)
	t.tween_callback(flare.queue_free)

	var ring := Shockwave.new()
	ring.color = _fx_tint
	add_child(ring)
	ring.position = at
	ring.run(6.0, 82.0, 10.0, 1.0, 0.85, 0.30)

	# A paladin's blow is supposed to be the thing you look at, and after dark
	# the surest way to make it so is to let it light the rank it lands in.
	Lighting.flash(self, to_global(at), _fx_tint, 1.30, 240.0, 0.26)

	# Embers: slow, barely falling, and still glowing after the stroke is gone.
	var embers := FxUtil.burst(self, 12, 0.55, 40.0, 160.0,
		Color(_fx_tint.r, _fx_tint.g, _fx_tint.b, 1.0),
		Color(_fx_tint.r, _fx_tint.g * 0.55, 0.15, 0.0))
	embers.position = at
	embers.direction = dir
	embers.spread = 110.0
	embers.gravity = Vector2(0, -30)
	embers.damping_min = 60.0
	embers.damping_max = 120.0
	embers.scale_amount_curve = FxUtil.swell_curve()
	embers.emitting = true

# The level 3 shot leaving the weapon: the ordinary streak, a flash at the
# release, and a tight spray running straight down the line of the shot so the
# eye is pulled after it rather than left at the shooter.
func _release_big(at: Vector2, dir: Vector2) -> void:
	_release_streak(at, dir, _fx_shot, _fx_tint)

	var flash := FxUtil.bloom(self, 0.08, 0.95, _fx_tint, 96)
	flash.position = at
	var t := create_tween()
	t.tween_property(flash, "scale", Vector2.ONE * 0.58, 0.17) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(flash, "modulate:a", 0.0, 0.17)
	t.tween_callback(flash.queue_free)

	var line := FxUtil.burst(self, 14, 0.4, 130.0, 300.0,
		Color(1, 1, 1, 1.0), Color(_fx_tint.r, _fx_tint.g, _fx_tint.b, 0.0))
	line.position = at
	line.direction = dir
	line.spread = 16.0
	line.gravity = Vector2.ZERO
	line.damping_min = 140.0
	line.damping_max = 260.0
	line.scale_amount_min = 1.6
	line.scale_amount_max = 3.4
	line.emitting = true

# Kicked up by the lunge on the follow-through, so the weight of the step lands
# somewhere instead of the body simply sliding forward.
func _foot_dust(dir: Vector2) -> void:
	var dust := FxUtil.burst(self, 7, 0.34, 40.0, 120.0,
		Color(0.86, 0.80, 0.68, 0.85), Color(0.55, 0.48, 0.40, 0.0), false)
	dust.position = Vector2(dir.x * _radius * 0.4, _radius * 0.7)
	dust.direction = Vector2(signf(dir.x), -0.4)
	dust.spread = 32.0
	dust.gravity = Vector2(0, 220)
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.2
	dust.emitting = true

# Light gathering on the shot before it goes: swells through the draw and is
# still burning as the release frame takes over from it.
func _charge_glow(at: Vector2, tint: Color, size: float) -> void:
	var glow := FxUtil.bloom(self, 0.04, 0.0, tint, 96)
	glow.position = at
	var t := create_tween()
	t.tween_property(glow, "modulate:a", 0.85, 0.10)
	t.parallel().tween_property(glow, "scale", Vector2.ONE * size, 0.17) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(glow, "modulate:a", 0.0, 0.13)
	t.tween_callback(glow.queue_free)

# The sheet's own shot art, used as the flash of the thing leaving the weapon --
# the projectile itself is a separate node that flies to the target.
func _release_streak(at: Vector2, dir: Vector2, tex_path: String, tint: Color) -> void:
	# The shot leaving the weapon is the brightest instant of a ranged unit's
	# whole cycle, and after dark it is the only one that lights the archer.
	Lighting.flash(self, to_global(at), tint, 0.80, 165.0, 0.14)
	if tex_path != "":
		var streak := FxUtil.glow(self, load(tex_path), 0.26, 0.95)
		streak.position = at
		streak.rotation = dir.angle()
		var t := create_tween()
		t.tween_property(streak, "position", at + dir * (_radius * 0.9), 0.13) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(streak, "scale", Vector2.ONE * 0.36, 0.13)
		t.parallel().tween_property(streak, "modulate:a", 0.0, 0.13)
		t.tween_callback(streak.queue_free)

	var motes := FxUtil.burst(self, 8, 0.28, 60.0, 170.0,
		tint, Color(tint.r, tint.g, tint.b, 0.0))
	motes.position = at
	motes.direction = dir
	motes.spread = 55.0
	motes.gravity = Vector2(0, 120)
	motes.emitting = true

func _play_attack_animation() -> void:
	if not is_instance_valid(_visual):
		return
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	var tw := create_tween()
	tw.tween_property(_visual, "scale", _rest_scale() * Vector2(1.3, 0.75), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "scale", _rest_scale(), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_start_idle_animation)

# A sword stroke, aimed at whatever is being fought. The blade is painted into
# the sprite, so the swing is the body turning back and driving through the
# blow, with the arc landing on the beat the damage does.
const SWING_BACK := 0.34
const SWING_THROUGH := 0.46

func play_melee_swing(dir: Vector2) -> void:
	if not is_instance_valid(_visual):
		return
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	if _shoot_tween != null and _shoot_tween.is_valid():
		_shoot_tween.kill()

	var aim: Vector2 = dir.normalized()

	var tw := create_tween()
	tw.tween_property(_visual, "rotation", -SWING_BACK, 0.11) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_visual, "position", aim * -6.0, 0.11)
	tw.parallel().tween_property(_visual, "scale",
		_rest_scale() * Vector2(0.94, 1.06), 0.11)

	tw.tween_property(_visual, "rotation", SWING_THROUGH, 0.07) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_visual, "position", aim * 12.0, 0.07) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_visual, "scale",
		_rest_scale() * Vector2(1.14, 0.88), 0.07)

	tw.tween_callback(_spawn_slash.bind(aim))

	tw.tween_property(_visual, "rotation", 0.0, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_visual, "position", Vector2.ZERO, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_visual, "scale", _rest_scale(), 0.2)
	tw.tween_callback(_start_idle_animation)

func _spawn_slash(aim: Vector2) -> void:
	var arc := SlashArc.new()
	add_child(arc)
	arc.position = Vector2(0, -_radius * 0.35)
	arc.play(aim, _radius * 1.3, 1.9, slash_tint, 10.0)

# Draw and release: the shooter leans back against the shot, snaps forward as
# it goes, then settles. Aimed along the shot so a defender visibly turns its
# weight toward whatever it is firing at.
func play_shoot_animation(dir: Vector2) -> void:
	if not is_instance_valid(_visual):
		return
	if _shoot_tween != null and _shoot_tween.is_valid():
		_shoot_tween.kill()
	# The looping idle also owns scale; leave it running and the two fight.
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()

	var aim: Vector2 = dir.normalized()
	_shoot_tween = create_tween()
	_shoot_tween.tween_property(_visual, "position", aim * -7.0, 0.13) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shoot_tween.parallel().tween_property(_visual, "scale",
		_rest_scale() * Vector2(0.92, 1.08), 0.13)
	_shoot_tween.tween_property(_visual, "position", aim * 9.0, 0.06) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_shoot_tween.parallel().tween_property(_visual, "scale",
		_rest_scale() * Vector2(1.12, 0.90), 0.06)
	_shoot_tween.tween_property(_visual, "position", Vector2.ZERO, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shoot_tween.parallel().tween_property(_visual, "scale", _rest_scale(), 0.18)
	_shoot_tween.tween_callback(_start_idle_animation)

func _play_hit_flash() -> void:
	if not is_instance_valid(_visual):
		return
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", Color(1, 0.4, 0.4), 0.08)
	tw.tween_property(_visual, "modulate", Color(1, 1, 1), 0.15)

# ------------------------------------------------------------------- frozen
#
# What an ice wolf's charge leaves behind. A frozen unit is still standing, still
# in its slot, and still worth killing -- it simply cannot act -- so this is a
# timer and a look rather than a state of its own. CombatManager ticks it, and
# skipping the unit's turn while it runs is the whole of the mechanic.
#
# Stopping the idle breathing is most of what sells it: that loop is the clearest
# sign a unit is alive, and a body that has gone still and blue reads as iced
# before the player has read anything else on the screen.
#
# The blue is a tint and not a modulate. Modulate can only multiply, and gold
# armour multiplied by ice blue comes out green -- a frozen hoplite went olive
# rather than cold. This blends the pixel toward the tint instead, and keeps the
# pixel's own brightness while doing it, so highlights stay bright, shadows stay
# dark, and every unit freezes the same colour whatever it is painted.

const FROZEN_TINT := Color(0.42, 0.68, 1.0)
const FROZEN_AMOUNT := 0.82

# The ice itself is two lines inside the shader every body already carries (see
# Lighting.BODY_SHADER). It used to be a shader of its own, swapped in over the
# top -- which worked until there was anything else on a body worth keeping, and
# a frozen soldier lost the light on him along with the ability to move.

var frozen_timer: float = 0.0

func is_frozen() -> bool:
	return frozen_timer > 0.0

# Re-applied rather than stacked, exactly as a vine is on an enemy: a second
# charge into the same soldier renews the hold instead of compounding it.
func freeze(seconds: float) -> void:
	if seconds <= 0.0 or hp <= 0.0:
		return
	var already: bool = is_frozen()
	frozen_timer = maxf(frozen_timer, seconds)
	if already:
		return

	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	_show_frame(0)

	if not is_instance_valid(_visual):
		return
	# Left in the pose it was caught in, at rest: the frame tween above is gone,
	# so nothing else is going to put the body back where it belongs.
	_visual.scale = _rest_scale()
	_visual.position = Vector2.ZERO

	if _lit == null:
		return
	var mat: ShaderMaterial = _lit
	mat.set_shader_parameter("ice", FROZEN_TINT)
	# Runs in rather than snapping on, quickly enough to still read as the blow
	# landing rather than as weather setting in.
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("ice_amount", v), 0.0, FROZEN_AMOUNT, 0.14)

# Returns true while the unit is still iced, which is also what tells the caller
# to skip its turn.
func tick_frozen(delta: float) -> bool:
	if frozen_timer <= 0.0:
		return false
	frozen_timer = maxf(0.0, frozen_timer - delta)
	if frozen_timer > 0.0:
		return true
	_thaw()
	return false

func _thaw() -> void:
	if _lit != null:
		# Dropped rather than faded: the shatter below is what carries the moment,
		# and a slow bleed back to normal colour reads as the unit recovering
		# instead of the ice breaking.
		_lit.set_shader_parameter("ice_amount", 0.0)
	if hp <= 0.0:
		return
	# The ice comes off rather than fading out, so the moment the unit is back in
	# the fight is a moment the player can see.
	var shards := FxUtil.burst(self, 10, 0.34, 70.0, 210.0,
		Color(0.86, 0.96, 1.0, 1.0), Color(0.35, 0.62, 0.95, 0.0))
	shards.position = Vector2(0, -_radius * 0.3)
	shards.emitting = true
	_start_idle_animation()

const SPRITE_VISUAL_SCALE := 1.3 # art renders relative to the physics collision circle for readability

func _build_sprite(art_path: String, radius: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(art_path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex_size: Vector2 = sprite.texture.get_size()
	var target_diameter := radius * 2.0 * SPRITE_VISUAL_SCALE
	var scale_factor: float = target_diameter / max(tex_size.x, tex_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	# Everything a flat drawing cannot do for itself: a lit side and a shaded
	# one, an edge that catches the light, boots that sit in shadow -- and the
	# ice, which lives in the same shader so that freezing a body no longer
	# means throwing away the light on it. Bodies are the only things in the
	# game a real light is allowed to touch, which is what the layer says.
	_lit = Lighting.body_material()
	sprite.material = _lit
	sprite.light_mask = Lighting.BODY_LAYER
	return sprite

func _circle_points(r: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a := TAU * i / segs
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

# ------------------------------------------------------- picked up and sold
#
# What the player can do to a unit that is already standing on the field: take
# hold of it and put it down somewhere else, or take it off the board for gold.
# Both are driven from Main, which owns the lanes and the money; everything here
# is what the unit itself has to do about it.

# How far from its middle a tap still counts as landing on this unit. Generously
# wider than the body -- these are thumbs on a phone, and the alternative to a
# forgiving target is a player who taps a soldier three times and gives up. The
# floor matters most for the small level 2 units, which are barely 76px across.
const TAP_MIN_RADIUS := 52.0

func tap_radius() -> float:
	return maxf(_radius * 1.2, TAP_MIN_RADIUS)

# Off the ground and into the hand: the body comes up, grows a little, and its
# shadow spreads and pales underneath it the way GroundShadow was built to. The
# idle breath is stopped for the duration -- it owns scale, and the two would
# fight over it -- and started again on the way down.
const HELD_LIFT := 16.0
const HELD_SWELL := 1.12
const HELD_Z := 60

func lift() -> void:
	if not is_instance_valid(_visual):
		return
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	_show_frame(0)
	z_index = HELD_Z

	var tw := create_tween()
	tw.tween_property(_visual, "scale", _rest_scale() * HELD_SWELL, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_visual, "position:y", -HELD_LIFT, 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _shadow != null and is_instance_valid(_shadow):
		tw.parallel().tween_method(_shadow.set_lift, 0.0, 1.0, 0.14)

func settle() -> void:
	if not is_instance_valid(_visual):
		return
	z_index = 0
	var tw := create_tween()
	tw.tween_property(_visual, "position:y", 0.0, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _shadow != null and is_instance_valid(_shadow):
		tw.parallel().tween_method(_shadow.set_lift, 1.0, 0.0, 0.16)
	# The landing squash, and only then is the breath handed back its scale.
	tw.tween_property(_visual, "scale",
		_rest_scale() * Vector2(1.14, 0.86), 0.07)
	tw.tween_callback(_start_idle_animation)

# Taken off the field by the player rather than cut down on it. It leaves by the
# same door a death does -- the signal is what unhooks it from its lane, from
# whatever was fighting it and from the totem it planted -- but it goes out on
# gold rather than on a collapse, so a sale never reads as a unit being lost.
#
# The coins themselves are Main's business: it knows what the unit was worth and
# where the counter is. All that happens here is the body coming apart.
func sell() -> void:
	if hp <= 0:
		return
	hp = 0.0
	held = false
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	died.emit(self)

	# Parented to the field rather than to the body, which is about to be gone --
	# and so, unlike the sparks a swing throws off, it has to take itself off that
	# field again or every sale leaves a spent emitter behind for the whole run.
	var host: Node = get_parent()
	if host != null:
		var gold := FxUtil.burst(host, 14, 0.42, 90.0, 260.0,
			Color(1.0, 0.90, 0.52, 1.0), Color(0.95, 0.62, 0.18, 0.0))
		gold.global_position = global_position + Vector2(0, -_radius * 0.4)
		gold.gravity = Vector2(0, 320)
		gold.scale_amount_curve = FxUtil.swell_curve()
		gold.emitting = true
		var life := gold.create_tween()
		life.tween_interval(gold.lifetime + 0.2)
		life.tween_callback(gold.queue_free)

	# Up and away rather than down and out: a death sinks, and this is the one
	# exit from the field the player asked for.
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 26.0, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(queue_free)

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: float) -> void:
	if hp <= 0:
		return
	hp = max(0.0, hp - amount)
	if hp <= 0:
		if _idle_tween != null and _idle_tween.is_valid():
			_idle_tween.kill()
		died.emit(self)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)
	else:
		_play_hit_flash()

func process_combat(delta: float) -> void:
	if engaged_enemy != null \
			and (not is_instance_valid(engaged_enemy) or not engaged_enemy.is_alive()):
		engaged_enemy = null

	# Normally a soldier swings at whatever squared up against it. A body the
	# player has picked out overrides that for as long as it is inside this
	# unit's reach -- which is the whole of what focusing can do for somebody who
	# cannot leave the slot he is holding.
	var target: Enemy = CombatManager.focus_within(self)
	if target == null:
		target = engaged_enemy
	if target == null:
		return

	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	_attack_timer = effective_interval()
	# Held onto across the blow: a killing hit runs the enemy's death signal
	# before take_damage returns, and that clears `engaged_enemy` out from
	# under us. The swing still has to be aimed at whatever was just hit.
	var hit: Enemy = target
	# The damage lands on the contact frame, which is a beat after the swing
	# starts -- so whether the target is still there is a question that has
	# to be asked then, not now.
	play_attack(hit.global_position - global_position, func() -> void:
		if is_instance_valid(hit) and hit.is_alive():
			hit.take_damage(damage, global_position, false, self))
