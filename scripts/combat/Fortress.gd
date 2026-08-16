extends Node2D
class_name Fortress

const ImpactEffect = preload("res://scripts/fx/ImpactEffect.gd")

signal hp_changed(current: float, max_hp: float)
signal died

const MAX_LEVEL := 5
const VISUAL_DIAMETER := 220.0

var max_hp: float = 100.0
var hp: float = 100.0
var level: int = 1

var _visual: CanvasItem
var _sprite: Sprite2D
var _lit: ShaderMaterial = null
var _shade_stamp: int = -1

# ------------------------------------------------------------------ the hearth
#
# The keep is the only thing standing on the crossroads that the painting did
# not draw, so it is the only thing there with no light of its own. After dark
# that shows immediately: twelve signposts burning around a black castle.
#
# So it gets a fire. Not a torch on the wall -- the whole building glows, the
# way a keep full of people does at night, and it answers to what is happening
# to it. At full health it is a steady warm hall; as the walls come down it
# guts, reddens and starts to beat, and a player who never once looks at the
# health bar still knows exactly how the run is going.
const HEARTH_RADIUS := 300.0
const HEARTH_WARM := Color(1.0, 0.72, 0.34)
const HEARTH_HURT := Color(1.0, 0.34, 0.14)

var _hearth: PointLight2D = null
var _hearth_phase: float = 0.0
var _shade_timer: float = 0.0

func _ready() -> void:
	_build_visual()
	hp = max_hp

func _build_visual() -> void:
	var art_path := UnitDatabase.get_art_path("castle_%d" % level)
	if art_path != "":
		_sprite = Sprite2D.new()
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Lit like a body rather than like scenery, because that is what it is:
		# the one building in the picture that is not painted into the map, and
		# the only one that would otherwise stay at noon all night. Its shape is
		# held back to a fraction of a soldier's -- a keep is a box of walls, and
		# rounding it off the way a sphere is rounded reads as a haystack.
		_lit = Lighting.body_material()
		_sprite.material = _lit
		_sprite.light_mask = Lighting.BODY_LAYER
		add_child(_sprite)
		_visual = _sprite
		_apply_art(art_path)
		_build_hearth()
		return

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-70, -55), Vector2(70, -55), Vector2(70, 55), Vector2(-70, 55)
	])
	body.color = Color(0.5, 0.5, 0.58)
	add_child(body)
	_visual = body

	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-80, -55), Vector2(0, -100), Vector2(80, -55)
	])
	roof.color = Color(0.6, 0.25, 0.25)
	add_child(roof)

	var label := Label.new()
	label.text = "FORTRESS"
	label.add_theme_font_size_override("font_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-70, -15)
	label.size = Vector2(140, 30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _build_hearth() -> void:
	_hearth = Lighting.fire_light(self, HEARTH_WARM, HEARTH_RADIUS)
	_hearth.position = Vector2(0, -12.0)
	# Registered as a fire so the line drawn up in front of the keep throws its
	# shadows out toward the road the enemy is coming down, rather than back
	# against the wall it is standing to defend.
	Lighting.add_fire(global_position, 1.2, 0.9)

func _process(delta: float) -> void:
	var stamp: int = Lighting.body_stamp(false)
	if stamp != _shade_stamp:
		_shade_stamp = stamp
		Lighting.tune_body(_lit, false, 0.45)
	if _hearth == null:
		return

	_hearth_phase += delta
	# How hard the fire is being pushed. A whole keep does not gutter like a
	# candle: at full health this is very nearly a steady light, and it only
	# starts to move once there is something wrong with the building. By the
	# last quarter it is beating, and it is red.
	var hurt: float = 1.0 - clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var beat: float = 0.05 + 0.34 * hurt * hurt
	var f: float = 1.0 + beat * (sin(_hearth_phase * (2.1 + 5.4 * hurt)) \
		+ 0.4 * sin(_hearth_phase * 7.3 + 1.1))
	_hearth.color = HEARTH_WARM.lerp(HEARTH_HURT, hurt * 0.85)
	_hearth.energy = (0.10 + 0.72 * Lighting.night()) * f * (1.0 + 0.4 * hurt)

func set_level(new_level: int) -> void:
	new_level = clamp(new_level, 1, MAX_LEVEL)
	if new_level == level:
		return
	level = new_level
	var art_path := UnitDatabase.get_art_path("castle_%d" % level)
	if art_path != "" and _sprite != null:
		_apply_art(art_path)

# The castle is hung by its weight rather than by its canvas.
#
# Every castle_N.png is a heavy mound of walls under a thin spire and a flag, so
# the middle of the file sits well above the middle of the building. Centred on
# the crossroads the way any sprite would be, the castle reads as standing just
# below the plaza instead of on it. Pinning the alpha-weighted centre of the
# picture to the node puts the mass of the building on the crossing, and it
# re-measures itself whenever a level changes the art -- a nudge per level, hand
# picked off a screenshot, would go stale the moment a castle was redrawn.
func _apply_art(path: String) -> void:
	_sprite.texture = load(path)
	var tex_size: Vector2 = _sprite.texture.get_size()
	var scale_factor: float = VISUAL_DIAMETER / max(tex_size.x, tex_size.y)
	_sprite.scale = Vector2(scale_factor, scale_factor)
	# Sprite2D.offset is in texture pixels, applied before the scale above.
	_sprite.offset.y = tex_size.y * 0.5 - _ink_center_y(_sprite.texture)

# Where the ink actually sits, down the picture, in texture pixels. Sampled on a
# grid rather than pixel by pixel -- this is an average over some 200x200
# pixels, and every second one gives the same answer for a quarter of the work.
const INK_SAMPLE_STEP := 2

func _ink_center_y(tex: Texture2D) -> float:
	var img: Image = tex.get_image()
	if img == null:
		return tex.get_size().y * 0.5
	if img.is_compressed():
		img.decompress()

	var w: int = img.get_width()
	var h: int = img.get_height()
	var total: float = 0.0
	var weighted: float = 0.0
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			var a: float = img.get_pixel(x, y).a
			total += a
			weighted += a * float(y)
			x += INK_SAMPLE_STEP
		y += INK_SAMPLE_STEP
	# A picture with nothing in it is left where it is rather than divided by zero.
	if total <= 0.0:
		return float(h) * 0.5
	return weighted / total

func grow_max_hp(flat_amount: float) -> void:
	max_hp += flat_amount
	hp += flat_amount
	hp_changed.emit(hp, max_hp)

func heal_percent(base_max_hp: float, percent: float) -> void:
	hp = min(max_hp, hp + base_max_hp * percent)
	hp_changed.emit(hp, max_hp)

# Flat repair between waves. Silent when already full, so the HUD does not
# pulse for a heal that did nothing.
func heal(amount: float) -> void:
	if amount <= 0.0 or hp >= max_hp or hp <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)

# Where along the line to the attacker the rubble bursts. Enemies stop and
# swing from ~100px out, so this has to stay well inside that or the effect
# lands next to the enemy and reads as coming off the enemy instead of the
# masonry. A third of the visual radius puts it on the wall face.
const WALL_OFFSET := 36.0

func take_damage(amount: float, from_position: Vector2 = Vector2.INF) -> void:
	if hp <= 0:
		return
	hp = max(0.0, hp - amount)
	hp_changed.emit(hp, max_hp)
	_flash()
	_spawn_hit_fx(amount, from_position)
	if hp <= 0:
		died.emit()

func _spawn_hit_fx(amount: float, from_position: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	# Off the middle of the building rather than the middle of the node: the art
	# is hung a little above its position (see _apply_art), and rubble a hand's
	# width below the wall it came off reads as coming off the ground.
	var center := _visual_center()
	var from_dir := Vector2.ZERO
	if from_position.is_finite():
		from_dir = (from_position - center).normalized()

	var fx := ImpactEffect.new()
	host.add_child(fx)
	fx.global_position = center + from_dir * WALL_OFFSET
	fx.play_castle_hit(from_dir, amount / maxf(1.0, max_hp * 0.12))

func _visual_center() -> Vector2:
	if _sprite == null:
		return global_position
	return global_position + Vector2(0.0, _sprite.offset.y * _sprite.scale.y)

func _flash() -> void:
	var tw := create_tween()
	tw.tween_property(_visual, "modulate", Color(1, 0.4, 0.4), 0.08)
	tw.tween_property(_visual, "modulate", Color(1, 1, 1), 0.15)
