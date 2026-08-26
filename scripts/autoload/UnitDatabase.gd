extends Node

# Data-driven definitions for merge branches and enemies.
# New branches/levels/enemies can be added here without touching gameplay code.

const DEFS := {
	# --- Branch A: Wood / Warrior (melee, frontline) ---
	"wood": {
		"branch": "wood", "level": 1, "name": "WOOD", "is_unit": false,
		"merge_into": "warrior", "radius": 34.0, "color": Color(0.55, 0.35, 0.15),
	},
	"warrior": {
		"branch": "wood", "level": 2, "name": "WARRIOR", "is_unit": true, "role": "melee",
		"merge_into": "knight", "radius": 42.0, "color": Color(0.75, 0.75, 0.8),
		"hp": 135.0, "damage": 15.0, "attack_interval": 1.2, "range": 95.0, "aoe_radius": 0.0,
	},
	# "slash_tint" colours the stroke a melee unit leaves; "shot_tint" and
	# "shot_scale" do the same for what a ranged one fires. Left out means
	# plain steel at normal size.
	"knight": {
		"branch": "wood", "level": 3, "name": "KNIGHT", "is_unit": true, "role": "melee",
		"merge_into": "paladin", "radius": 50.0, "color": Color(0.85, 0.7, 0.2),
		"hp": 290.0, "damage": 30.0, "attack_interval": 1.4, "range": 110.0, "aoe_radius": 0.0,
		"slash_tint": Color(1.0, 0.93, 0.62),
	},
	# Top of the branch. Two knights' worth of wall and rather more than two
	# knights' worth of blade -- the last merge in a branch has to feel like the
	# reward for six pieces, not like one more step.
	"paladin": {
		"branch": "wood", "level": 4, "name": "PALADIN", "is_unit": true, "role": "melee",
		"merge_into": "", "radius": 58.0, "color": Color(0.98, 0.82, 0.30),
		"hp": 620.0, "damage": 66.0, "attack_interval": 1.3, "range": 125.0, "aoe_radius": 0.0,
		"slash_tint": Color(1.0, 0.84, 0.35),
	},

	# --- Branch B: Bow / Archer (ranged, backline) ---
	"bow": {
		"branch": "bow", "level": 1, "name": "BOW", "is_unit": false,
		"merge_into": "archer", "radius": 30.0, "color": Color(0.4, 0.3, 0.15),
	},
	"archer": {
		"branch": "bow", "level": 2, "name": "ARCHER", "is_unit": true, "role": "ranged",
		"merge_into": "master_archer", "radius": 38.0, "color": Color(0.3, 0.6, 0.35),
		"hp": 55.0, "damage": 14.0, "attack_interval": 0.8, "range": 380.0, "aoe_radius": 0.0,
	},
	"master_archer": {
		"branch": "bow", "level": 3, "name": "MASTER ARCHER", "is_unit": true, "role": "ranged",
		"merge_into": "elite_ranger", "radius": 44.0, "color": Color(0.2, 0.75, 0.4),
		"hp": 90.0, "damage": 28.0, "attack_interval": 0.7, "range": 440.0, "aoe_radius": 0.0,
		"shot_tint": Color(0.70, 1.0, 0.76), "shot_scale": 1.15,
	},
	"elite_ranger": {
		"branch": "bow", "level": 4, "name": "ELITE RANGER", "is_unit": true, "role": "ranged",
		"merge_into": "", "radius": 50.0, "color": Color(0.45, 0.95, 0.35),
		"hp": 140.0, "damage": 58.0, "attack_interval": 0.6, "range": 500.0, "aoe_radius": 0.0,
		"shot_tint": Color(0.62, 1.0, 0.42), "shot_scale": 1.45,
	},

	# --- Branch C: Crystal / Mage (ranged, backline, AoE) ---
	"crystal": {
		"branch": "crystal", "level": 1, "name": "CRYSTAL", "is_unit": false,
		"merge_into": "apprentice_mage", "radius": 30.0, "color": Color(0.4, 0.55, 0.9),
	},
	"apprentice_mage": {
		"branch": "crystal", "level": 2, "name": "APPR. MAGE", "is_unit": true, "role": "ranged",
		"merge_into": "mage", "radius": 38.0, "color": Color(0.5, 0.4, 0.9),
		"hp": 45.0, "damage": 18.0, "attack_interval": 2.0, "range": 290.0, "aoe_radius": 60.0,
		"shot_scale": 1.45,
	},
	# Kept above the apprentice's: the level 3 bolt should never look like the
	# smaller spell of the two.
	"mage": {
		"branch": "crystal", "level": 3, "name": "MAGE", "is_unit": true, "role": "ranged",
		"merge_into": "archmage", "radius": 44.0, "color": Color(0.7, 0.3, 0.9),
		"hp": 75.0, "damage": 40.0, "attack_interval": 2.2, "range": 330.0, "aoe_radius": 100.0,
		"shot_scale": 1.75,
	},
	# "shot_sparkle" gives the orb a trail of violet motes shed in world space,
	# so an archmage's bolt is recognisable from across the arena before it
	# lands rather than only when it does.
	"archmage": {
		"branch": "crystal", "level": 4, "name": "ARCHMAGE", "is_unit": true, "role": "ranged",
		"merge_into": "", "radius": 50.0, "color": Color(0.80, 0.40, 1.0),
		"hp": 120.0, "damage": 82.0, "attack_interval": 2.0, "range": 380.0, "aoe_radius": 135.0,
		"shot_tint": Color(0.86, 0.48, 1.0), "shot_scale": 2.1, "shot_sparkle": true,
	},

	# --- The upgraded materials ---
	#
	# From wave 20 the tray stops dropping wood, bows and crystals and starts
	# dropping these instead; see SpawnManager.MATERIAL_UPGRADED. Gold and
	# emerald bring lines of their own: gold grows hoplites where the wood line
	# grew warriors, emerald grows vine mages where the bow line grew archers,
	# and the totem replaces the crystal outright and grows shamans.
	"gold": {
		"branch": "wood", "level": 1, "name": "GOLD", "is_unit": false,
		"merge_into": "hoplite", "radius": 34.0, "color": Color(0.95, 0.76, 0.25),
	},
	"emerald": {
		"branch": "bow", "level": 1, "name": "EMERALD", "is_unit": false,
		"merge_into": "vine_mage", "radius": 30.0, "color": Color(0.30, 0.88, 0.45),
	},

	# --- Emerald's line: Vine mages (ranged, backline) ---
	#
	# They take the bow line's place on the inner ring but they are not really
	# shooters: the vine that lands does very little on impact and everything
	# afterwards. "root_time" is how long whatever it hits cannot move and
	# "poison_dps" how fast it rots; the rot runs for the hold plus
	# Enemy.POISON_TAIL, so a longer vine is a longer poisoning as well.
	#
	# The root is deliberately shorter than the gap between casts -- a vine mage
	# should be able to hold one enemy in place, not hold it forever.
	"vine_mage": {
		"branch": "bow", "level": 2, "name": "VINE MAGE", "is_unit": true, "role": "ranged",
		"merge_into": "elder_vine_mage", "radius": 44.0, "color": Color(0.35, 0.75, 0.32),
		"hp": 60.0, "damage": 14.0, "attack_interval": 1.6, "range": 380.0, "aoe_radius": 0.0,
		"shot_tint": Color(0.62, 1.0, 0.45), "shot_scale": 0.16,
		"root_time": 0.8, "poison_dps": 9.0,
	},
	"elder_vine_mage": {
		"branch": "bow", "level": 3, "name": "ELDER VINE MAGE", "is_unit": true, "role": "ranged",
		"merge_into": "ancient_vine_mage", "radius": 52.0, "color": Color(0.30, 0.85, 0.35),
		"hp": 100.0, "damage": 24.0, "attack_interval": 1.5, "range": 420.0, "aoe_radius": 0.0,
		"shot_tint": Color(0.58, 1.0, 0.40), "shot_scale": 0.20,
		"root_time": 1.0, "poison_dps": 17.0,
	},
	"ancient_vine_mage": {
		"branch": "bow", "level": 4, "name": "ANCIENT VINE MAGE", "is_unit": true, "role": "ranged",
		"merge_into": "", "radius": 60.0, "color": Color(0.35, 0.95, 0.40),
		"hp": 150.0, "damage": 38.0, "attack_interval": 1.4, "range": 460.0, "aoe_radius": 0.0,
		"shot_tint": Color(0.55, 1.0, 0.38), "shot_scale": 0.24,
		"root_time": 1.2, "poison_dps": 30.0,
	},

	# --- Gold's line: Hoplites (melee, frontline) ---
	#
	# They hold the ring the warriors used to, but they do it with a thrown
	# spear rather than a sword: the blow is dealt at the moment the spear
	# leaves the hand, and the shaft that crosses the gap is what the player
	# sees. "spear_art" is what flies and "impact_art" is what is left where it
	# lands; "spear_spark" is how much gold comes off the throw, which is the
	# one thing that visibly separates the three tiers.
	"hoplite": {
		"branch": "wood", "level": 2, "name": "HOPLITE", "is_unit": true, "role": "melee",
		"merge_into": "veteran_hoplite", "radius": 44.0, "color": Color(0.85, 0.70, 0.32),
		"hp": 170.0, "damage": 22.0, "attack_interval": 1.1, "range": 120.0, "aoe_radius": 0.0,
		"spear_art": "res://art/fx_spear_1.png", "impact_art": "res://art/fx_spear_impact_1.png",
		"spear_spark": 0.0,
	},
	"veteran_hoplite": {
		"branch": "wood", "level": 3, "name": "VETERAN HOPLITE", "is_unit": true, "role": "melee",
		"merge_into": "elite_hoplite", "radius": 52.0, "color": Color(0.92, 0.76, 0.30),
		"hp": 350.0, "damage": 45.0, "attack_interval": 1.15, "range": 130.0, "aoe_radius": 0.0,
		"spear_art": "res://art/fx_spear_2.png", "impact_art": "res://art/fx_spear_impact_2.png",
		"spear_spark": 1.0,
	},
	"elite_hoplite": {
		"branch": "wood", "level": 4, "name": "ELITE HOPLITE", "is_unit": true, "role": "melee",
		"merge_into": "", "radius": 60.0, "color": Color(1.0, 0.82, 0.30),
		"hp": 720.0, "damage": 92.0, "attack_interval": 1.1, "range": 140.0, "aoe_radius": 0.0,
		"spear_art": "res://art/fx_spear_3.png", "impact_art": "res://art/fx_spear_impact_3.png",
		"spear_spark": 2.1,
	},

	# --- Branch D: Totem / Shaman (support) ---
	#
	# A shaman never attacks. It plants a totem beside itself and everything of
	# ours standing in that totem's circle swings faster -- "totem_haste" is the
	# multiplier on rate of attack, "totem_radius" how far the circle reaches,
	# and "totem_art" which of the three carved posts is planted.
	"totem": {
		"branch": "crystal", "level": 1, "name": "TOTEM", "is_unit": false,
		"merge_into": "shaman", "radius": 32.0, "color": Color(0.30, 0.72, 0.66),
	},
	"shaman": {
		"branch": "crystal", "level": 2, "name": "SHAMAN", "is_unit": true, "role": "support",
		"merge_into": "elder_shaman", "radius": 44.0, "color": Color(0.35, 0.80, 0.72),
		"hp": 95.0, "damage": 0.0, "attack_interval": 1.0, "range": 0.0, "aoe_radius": 0.0,
		"totem_art": "res://art/totem_1.png", "totem_radius": 185.0, "totem_haste": 1.25,
	},
	"elder_shaman": {
		"branch": "crystal", "level": 3, "name": "ELDER SHAMAN", "is_unit": true, "role": "support",
		"merge_into": "great_shaman", "radius": 52.0, "color": Color(0.30, 0.88, 0.78),
		"hp": 150.0, "damage": 0.0, "attack_interval": 1.0, "range": 0.0, "aoe_radius": 0.0,
		"totem_art": "res://art/totem_2.png", "totem_radius": 230.0, "totem_haste": 1.45,
	},
	"great_shaman": {
		"branch": "crystal", "level": 4, "name": "GREAT SHAMAN", "is_unit": true, "role": "support",
		"merge_into": "", "radius": 60.0, "color": Color(0.42, 0.95, 0.85),
		"hp": 220.0, "damage": 0.0, "attack_interval": 1.0, "range": 0.0, "aoe_radius": 0.0,
		"totem_art": "res://art/totem_3.png", "totem_radius": 285.0, "totem_haste": 1.7,
	},

	# --- The heroes ---
	#
	# One of these is chosen from the menu before a run and is standing on the
	# field the moment the run begins; nothing merges into a hero and no hero
	# merges into anything, so they sit in this table for their stats and their
	# art and take no part in the tray at all. The run is handed a free field
	# slot to carry it (see Main._spawn_hero), so choosing one never costs the
	# player a unit they would otherwise have fielded.
	#
	# Every one of them has a passive nobody else has, written as its own key so
	# the effect lives with the stats it is balanced against:
	#
	#   "hero_slow"       the blow leaves the body slower for "hero_slow_time"
	#   "hero_mend"       the fraction of its own missing health a hit gives back
	#   "hero_pierce"     the shot runs on through, hitting everything on the line
	#   "hero_knock"      the blow throws back everything within "hero_knock_radius"
	#   "hero_skull"      a kill leaves a skull standing where the body fell
	#   "hero_venom"      the dart rots for "hero_venom_time" after it lands
	#
	# Stat-wise they sit alongside a level 4 merge: a hero should be worth
	# building a line around and never worth more than the line itself.
	"hero_void_master": {
		"branch": "hero", "level": 4, "name": "VOID MASTER", "is_unit": true, "role": "ranged",
		"is_hero": true, "title": "THE WEAVER OF NOTHINGNESS",
		"merge_into": "", "radius": 56.0, "color": Color(0.62, 0.34, 0.96),
		"hp": 240.0, "damage": 44.0, "attack_interval": 1.6, "range": 400.0, "aoe_radius": 62.0,
		"shot_tint": Color(0.88, 0.62, 1.0), "shot_scale": 0.52,
		"hero_slow": 0.5, "hero_slow_time": 2.6,
		"desc": "Void balls leave whatever they touch crawling.",
	},
	"hero_aurelia": {
		"branch": "hero", "level": 4, "name": "AURELIA", "is_unit": true, "role": "ranged",
		"is_hero": true, "title": "LIGHTBRINGER",
		"merge_into": "", "radius": 56.0, "color": Color(1.0, 0.82, 0.34),
		"hp": 300.0, "damage": 38.0, "attack_interval": 1.3, "range": 380.0, "aoe_radius": 0.0,
		"shot_tint": Color(1.0, 0.88, 0.48), "shot_scale": 0.55,
		"hero_mend": 0.18,
		"desc": "Every hit closes a share of her own wounds.",
	},
	"hero_lumen_strike": {
		"branch": "hero", "level": 4, "name": "LUMEN STRIKE", "is_unit": true, "role": "ranged",
		"is_hero": true, "title": "THE BEAM OF JUSTICE",
		"merge_into": "", "radius": 56.0, "color": Color(1.0, 0.78, 0.28),
		"hp": 250.0, "damage": 40.0, "attack_interval": 1.5, "range": 460.0, "aoe_radius": 0.0,
		"shot_tint": Color(1.0, 0.84, 0.36), "shot_scale": 0.6,
		"hero_pierce": 52.0,
		"desc": "The light wave runs on through the whole rank.",
	},
	"hero_windmaster": {
		"branch": "hero", "level": 4, "name": "WINDMASTER", "is_unit": true, "role": "ranged",
		"is_hero": true, "title": "MASTER OF THE GALE",
		"merge_into": "", "radius": 56.0, "color": Color(0.80, 0.95, 0.45),
		"hp": 250.0, "damage": 34.0, "attack_interval": 1.6, "range": 400.0, "aoe_radius": 55.0,
		"shot_tint": Color(0.86, 1.0, 0.52), "shot_scale": 0.5,
		"hero_knock": 130.0, "hero_knock_radius": 135.0,
		"desc": "The gale throws back everything where it lands. Bosses stand.",
	},
	# "ascend_anim" is the second set of drawings a hero grows into once its own
	# ability comes in: the zombie lord stops being a corpse with a grudge and
	# becomes the thing on the front of his own design sheet. Nothing but the art
	# changes -- see Defender._ascend -- because the promotion the player is
	# actually being given is the button, and a stat jump on top of it would make
	# the level that unlocks it the only level that matters.
	"hero_zombie_lord": {
		"branch": "hero", "level": 4, "name": "ZOMBIE LORD", "is_unit": true, "role": "melee",
		"is_hero": true, "title": "RULER OF THE ROTTEN",
		"merge_into": "", "radius": 58.0, "color": Color(0.55, 0.86, 0.42),
		"hp": 640.0, "damage": 52.0, "attack_interval": 1.3, "range": 130.0, "aoe_radius": 0.0,
		"slash_tint": Color(0.62, 0.95, 0.48),
		"hero_skull": true, "ascend_anim": "hero_zombie_lord_up",
		"desc": "Whatever his bite kills leaves a skull behind.",
	},
	"hero_venom_dartmaster": {
		"branch": "hero", "level": 4, "name": "VENOM DARTMASTER", "is_unit": true, "role": "ranged",
		"is_hero": true, "title": "MASTER OF POISONED BREATH",
		"merge_into": "", "radius": 54.0, "color": Color(0.72, 1.0, 0.30),
		"hp": 230.0, "damage": 24.0, "attack_interval": 1.1, "range": 430.0, "aoe_radius": 0.0,
		"shot_tint": Color(0.82, 1.0, 0.40), "shot_scale": 0.62,
		"hero_venom": 22.0, "hero_venom_time": 4.0,
		"desc": "Darts leave a rot that keeps working long after they land.",
	},
	# "aura_anim" is the row a hero is drawn out of for as long as its cast is
	# running, and the only one of these that is temporary: the cronomancer turns
	# to face the field and holds the hour open, then goes back to the row he came
	# from when it closes. See Defender.enter_aura.
	#
	# His passive is the same slow his cast is, at a fraction of the depth and on
	# one body at a time -- the button is the hour, the bolts are the minutes.
	"hero_cronomancer": {
		"branch": "hero", "level": 4, "name": "CRONOMANCER", "is_unit": true, "role": "ranged",
		"is_hero": true, "title": "KEEPER OF THE HOUR",
		"merge_into": "", "radius": 56.0, "color": Color(0.44, 0.64, 1.0),
		"hp": 240.0, "damage": 36.0, "attack_interval": 1.5, "range": 420.0, "aoe_radius": 0.0,
		"shot_tint": Color(0.60, 0.80, 1.0), "shot_scale": 0.52,
		"hero_slow": 0.72, "hero_slow_time": 1.8, "hero_slow_tint": Color(0.38, 0.62, 1.0),
		"aura_anim": "hero_cronomancer_aura",
		"desc": "Every bolt drags at the hour of whatever it touches.",
	},
}

# The six merge branches, deepest tier last -- what the collection room counts
# itself against, and the only place the branches are written down in order.
const MERGE_BRANCHES := [
	["warrior", "knight", "paladin"],
	["archer", "master_archer", "elite_ranger"],
	["apprentice_mage", "mage", "archmage"],
	["hoplite", "veteran_hoplite", "elite_hoplite"],
	["vine_mage", "elder_vine_mage", "ancient_vine_mage"],
	["shaman", "elder_shaman", "great_shaman"],
]

# The roster, in the order the menu offers it. Kept as its own list rather than
# filtered out of DEFS, so the order on the hero shelf is a decision and not
# whatever order a dictionary happens to iterate in.
# The dartmaster leads because he is the one the player already owns -- see
# MetaManager.STARTER_HERO -- and a shelf that opens on six locked rows and the
# only usable one buried in the middle reads as a shop rather than a roster.
const HERO_IDS := [
	"hero_venom_dartmaster", "hero_void_master", "hero_aurelia",
	"hero_lumen_strike", "hero_windmaster", "hero_zombie_lord",
	"hero_cronomancer",
]

func is_hero(id: String) -> bool:
	return bool(DEFS.get(id, {}).get("is_hero", false))

# Every mergeable body at one merge tier, heroes left out -- what a unit chest
# on the menu shop's shelf draws from. Read off DEFS rather than written out a
# second time, so a branch added there turns up in the chests by itself.
func units_of_tier(tier: int) -> Array:
	var out: Array = []
	for id in DEFS.keys():
		var d: Dictionary = DEFS[id]
		if not bool(d.get("is_unit", false)) or bool(d.get("is_hero", false)):
			continue
		if int(d.get("level", 0)) == tier:
			out.append(id)
	return out

# The picture the menu shows on the shelf and on the plaque beside the BATTLE
# plate. The painted portrait off art/hero_page.png comes first -- that is the
# face the hero shelf is drawn around, and the plaque showing a different one of
# the same hero would read as two heroes. The design-sheet face is the fallback
# for anyone the page has no row for, and "" for anyone with neither.
func get_hero_face(id: String) -> String:
	for path in ["res://art/%s_portrait.png" % id, "res://art/%s_face.png" % id]:
		if ResourceLoader.exists(path):
			return path
	return ""

# "reward" is the gold a kill drops, roughly tracking how long the enemy takes
# to bring down rather than its raw HP, so slow armored types stay worth it.
#
# "gait" picks how the body moves -- see Enemy.GAITS. The art is a single still
# frame per enemy, so the walk, the hover and the attack are all built from the
# sprite's transform; the gait is what makes a goblin read differently from an
# orc without new art.
const ENEMY_DEFS := {
	# "ignores_line" is the goblin's whole trick: it runs straight past the
	# soldiers holding its lane and goes for the fortress, so a lane that is
	# safe against everything else still leaks goblins. Every other enemy has
	# to put down every unit on its lane before it can take another step in.
	"goblin": {
		"name": "GOBLIN", "hp": 50.0, "damage": 4.0, "speed": 70.0,
		"attack_interval": 1.0, "color": Color(0.2, 0.6, 0.25), "damage_reduction": 0.0,
		"reward": 3, "gait": "scurry", "melee": "swing", "ignores_line": true,
	},
	# Orc and armoured knight had no radius of their own, so both were drawn at
	# the goblin's default 28 -- the heavies read as reskinned trash. Their
	# radius also sets sprite size, health bar width and hit-effect scale.
	"orc": {
		"name": "ORC", "hp": 150.0, "damage": 12.0, "speed": 38.0,
		"attack_interval": 1.3, "color": Color(0.35, 0.5, 0.2), "damage_reduction": 0.0,
		"reward": 9, "gait": "plod", "radius": 40.0, "melee": "swing",
	},
	"bat": {
		"name": "BAT", "hp": 35.0, "damage": 6.0, "speed": 130.0,
		"attack_interval": 0.9, "color": Color(0.4, 0.2, 0.5), "damage_reduction": 0.0,
		"reward": 4, "gait": "flit", "melee": "bite",
	},
	"armored_knight": {
		"name": "ARM. KNIGHT", "hp": 175.0, "damage": 12.0, "speed": 44.0,
		"attack_interval": 1.4, "color": Color(0.5, 0.5, 0.55), "damage_reduction": 0.15,
		"reward": 16, "gait": "march", "radius": 38.0, "melee": "swing",
		"slash_tint": Color(1.0, 0.62, 0.58),
	},
	# Twice the size of every other body on the field, and it does not swing a
	# weapon: it throws the crystal in its chest. "magic" replaces the sword arc
	# with a bolt that crosses the gap, so the blow reads from across the arena.
	"stone_golem": {
		"name": "STONE GOLEM", "hp": 1600.0, "damage": 26.0, "speed": 25.0,
		"attack_interval": 1.8, "color": Color(0.45, 0.42, 0.4), "damage_reduction": 0.15,
		"radius": 144.0, "is_boss": true, "slam_interval": 8.0, "slam_damage": 10.0,
		"reward": 150, "gait": "lumber", "melee": "magic",
	},

	# --- The winter roster ---
	#
	# Once the golem is down the map freezes over and the field belongs to these
	# alone; see WaveManager._winter_pool.
	#

	# The mid-boss of the frozen half, ten waves into it. It throws the same
	# slam a stone golem does -- CombatManager reads nothing about a boss
	# except `is_boss` to know it wants one -- so this is a stat line and a
	# name standing between the golem and the dragon, not new combat code.
	# Tougher than the golem it follows, softer than the dragon it leads into.
	"frost_troll": {
		"name": "FROST TROLL", "hp": 2100.0, "damage": 30.0, "speed": 32.0,
		"attack_interval": 1.6, "color": Color(0.58, 0.72, 0.88), "damage_reduction": 0.18,
		"radius": 128.0, "is_boss": true, "slam_interval": 6.5, "slam_damage": 14.0,
		"reward": 220, "gait": "lumber", "melee": "magic",
	},
	# The ice wolf is the first of them, and it is dangerous for what it does
	# rather than what it hits for: "dash_*" is its charge, which crosses the gap
	# for better than double damage and leaves whatever it lands on frozen solid
	# for a couple of seconds -- long enough that a lane can be opened by taking
	# its best soldier out of the fight rather than by killing him. It arrives
	# with the charge nearly ready ("dash_delay") and then has to earn the next
	# one, so a wolf is at its most dangerous in the seconds after it appears.
	"ice_wolf": {
		"name": "ICE WOLF", "hp": 190.0, "damage": 14.0, "speed": 96.0,
		"attack_interval": 0.9, "color": Color(0.55, 0.75, 0.95), "damage_reduction": 0.0,
		# Radius is read as the sprite's longest side, and a wolf is drawn long
		# rather than tall: at the orc's 40 it stood barely half a soldier high
		# and read as a dog. This is what makes it as big across as a knight.
		"reward": 14, "gait": "lope", "radius": 58.0, "melee": "bite",
		"dash_cooldown": 6.0, "dash_delay": 2.0, "dash_damage_mult": 2.2,
		"dash_freeze": 2.0,
	},

	# The other half of the winter line, and the opposite of the wolf in every
	# way that matters: it has no trick at all. It walks up slowly behind a
	# shield, takes a long time to kill, and hits hard enough that leaving it
	# alone is not an option -- so a lane of wolves is a race and a lane of
	# skeletons is a grind, and a lane of both is the actual problem.
	"ice_soldier": {
		"name": "FROST SKELETON", "hp": 320.0, "damage": 24.0, "speed": 42.0,
		"attack_interval": 1.4, "color": Color(0.62, 0.74, 0.88),
		"damage_reduction": 0.18, "reward": 20, "gait": "march", "radius": 46.0,
		"melee": "swing",
	},

	# The third of the winter roster, and the only enemy in the game that never
	# strikes anything: its damage is zero and it has no melee at all. What it
	# does instead is open a circle of cold on the line -- everything of ours
	# standing in it swings slower for as long as it lasts.
	#
	# "field_slow" multiplies rate of attack, so 0.55 is a soldier fighting at a
	# little over half speed; "field_range" is how far from itself it can put the
	# circle, which is longer than the line is deep so it can cast from behind
	# the bodies queued in front of it. It never picks a soldier to fight and
	# never joins the melee -- see CombatManager._process_caster.
	"ice_wizard": {
		"name": "ICE WIZARD", "hp": 210.0, "damage": 0.0, "speed": 38.0,
		"attack_interval": 5.0, "color": Color(0.45, 0.62, 0.95),
		"damage_reduction": 0.05, "reward": 26, "gait": "march", "radius": 48.0,
		"field_radius": 150.0, "field_slow": 0.55, "field_time": 6.0,
		# Long enough to reach the line from a few ranks back in the queue: a
		# wizard behind three wolves is still a wizard.
		"field_range": 460.0, "field_delay": 1.6,
		"field_art": "res://art/ice_wizard_field.png",
	},

	# The boss the frozen half of the run is building toward, and the only thing
	# in the game that flies. "altitude" is how far above its own position it is
	# drawn -- the lane rules still walk it along the ground, it is simply drawn
	# up in the air over that point, with a shadow underneath to say so.
	#
	# Its breath is not an attack it makes, it is a state it enters: once lit it
	# stays lit while anything is in range, and killing what it is pointed at
	# only sends the stream on to the next body. "damage" is what one tick of it
	# costs, dealt every "breath_interval" to everything within "breath_radius"
	# of where the stream is landing -- which during a sweep is a moving point,
	# so it burns the ground between two soldiers as it crosses.
	"ice_dragon": {
		"name": "ICE DRAGON", "hp": 2600.0, "damage": 15.0, "speed": 30.0,
		"attack_interval": 1.0, "color": Color(0.40, 0.62, 0.92),
		"damage_reduction": 0.12, "reward": 300, "gait": "soar", "radius": 96.0,
		"melee": "magic",
		# Drawn high enough to clear its own shadow by a good margin -- the gap
		# between the two is the only thing saying it is in the air -- and no
		# bigger than it has to be: a body this size hovering at this height on
		# the north lane is already half over the top of the arena.
		"is_boss": true, "altitude": 130.0,
		"breath_radius": 74.0, "breath_range": 430.0, "breath_interval": 0.3,
	},
}

func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})

# What a unit already standing on the field is worth if the player takes it back
# off again. Priced off the merge tier and nothing else, so every branch sells
# for the same as every other and the number is one the player can learn once.
#
# It climbs far faster than the tier does -- a level 3 is two level 2s, but it
# sells for five of them, and a level 4 for twenty. Selling is meant to be how a
# board is rearranged and how a bad early unit is cashed out, never a way to farm
# gold: three warriors merged and sold are worth five, and three warriors sold
# where they stand are worth three.
#
# Materials are not units and cannot be on the field at all, so they price at 0.
const SELL_PRICES := {2: 1, 3: 5, 4: 20}

func get_sell_price(id: String) -> int:
	var d: Dictionary = DEFS.get(id, {})
	if not bool(d.get("is_unit", false)):
		return 0
	# A hero was never bought and cannot be replaced: there is no price at which
	# selling the one unit the run was built around is a decision worth offering.
	if bool(d.get("is_hero", false)):
		return 0
	return int(SELL_PRICES.get(int(d.get("level", 0)), 0))

func get_merge_result(id: String) -> String:
	var d: Dictionary = DEFS.get(id, {})
	return d.get("merge_into", "")

func is_unit(id: String) -> bool:
	var d: Dictionary = DEFS.get(id, {})
	return d.get("is_unit", false)

func get_enemy_def(id: String) -> Dictionary:
	return ENEMY_DEFS.get(id, {})

# Lets a roster name creatures that have not been built yet -- see
# WaveManager's winter pool, which is written out in full and filtered down to
# whatever actually exists.
func has_enemy(id: String) -> bool:
	return ENEMY_DEFS.has(id)

# Returns "res://art/<id>.png" if hand-authored art exists for this id, else "".
# Visual builders fall back to the placeholder colored polygon when this is
# empty. A def carrying "art_id" borrows that id's picture -- but only until its
# own turns up, which is why its own file is looked for first.
func get_art_path(id: String) -> String:
	var path := "res://art/%s.png" % id
	if ResourceLoader.exists(path):
		return path
	var borrowed: String = String(DEFS.get(id, {}).get("art_id", ""))
	if borrowed != "":
		path = "res://art/%s.png" % borrowed
		if ResourceLoader.exists(path):
			return path
	return ""

# The colour that borrowed art is multiplied by. White once a def has art of
# its own, so a real gold nugget is never repainted.
func get_art_tint(id: String) -> Color:
	var d: Dictionary = DEFS.get(id, {})
	if String(d.get("art_id", "")) == "":
		return Color(1, 1, 1)
	if ResourceLoader.exists("res://art/%s.png" % id):
		return Color(1, 1, 1)
	return d.get("art_tint", Color(1, 1, 1))

# ------------------------------------------------------------- experience
#
# What one kill is worth to the soldier that landed it. Priced off the gold the
# body drops rather than given a number of its own: that figure already tracks
# how long the thing takes to bring down, which is the same thing a kill is
# worth as experience. A goblin is one point and the golem is fifty, so a unit
# that holds a lane against the rabble climbs steadily and one that lands the
# blow on a boss takes several levels for it.
const XP_PER_REWARD := 3.0

func get_enemy_xp(id: String) -> int:
	var reward: float = float(ENEMY_DEFS.get(id, {}).get("reward", 2))
	return maxi(1, int(round(reward / XP_PER_REWARD)))

# ------------------------------------------------------------- special abilities
#
# A unit that has been on the field long enough to reach ABILITY_LEVEL earns one
# thing no merge can give it: a blow the player throws by hand. Only the top two
# tiers have one at all -- a level 2 unit is a stepping stone and gets nowhere
# near twenty levels before it is merged away -- so this is the reward for
# keeping one particular soldier alive through a whole run rather than for
# building another of the same kind.
#
# "power" is the multiplier on the caster's own damage, so an ability grows with
# every level and every upgrade the unit has taken rather than being a flat
# number that goes stale. "radius" is the ground it covers and "cooldown" the
# wait between casts.
const ABILITY_DEFS := {
	# The one that was asked for: arrows fall out of the sky over a patch of
	# ground, one after another, for as long as the volley lasts.
	"arrow_rain": {
		"name": "ARROW RAIN", "color": Color(0.55, 1.0, 0.48),
		"cooldown": 22.0, "radius": 200.0, "power": 0.55, "count": 16,
		"duration": 1.9, "hit_radius": 52.0, "ranged": true,
		"desc": "Arrows fall over the target for two seconds.",
	},
	# The mage answer: one stone, dropped once, on everything at once.
	"meteor": {
		"name": "METEOR", "color": Color(1.0, 0.56, 0.30),
		"cooldown": 26.0, "radius": 185.0, "power": 3.4, "count": 1,
		"duration": 0.62, "hit_radius": 185.0, "ranged": true,
		"desc": "A falling stone that breaks the whole cluster.",
	},
	# Melee have no reach to throw anything with, so theirs lands where they are
	# standing: the ring of ground around the unit, and everything on it pinned.
	"war_slam": {
		"name": "WAR SLAM", "color": Color(1.0, 0.86, 0.42),
		"cooldown": 20.0, "radius": 235.0, "power": 2.6, "count": 1,
		"duration": 0.0, "hit_radius": 235.0, "ranged": false,
		"root": 1.6,
		"desc": "Breaks the ground underfoot and pins the line.",
	},
	# The vine line does its killing after the hit rather than on it, so its
	# ability is a long hold and a heavy rot rather than a big number.
	"briar": {
		"name": "BRIAR SNARE", "color": Color(0.52, 1.0, 0.42),
		"cooldown": 24.0, "radius": 210.0, "power": 0.9, "count": 1,
		"duration": 0.35, "hit_radius": 210.0, "ranged": true,
		"root": 2.6, "poison_mult": 2.4,
		"desc": "Roots and rots everything in the patch.",
	},
	# A shaman never throws anything at anybody. Its ability is aimed the other
	# way: at the line, which fights faster and gets some of its wounds back.
	"rally": {
		"name": "WAR RALLY", "color": Color(0.42, 0.95, 0.85),
		"cooldown": 30.0, "radius": 0.0, "power": 0.0, "count": 1,
		"duration": 8.0, "hit_radius": 0.0, "ranged": false,
		"haste": 1.6, "heal": 0.35,
		"desc": "Every soldier swings faster and is patched up.",
	},
}

# Which unit has which. Keyed on the unit rather than on its branch because the
# branches do not run clean -- the vine mages sit on the bow branch and throw
# nothing like an arrow.
const UNIT_ABILITY := {
	"knight": "war_slam", "paladin": "war_slam",
	"veteran_hoplite": "war_slam", "elite_hoplite": "war_slam",
	"master_archer": "arrow_rain", "elite_ranger": "arrow_rain",
	"mage": "meteor", "archmage": "meteor",
	"elder_vine_mage": "briar", "ancient_vine_mage": "briar",
	"elder_shaman": "rally", "great_shaman": "rally",
}

func get_ability_id(unit_id: String) -> String:
	if is_hero(unit_id):
		return String(HERO_ABILITY_DEFS.get(unit_id, {}).get("kind", ""))
	return String(UNIT_ABILITY.get(unit_id, ""))

func get_ability(unit_id: String) -> Dictionary:
	if is_hero(unit_id):
		return HERO_ABILITY_DEFS.get(unit_id, {})
	return ABILITY_DEFS.get(get_ability_id(unit_id), {})

# --------------------------------------------------- the heroes' own abilities
#
# A hero earns its cast at HERO_ABILITY_LEVEL rather than the twenty a merged
# unit needs, and it earns it on a button of its own standing over the shop
# rather than on a card the player has to go looking for. Both differences say
# the same thing: the hero is the unit the whole run was built around, and the
# one blow it throws by hand should be the thing the player is watching for
# rather than something buried a tap deep.
#
# Ten is early enough that a hero left holding a lane has its button lit inside
# the first handful of waves, and the wait between casts is short enough to be
# part of the fight rather than a once-a-run event.
#
# "kind" is what CombatManager dispatches on; see cast_ability there. Anything
# without an entry here simply has no button, which is how the four heroes that
# have not been given one yet behave.
const HERO_ABILITY_LEVEL := 10

const HERO_ABILITY_DEFS := {
	# Not aimed at anything: it opens under everything at once, which is the
	# whole of it. "power" is the multiplier on the hero's own damage, so the
	# collapse grows with every level and every upgrade he has taken.
	"hero_void_master": {
		"kind": "void_collapse",
		"name": "VOID COLLAPSE", "color": Color(0.72, 0.40, 1.0),
		"cooldown": 20.0, "power": 3.2, "radius": 96.0,
		"desc": "A black hole opens under every enemy on the field.",
	},
	# The one ability in the game that spends something the player has been
	# building up rather than a cooldown alone: the skulls his bite leaves are
	# the ammunition, and they rot away on their own if he never calls them.
	"hero_zombie_lord": {
		"kind": "rise_damned",
		"name": "RISE OF THE DAMNED", "color": Color(0.62, 0.95, 0.42),
		"cooldown": 20.0, "power": 0.0, "radius": 0.0,
		"desc": "Every skull still standing rises to fight for you.",
	},
	# The only cast in the game that deals no damage at all, and the only one
	# that lasts: for "duration" seconds every enemy already on the field walks
	# and swings at "slow" of its own pace. It buys the line time rather than
	# spending anything, which is why it is the shortest wait of the three --
	# twenty seconds of cooldown for five seconds of held breath.
	#
	# It reaches every lane, like the void master's, and for the same reason:
	# a hero holding the north road has to be worth something to the south one.
	"hero_cronomancer": {
		"kind": "time_stop",
		"name": "HOUR OF STILLNESS", "color": Color(0.46, 0.72, 1.0),
		"cooldown": 20.0, "power": 0.0, "radius": 0.0,
		"duration": 5.0, "slow": 0.35,
		"desc": "Every enemy on the field crawls for five seconds.",
	},
}

func get_hero_ability(id: String) -> Dictionary:
	return HERO_ABILITY_DEFS.get(id, {})

# The stem the hero's button art is filed under: "hero_void_master" is drawn on
# art/void_master_button_*.png, because the sheet was named after the hero and
# not after the id the game gave it.
func hero_art_key(id: String) -> String:
	return id.trim_prefix("hero_")

# ------------------------------------------------------------- the raised dead
#
# What a body comes back as when the zombie lord calls it up. Three drawings
# cover the whole roster, so this is a mapping from what died to whichever of
# them stands up in its place: the armoured ranks come back as the knight, the
# beasts as the wolf, and anything heavy as the orc.
#
# Anything not named here -- a creature added later, most likely -- comes back
# as the orc, which is the form that reads as "something big and rotten" rather
# than as anything in particular.
const ZOMBIE_FORMS := {
	"armored_knight": "knight", "ice_soldier": "knight", "ice_wizard": "knight",
	"bat": "wolf", "ice_wolf": "wolf", "ice_dragon": "wolf",
	"goblin": "orc", "orc": "orc", "stone_golem": "orc", "frost_troll": "orc",
}

func zombie_form(enemy_id: String) -> String:
	return String(ZOMBIE_FORMS.get(enemy_id, "orc"))





