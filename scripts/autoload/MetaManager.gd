extends Node

# Persistent, cross-run progress: what a run leaves behind even when it ends
# in defeat. Nothing here is touched by Main._ready()'s reset block -- a
# session lives and dies inside GameManager/UpgradeManager/CombatManager, but
# the essence a run banked and the doors it unlocked belong to the player, not
# the run, and survive the next scene load on purpose.

signal essence_changed(total: int)
signal achievement_unlocked(id: String)
signal hero_changed(id: String)

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
# Which of the six the player marches out with. Chosen on the menu and read
# once, by Main, at the top of a run -- so it belongs to the player rather than
# to the run and is saved with everything else that outlives one.
#
# Stored as a plain id and validated on the way out rather than on the way in,
# because a save file written by an older build can name a hero this one no
# longer has, and the sensible answer to that is the first of the current
# roster and not an empty field.
var selected_hero: String = ""

func hero_id() -> String:
	if UnitDatabase.HERO_IDS.has(selected_hero):
		return selected_hero
	return String(UnitDatabase.HERO_IDS[0]) if not UnitDatabase.HERO_IDS.is_empty() else ""

func select_hero(id: String) -> void:
	if not UnitDatabase.HERO_IDS.has(id) or id == selected_hero:
		return
	selected_hero = id
	_save()
	hero_changed.emit(id)

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

# Mirrors Menu.COLLECTION_BRANCHES -- kept as its own copy rather than a
# cross-reference into a scene script, since an autoload has to exist before
# any scene does and cannot depend on one.
const BRANCH_GROUPS := [
	["warrior", "knight", "paladin"],
	["archer", "master_archer", "elite_ranger"],
	["apprentice_mage", "mage", "archmage"],
	["hoplite", "veteran_hoplite", "elite_hoplite"],
	["vine_mage", "elder_vine_mage", "ancient_vine_mage"],
	["shaman", "elder_shaman", "great_shaman"],
]

func _ready() -> void:
	_load()
	# A unit is "seen" the moment a merge first produces it. Listening here
	# rather than being told keeps every other script free of ever having to
	# remember this system exists.
	MergeManager.unit_created.connect(_on_unit_created)
	MergeManager.bonus_unit_created.connect(_on_bonus_unit_created)
	MergeManager.combo_changed.connect(_on_combo_changed)

func _on_unit_created(unit_id: String, _at: Vector2) -> void:
	grant_achievement("first_blood")
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
	for group in BRANCH_GROUPS:
		var hit := false
		for id in group:
			if units_seen.get(id, false):
				total_seen += 1
				hit = true
		if hit:
			branches_hit += 1
	if branches_hit >= BRANCH_GROUPS.size():
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
	var reward: int = int(ACHIEVEMENTS[id].get("reward", 0))
	essence += reward
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
	essence += reward
	_save()
	essence_changed.emit(essence)
	return reward

# Called once, from Main, the moment a run ends. Essence is paid for ending a
# run at all, not for winning one -- the run that stalls at wave 14 still
# banked something for it, which is the whole point of a layer that outlives
# the run. wave_reached is whatever WaveManager.current_wave was; beat_dragon
# is whether the ice dragon itself went down this run, not merely whether the
# run survived past its wave.
func record_run_end(wave_reached: int, beat_dragon: bool) -> int:
	runs_played += 1
	best_wave = maxi(best_wave, wave_reached)
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
	essence += reward
	_save()
	essence_changed.emit(essence)
	return reward

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		# A brand new save: the one grant that only ever happens here, so the
		# Rewards room a first-time player might open mid-run is never empty.
		essence = STARTER_ESSENCE_GRANT
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
	cfg.save(SAVE_PATH)
