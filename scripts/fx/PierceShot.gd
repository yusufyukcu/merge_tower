extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# Lumen Strike's light wave, and the only shot in the game that does not stop at
# the first thing it meets.
#
# Everything else a defender fires is a Projectile: it homes on one body and
# spends itself on arrival. This is the opposite of that in both halves -- it is
# aimed once, at where the target was when it left, and then it simply travels.
# Anything that comes within `reach` of the line it is drawing takes the blow,
# once, and the wave keeps going. A rank queued up along a lane is therefore one
# shot rather than eight, which is the whole reason he is worth a slot.
#
# It carries a list of what it has already hit rather than a count, because at
# 1100 px/s a body a hundred pixels deep is inside the corridor for several
# frames and would otherwise be struck once per frame.
#
# The callback is handed the enemy rather than closing over it, for the same
# reason Projectile does it: a wave that crosses the whole arena outlives most of
# what it passes.

const SPEED := 1150.0
const TRAIL_POINTS := 12

var _dir: Vector2 = Vector2.RIGHT
var _left: float = 0.0
var _reach: float = 50.0
var _on_hit: Callable = Callable()
var _hit: Dictionary = {}          # enemy instance id -> true
var _tint: Color = Color(1, 1, 1)

var _body: Node2D = null
var _trail: Line2D = null

func fire(from: Vector2, dir: Vector2, distance: float, reach: float,
		on_hit: Callable, tint: Color = Color(1, 1, 1), size: float = 1.0,
		art_frames: Array = []) -> void:
	global_position = from
	_dir = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_left = maxf(distance, 1.0)
	_reach = maxf(reach, 8.0)
	_on_hit = on_hit
	_tint = tint
	rotation = _dir.angle()
	z_index = 55

	_body = Node2D.new()
	_body.scale = Vector2.ONE * size
	add_child(_body)
	_build_head(art_frames)
	_build_trail()

# The wave itself, drawn pointing along +X with its leading edge at the node --
# the same registration Projectile uses for its drawn shots, so the art can be
# swapped between the two without moving.
func _build_head(paths: Array) -> void:
	for p in paths:
		var path := String(p)
		if not ResourceLoader.exists(path):
			continue
		var s := Sprite2D.new()
		s.texture = load(path)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.material = FxUtil.additive()
		s.centered = false
		s.offset = Vector2(-float(s.texture.get_width()), -float(s.texture.get_height()) * 0.5)
		_body.add_child(s)
		return

	# No art: a bright core is still a readable shot.
	FxUtil.bloom(_body, 0.4, 0.9, _tint, 96)

func _build_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = 12.0
	_trail.default_color = _tint
	_trail.material = FxUtil.additive()
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.z_index = 54

	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.0))
	taper.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = taper

	var grad := Gradient.new()
	grad.set_color(0, Color(_tint.r, _tint.g, _tint.b, 0.0))
	grad.set_color(1, Color(_tint.r, _tint.g, _tint.b, 0.6))
	_trail.gradient = grad
	add_child(_trail)

func _physics_process(delta: float) -> void:
	var step: float = minf(SPEED * delta, _left)
	global_position += _dir * step
	_left -= step

	_trail.add_point(global_position)
	while _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)

	_sweep()

	if _left <= 0.0:
		set_physics_process(false)
		_dissolve()

# Everything standing in the corridor the wave has just crossed. Duplicated for
# the usual reason: a kill erases from `enemies` mid-loop.
func _sweep() -> void:
	if not _on_hit.is_valid():
		return
	for e in CombatManager.enemies.duplicate():
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var key: int = e.get_instance_id()
		if _hit.has(key):
			continue
		if global_position.distance_to(e.global_position) > _reach + e._radius * 0.5:
			continue
		_hit[key] = true
		_on_hit.call(e)

func _dissolve() -> void:
	if _body != null:
		_body.visible = false
	var tw := create_tween()
	tw.tween_property(_trail, "modulate:a", 0.0, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)
