extends Node

# Picked once, before the tray drops its first piece. Where an upgrade card
# shapes how a run grows, a blessing shapes what kind of run it is from the
# first drop -- so it is chosen before anything else happens rather than
# offered alongside everything that already scales a run up.
#
# Every number below is read live, at the point whatever it touches actually
# runs (a drop weight, a merge roll, a fortress spawn) -- nothing here mutates
# another system's constants, so an unpicked blessing is exactly a no-op
# rather than a second copy of a default to keep in sync.

const DEFS := {
	"woodland_oath": {
		"name": "WOODLAND OATH", "icon": "🌲",
		"desc": "Wood drops +55%, the other two branches -20%. Warriors start a level ahead.",
		"branch_bias": {"wood": 1.55, "bow": 0.8, "crystal": 0.8},
		"seed_upgrade": "warrior_hp",
	},
	"rangers_pact": {
		"name": "RANGER'S PACT", "icon": "🏹",
		"desc": "Bow drops +55%, the other two branches -20%. Archers start a level ahead.",
		"branch_bias": {"bow": 1.55, "wood": 0.8, "crystal": 0.8},
		"seed_upgrade": "archer_aspd",
	},
	"arcane_circle": {
		"name": "ARCANE CIRCLE", "icon": "🔮",
		"desc": "Crystal drops +55%, the other two branches -20%. Mages start a level ahead.",
		"branch_bias": {"crystal": 1.55, "wood": 0.8, "bow": 0.8},
		"seed_upgrade": "mage_aoe",
	},
	"veterans_head_start": {
		"name": "VETERAN'S HEAD START", "icon": "🎖️",
		"desc": "+2 field slots for this run. Gold earned -10%.",
		"bonus_slots": 2, "gold_mult": 0.9,
	},
	"combo_zealot": {
		"name": "COMBO ZEALOT", "icon": "🔥",
		"desc": "Merge combo window +60%, combo bonus grows faster. Base luck -1%.",
		"combo_window_mult": 1.6, "combo_step_mult": 1.75, "base_rare_delta": -0.01,
	},
	"pitys_friend": {
		"name": "PITY'S FRIEND", "icon": "🍀",
		"desc": "The pity counter kicks in sooner and hits harder. Fortress max HP -10.",
		"pity_threshold_delta": -3, "pity_boost_mult": 1.4, "fortress_hp_delta": -10.0,
	},
	# Only offered to a run that has already beaten the game once -- the one
	# card here that is not for a first run at all.
	"golems_blessing": {
		"name": "GOLEM'S BLESSING", "icon": "🗿",
		"desc": "Fortress starts at +25% max HP, fully healed. Defender damage -10%.",
		"fortress_hp_mult": 1.25, "defender_damage_mult": 0.9,
		"requires": "dragon_bonus",
	},
}

var active_id: String = ""

func reset() -> void:
	active_id = ""

# What the player is actually offered this run -- gated cards only turn up
# once whatever they require has been earned.
func choices() -> Array:
	var ids: Array = []
	for id in DEFS.keys():
		var req: String = String(DEFS[id].get("requires", ""))
		if req == "dragon_bonus" and not MetaManager.has_dragon_bonus():
			continue
		ids.append(id)
	return ids

func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})

func apply(id: String) -> void:
	active_id = id if DEFS.has(id) else ""

func active_def() -> Dictionary:
	return DEFS.get(active_id, {})

func branch_bias(branch: String) -> float:
	return float(active_def().get("branch_bias", {}).get(branch, 1.0))

func bonus_slots() -> int:
	return int(active_def().get("bonus_slots", 0))

func gold_mult() -> float:
	return float(active_def().get("gold_mult", 1.0))

func combo_window_mult() -> float:
	return float(active_def().get("combo_window_mult", 1.0))

func combo_step_mult() -> float:
	return float(active_def().get("combo_step_mult", 1.0))

func base_rare_delta() -> float:
	return float(active_def().get("base_rare_delta", 0.0))

func pity_threshold_delta() -> int:
	return int(active_def().get("pity_threshold_delta", 0))

func pity_boost_mult() -> float:
	return float(active_def().get("pity_boost_mult", 1.0))

func fortress_hp_delta() -> float:
	return float(active_def().get("fortress_hp_delta", 0.0))

func fortress_hp_mult() -> float:
	return float(active_def().get("fortress_hp_mult", 1.0))

func defender_damage_mult() -> float:
	return float(active_def().get("defender_damage_mult", 1.0))

func seed_upgrade_id() -> String:
	return String(active_def().get("seed_upgrade", ""))
