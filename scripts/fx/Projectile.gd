extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# What a ranged defender actually sends downrange. Two looks share one flight:
# a drawn arrow for the bow branch, a glowing bolt for the crystal branch.
#
# The shot carries its damage rather than the shooter applying it at the moment
# of firing: the hit lands when the arrow arrives, so the flinch, the impact
# effect and the health bar all move on the frame the player sees contact. The
# cost of that honesty is that a shot already in the air is wasted if something
# else kills the target first -- at 900 px/s over a backline's worth of ground
# that is roughly a sixth of a second, and it looks far better than damage
# appearing before the arrow does.
#
# The flight homes: enemies drift while a shot is airborne, and a straight line
# to where they used to be reads as a miss that still deals damage.
#
# Two touches keep the flight from looking like a sprite being slid along a
# line: the shot swells slightly through the middle of its travel, which reads
# as it rising over the ground and dropping back onto the target, and it drags
# a short trail that is laid down in world space rather than carried along.

const SPEED := 900.0
const MAX_LIFE := 1.4
const ARRIVE_DISTANCE := 8.0
const TRAIL_POINTS := 9
const LOFT := 0.22          # how much the shot swells at the top of its arc

var _target: Node2D = null
var _target_pos: Vector2 = Vector2.ZERO
var _on_hit: Callable = Callable()
var _life: float = 0.0
var _spent: bool = false

var _body: Node2D = null
var _trail: Line2D = null
var _tint: Color = Color(1, 1, 1)
var _size: float = 1.0
var _start_distance: float = 1.0

func fire(from: Vector2, target: Node2D, kind: String, on_hit: Callable,
		tint: Color = Color(1, 1, 1), size: float = 1.0,
		sparkle: bool = false, art_frames: Array = []) -> void:
	global_position = from
	_target = target
	_target_pos = target.global_position
	_on_hit = on_hit
	_tint = tint
	_size = size
	_start_distance = maxf(from.distance_to(_target_pos), 1.0)
	z_index = 55
	rotation = (_target_pos - from).angle()

	_body = Node2D.new()
	_body.scale = Vector2.ONE * size
	add_child(_body)

	if not art_frames.is_empty():
		_build_drawn(art_frames)
	elif kind == "bolt":
		_build_bolt()
	else:
		_build_arrow()

	if sparkle:
		_build_sparkle()

	_build_trail(kind)

# Shaft, head and fletching, drawn pointing along +X so the node's rotation is
# the flight direction. Only the steel and the feathers take the owner's tint;
# the shaft stays wood whatever fires it.
func _build_arrow() -> void:
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(-18, -1.6), Vector2(10, -1.6), Vector2(10, 1.6), Vector2(-18, 1.6)])
	shaft.color = Color(0.40, 0.27, 0.15)
	_body.add_child(shaft)

	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(10, -4.5), Vector2(21, 0), Vector2(10, 4.5)])
	head.color = Color(0.84, 0.86, 0.92) * _tint
	_body.add_child(head)

	var fletch := Polygon2D.new()
	fletch.polygon = PackedVector2Array([
		Vector2(-18, -5.0), Vector2(-10, -1.2), Vector2(-10, 1.2), Vector2(-18, 5.0)])
	fletch.color = Color(0.88, 0.82, 0.74) * _tint
	_body.add_child(fletch)

func _build_bolt() -> void:
	var halo := FxUtil.bloom(_body, 0.34, 0.75, _tint * Color(0.72, 0.55, 1.0), 64)
	# A slow pulse so the bolt looks lit from inside rather than pasted on.
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(halo, "scale", Vector2.ONE * 0.44, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(halo, "scale", Vector2.ONE * 0.34, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var core := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(10):
		var a: float = TAU * i / 10.0
		pts.append(Vector2(cos(a) * 8.0, sin(a) * 5.5))
	core.polygon = pts
	core.color = Color(0.93, 0.86, 1.0) * _tint
	_body.add_child(core)

# A shot with drawn art instead of a built shape, and more than one frame of it:
# the vine is a seed when it leaves the staff and a whole creeper by the time it
# arrives, so the frame is picked from how far along the flight it is rather
# than from a clock. A shot that crosses the arena grows the whole way; one
# fired at something two steps away barely opens.
var _art: Array = []
var _art_sprite: Sprite2D = null

func _build_drawn(paths: Array) -> void:
	for p in paths:
		var path := String(p)
		if ResourceLoader.exists(path):
			_art.append(load(path))
	if _art.is_empty():
		_build_arrow()
		return

	_art_sprite = Sprite2D.new()
	_art_sprite.texture = _art[0]
	_art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art_sprite.modulate = _tint
	# Drawn pointing along +X with the head at the leading edge, so the shaft
	# trails behind the point the shot is actually at.
	_art_sprite.centered = false
	_art_sprite.offset = Vector2(-float(_art[0].get_width()), -float(_art[0].get_height()) * 0.5)
	_body.add_child(_art_sprite)

func _update_art(progress: float) -> void:
	if _art_sprite == null or _art.is_empty():
		return
	var i: int = clampi(int(progress * _art.size()), 0, _art.size() - 1)
	var tex: Texture2D = _art[i]
	if _art_sprite.texture == tex:
		return
	_art_sprite.texture = tex
	_art_sprite.offset = Vector2(-float(tex.get_width()), -float(tex.get_height()) * 0.5)

# Motes shed continuously along the flight. Emitted in world space rather than
# in the shot's own frame, so they stay where they were dropped and the bolt
# leaves a wake of sparks instead of carrying a cloud along with it.
func _build_sparkle() -> void:
	var p := CPUParticles2D.new()
	p.texture = FxUtil.dot_texture()
	p.material = FxUtil.additive()
	p.local_coords = false
	p.amount = 26
	p.lifetime = 0.5
	p.explosiveness = 0.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 7.0 * _size
	p.spread = 180.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0, -25)
	p.damping_min = 30.0
	p.damping_max = 70.0
	p.scale_amount_min = 1.6 * _size
	p.scale_amount_max = 3.4 * _size
	p.scale_amount_curve = FxUtil.swell_curve()
	p.color_ramp = FxUtil.ramp(
		Color(1.0, 0.92, 1.0, 1.0),
		Color(_tint.r * 0.75, _tint.g * 0.3, _tint.b, 0.0))
	p.emitting = true
	_body.add_child(p)

# Laid down in world space: a trail parented to a moving node would be dragged
# along with it and never fall behind.
func _build_trail(kind: String) -> void:
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = (5.5 if kind == "bolt" else 3.2) * _size
	_trail.default_color = _tint
	_trail.material = FxUtil.additive()
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.z_index = 54

	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.0))
	taper.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = taper

	var base: Color = _tint * (Color(0.70, 0.55, 1.0) if kind == "bolt" else Color(1, 1, 1))
	var grad := Gradient.new()
	grad.set_color(0, Color(base.r, base.g, base.b, 0.0))
	grad.set_color(1, Color(base.r, base.g, base.b, 0.55))
	_trail.gradient = grad
	add_child(_trail)

func _physics_process(delta: float) -> void:
	if _spent:
		return

	if is_instance_valid(_target):
		_target_pos = _target.global_position

	var to: Vector2 = _target_pos - global_position
	var dist: float = to.length()
	if dist > 0.001:
		rotation = to.angle()

	var step: float = SPEED * delta
	if dist <= maxf(step, ARRIVE_DISTANCE):
		global_position = _target_pos
		_push_trail()
		_impact()
		return

	global_position += to / dist * step
	_push_trail()

	# Swells through the middle of the flight and settles back down onto the
	# target: the shot reads as travelling over ground, not across a screen.
	var progress: float = clampf(1.0 - dist / _start_distance, 0.0, 1.0)
	var loft: float = 1.0 + sin(progress * PI) * LOFT
	_body.scale = Vector2.ONE * _size * loft
	_update_art(progress)

	_life += delta
	if _life > MAX_LIFE:
		_fade_out()

func _push_trail() -> void:
	if _trail == null:
		return
	_trail.add_point(global_position)
	while _trail.get_point_count() > TRAIL_POINTS:
		_trail.remove_point(0)

# The target is handed back to the callback rather than captured by it. A
# lambda that closes over the enemy holds a reference that goes stale the
# moment something else kills it, and calling through a freed capture is an
# error rather than a quiet miss -- which is exactly the case this shot is
# built to survive.
func _impact() -> void:
	_spent = true
	set_physics_process(false)
	if _on_hit.is_valid() and is_instance_valid(_target):
		_on_hit.call(_target)
	_dissolve()

func _fade_out() -> void:
	_spent = true
	set_physics_process(false)
	_dissolve()

# The head disappears on contact; the trail is left to burn out behind it.
func _dissolve() -> void:
	if _body != null:
		_body.visible = false
	var tw := create_tween()
	tw.tween_property(_trail, "modulate:a", 0.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)
