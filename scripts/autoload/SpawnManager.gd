extends Node

# Chooses the next level-1 material (branch id doubles as the material id:
# "wood", "bow", "crystal"). Weighted random with a pity counter so a branch
# can never go unfairly long without appearing.

const BASE_WEIGHTS := {"wood": 0.45, "bow": 0.35, "crystal": 0.20}
const PITY_THRESHOLD := 8
const PITY_BOOST := 0.18

# What each of the three slots drops once the merge upgrade has landed. The slot
# keys never change -- weights, the pity counter and the spawn-chance upgrades
# all stay keyed on them -- only the piece that comes out does.
const MATERIAL_UPGRADED := {"wood": "gold", "bow": "emerald", "crystal": "totem"}

var _drops_since_seen: Dictionary = {"wood": 0, "bow": 0, "crystal": 0}

func reset() -> void:
	_drops_since_seen = {"wood": 0, "bow": 0, "crystal": 0}

# The piece a slot is currently dropping. Pieces already lying in the tray are
# untouched by the upgrade: an old crystal still merges into a mage, and only
# what falls from here on is a totem.
func material_for(slot: String) -> String:
	if GameManager.merge_upgraded:
		return String(MATERIAL_UPGRADED.get(slot, slot))
	return slot

func get_next_material() -> String:
	var base: Dictionary = BASE_WEIGHTS
	var weights: Dictionary = {}
	for branch in base.keys():
		var w: float = float(base[branch]) * UpgradeManager.mult.get(branch + "_spawn", 1.0)
		var since: int = _drops_since_seen.get(branch, 0)
		if since >= PITY_THRESHOLD:
			w += float(since - PITY_THRESHOLD + 1) * PITY_BOOST * UpgradeManager.mult.get("pity_boost", 1.0)
		weights[branch] = w

	var total := 0.0
	for w2 in weights.values():
		total += w2

	var roll: float = randf() * total
	var chosen: String = "wood"
	var acc := 0.0
	for branch in weights.keys():
		acc += weights[branch]
		if roll <= acc:
			chosen = branch
			break

	for branch in _drops_since_seen.keys():
		if branch == chosen:
			_drops_since_seen[branch] = 0
		else:
			_drops_since_seen[branch] += 1

	return material_for(chosen)
