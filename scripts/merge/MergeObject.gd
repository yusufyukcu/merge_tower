extends RigidBody2D
class_name MergeObject

# A single physics-based material/unit in the merge area.
# `held`   -> currently being positioned by the player's finger: frozen, passed
#             straight through by everything else, and never merging.
# `merged` -> already consumed by a merge or SEND this frame; guards against
#             double-processing when multiple contacts are reported at once.

var unit_id: String = "wood"
var merged: bool = false

# A piece the player is still aiming is NOT part of the pile: it hangs over the
# well waiting to be let go. It used to hang there as a solid frozen body, which
# meant the piece dropped a moment earlier could land on top of it, get wedged
# above the danger line and lose the run with a nearly empty tray. Holding it is
# aiming, not stacking -- so it only becomes solid the moment it is released.
var held: bool = false:
	set(value):
		var was_held: bool = held
		held = value
		_apply_solidity()
		if was_held and not value:
			# Let go: stretched thin for the fall. The landing squash read
			# backwards -- anticipation on the way down, weight on the way in.
			_squash(-0.13, 0.26)

# Everything in the tray shares one layer: pieces collide with each other and
# with the three walls, nothing else.
const PIECE_LAYER := 1

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

var _def: Dictionary = {}
var _visual: Node2D = null
# The art's fitted scale, kept because every squash below has to spring back to
# it and reading it off the sprite mid-squash would read the squash instead.
var _base_scale: Vector2 = Vector2.ONE
var _radius: float = 34.0

func setup(id: String) -> void:
	unit_id = id
	_def = UnitDatabase.get_def(id)
	var radius: float = _def.get("radius", 34.0)
	_radius = radius

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)

	var art_path := UnitDatabase.get_art_path(id)
	if art_path != "":
		_visual = _build_sprite(art_path, radius)
		# White for anything drawn as itself; a stand-in borrowing another
		# piece's art is repainted here rather than in the file.
		_visual.modulate = UnitDatabase.get_art_tint(id)
		add_child(_visual)
	else:
		var visual := Polygon2D.new()
		visual.polygon = _circle_points(radius, 16)
		visual.color = _def.get("color", Color.WHITE)
		add_child(visual)
		_visual = visual

		var label := Label.new()
		label.text = str(_def.get("name", "")).left(4)
		label.add_theme_font_size_override("font_size", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(-radius, -radius)
		label.size = Vector2(radius * 2.0, radius * 2.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

	_base_scale = _visual.scale
	_play_spawn_animation()

func _play_spawn_animation() -> void:
	# Squash-stretch pop: shoot up thin, overshoot wide and short, then settle.
	# Reads as the piece landing with weight instead of just scaling in.
	#
	# Parked in the same slot the landing squash uses, because they deform the
	# same art: a piece that lands inside its own birth should be doing the
	# landing, not both at once.
	_visual.scale = Vector2(_base_scale.x * 0.25, _base_scale.y * 1.5)
	_squash_tween = create_tween()
	_squash_tween.tween_property(_visual, "scale",
			Vector2(_base_scale.x * 1.18, _base_scale.y * 0.86), 0.11) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(_visual, "scale", _base_scale, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

const SPRITE_VISUAL_SCALE := 1.3 # art renders relative to the physics collision circle for readability

func _build_sprite(art_path: String, radius: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(art_path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex_size: Vector2 = sprite.texture.get_size()
	var target_diameter := radius * 2.0 * SPRITE_VISUAL_SCALE
	var scale_factor: float = target_diameter / max(tex_size.x, tex_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	# A piece takes light, unlike the tray it is resting in: the bowls either
	# side of SEND reach the bottom of the pile, and a merge lights the whole
	# well for the moment it takes. No shading shader here though -- a piece
	# rolls, and a rim light that rolled with it would be a rim light coming
	# from underneath half the time.
	sprite.light_mask = Lighting.BODY_LAYER
	return sprite

func _circle_points(r: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a := TAU * i / segs
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _ready() -> void:
	add_to_group("merge_objects")
	contact_monitor = true
	max_contacts_reported = 6
	gravity_scale = 1.0
	linear_damp = 0.8
	angular_damp = 2.0
	# The piece may already have been marked held/merged before it was added to
	# the tree, so the state is applied rather than assumed.
	_apply_solidity()
	# Spread the resting sweeps below over frames instead of having every piece
	# in the tray run one on the same tick.
	_resting_timer = randf() * RESTING_INTERVAL

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.05
	mat.friction = 0.9
	physics_material_override = mat

	body_entered.connect(_on_body_entered)

# A piece is only part of the physics of the tray once it is in the tray: not
# while it hangs from the player's finger, and not once a merge or a SEND has
# claimed it. Anything else can pass straight through it.
func _apply_solidity() -> void:
	var solid: bool = not held and not merged
	collision_layer = PIECE_LAYER if solid else 0
	collision_mask = PIECE_LAYER if solid else 0

func _on_body_entered(body: Node) -> void:
	if merged or held:
		return
	if body is MergeObject:
		var other := body as MergeObject
		if not other.merged and not other.held and other.unit_id == unit_id:
			MergeManager.request_merge(self, other)
			# The merge burst is the feedback for this contact; a thud under it
			# would only be heard as the burst being muddy.
			return
	_land()

# ------------------------------------------------------------------- landing
#
# What a piece does the moment it arrives: flatten on the blow and spring back
# past round, kick up dust off the surface it hit, and speak -- lower the bigger
# it is, louder the harder it came down. Only the art is deformed; the collision
# circle stays a circle, so nothing the player has stacked is disturbed by any
# of it.
#
# The speed that matters is the one from the frame BEFORE the contact: by the
# time `body_entered` arrives the solver has already taken it away, which is why
# it is sampled every physics frame rather than read here.

# Measured against the tray the game actually has rather than picked: a piece
# let go at the top of the well reaches the floor at ~640 px/s and one dropped
# from halfway at ~465, so full strength is the full drop, and a piece shuffling
# a few pixels onto the pile falls under LAND_MIN_SPEED and stays quiet.
#
# A landing is felt on the piece and heard, never on the camera: the tray is
# where the player is aiming, and a screen that jolts every time something is
# put down makes the thing being aimed at the least steady part of it.
const LAND_MIN_SPEED := 190.0    # below this a contact is a nudge, not a landing
const LAND_MAX_SPEED := 660.0    # at or above it, a full-strength slam
const LAND_COOLDOWN := 0.14      # one landing per piece per settling, not per contact

var _speed: float = 0.0
var _land_cooldown: float = 0.0
var _squash_tween: Tween = null

func _land() -> void:
	if _land_cooldown > 0.0 or _speed < LAND_MIN_SPEED:
		return
	_land_cooldown = LAND_COOLDOWN
	var power: float = clampf(
		(_speed - LAND_MIN_SPEED) / (LAND_MAX_SPEED - LAND_MIN_SPEED), 0.0, 1.0)
	_squash(0.10 + 0.26 * power, 0.34)
	_dust(power)
	Sfx.land(_radius, 0.25 + 0.75 * power)

# Wide and short by `amount`, springing back elastic. Used by the landing, and
# by letting go of a piece -- the same deformation read backwards.
func _squash(amount: float, dur: float) -> void:
	if _visual == null or not is_inside_tree():
		return
	if _squash_tween != null and _squash_tween.is_valid():
		_squash_tween.kill()
	_visual.scale = Vector2(_base_scale.x * (1.0 + amount), _base_scale.y * (1.0 - amount))
	_squash_tween = create_tween()
	_squash_tween.tween_property(_visual, "scale", _base_scale, dur) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# Parented to the tray rather than to the piece: dust thrown up off a surface
# belongs to the surface, and a piece consumed by a merge a moment later should
# not take its own landing with it.
func _dust(power: float) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var p := FxUtil.burst(host, int(4 + 8 * power), 0.42, 40.0, 60.0 + 150.0 * power,
		Color(0.86, 0.80, 0.68, 0.5), Color(0.70, 0.63, 0.52, 0.0), false)
	p.global_position = global_position + Vector2(0, _radius * 0.7)
	p.direction = Vector2.UP
	p.spread = 82.0
	p.gravity = Vector2(0, 260)
	p.damping_min = 60.0
	p.damping_max = 130.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 3.2 + 2.0 * power
	p.scale_amount_curve = FxUtil.grow_curve()
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(
		func() -> void:
			if is_instance_valid(p):
				p.queue_free())

# ---------------------------------------------------------------- anticipation
#
# The piece on the finger breathes, so the thing the player is aiming is alive
# rather than pinned to the top of the screen; letting go stretches it thin for
# the fall. Both move the art alone -- the body underneath does not budge, and
# while it is held there is nothing for it to budge against anyway.

const BOB_PX := 3.5
const BOB_RATE := 3.6

var _bob_time: float = 0.0

func _process(delta: float) -> void:
	if _visual == null:
		return
	if held:
		_bob_time += delta
		_visual.position.y = -BOB_PX * (0.5 + 0.5 * sin(_bob_time * BOB_RATE))
	elif not _visual.position.is_zero_approx():
		_visual.position = _visual.position.move_toward(Vector2.ZERO, 90.0 * delta)

# `body_entered` only fires on the frame two pieces first touch. Whenever a
# merge is refused at exactly that moment -- the other piece was still held, or
# was already being consumed by a merge of its own -- the pair is left resting
# against each other with no second contact event ever coming, and sits there
# unmerged until something knocks it apart and back together again. That is what
# made merges arrive in bursts: several stuck pairs going off at once on the next
# jolt, where one merge should have resolved as it landed.
#
# So contacts are swept as well as listened for. A piece touching a twin merges
# on the spot, whatever the reason the contact itself was missed.
const RESTING_INTERVAL := 0.1
var _resting_timer: float = 0.0

func _physics_process(delta: float) -> void:
	# Sampled whatever the piece is doing, because a landing is measured by the
	# speed the piece had on its way in, not by what the solver left it with.
	_speed = linear_velocity.length()
	_land_cooldown = maxf(0.0, _land_cooldown - delta)

	if merged or held:
		return
	_resting_timer -= delta
	if _resting_timer > 0.0:
		return
	_resting_timer = RESTING_INTERVAL

	for body in get_colliding_bodies():
		if not (body is MergeObject):
			continue
		var other := body as MergeObject
		if other.merged or other.held or other.unit_id != unit_id:
			continue
		MergeManager.request_merge(self, other)
		return

# Wiped by the CLEAR button. Locks the piece out of merging and sending first,
# then drops it out of the simulation and shrinks the art away -- the body is
# only freed at the end, so a piece can never merge on its way out.
func dissolve() -> void:
	if merged:
		return
	merged = true
	held = true
	freeze = true
	collision_layer = 0
	collision_mask = 0

	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector2.ZERO, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(queue_free)

func is_deployable() -> bool:
	return bool(_def.get("is_unit", false)) and not merged and not held

func get_stats() -> Dictionary:
	return _def
