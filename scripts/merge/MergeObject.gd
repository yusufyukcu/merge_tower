extends RigidBody2D
class_name MergeObject

# A single physics-based material/unit in the merge area.
# `held`   -> currently being positioned by the player's finger (frozen, no merging).
# `merged` -> already consumed by a merge or SEND this frame; guards against
#             double-processing when multiple contacts are reported at once.

var unit_id: String = "wood"
var merged: bool = false
var held: bool = false

var _def: Dictionary = {}
var _visual: Node2D = null

func setup(id: String) -> void:
	unit_id = id
	_def = UnitDatabase.get_def(id)
	var radius: float = _def.get("radius", 34.0)

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

	_play_spawn_animation()

func _play_spawn_animation() -> void:
	# Squash-stretch pop: shoot up thin, overshoot wide and short, then settle.
	# Reads as the piece landing with weight instead of just scaling in.
	var base_scale: Vector2 = _visual.scale
	_visual.scale = Vector2(base_scale.x * 0.25, base_scale.y * 1.5)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector2(base_scale.x * 1.18, base_scale.y * 0.86), 0.11) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "scale", base_scale, 0.20) \
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

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.05
	mat.friction = 0.9
	physics_material_override = mat

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if merged or held:
		return
	if body is MergeObject:
		var other := body as MergeObject
		if other.merged or other.held:
			return
		if other.unit_id == unit_id:
			MergeManager.request_merge(self, other)

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
