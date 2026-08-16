extends Node

# 20 milestone upgrades across 5 categories (spec section 32). Most are
# passive multipliers consulted by Defender/SpawnManager/MergeManager at the
# moment they need a stat, so a pick applies to everything from that point on
# without needing to walk and mutate already-spawned nodes. The two fortress
# upgrades are the exception (they need to change fortress.hp/max_hp right
# now), so Main.gd special-cases those two ids after calling apply().

const DEFS := {
	"wood_spawn": {"name": "WOODCUTTER", "category": "general", "desc": "Wood spawn chance +20%", "icon": "🪵", "max_level": 3},
	"bow_spawn": {"name": "FLETCHER", "category": "general", "desc": "Bow spawn chance +20%", "icon": "🏹", "max_level": 3},
	"crystal_spawn": {"name": "ARCANIST", "category": "general", "desc": "Crystal spawn chance +20%", "icon": "🔮", "max_level": 3},
	"all_spawn_luck": {"name": "FOUR-LEAF CLOVER", "category": "general", "desc": "Rare branches catch up 10% faster", "icon": "🍀", "max_level": 3},
	"rare_merge": {"name": "LUCKY MERGE", "category": "general", "desc": "+10% chance a merge produces a bonus unit", "icon": "✨", "max_level": 3},

	"warrior_hp": {"name": "TOUGH TRAINING", "category": "warrior", "desc": "Warrior HP +20%", "icon": "⚔️", "max_level": 3},
	"warrior_damage": {"name": "SHARPENED BLADES", "category": "warrior", "desc": "Warrior damage +20%", "icon": "⚔️", "max_level": 3},
	"warrior_aspd": {"name": "RAPID STRIKES", "category": "warrior", "desc": "Warrior attack speed +15%", "icon": "⚔️", "max_level": 3},
	"knight_hp": {"name": "REINFORCED ARMOR", "category": "warrior", "desc": "Knight HP +25%", "icon": "🛡️", "max_level": 3},
	"knight_damage": {"name": "HEAVY STRIKES", "category": "warrior", "desc": "Knight damage +25%", "icon": "🛡️", "max_level": 3},

	"archer_damage": {"name": "RAZOR ARROWS", "category": "archer", "desc": "Archer damage +20%", "icon": "🏹", "max_level": 3},
	"archer_aspd": {"name": "RAPID FIRE", "category": "archer", "desc": "Archer attack speed +20%", "icon": "🏹", "max_level": 3},
	"archer_range": {"name": "EAGLE EYE", "category": "archer", "desc": "Archer/Master Archer range +20%", "icon": "🏹", "max_level": 3},
	"master_archer_damage": {"name": "PRECISION SHOT", "category": "archer", "desc": "Master Archer damage +25%", "icon": "🎯", "max_level": 3},

	"mage_damage": {"name": "ARCANE POWER", "category": "mage", "desc": "Mage damage +25%", "icon": "🔮", "max_level": 3},
	"mage_aoe": {"name": "WIDER BLAST", "category": "mage", "desc": "Mage AoE radius +20%", "icon": "💥", "max_level": 3},
	"mage_aspd": {"name": "QUICK CASTING", "category": "mage", "desc": "Mage attack speed +15%", "icon": "🔮", "max_level": 3},

	"fortress_max_hp": {"name": "REINFORCED WALLS", "category": "fortress", "desc": "Fortress maximum HP +20", "icon": "🏰", "max_level": 3},
	"fortress_heal": {"name": "EMERGENCY REPAIRS", "category": "fortress", "desc": "Heal fortress 20% of max HP now", "icon": "🧱", "max_level": 3},
	"defender_damage": {"name": "WAR HORN", "category": "fortress", "desc": "All defender damage +10%", "icon": "📯", "max_level": 3},
}

var levels: Dictionary = {}
var mult: Dictionary = {}

func _ready() -> void:
	reset()

func reset() -> void:
	levels = {}
	for id in DEFS.keys():
		levels[id] = 0
	_rebuild_mult()

func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})

func get_level(id: String) -> int:
	return levels.get(id, 0)

func get_random_choices(n: int) -> Array:
	var available: Array = []
	for id in DEFS.keys():
		var max_level: int = DEFS[id].get("max_level", 3)
		if levels.get(id, 0) < max_level:
			available.append(id)
	available.shuffle()
	return available.slice(0, min(n, available.size()))

func apply(id: String) -> void:
	levels[id] = levels.get(id, 0) + 1
	_rebuild_mult()

func _rebuild_mult() -> void:
	mult = {
		"wood_spawn": 1.0 + 0.2 * levels.get("wood_spawn", 0),
		"bow_spawn": 1.0 + 0.2 * levels.get("bow_spawn", 0),
		"crystal_spawn": 1.0 + 0.2 * levels.get("crystal_spawn", 0),
		"pity_boost": 1.0 + 0.1 * levels.get("all_spawn_luck", 0),
		"rare_merge_chance": 0.1 * levels.get("rare_merge", 0),

		"warrior_hp": 1.0 + 0.2 * levels.get("warrior_hp", 0),
		"warrior_damage": 1.0 + 0.2 * levels.get("warrior_damage", 0),
		"warrior_aspd": 1.0 + 0.15 * levels.get("warrior_aspd", 0),
		"knight_hp": 1.0 + 0.25 * levels.get("knight_hp", 0),
		"knight_damage": 1.0 + 0.25 * levels.get("knight_damage", 0),

		"archer_damage": 1.0 + 0.2 * levels.get("archer_damage", 0),
		"archer_aspd": 1.0 + 0.2 * levels.get("archer_aspd", 0),
		"archer_range": 1.0 + 0.2 * levels.get("archer_range", 0),
		"master_archer_damage": 1.0 + 0.25 * levels.get("master_archer_damage", 0),

		"mage_damage": 1.0 + 0.25 * levels.get("mage_damage", 0),
		"mage_aoe": 1.0 + 0.2 * levels.get("mage_aoe", 0),
		"mage_aspd": 1.0 + 0.15 * levels.get("mage_aspd", 0),

		"defender_damage": 1.0 + 0.1 * levels.get("defender_damage", 0),
	}
