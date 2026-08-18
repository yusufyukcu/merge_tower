extends Node

# Central authority for resolving merges so a pair can never merge twice
# in the same frame, even if multiple collisions are reported simultaneously.

signal unit_created(unit_id: String, position: Vector2)
# Fired alongside unit_created, only for the free extra a lucky roll produces
# -- a second, narrower signal rather than a parameter on the first one, so
# nothing that only cares about a unit existing has to learn to ignore it.
signal bonus_unit_created(unit_id: String, position: Vector2)
# How many merges have landed inside the current combo window, 0 once it has
# lapsed. Main listens for the small on-screen multiplier; nothing else in the
# game needs to know a combo exists.
signal combo_changed(count: int)

# A merge is never a sure thing to be worth nothing extra: even at upgrade
# level zero there is a small chance of a bonus unit, so a brand new run still
# sees the spark occasionally rather than that being purely something the
# Lucky Merge upgrade unlocks from scratch.
const BASE_RARE_CHANCE := 0.02

# Merges landed close together in time stack a rising bonus on top of the base
# (and upgraded) chance, capped well below where it would make the upgrade
# pointless. Keeping the board moving is its own small reward this way, on top
# of whatever the merge itself was worth.
const COMBO_WINDOW := 2.0
const COMBO_STEP_BONUS := 0.02
const COMBO_MAX_BONUS := 0.20

var _combo_count: int = 0
var _combo_timer: float = 0.0

func _process(delta: float) -> void:
	if _combo_timer <= 0.0:
		return
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo_count = 0
		combo_changed.emit(0)

# How deep the current streak is, for anything pitching itself off it. Read
# live rather than mirrored, so there is only ever the one count.
func combo_count() -> int:
	return _combo_count

func request_merge(a: MergeObject, b: MergeObject) -> void:
	if a == null or b == null or a == b:
		return
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	if a.merged or b.merged or a.held or b.held:
		return
	if a.unit_id != b.unit_id:
		return

	var next_id: String = UnitDatabase.get_merge_result(a.unit_id)
	if next_id == "":
		return # top of the branch, nothing to merge into yet

	# Lock both immediately (plain script state, safe mid-physics-step) so a
	# third simultaneous collision this frame cannot trigger a duplicate merge
	# involving either object. The actual physics-server changes (freeze,
	# collision layers) are deferred below since this runs from inside a
	# contact callback, where Godot forbids changing body state directly.
	a.merged = true
	b.merged = true

	call_deferred("_finish_merge", a, b, next_id)

func _finish_merge(a: MergeObject, b: MergeObject, next_id: String) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	a.freeze = true
	b.freeze = true
	a.collision_layer = 0
	a.collision_mask = 0
	b.collision_layer = 0
	b.collision_mask = 0

	var mid: Vector2 = (a.global_position + b.global_position) / 2.0
	a.queue_free()
	b.queue_free()

	# Counted before the unit is announced, not after: the merge's own noise and
	# shake are pitched off how deep the streak is, and a streak that only
	# updates afterwards would always be reporting the merge before this one.
	_combo_count += 1
	_combo_timer = COMBO_WINDOW * BlessingManager.combo_window_mult()
	combo_changed.emit(_combo_count)

	unit_created.emit(next_id, mid)

	# Base chance floors it for every run; the "Lucky Merge" upgrade overrides
	# rather than adds to that floor once it is worth more than it, and a hot
	# streak of merges stacks its own bonus on top of whichever of the two won.
	var base: float = maxf(0.0, BASE_RARE_CHANCE + BlessingManager.base_rare_delta())
	var rare_chance: float = maxf(base, UpgradeManager.mult.get("rare_merge_chance", 0.0))
	rare_chance += minf(COMBO_MAX_BONUS, float(_combo_count - 1) * COMBO_STEP_BONUS * BlessingManager.combo_step_mult())
	# The very first bonus-eligible merge of the save file's life always
	# lands, so a brand new player learns what a lucky merge even looks like
	# before ever meeting the real, much longer odds of one.
	var first_ever: bool = not MetaManager.seen_first_bonus_merge
	if first_ever:
		rare_chance = 1.0
	if rare_chance > 0.0 and randf() < rare_chance:
		var bonus_pos: Vector2 = mid + Vector2(randf_range(-40.0, 40.0), -30.0)
		unit_created.emit(next_id, bonus_pos)
		bonus_unit_created.emit(next_id, bonus_pos)
		if first_ever:
			MetaManager.consume_first_bonus_merge()
