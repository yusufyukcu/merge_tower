extends Node

# Central authority for resolving merges so a pair can never merge twice
# in the same frame, even if multiple collisions are reported simultaneously.

signal unit_created(unit_id: String, position: Vector2)

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
	unit_created.emit(next_id, mid)

	# "Lucky Merge" upgrade: small chance of a free bonus unit alongside the merge.
	var rare_chance: float = UpgradeManager.mult.get("rare_merge_chance", 0.0)
	if rare_chance > 0.0 and randf() < rare_chance:
		var bonus_pos: Vector2 = mid + Vector2(randf_range(-40.0, 40.0), -30.0)
		unit_created.emit(next_id, bonus_pos)
