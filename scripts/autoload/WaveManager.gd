extends Node

# Data-driven wave progression. Waves start automatically with no player
# input; enemy pool and difficulty scale gradually per spec sections 29-30/63.
# Emits spawn requests rather than instancing enemies itself, since Main.gd
# owns the scene tree the enemies live in.

signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal spawn_enemy_requested(enemy_id: String)

enum State { IDLE, SPAWNING, BETWEEN_WAVES, AWAITING_UPGRADE }

const BETWEEN_WAVE_DELAY := 1.5

var current_wave: int = 0
var hp_mult: float = 1.0
var damage_mult: float = 1.0

var _state: int = State.IDLE
var _spawn_queue: Array = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = 1.0
var _between_wave_timer: float = 0.0

func reset() -> void:
	current_wave = 0
	hp_mult = 1.0
	damage_mult = 1.0
	_spawn_queue = []
	_state = State.IDLE
	_between_wave_timer = 0.0

func start() -> void:
	reset()
	_begin_next_wave()

func _begin_next_wave() -> void:
	current_wave += 1
	var wd: Dictionary = _build_wave_def(current_wave)
	_spawn_queue = (wd["enemies"] as Array).duplicate()
	_spawn_interval = wd["spawn_interval"]
	hp_mult = wd["hp_mult"]
	damage_mult = wd["damage_mult"]
	_spawn_timer = 0.0
	_state = State.SPAWNING
	wave_started.emit(current_wave)

# The bosses that have a wave of their own, on top of the standing rule of one
# every thirty. The dragon's fifty is not a multiple of anything -- it is where
# it was asked for -- so the two live side by side rather than one being bent
# into the other's shape.
const BOSS_SCHEDULE := {30: "stone_golem", 40: "frost_troll", 50: "ice_dragon"}

func is_boss_wave(wave: int) -> bool:
	if BOSS_SCHEDULE.has(wave):
		return true
	return wave > 0 and wave % 30 == 0

# ------------------------------------------------------------------- winter
#
# The golem falls on wave 30 and the map freezes over behind it (see
# Main._play_winter_change). Everything after that is fought in the snow and
# against what lives there: the green roster stops appearing entirely.
#
# The winter roster is written out in full here even though it is not all built
# yet. Ids the database has never heard of are filtered out rather than spawned
# as nothing, so the rest can be added one creature at a time without this
# having to be touched again -- and until the first of them existed, the game
# simply kept playing with the old roster.
const WINTER_WAVE := 30
const WINTER_BOSS := "ice_dragon"
# A mid-boss the far side of the changeover, so winter is not fifty waves on
# one boss and its own reskinned roster. Same slam a stone golem throws --
# CombatManager reads `is_boss` and nothing else to know a body wants one --
# so this is a stat line and a name, not new combat code.
const WINTER_MIDBOSS := "frost_troll"

func is_winter(wave: int) -> bool:
	return wave > WINTER_WAVE and not is_lava(wave)

# --------------------------------------------------------------------- embers
#
# The second changeover, and the same shape as the first: the dragon falls on
# wave 50 and the snow goes out from under it (see Main._play_lava_change).
# Everything after that is fought on the ember map.
#
# The dragon's wave is already in BOSS_SCHEDULE, so this names the wave rather
# than scheduling anything of its own -- the map turns on the beat that wave is
# cleared, which is the beat the dragon is dead.
const LAVA_WAVE := 50

func is_lava(wave: int) -> bool:
	return wave > LAVA_WAVE

# Which of the three the field is standing on for a given wave. One place for
# the answer, because the map, the light, the roster and -- once a run can be
# walked away from -- the menu the player comes back to all want it.
const BIOME_FOREST := "forest"
const BIOME_ICE := "ice"
const BIOME_LAVA := "lava"

func biome_for(wave: int) -> String:
	if is_lava(wave):
		return BIOME_LAVA
	if wave > WINTER_WAVE:
		return BIOME_ICE
	return BIOME_FOREST

# The ember roster, written out in full the same way winter's was and for the
# same reason: ids the database has never heard of are filtered out rather than
# spawned as nothing, so the fire creatures can be added one at a time. Until
# the first of them exists this comes back empty and the winter roster keeps
# marching -- which is a frozen army walking a burning map, but a run that
# keeps playing beats a run that spawns nothing.
const LAVA_IMP_WAVE := 51
const LAVA_HOUND_WAVE := 55
const LAVA_BRUTE_WAVE := 60

func _lava_pool(wave: int) -> Array:
	var ids: Array = []
	if wave >= LAVA_IMP_WAVE:
		ids.append("ember_imp")
	if wave >= LAVA_HOUND_WAVE:
		ids.append("magma_hound")
	if wave >= LAVA_BRUTE_WAVE:
		ids.append("obsidian_brute")
	return ids

# The winter roster comes in a body at a time rather than all three landing on
# the same wave the map turns to snow -- the wolf is the first cold thing the
# player fights, the skeleton and the wizard are things that had to wait for a
# board that could take them. Ids the database has never heard of are filtered
# out rather than spawned as nothing, so the rest can be added one creature at
# a time without this having to be touched again.
const WINTER_WOLF_WAVE := 31
const WINTER_SOLDIER_WAVE := 35
const WINTER_WIZARD_WAVE := 40

func _winter_pool(wave: int) -> Array:
	var ids: Array = ["ice_wolf"]
	if wave >= WINTER_SOLDIER_WAVE:
		ids.append("ice_soldier")
	if wave >= WINTER_WIZARD_WAVE:
		ids.append("ice_wizard")
	return ids

func _built(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if UnitDatabase.has_enemy(id):
			out.append(id)
	return out

# The boss the ember phase is meant to build toward. Named here rather than put
# in BOSS_SCHEDULE because it does not own one wave: it is whichever multiple of
# thirty falls past the dragon, for as long as the player keeps going.
const LAVA_BOSS := "molten_titan"

func _boss_for(wave: int) -> String:
	var named: Array = _built([String(BOSS_SCHEDULE.get(wave, ""))])
	if not named.is_empty():
		return named[0]
	if is_lava(wave):
		# Its own boss once there is one, and the dragon again until then --
		# past fifty there is nothing else left that has ever been a boss.
		var lava: Array = _built([LAVA_BOSS, WINTER_BOSS, WINTER_MIDBOSS])
		if not lava.is_empty():
			return lava[0]
	if is_winter(wave):
		# Past the two scheduled winter bosses, the multiples of thirty
		# alternate rather than repeating the dragon forever -- the boss
		# changes with the wave the way the trash roster already does.
		var pick: String = WINTER_MIDBOSS if (wave / 30) % 2 == 0 else WINTER_BOSS
		var winter: Array = _built([pick, WINTER_BOSS, WINTER_MIDBOSS])
		if not winter.is_empty():
			return winter[0]
	return "stone_golem"

func _pool_for(wave: int) -> Array:
	# The ember roster first, then the frozen one under it, then the green one
	# under both. Each falls through to the next when nothing in it is built
	# yet, so an unfinished phase borrows the last finished one's creatures
	# rather than spawning an empty wave.
	if is_lava(wave):
		var lava: Array = _built(_lava_pool(wave))
		if not lava.is_empty():
			return lava
	if wave > WINTER_WAVE:
		var winter: Array = _built(_winter_pool(wave))
		if not winter.is_empty():
			return winter

	var pool: Array = ["goblin"]
	if wave >= 3:
		pool.append("bat")
	if wave >= 5:
		pool.append("orc")
	# The armoured knight used to arrive on wave 8 and end the run there:
	# it walked through the line and had the fortress down in four blows.
	# It is softer now and comes a wave later, once a real board exists.
	if wave >= 9:
		pool.append("armored_knight")
	return pool

# ------------------------------------------------------------- how many come
#
# The size of a wave compounds rather than climbing by a fixed step. The old
# rule added roughly half a body per wave and stopped at eighteen, which meant
# the twentieth wave was barely worse than the twelfth and every wave after the
# cap was identical -- the run stopped getting harder long before it stopped.
#
# Each wave is now GROWTH times the one before it, so the pressure keeps pace
# with a board that is itself compounding: units merge upward, they level with
# every kill, and by wave twenty a lane is holding several times what it held at
# wave five. The cap is a rendering limit rather than a design one -- forty-five
# bodies walking four lanes is as much as the field can show at once.
const WAVE_BASE_COUNT := 3.0
const WAVE_GROWTH := 1.11
const WAVE_MAX_COUNT := 45

func wave_count(wave: int) -> int:
	return mini(int(round(WAVE_BASE_COUNT * pow(WAVE_GROWTH, maxi(wave, 1) - 1))),
		WAVE_MAX_COUNT)

# ------------------------------------------------------------- wave modifiers
#
# A periodic twist on the standard mix rather than just more of it -- pure
# multipliers on the count and the two scalars every enemy already reads
# (Enemy.apply_wave_scaling), so a wave can feel like a rush or an elite pack
# without a new enemy id, new art or any new code in Enemy/CombatManager.
const MODIFIERS := {
	"swarm": {"name": "SWARM", "count_mult": 1.8, "hp_mult": 0.6, "dmg_mult": 1.0},
	"elite": {"name": "ELITE PACK", "count_mult": 0.6, "hp_mult": 1.6, "dmg_mult": 1.3},
	"brutal": {"name": "BRUTAL", "count_mult": 1.0, "hp_mult": 1.15, "dmg_mult": 1.5},
}
const MODIFIER_CYCLE := ["swarm", "elite", "brutal"]
const MODIFIER_EVERY := 7
const MODIFIER_START := 4

# The id of the modifier landing on this wave, or "" for an ordinary one.
# Boss waves never carry one -- the boss is already the twist that wave gets.
func modifier_for(wave: int) -> String:
	if is_boss_wave(wave) or wave < MODIFIER_START:
		return ""
	if (wave - MODIFIER_START) % MODIFIER_EVERY != 0:
		return ""
	var idx: int = ((wave - MODIFIER_START) / MODIFIER_EVERY) % MODIFIER_CYCLE.size()
	return MODIFIER_CYCLE[idx]

func modifier_name(id: String) -> String:
	return String(MODIFIERS.get(id, {}).get("name", ""))

func _build_wave_def(wave: int) -> Dictionary:
	var enemies: Array = []
	var interval: float = 1.0
	var mod_id: String = modifier_for(wave)
	var mod: Dictionary = MODIFIERS.get(mod_id, {})

	if is_boss_wave(wave):
		enemies = [_boss_for(wave)]
	else:
		var pool: Array = _pool_for(wave)

		var count: int = maxi(1, int(round(wave_count(wave) * float(mod.get("count_mult", 1.0)))))

		for i in range(count):
			enemies.append(pool[randi() % pool.size()])

		interval = clamp(1.15 - wave * 0.022, 0.34, 1.15)

	# Health climbs faster than damage on purpose: a wave that takes longer to
	# cut down is a harder wave, while a wave that hits harder mostly shortens
	# the run. The old 8%/5% per wave put both out of reach by wave 8.
	var hp_scale: float
	var dmg_scale: float
	if wave <= 50:
		hp_scale = 1.0 + (wave - 1) * 0.055
		dmg_scale = 1.0 + (wave - 1) * 0.03
	else:
		# Softer scaling past wave 50 per spec section 30.
		hp_scale = 1.0 + 49 * 0.055 + log(wave - 49) * 0.35
		dmg_scale = 1.0 + 49 * 0.03 + log(wave - 49) * 0.2

	hp_scale *= float(mod.get("hp_mult", 1.0))
	dmg_scale *= float(mod.get("dmg_mult", 1.0))

	return {
		"enemies": enemies,
		"spawn_interval": interval,
		"hp_mult": hp_scale,
		"damage_mult": dmg_scale,
		"modifier": mod_id,
	}

func _process(delta: float) -> void:
	if not GameManager.is_playing():
		return

	match _state:
		State.SPAWNING:
			if _spawn_queue.size() > 0:
				_spawn_timer -= delta
				if _spawn_timer <= 0.0:
					_spawn_timer = _spawn_interval
					var id: String = _spawn_queue.pop_front()
					spawn_enemy_requested.emit(id)
			elif CombatManager.enemies.is_empty():
				wave_cleared.emit(current_wave)
				if current_wave % 10 == 0:
					_state = State.AWAITING_UPGRADE
				else:
					_between_wave_timer = BETWEEN_WAVE_DELAY
					_state = State.BETWEEN_WAVES
		State.BETWEEN_WAVES:
			_between_wave_timer -= delta
			if _between_wave_timer <= 0.0:
				_begin_next_wave()
		State.AWAITING_UPGRADE, State.IDLE:
			pass

func resume_after_upgrade() -> void:
	if _state != State.AWAITING_UPGRADE:
		return
	_between_wave_timer = BETWEEN_WAVE_DELAY
	_state = State.BETWEEN_WAVES
