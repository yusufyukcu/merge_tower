extends Node

# Persistent, cross-run progress: what a run leaves behind even when it ends
# in defeat. Nothing here is touched by Main._ready()'s reset block -- a
# session lives and dies inside GameManager/UpgradeManager/CombatManager, but
# the essence a run banked and the doors it unlocked belong to the player, not
# the run, and survive the next scene load on purpose.

signal essence_changed(total: int)
signal gold_changed(total: int)
signal achievement_unlocked(id: String)
signal hero_changed(id: String)
signal inventory_changed

const SAVE_PATH := "user://meta.cfg"

var essence: int = 0
var bonus_slot_tier: int = 0
var tier4_unlocked: bool = false
var dragon_bonus_unlocked: bool = false
var best_wave: int = 0
var runs_played: int = 0
# unit_id -> true, the moment a merge first produces it. Base materials are
# not in here at all -- they are on the tray from the first drop of the first
# run and there is nothing about them left to discover.
var units_seen: Dictionary = {}

# Three permanent steps, each a starting unit slot the run never has to earn.
# Priced in essence rather than gold: gold resets every run, essence is the
# only thing that does not, so it is the only thing that can fairly buy
# something that also does not.
const BONUS_SLOT_COSTS := [200, 500, 1200]

# --------------------------------------------------------------------- shop
#
# Where essence goes once the field-slot ladder isn't the only thing worth
# saving for. Three separate sinks, each permanent, each read live by
# whatever it touches -- the same "an unpicked purchase is exactly a no-op"
# rule BlessingManager follows.

# Branch mastery: a permanent head start on the same "_spawn" upgrades the
# in-run card pool already offers (UpgradeManager.DEFS wood_spawn/bow_spawn/
# crystal_spawn), applied by calling UpgradeManager.apply() that many times
# at the start of every run from here on. Three tracks so specializing in one
# branch across many runs is an actual long-term decision, not just a bigger
# number.
const META_UPGRADE_IDS := ["wood_spawn", "bow_spawn", "crystal_spawn"]
const META_UPGRADE_NAMES := {
	"wood_spawn": "WOODCUTTING", "bow_spawn": "FLETCHING", "crystal_spawn": "ARCANE STUDY",
}
const META_UPGRADE_COSTS := [150, 400, 900]

var meta_upgrade_levels: Dictionary = {}

# A permanently open fourth seat at the upgrade table -- one purchase, for
# good, rather than a level that climbs.
var fourth_card_unlocked: bool = false
const FOURTH_CARD_COST := 500

# Every field slot bought with gold, for the rest of forever, a little
# cheaper -- three steps, same escalating shape as everything else here.
var discount_tier: int = 0
const DISCOUNT_COSTS := [200, 500, 1000]
const DISCOUNT_STEP := 0.1

func meta_upgrade_level(id: String) -> int:
	return int(meta_upgrade_levels.get(id, 0))

func next_meta_upgrade_cost(id: String) -> int:
	var level: int = meta_upgrade_level(id)
	if level >= META_UPGRADE_COSTS.size():
		return 0
	return int(META_UPGRADE_COSTS[level])

func buy_meta_upgrade(id: String) -> bool:
	var price: int = next_meta_upgrade_cost(id)
	if price <= 0 or essence < price:
		return false
	essence -= price
	meta_upgrade_levels[id] = meta_upgrade_level(id) + 1
	_save()
	essence_changed.emit(essence)
	return true

func buy_fourth_card() -> bool:
	if fourth_card_unlocked or essence < FOURTH_CARD_COST:
		return false
	essence -= FOURTH_CARD_COST
	fourth_card_unlocked = true
	_save()
	essence_changed.emit(essence)
	return true

func next_discount_cost() -> int:
	if discount_tier >= DISCOUNT_COSTS.size():
		return 0
	return int(DISCOUNT_COSTS[discount_tier])

func buy_discount() -> bool:
	var price: int = next_discount_cost()
	if price <= 0 or essence < price:
		return false
	essence -= price
	discount_tier += 1
	_save()
	essence_changed.emit(essence)
	return true

# What every gold price in the game -- right now just GameManager's field
# slots -- is multiplied by. 1.0 with nothing bought, down 10% a tier.
func discount_mult() -> float:
	return 1.0 - DISCOUNT_STEP * float(discount_tier)

# -------------------------------------------------------------------- hero
#
# Which of the seven the player marches out with. Chosen on the menu and read
# once, by Main, at the top of a run -- so it belongs to the player rather than
# to the run and is saved with everything else that outlives one.
#
# Stored as a plain id and validated on the way out rather than on the way in,
# because a save file written by an older build can name a hero this one no
# longer has -- or one it has but the player no longer owns -- and the sensible
# answer to either is the hero everybody starts with, not an empty field.
var selected_hero: String = ""

# The roster is owned rather than handed over: the dartmaster is who a new
# player starts with, and the other six are bought once each with essence. The
# prices are the ones painted onto art/hero_page.png, so the shelf and the
# ledger cannot drift apart.
const STARTER_HERO := "hero_venom_dartmaster"
const HERO_UNLOCK_COSTS := {
	"hero_void_master": 1500,
	"hero_aurelia": 1250,
	"hero_lumen_strike": 1250,
	"hero_windmaster": 1000,
	"hero_zombie_lord": 1000,
	"hero_cronomancer": 1500,
}

# And every hero owned carries a level, bought with gold, that it walks onto the
# field at -- the same level a merged unit would have had to fight its way to.
# Defender does the growing (see Defender.start_at_level); all this holds is the
# number and what the next one costs.
#
# The curve is flat-stepped rather than compounding: cheap enough at the start
# that the first few are bought without thinking, and steep enough by the
# twenties that a maxed hero is most of a season's gold. Level 10 is the one
# worth naming -- UnitDatabase.HERO_ABILITY_LEVEL -- because that is where the
# hero's cast comes in, and it lands around 32,000 gold, or two or three runs.
const HERO_LEVEL_BASE := 800
const HERO_LEVEL_STEP := 700

var heroes_owned: Array = []
var hero_levels: Dictionary = {}

func hero_owned(id: String) -> bool:
	return id == STARTER_HERO or heroes_owned.has(id)

func hero_unlock_cost(id: String) -> int:
	return int(HERO_UNLOCK_COSTS.get(id, 0))

func unlock_hero(id: String) -> bool:
	if hero_owned(id) or not UnitDatabase.HERO_IDS.has(id):
		return false
	var price: int = hero_unlock_cost(id)
	if price <= 0 or essence < price:
		return false
	essence -= price
	heroes_owned.append(id)
	_save()
	essence_changed.emit(essence)
	return true

func hero_max_level() -> int:
	return Defender.MAX_LEVEL

func hero_level(id: String) -> int:
	return clampi(int(hero_levels.get(id, 1)), 1, hero_max_level())

# 0 once there is nothing left to buy, which is also what the shelf reads as
# MAX rather than as a price of nothing.
func hero_level_cost(id: String) -> int:
	if not hero_owned(id):
		return 0
	var level: int = hero_level(id)
	if level >= hero_max_level():
		return 0
	return HERO_LEVEL_BASE + HERO_LEVEL_STEP * (level - 1)

func level_up_hero(id: String) -> bool:
	var price: int = hero_level_cost(id)
	if price <= 0 or not spend_gold(price):
		return false
	hero_levels[id] = hero_level(id) + 1
	_save()
	return true

func hero_id() -> String:
	if UnitDatabase.HERO_IDS.has(selected_hero) and hero_owned(selected_hero):
		return selected_hero
	return STARTER_HERO

func select_hero(id: String) -> void:
	if not UnitDatabase.HERO_IDS.has(id) or not hero_owned(id) or id == selected_hero:
		return
	selected_hero = id
	_save()
	hero_changed.emit(id)

# ------------------------------------------------------------------ the road
#
# Where the player last stood when they left the field. The run is one road
# through three places -- the green crossroads, the frozen one past the golem,
# the burning one past the dragon -- and the menu is painted three times over
# so that coming home means coming home to the last place you were, not always
# to the forest.
#
# Written on every run end, whether the player walked off the field or was
# driven off it: it is a record of where you were, not of how you left.
#
# The literal rather than WaveManager.BIOME_FOREST: this runs while the
# autoloads are still being stood up, and an initializer that reaches for
# another singleton is one editor reorder away from being null.
var last_biome: String = "forest"

# What each of the three is called, and what the courtyard behind the menu is
# painted as. The art is the whole of the difference -- same layout, same
# plaques, three palettes -- so this table is the only place the three are ever
# told apart.
const BIOMES := {
	"forest": {
		"chapter": 1, "name": "GREEN CROSSROADS", "art": "res://art/forest_menu.png",
		"waves": "WAVES 1 - 30", "boss": "STONE GOLEM",
	},
	"ice": {
		"chapter": 2, "name": "FROZEN CROSSROADS", "art": "res://art/ice_menu.png",
		"waves": "WAVES 31 - 50", "boss": "ICE DRAGON",
	},
	"lava": {
		"chapter": 3, "name": "EMBER CROSSROADS", "art": "res://art/lava_menu.png",
		"waves": "WAVE 51 ONWARD", "boss": "MOLTEN TITAN",
	},
}

const BIOME_ORDER := ["forest", "ice", "lava"]

func biome_def(id: String) -> Dictionary:
	return BIOMES.get(id, BIOMES[WaveManager.BIOME_FOREST])

# The biome the menu should be wearing. Validated on the way out rather than on
# the way in, for the same reason the hero is: a save written by an older build
# can name a place this one does not have.
func menu_biome() -> String:
	return last_biome if BIOMES.has(last_biome) else String(WaveManager.BIOME_FOREST)

# The furthest of the three the player has ever set foot in, which is what the
# chapter plaque on the menu reports. Read off best_wave rather than stored, so
# it can never disagree with the number beside it.
func furthest_biome() -> String:
	return WaveManager.biome_for(best_wave)

# ------------------------------------------------------------------ the pack
#
# What a run left with rather than what it left behind. A player who walks off
# the field takes the units standing on it home, and they are kept here -- one
# entry per body, with the level that body had actually earned, because a
# veteran archer is not the same thing as a fresh one and the pack should not
# pretend otherwise.
#
# Stored flat rather than grouped: the grouping is a way of showing it, and the
# moment anything wants to spend one of these it will want them one at a time.
var inventory: Array = []

func inventory_count() -> int:
	return inventory.size()

func inventory_stacks() -> Array:
	return group_units(inventory)

# A list of bodies as the player reads it: one row per (unit, level) with a
# count on it, deepest tier first, then highest level, then alphabetical -- so
# the row that matters is always at the top and the order never wobbles between
# openings. Used both for the stored pack and for the preview of a pack a
# retreat has not been confirmed into yet, so the two can never disagree about
# what the player is being shown.
func group_units(entries: Array) -> Array:
	var by_key: Dictionary = {}
	for entry in entries:
		var id: String = String((entry as Dictionary).get("id", ""))
		if id == "":
			continue
		var level: int = int((entry as Dictionary).get("level", 1))
		var key: String = "%s@%d" % [id, level]
		if by_key.has(key):
			by_key[key]["count"] = int(by_key[key]["count"]) + 1
		else:
			by_key[key] = {"id": id, "level": level, "count": 1}

	var rows: Array = by_key.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = int(UnitDatabase.get_def(String(a["id"])).get("level", 0))
		var tb: int = int(UnitDatabase.get_def(String(b["id"])).get("level", 0))
		if ta != tb:
			return ta > tb
		if int(a["level"]) != int(b["level"]):
			return int(a["level"]) > int(b["level"])
		return String(a["id"]) < String(b["id"]))
	return rows

# `entries` is [{"id": String, "level": int}, ...] -- exactly what Main hands
# over when a retreat is confirmed. Silently drops anything the database does
# not recognise rather than storing a row nothing can ever draw.
func add_to_inventory(entries: Array) -> void:
	var added: int = 0
	for e in entries:
		var d: Dictionary = e as Dictionary
		var id: String = String(d.get("id", ""))
		if id == "" or not UnitDatabase.is_unit(id):
			continue
		inventory.append({"id": id, "level": maxi(1, int(d.get("level", 1)))})
		added += 1
	if added == 0:
		return
	_save()
	inventory_changed.emit()

# ----------------------------------------------------------------- the squad
#
# The two plaques either side of the hero on the front screen. What stands in
# one is a body out of the pack, held by name and by the level it came home at
# -- a warrior carried back at level 6 is not the same thing as a fresh one,
# and the pack already tells the two apart.
#
# Picking is free and can be undone right up until the run starts. Starting one
# takes both bodies out of the pack for good -- see take_squad, and Main, which
# stands them on the ring before the first piece drops. That is the whole
# trade: a unit spent out of the pack to have it on the field from the first
# second rather than merged for over the first ten waves.
var squad: Array = [{}, {}]

func squad_entry(slot: int) -> Dictionary:
	if slot < 0 or slot >= squad.size():
		return {}
	return squad[slot] as Dictionary

func squad_id(slot: int) -> String:
	return String(squad_entry(slot).get("id", ""))

func squad_level(slot: int) -> int:
	return maxi(1, int(squad_entry(slot).get("level", 1)))

# How many of this exact body -- same name, same level -- the pack holds that
# the other plaque has not already taken. Both plaques can hold a level 3
# warrior only if the pack holds two of them.
func squad_free_count(id: String, level: int, for_slot: int = -1) -> int:
	if id == "":
		return 0
	var free: int = 0
	for entry in inventory:
		var e: Dictionary = entry as Dictionary
		if String(e.get("id", "")) == id and int(e.get("level", 1)) == level:
			free += 1
	for i in range(squad.size()):
		if i == for_slot:
			continue
		if squad_id(i) == id and squad_level(i) == level:
			free -= 1
	return maxi(free, 0)

func set_squad(slot: int, id: String, level: int = 1) -> bool:
	if slot < 0 or slot >= squad.size():
		return false
	if id == "":
		if squad_entry(slot).is_empty():
			return false
		squad[slot] = {}
		_save()
		inventory_changed.emit()
		return true
	if squad_free_count(id, level, slot) <= 0:
		return false
	if squad_id(slot) == id and squad_level(slot) == level:
		return false
	squad[slot] = {"id": id, "level": maxi(1, level)}
	_save()
	inventory_changed.emit()
	return true

# What the run takes. Called once, by Main, the moment a run actually begins:
# the bodies come out of the pack and the plaques are emptied with them, so
# what the menu shows afterwards is the truth -- they are spent, and the next
# run starts with two empty plaques waiting to be filled again.
#
# A plaque is emptied whether or not its body was still findable in the pack.
# The two cannot normally disagree, and when they somehow do, a plaque holding
# something nobody owns is the half that has to go.
func take_squad() -> Array:
	var taken: Array = []
	for i in range(squad.size()):
		var id: String = squad_id(i)
		if id == "":
			continue
		var level: int = squad_level(i)
		squad[i] = {}
		var at: int = _find_in_pack(id, level)
		if at < 0:
			continue
		inventory.remove_at(at)
		taken.append({"id": id, "level": level})
	if taken.is_empty():
		return taken
	_save()
	inventory_changed.emit()
	return taken

func _find_in_pack(id: String, level: int) -> int:
	for i in range(inventory.size()):
		var e: Dictionary = inventory[i] as Dictionary
		if String(e.get("id", "")) == id and int(e.get("level", 1)) == level:
			return i
	return -1

# Walked over the plaques rather than over the pack, and on the way in rather
# than on the way out: a save written when the pack was fuller, or by the build
# that held a plaque as a bare name with no level on it, opens with the plaque
# empty instead of holding a body the pack cannot show.
func prune_squad() -> void:
	if squad.size() != 2:
		squad = [{}, {}]
	var emptied: bool = false
	for i in range(squad.size()):
		if not (squad[i] is Dictionary):
			squad[i] = {}
			emptied = true
			continue
		var id: String = squad_id(i)
		if id == "":
			continue
		if not UnitDatabase.is_unit(id) or squad_free_count(id, squad_level(i), i) <= 0:
			squad[i] = {}
			emptied = true
	if emptied:
		_save()

# ------------------------------------------------------------------ the rank
#
# One number for how long the player has been at this, hung on the essence they
# have ever banked rather than on a counter of its own -- every way of earning
# essence already feeds it, so nothing new has to be tracked to make it move.
#
# Never spent, only ever added to: the shop takes from `essence`, not from this.
var essence_earned_total: int = 0

const RANK_BASE := 120
const RANK_STEP := 80
const RANK_MAX := 99

# Essence banked, cumulatively, to have finished rank r. r = 0 is the start.
func _rank_total(r: int) -> int:
	if r <= 0:
		return 0
	return r * RANK_BASE + RANK_STEP * (r * (r - 1)) / 2

func commander_rank() -> int:
	var r: int = 1
	while r < RANK_MAX and essence_earned_total >= _rank_total(r):
		r += 1
	return r

# How far into the current rank the player is, as {into, span} -- the two
# numbers the bar under the name on the menu is drawn from.
func rank_progress() -> Dictionary:
	var r: int = commander_rank()
	if r >= RANK_MAX:
		return {"into": 1, "span": 1}
	var floor_at: int = _rank_total(r - 1)
	return {
		"into": maxi(0, essence_earned_total - floor_at),
		"span": maxi(1, _rank_total(r) - floor_at),
	}

# Every gain of essence in the game comes through here, so the lifetime total
# and the balance can never drift apart. Spending goes straight at `essence`,
# which is the whole difference between the two numbers.
func _gain_essence(amount: int) -> void:
	if amount <= 0:
		return
	essence += amount
	essence_earned_total += amount

# ----------------------------------------------------------------- the purse
#
# Gold does not survive a run -- that is the point of it -- but the total ever
# taken off the field does, as a career number and nothing more. Nothing spends
# this; it is what the coin on the menu counts.
var total_gold_earned: int = 0

func record_gold(amount: int) -> void:
	if amount <= 0:
		return
	total_gold_earned += amount

# ------------------------------------------------------------- the gold bank
#
# The gold a run earns still dies with the run. This is a different purse: the
# one the menu shop spends, filled only from outside a run -- the free gold the
# shelf hands out once a day, and gold traded for essence on the gold page. It
# is kept apart from `total_gold_earned` on purpose, because that number is a
# record of what has happened and this one is a balance.
var gold: int = 0

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	_save()
	gold_changed.emit(gold)

# Reports whether the purchase went through, the same way GameManager's own
# purse does, so a caller can charge and act in one step.
func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	gold -= amount
	_save()
	gold_changed.emit(gold)
	return true

# --------------------------------------------------------------- free gold
#
# The one line on the shelf that costs nothing. A rolling twenty-four hours
# from the moment it was taken rather than a calendar day, so the shelf cannot
# be emptied twice by claiming at one minute to midnight -- which is also why
# it is stored as a stamp and not as a date the way the menu's gift tile is.
const FREE_GOLD_AMOUNT := 1000
const FREE_GOLD_COOLDOWN := 86400

var last_free_gold_at: int = 0

func _now() -> int:
	return int(Time.get_unix_time_from_system())

# Clamped at both ends, so a clock wound backwards after a claim costs the
# player a day at worst rather than locking the line for years.
func free_gold_seconds_left() -> int:
	if last_free_gold_at <= 0:
		return 0
	return clampi(FREE_GOLD_COOLDOWN - (_now() - last_free_gold_at), 0, FREE_GOLD_COOLDOWN)

func free_gold_ready() -> bool:
	return free_gold_seconds_left() <= 0

func claim_free_gold() -> int:
	if not free_gold_ready():
		return 0
	last_free_gold_at = _now()
	gold += FREE_GOLD_AMOUNT
	_save()
	gold_changed.emit(gold)
	return FREE_GOLD_AMOUNT

# --------------------------------------------------------------- gold packs
#
# The gold page, in order. Every figure here is the one painted on the plate:
# the screen is the price list, and this table only has to agree with it.
const GOLD_PACKS := [
	{"gold": 5000, "essence": 200},
	{"gold": 12000, "essence": 450},
	{"gold": 25000, "essence": 800},
	{"gold": 60000, "essence": 1750},
	{"gold": 150000, "essence": 4000},
	{"gold": 350000, "essence": 8500},
]
# Which of the six the BEST VALUE banner is pointing at.
const GOLD_PACK_BEST := 4

func buy_gold_pack(index: int) -> bool:
	if index < 0 or index >= GOLD_PACKS.size():
		return false
	var pack: Dictionary = GOLD_PACKS[index]
	var price: int = int(pack["essence"])
	if essence < price:
		return false
	essence -= price
	gold += int(pack["gold"])
	_save()
	essence_changed.emit(essence)
	gold_changed.emit(gold)
	return true

# -------------------------------------------------------------- unit chests
#
# Three chests, one per merge tier, each drawing bodies straight into the pack
# the retreat button fills -- so what a chest hands over is the same kind of
# thing a run walked home with, and there is only one place to go and look at
# it. "tier" is UnitDatabase's own level, where 1 is a raw material and the
# three tiers of actual unit are 2, 3 and 4; the shelf calls those Level 1, 2
# and 3, which is what a player counts.
const CHEST_MIN := 3
const CHEST_MAX := 5

const UNIT_CHESTS := {
	"wood": {"price": 10000, "tier": 2},
	"silver": {"price": 30000, "tier": 3},
	"gold": {"price": 75000, "tier": 4},
}

const HERO_CHEST_PRICE := 150000

# Returns what was drawn, or an empty list if the purchase did not happen --
# the caller shows the one and reports nothing on the other.
func buy_unit_chest(id: String) -> Array:
	var def: Dictionary = UNIT_CHESTS.get(id, {})
	if def.is_empty():
		return []
	var pool: Array = UnitDatabase.units_of_tier(int(def["tier"]))
	if pool.is_empty() or not spend_gold(int(def["price"])):
		return []
	var drawn: Array = []
	for i in range(randi_range(CHEST_MIN, CHEST_MAX)):
		drawn.append({"id": String(pool[randi() % pool.size()]), "level": 1})
	record_quest("chests", 1)
	add_to_inventory(drawn)
	return drawn

func buy_hero_chest() -> String:
	if UnitDatabase.HERO_IDS.is_empty() or not spend_gold(HERO_CHEST_PRICE):
		return ""
	var id: String = String(UnitDatabase.HERO_IDS[randi() % UnitDatabase.HERO_IDS.size()])
	record_quest("chests", 1)
	add_to_inventory([{"id": id, "level": 1}])
	return id

# --------------------------------------------------------------- run boosts
#
# The two lines on the shelf that are spent rather than owned: both are bought
# now and used by the next run to actually start, whatever becomes of it. Held
# one at a time -- a shelf that can be bought from twice over stops being a
# decision and turns into a slider -- so a line already paid for reads as armed
# and cannot be bought again until a run has taken it.
const UNIT_BOOST_PRICE := 15000
const UNIT_BOOST_MULT := 1.25
const EXTRA_SLOT_PRICE := 20000

var pending_unit_boost: bool = false
var pending_extra_slot: bool = false

# Armed for the run being played rather than for the next one, and deliberately
# not saved: it belongs to the run, and a run does not survive the app closing.
var _run_unit_boost: bool = false

func buy_unit_boost() -> bool:
	if pending_unit_boost or not spend_gold(UNIT_BOOST_PRICE):
		return false
	pending_unit_boost = true
	_save()
	return true

func buy_extra_slot() -> bool:
	if pending_extra_slot or not spend_gold(EXTRA_SLOT_PRICE):
		return false
	pending_extra_slot = true
	_save()
	return true

# Called once, by Main, the moment a run actually begins. Everything bought for
# "the next run" is spent on this one here, so a run that ends badly still
# counts as the run it was bought for.
func take_run_boosts() -> Dictionary:
	var out: Dictionary = {
		"extra_slots": 1 if pending_extra_slot else 0,
		"unit_boost": pending_unit_boost,
	}
	_run_unit_boost = pending_unit_boost
	if pending_unit_boost:
		record_quest("boosts", 1)
	pending_unit_boost = false
	pending_extra_slot = false
	_save()
	return out

# What every defender's damage is multiplied by for the whole of this run. 1.0
# with nothing bought, which is exactly a no-op.
func run_damage_mult() -> float:
	return UNIT_BOOST_MULT if _run_unit_boost else 1.0

# ---------------------------------------------------------------- the quests
#
# Six a day, off the painted board -- see QuestsScreen. Every line of that
# picture is fixed: the wording, the goal and the reward are all painted, and
# this table only has to agree with what is written there.
#
# What each one counts is the thing the game was already in a position to tell
# it, rather than a new counter threaded through the run: a merge is a unit
# created, a wave survived is a wave cleared, a battle won is a run walked away
# from rather than one lost, and "level 3" is the top merge tier -- which is
# already what the shop's chests call Level 3.
signal quests_changed

const QUESTS := [
	{"id": "battles", "goal": 3, "gold": 1000},
	{"id": "merges", "goal": 10, "gold": 1500},
	{"id": "waves", "goal": 5, "gold": 2000},
	{"id": "chests", "goal": 2, "gold": 1000},
	{"id": "boosts", "goal": 2, "gold": 1500},
	{"id": "level3", "goal": 3, "gold": 2500},
]

# A calendar day rather than a rolling one, because the board says the board's
# own words: it counts down to a refresh, and a refresh happens at midnight.
var quest_day: String = ""
var quest_progress: Dictionary = {}
var quest_claimed: Dictionary = {}

func quest_goal(id: String) -> int:
	for q in QUESTS:
		if String((q as Dictionary)["id"]) == id:
			return int((q as Dictionary)["goal"])
	return 0

func quest_reward(id: String) -> int:
	for q in QUESTS:
		if String((q as Dictionary)["id"]) == id:
			return int((q as Dictionary)["gold"])
	return 0

func quest_count(id: String) -> int:
	return mini(int(quest_progress.get(id, 0)), quest_goal(id))

func quest_is_claimed(id: String) -> bool:
	return bool(quest_claimed.get(id, false))

func quest_done(id: String) -> bool:
	var goal: int = quest_goal(id)
	return goal > 0 and quest_count(id) >= goal

func quest_claimable(id: String) -> bool:
	return quest_done(id) and not quest_is_claimed(id)

# What the number on the DAILY QUESTS tab is.
func quests_claimable_count() -> int:
	var n: int = 0
	for q in QUESTS:
		if quest_claimable(String((q as Dictionary)["id"])):
			n += 1
	return n

# Checked wherever the board can be looked at or moved, rather than on a timer:
# the day can turn while the game is sitting on the menu, and the first thing
# that asks about the board after midnight is what rolls it.
func roll_quests() -> void:
	var today: String = _today_string()
	if quest_day == today:
		return
	quest_day = today
	quest_progress = {}
	quest_claimed = {}
	_save()
	quests_changed.emit()

func record_quest(id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	roll_quests()
	var goal: int = quest_goal(id)
	if goal <= 0 or quest_count(id) >= goal:
		return
	quest_progress[id] = mini(quest_count(id) + amount, goal)
	_save()
	quests_changed.emit()

func claim_quest(id: String) -> int:
	roll_quests()
	if not quest_claimable(id):
		return 0
	var reward: int = quest_reward(id)
	quest_claimed[id] = true
	# add_gold saves and reports on its own; the second save is what puts the
	# claim itself on disk, and it is cheap enough not to be worth avoiding.
	add_gold(reward)
	record_gold(reward)
	_save()
	quests_changed.emit()
	return reward

func quests_seconds_left() -> int:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var used: int = int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"])
	return clampi(86400 - used, 0, 86400)

# --------------------------------------------------------------- the options
#
# Held here rather than on the pause menu so they survive the scene the pause
# menu dies with, and so the gear on the main menu has something real behind it.
var sound_enabled: bool = true
var screen_fx_enabled: bool = true

func set_sound_enabled(on: bool) -> void:
	sound_enabled = on
	apply_sound()
	_save()

func set_screen_fx_enabled(on: bool) -> void:
	screen_fx_enabled = on
	_save()

func apply_sound() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, not sound_enabled)

# ------------------------------------------------------------- first session
#
# Each fires at most once in the life of the save file, then never again --
# the point is to teach what the game's real randomness feels like, not to
# keep thumbing the scale.
var seen_first_bonus_merge: bool = false
var seen_first_kill: bool = false
var seen_first_send: bool = false
const STARTER_ESSENCE_GRANT := 40

# ------------------------------------------------------------------- daily
var last_claim_date: String = ""
var daily_streak: int = 0
const DAILY_BASE := 10
const DAILY_STEP := 5
const DAILY_STREAK_CAP := 7

# --------------------------------------------------------------- achievements
#
# Every condition below is read off a signal or a field some other system
# already produces for its own reasons -- nothing here invents a new thing to
# track just to have something to check off.
const ACHIEVEMENTS := {
	"first_blood": {"name": "FIRST BLOOD", "desc": "Merge your first unit.", "reward": 10},
	"six_of_one": {"name": "SIX OF ONE", "desc": "Discover a unit from all six branches.", "reward": 30},
	"full_roster": {"name": "FULL ROSTER", "desc": "Discover all eighteen mergeable units.", "reward": 100},
	"stonebreaker": {"name": "STONEBREAKER", "desc": "Defeat the stone golem.", "reward": 20},
	"troll_slayer": {"name": "TROLL SLAYER", "desc": "Defeat the frost troll.", "reward": 25},
	"dragonslayer": {"name": "DRAGONSLAYER", "desc": "Defeat the ice dragon.", "reward": 15},
	"into_winter": {"name": "INTO WINTER", "desc": "Reach wave 31.", "reward": 15},
	"endless_deep": {"name": "ENDLESS DEEP", "desc": "Reach wave 60.", "reward": 50},
	"storm_weathered": {"name": "STORM WEATHERED", "desc": "Clear a BRUTAL wave without a scratch.", "reward": 25},
	"combo_master": {"name": "COMBO MASTER", "desc": "Chain a x10 merge combo.", "reward": 20},
	"lucky_strike": {"name": "LUCKY STRIKE", "desc": "Land a bonus-unit merge.", "reward": 10},
	"marathon": {"name": "MARATHON", "desc": "Play twenty-five runs.", "reward": 40},
}

var achievements_seen: Dictionary = {}

# ---------------------------------------------------------------- rich stats
var total_kills: int = 0
var longest_clean_streak_ever: int = 0
var deepest_tier_seen: int = 0
# -1 means never cleared wave 30 at all, so a first clear always beats it.
var fastest_wave30_sec: float = -1.0


func _ready() -> void:
	_load()
	# A unit is "seen" the moment a merge first produces it. Listening here
	# rather than being told keeps every other script free of ever having to
	# remember this system exists.
	MergeManager.unit_created.connect(_on_unit_created)
	MergeManager.bonus_unit_created.connect(_on_bonus_unit_created)
	MergeManager.combo_changed.connect(_on_combo_changed)
	# After the load rather than inside it: the pack has to be read back before
	# a plaque holding something out of it can be checked against it.
	prune_squad()
	# The board can turn over while the game sits on the menu, so it is rolled
	# on the way in as well as by anything that writes to it.
	roll_quests()
	WaveManager.wave_cleared.connect(func(_wave: int) -> void: record_quest("waves", 1))

func _on_unit_created(unit_id: String, _at: Vector2) -> void:
	grant_achievement("first_blood")
	# Every merge is one of these, and a merge that lands on the top tier is
	# also the other. Counted before the early return below, which is only
	# there to stop the collection being re-checked for a body already seen.
	record_quest("merges", 1)
	if int(UnitDatabase.get_def(unit_id).get("level", 0)) >= 4:
		record_quest("level3", 1)
	if units_seen.get(unit_id, false):
		return
	units_seen[unit_id] = true
	var level: int = int(UnitDatabase.get_def(unit_id).get("level", 0))
	if level > deepest_tier_seen:
		deepest_tier_seen = level
	_check_collection_achievements()
	_save()

func _on_bonus_unit_created(_unit_id: String, _at: Vector2) -> void:
	grant_achievement("lucky_strike")

func _on_combo_changed(count: int) -> void:
	if count >= 10:
		grant_achievement("combo_master")

func _check_collection_achievements() -> void:
	var branches_hit := 0
	var total_seen := 0
	for group in UnitDatabase.MERGE_BRANCHES:
		var hit := false
		for id in group:
			if units_seen.get(id, false):
				total_seen += 1
				hit = true
		if hit:
			branches_hit += 1
	if branches_hit >= UnitDatabase.MERGE_BRANCHES.size():
		grant_achievement("six_of_one")
	if total_seen >= 18:
		grant_achievement("full_roster")

func has_achievement(id: String) -> bool:
	return bool(achievements_seen.get(id, false))

# Idempotent by design -- every call site is free to call this on every kill,
# every wave clear, every merge, without checking first itself.
func grant_achievement(id: String) -> void:
	if has_achievement(id) or not ACHIEVEMENTS.has(id):
		return
	achievements_seen[id] = true
	_gain_essence(int(ACHIEVEMENTS[id].get("reward", 0)))
	_save()
	essence_changed.emit(essence)
	achievement_unlocked.emit(id)

func record_kill() -> void:
	total_kills += 1

func record_clean_streak(streak: int) -> void:
	if streak > longest_clean_streak_ever:
		longest_clean_streak_ever = streak

func record_wave30_time(seconds: float) -> void:
	if fastest_wave30_sec < 0.0 or seconds < fastest_wave30_sec:
		fastest_wave30_sec = seconds

func bonus_base_slots() -> int:
	return bonus_slot_tier

func next_bonus_slot_cost() -> int:
	if bonus_slot_tier >= BONUS_SLOT_COSTS.size():
		return 0
	return int(BONUS_SLOT_COSTS[bonus_slot_tier])

func buy_bonus_slot() -> bool:
	var price: int = next_bonus_slot_cost()
	if price <= 0 or essence < price:
		return false
	essence -= price
	bonus_slot_tier += 1
	_save()
	essence_changed.emit(essence)
	return true

func has_tier4() -> bool:
	return tier4_unlocked

func has_dragon_bonus() -> bool:
	return dragon_bonus_unlocked

# Each fires at most once ever; a false return means it already happened on
# some earlier run and the caller should fall back to its normal behaviour.
func consume_first_bonus_merge() -> bool:
	if seen_first_bonus_merge:
		return false
	seen_first_bonus_merge = true
	_save()
	return true

func consume_first_kill() -> bool:
	if seen_first_kill:
		return false
	seen_first_kill = true
	_save()
	return true

func consume_first_send() -> bool:
	if seen_first_send:
		return false
	seen_first_send = true
	_save()
	return true

# ------------------------------------------------------------------- daily
#
# A missed day does not cost the streak outright -- only two or more in a row
# does -- so a single busy day never undoes a week of showing up, but the
# streak still means something.
func _today_string() -> String:
	var d: Dictionary = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]

func _days_between(a: String, b: String) -> int:
	if a == "" or b == "":
		return 999
	var ta: float = Time.get_unix_time_from_datetime_string(a + "T00:00:00")
	var tb: float = Time.get_unix_time_from_datetime_string(b + "T00:00:00")
	return int(round(abs(tb - ta) / 86400.0))

func daily_status() -> Dictionary:
	var today: String = _today_string()
	return {
		"claimable": today != last_claim_date,
		"streak": daily_streak,
		"days_missed": _days_between(last_claim_date, today),
	}

func claim_daily() -> int:
	var today: String = _today_string()
	if today == last_claim_date:
		return 0
	var missed: int = _days_between(last_claim_date, today)
	if last_claim_date == "" or missed <= 1:
		daily_streak += 1
	elif missed > 2:
		daily_streak = 1
	# missed == 2 is the one grace day: the streak survives untouched.
	last_claim_date = today
	var reward: int = DAILY_BASE + mini(daily_streak, DAILY_STREAK_CAP) * DAILY_STEP
	_gain_essence(reward)
	_save()
	essence_changed.emit(essence)
	return reward

# ------------------------------------------------------------- walking away
#
# What choosing to leave is worth over being carried off. Without this the two
# ways out of a run pay exactly the same, and a player with no reason to stop
# has no decision to make at wave 40 -- the only sensible move is to stand
# there until the wall falls, which is the opposite of a decision.
#
# It climbs with the wave rather than sitting flat, so there is always
# something on the far side of one more block of ten: a retreat at twenty is
# worth a half again, one at fifty better than double. The cap is there so the
# multiplier stops being the reason to go deep long before the waves do.
const EXTRACT_BASE := 1.15
const EXTRACT_STEP := 0.03
const EXTRACT_MAX := 3.0
const EXTRACT_FROM_WAVE := 10

func extract_multiplier(wave: int) -> float:
	return minf(EXTRACT_BASE + EXTRACT_STEP * float(maxi(0, wave - EXTRACT_FROM_WAVE)),
		EXTRACT_MAX)

# Called once, from Main, the moment a run ends. Essence is paid for ending a
# run at all, not for winning one -- the run that stalls at wave 14 still
# banked something for it, which is the whole point of a layer that outlives
# the run. wave_reached is whatever WaveManager.current_wave was; beat_dragon
# is whether the ice dragon itself went down this run, not merely whether the
# run survived past its wave; extracted is whether the player walked off the
# field rather than losing it.
func record_run_end(wave_reached: int, beat_dragon: bool, extracted: bool = false) -> int:
	runs_played += 1
	best_wave = maxi(best_wave, wave_reached)
	# Where the run ended, so the menu opens on the place it ended in.
	last_biome = WaveManager.biome_for(wave_reached)
	# A battle won is one the player left on their own terms -- walked off the
	# field with the pack, or put the dragon down -- rather than one the
	# fortress was taken in.
	if extracted or beat_dragon:
		record_quest("battles", 1)
	var reward: int = int(floor(wave_reached / 2.0))
	if wave_reached >= 20:
		reward += 10
	if wave_reached >= 30:
		reward += 20
		tier4_unlocked = true
	if wave_reached >= 31:
		grant_achievement("into_winter")
	if wave_reached >= 60:
		grant_achievement("endless_deep")
	if beat_dragon:
		reward += 50
		dragon_bonus_unlocked = true
	if runs_played >= 25:
		grant_achievement("marathon")
	# Applied last, so the retreat bonus is paid on the whole of what the run
	# earned rather than only on the part the wave counter accounted for.
	if extracted:
		reward = int(round(float(reward) * extract_multiplier(wave_reached)))
	_gain_essence(reward)
	_save()
	essence_changed.emit(essence)
	return reward

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		# A brand new save: the one grant that only ever happens here, so the
		# Rewards room a first-time player might open mid-run is never empty.
		_gain_essence(STARTER_ESSENCE_GRANT)
		apply_sound()
		_save()
		return
	essence = int(cfg.get_value("meta", "essence", 0))
	bonus_slot_tier = int(cfg.get_value("meta", "bonus_slot_tier", 0))
	tier4_unlocked = bool(cfg.get_value("meta", "tier4_unlocked", false))
	dragon_bonus_unlocked = bool(cfg.get_value("meta", "dragon_bonus_unlocked", false))
	best_wave = int(cfg.get_value("meta", "best_wave", 0))
	runs_played = int(cfg.get_value("meta", "runs_played", 0))
	units_seen = cfg.get_value("meta", "units_seen", {})
	seen_first_bonus_merge = bool(cfg.get_value("meta", "seen_first_bonus_merge", false))
	seen_first_kill = bool(cfg.get_value("meta", "seen_first_kill", false))
	seen_first_send = bool(cfg.get_value("meta", "seen_first_send", false))
	last_claim_date = String(cfg.get_value("meta", "last_claim_date", ""))
	daily_streak = int(cfg.get_value("meta", "daily_streak", 0))
	achievements_seen = cfg.get_value("meta", "achievements_seen", {})
	total_kills = int(cfg.get_value("meta", "total_kills", 0))
	longest_clean_streak_ever = int(cfg.get_value("meta", "longest_clean_streak_ever", 0))
	deepest_tier_seen = int(cfg.get_value("meta", "deepest_tier_seen", 0))
	fastest_wave30_sec = float(cfg.get_value("meta", "fastest_wave30_sec", -1.0))
	meta_upgrade_levels = cfg.get_value("meta", "meta_upgrade_levels", {})
	fourth_card_unlocked = bool(cfg.get_value("meta", "fourth_card_unlocked", false))
	discount_tier = int(cfg.get_value("meta", "discount_tier", 0))
	selected_hero = String(cfg.get_value("meta", "selected_hero", ""))
	hero_levels = cfg.get_value("meta", "hero_levels", {})
	# A save written before the roster was something you bought has no list at
	# all, and the honest reading of it is that whoever was standing on the ring
	# was already the player's. An update should never take a hero off someone.
	if cfg.has_section_key("meta", "heroes_owned"):
		heroes_owned = cfg.get_value("meta", "heroes_owned", [])
	else:
		heroes_owned = [selected_hero] if selected_hero != "" else []
	last_biome = String(cfg.get_value("meta", "last_biome", "forest"))
	inventory = cfg.get_value("meta", "inventory", [])
	squad = cfg.get_value("meta", "squad", [{}, {}])
	quest_day = String(cfg.get_value("meta", "quest_day", ""))
	quest_progress = cfg.get_value("meta", "quest_progress", {})
	quest_claimed = cfg.get_value("meta", "quest_claimed", {})
	total_gold_earned = int(cfg.get_value("meta", "total_gold_earned", 0))
	gold = int(cfg.get_value("meta", "gold", 0))
	last_free_gold_at = int(cfg.get_value("meta", "last_free_gold_at", 0))
	pending_unit_boost = bool(cfg.get_value("meta", "pending_unit_boost", false))
	pending_extra_slot = bool(cfg.get_value("meta", "pending_extra_slot", false))
	# Saves written before the rank existed have a balance but no history, so
	# the lifetime total starts as whatever is in hand rather than at zero --
	# an old save opens on the rank it had earned instead of back at one.
	essence_earned_total = int(cfg.get_value("meta", "essence_earned_total", essence))
	sound_enabled = bool(cfg.get_value("meta", "sound_enabled", true))
	screen_fx_enabled = bool(cfg.get_value("meta", "screen_fx_enabled", true))
	apply_sound()

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "essence", essence)
	cfg.set_value("meta", "bonus_slot_tier", bonus_slot_tier)
	cfg.set_value("meta", "tier4_unlocked", tier4_unlocked)
	cfg.set_value("meta", "dragon_bonus_unlocked", dragon_bonus_unlocked)
	cfg.set_value("meta", "best_wave", best_wave)
	cfg.set_value("meta", "runs_played", runs_played)
	cfg.set_value("meta", "units_seen", units_seen)
	cfg.set_value("meta", "seen_first_bonus_merge", seen_first_bonus_merge)
	cfg.set_value("meta", "seen_first_kill", seen_first_kill)
	cfg.set_value("meta", "seen_first_send", seen_first_send)
	cfg.set_value("meta", "last_claim_date", last_claim_date)
	cfg.set_value("meta", "daily_streak", daily_streak)
	cfg.set_value("meta", "achievements_seen", achievements_seen)
	cfg.set_value("meta", "total_kills", total_kills)
	cfg.set_value("meta", "longest_clean_streak_ever", longest_clean_streak_ever)
	cfg.set_value("meta", "deepest_tier_seen", deepest_tier_seen)
	cfg.set_value("meta", "fastest_wave30_sec", fastest_wave30_sec)
	cfg.set_value("meta", "meta_upgrade_levels", meta_upgrade_levels)
	cfg.set_value("meta", "fourth_card_unlocked", fourth_card_unlocked)
	cfg.set_value("meta", "discount_tier", discount_tier)
	cfg.set_value("meta", "selected_hero", selected_hero)
	cfg.set_value("meta", "heroes_owned", heroes_owned)
	cfg.set_value("meta", "hero_levels", hero_levels)
	cfg.set_value("meta", "last_biome", last_biome)
	cfg.set_value("meta", "inventory", inventory)
	cfg.set_value("meta", "squad", squad)
	cfg.set_value("meta", "quest_day", quest_day)
	cfg.set_value("meta", "quest_progress", quest_progress)
	cfg.set_value("meta", "quest_claimed", quest_claimed)
	cfg.set_value("meta", "total_gold_earned", total_gold_earned)
	cfg.set_value("meta", "gold", gold)
	cfg.set_value("meta", "last_free_gold_at", last_free_gold_at)
	cfg.set_value("meta", "pending_unit_boost", pending_unit_boost)
	cfg.set_value("meta", "pending_extra_slot", pending_extra_slot)
	cfg.set_value("meta", "essence_earned_total", essence_earned_total)
	cfg.set_value("meta", "sound_enabled", sound_enabled)
	cfg.set_value("meta", "screen_fx_enabled", screen_fx_enabled)
	cfg.save(SAVE_PATH)
