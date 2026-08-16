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
const BOSS_SCHEDULE := {30: "stone_golem", 50: "ice_dragon"}

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
const WINTER_POOL := ["ice_wolf", "ice_soldier", "ice_wizard"]
const WINTER_BOSS := "ice_dragon"

func is_winter(wave: int) -> bool:
	return wave > WINTER_WAVE

func _built(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if UnitDatabase.has_enemy(id):
			out.append(id)
	return out

func _boss_for(wave: int) -> String:
	var named: Array = _built([String(BOSS_SCHEDULE.get(wave, ""))])
	if not named.is_empty():
		return named[0]
	if is_winter(wave):
		var winter: Array = _built([WINTER_BOSS])
		if not winter.is_empty():
			return winter[0]
	return "stone_golem"

func _pool_for(wave: int) -> Array:
	if is_winter(wave):
		var winter: Array = _built(WINTER_POOL)
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

func _build_wave_def(wave: int) -> Dictionary:
	var enemies: Array = []
	var interval: float = 1.0

	if is_boss_wave(wave):
		enemies = [_boss_for(wave)]
	else:
		var pool: Array = _pool_for(wave)

		var count: int = wave_count(wave)

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

	return {
		"enemies": enemies,
		"spawn_interval": interval,
		"hp_mult": hp_scale,
		"damage_mult": dmg_scale,
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
