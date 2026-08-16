extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# A volley dropped on a patch of ground rather than fired at a body.
#
# The whole point of the ability is that it is aimed at a place: the arrows come
# down over a circle for a couple of seconds and whatever walks through it in
# that time is hit, so a player who reads the lane right catches a wave in it
# rather than one enemy. That is why the damage is handed out per arrow, on the
# frame each one lands, instead of totalled up and applied at the end -- an
# enemy that stepped out of the circle after the third arrow took three arrows.
#
# Two heights of node in one effect: the ring is painted on the ground under the
# fight and the arrows fall over the top of it. The layer this lives in is not
# y-sorted, so both are placed by z_index and neither ever slips behind a body.

const FLATTEN := 0.42        # the ground plane every circle in the game lies on
const SEGMENTS := 44
# The ring stays at the layer's own depth so the fight draws over it, and the
# arrows are lifted clear of everything. z_index is absolute within the canvas,
# so anything above zero here would put the painted circle on top of the bodies
# standing in it.
const RING_Z := 0
const ARROW_Z := 80

const FALL_HEIGHT := 640.0
const FALL_TIME := 0.30
const DRIFT := 90.0          # how far off vertical an arrow comes down

var _radius: float = 180.0
var _tint: Color = Color(0.55, 1.0, 0.48)
var _ring_alpha: float = 0.0
var _phase: float = 0.0
var _on_land: Callable = Callable()
var _pending: int = 0
var _spawning: bool = false

func play(radius: float, count: int, duration: float, tint: Color,
		on_land: Callable) -> void:
	_radius = maxf(radius, 8.0)
	_tint = tint
	_on_land = on_land
	_pending = maxi(count, 1)
	_spawning = true
	z_index = RING_Z
	material = FxUtil.additive()

	# The ring is up before the first arrow and gone a beat after the last, so
	# the volley reads as landing inside a marked patch rather than as arrows
	# arriving from nowhere.
	var tw := create_tween()
	tw.tween_method(_set_ring_alpha, 0.0, 1.0, 0.14)
	tw.tween_interval(duration)
	tw.tween_method(_set_ring_alpha, 1.0, 0.0, 0.30)
	tw.tween_callback(func() -> void:
		_spawning = false
		_maybe_finish())

	# Spread over the volley rather than fired at once: one long fall of arrows,
	# with each one's own start jittered so they never come down in step.
	for i in range(_pending):
		var at_time: float = duration * float(i) / float(maxi(_pending - 1, 1))
		var delay: float = maxf(0.0, at_time + randf_range(-0.05, 0.05))
		var shot := create_tween()
		shot.tween_interval(delay)
		shot.tween_callback(_drop_one)

func _set_ring_alpha(v: float) -> void:
	_ring_alpha = v
	queue_redraw()

# A point somewhere inside the circle, on the flattened ground plane. The square
# root is what keeps the volley even: without it every arrow crowds the middle.
func _random_point() -> Vector2:
	var a: float = randf() * TAU
	var r: float = sqrt(randf()) * _radius
	return Vector2(cos(a) * r, sin(a) * r * FLATTEN)

func _drop_one() -> void:
	var landing: Vector2 = _random_point()
	var lean: float = randf_range(-DRIFT, DRIFT)

	var arrow := Node2D.new()
	arrow.z_index = ARROW_Z
	arrow.position = landing + Vector2(lean, -FALL_HEIGHT)
	arrow.rotation = Vector2(-lean, FALL_HEIGHT).angle()
	# Drawn half again the size of one that was fired: these come down from a
	# long way up over a fight several bodies deep, and at the size of a normal
	# shot they read as green specks rather than as arrows.
	arrow.scale = Vector2(1.5, 1.5)
	add_child(arrow)
	_build_arrow(arrow)

	var tw := arrow.create_tween()
	tw.tween_property(arrow, "position", landing, FALL_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_land.bind(arrow, landing))

func _land(arrow: Node2D, at: Vector2) -> void:
	if _on_land.is_valid():
		_on_land.call(global_position + at)

	# A puff off the ground and the shaft left standing in it for a moment, so
	# the circle fills up with spent arrows over the length of the volley.
	var dust := FxUtil.burst(self, 5, 0.32, 40.0, 120.0,
		Color(0.92, 0.88, 0.74, 0.85), Color(0.62, 0.56, 0.42, 0.0), false)
	dust.position = at
	dust.z_index = ARROW_Z - 1
	dust.gravity = Vector2(0, 240)
	dust.emitting = true

	var tw := arrow.create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(arrow, "modulate:a", 0.0, 0.35)
	tw.tween_callback(arrow.queue_free)
	tw.tween_callback(_one_landed)

func _one_landed() -> void:
	_pending -= 1
	_maybe_finish()

# Both halves have to be done: the last arrow can finish falling before the ring
# has finished fading, and the ring can fade while an arrow is still in the air.
func _maybe_finish() -> void:
	if _pending <= 0 and not _spawning:
		queue_free()

# Drawn pointing along +X, the way every other shot in the game is, so the
# node's rotation is the direction it is falling.
func _build_arrow(host: Node2D) -> void:
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(-26, -1.8), Vector2(12, -1.8), Vector2(12, 1.8), Vector2(-26, 1.8)])
	shaft.color = Color(0.40, 0.27, 0.15)
	host.add_child(shaft)

	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(12, -5.0), Vector2(25, 0), Vector2(12, 5.0)])
	head.color = Color(0.86, 0.88, 0.94) * _tint
	host.add_child(head)

	var fletch := Polygon2D.new()
	fletch.polygon = PackedVector2Array([
		Vector2(-26, -6.0), Vector2(-16, -1.4), Vector2(-16, 1.4), Vector2(-26, 6.0)])
	fletch.color = Color(0.90, 0.84, 0.76) * _tint
	host.add_child(fletch)

func _process(delta: float) -> void:
	if _ring_alpha > 0.0:
		_phase += delta
		queue_redraw()

func _draw() -> void:
	if _ring_alpha <= 0.01:
		return
	var pts := PackedVector2Array()
	for i in range(SEGMENTS):
		var a: float = TAU * i / SEGMENTS
		pts.append(Vector2(cos(a) * _radius, sin(a) * _radius * FLATTEN))

	var breath: float = 0.5 + 0.5 * sin(_phase * 7.0)

	var fill := _tint
	fill.a = (0.055 + 0.030 * breath) * _ring_alpha
	draw_colored_polygon(pts, fill)

	var edge := _tint
	edge.a = (0.55 + 0.25 * breath) * _ring_alpha
	var loop: PackedVector2Array = pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, edge, 4.0, true)
