extends Node2D

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# What the zombie lord leaves where something he bit went down: a small skull
# pushed up out of the ground, glowing faintly, that settles and rots away again
# after half a minute.
#
# It used to be a marker and nothing else -- it did no damage, blocked nothing,
# and was never counted by anything. That is no longer true, and the change is
# the whole of what his ability spends: each of these remembers what fell here,
# and RISE OF THE DAMNED turns every one still standing into that creature's
# zombie, fighting for us. The trail of skulls down whichever lane he is holding
# is now a resource the player can watch accumulating and choose when to cash.
#
# It is still not a unit: nothing can attack it, it holds no lane, and it costs
# nothing to leave lying there. What it costs is time -- LIFETIME is long enough
# that a good wave leaves a row of them and short enough that they cannot be
# hoarded across a whole run.
#
# Parented to the ground layer rather than to anything that fought, because both
# the body that died and the hero that killed it are routinely gone before this
# has finished fading.

const TEX := "res://art/icon_skull.png"
const TINT := Color(0.62, 1.0, 0.52)

const RISE := 16.0        # how far it pushes up out of the ground
const HOLD := 28.0        # how long it stands before it starts to go
const FADE := 2.0
const LIFETIME := HOLD + FADE

var _skull: Sprite2D = null
var _glow: Sprite2D = null
var _phase: float = 0.0

# What died here, and how big it was. Both are read back by the ability: the
# first decides which zombie stands up and how hard it hits, the second how
# large it is drawn.
var enemy_id: String = ""
var body_size: float = 1.0
# Set the moment the ability claims this one, so a second press in the same
# frame -- or the tween that was already fading it -- cannot raise it twice.
var _spent: bool = false

# `size` scales the whole mark off the body that fell, so a goblin leaves a
# smaller skull than a golem does.
func play(size: float = 1.0, from_enemy: String = "") -> void:
	z_index = 4
	enemy_id = from_enemy
	body_size = size

	_glow = FxUtil.bloom(self, 0.0, 0.0, TINT, 96)
	_glow.position = Vector2(0, -18.0 * size)

	if ResourceLoader.exists(TEX):
		_skull = Sprite2D.new()
		_skull.texture = load(TEX)
		_skull.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex: Vector2 = _skull.texture.get_size()
		var k: float = (34.0 * size) / maxf(tex.y, 1.0)
		_skull.scale = Vector2(k, k)
		_skull.modulate = Color(0.86, 1.0, 0.80, 0.0)
		add_child(_skull)

	# The ground opens first and the skull comes up out of it, rather than the
	# skull simply appearing: the puff is what says it was pushed up.
	var soil := FxUtil.burst(self, 10, 0.45, 50.0, 150.0,
		Color(0.72, 1.0, 0.62, 1.0), Color(0.18, 0.42, 0.16, 0.0))
	soil.direction = Vector2.UP
	soil.spread = 70.0
	soil.gravity = Vector2(0, 260)
	soil.emitting = true

	var tw := create_tween()
	tw.tween_property(_glow, "scale", Vector2.ONE * 0.30 * size, 0.28)
	tw.parallel().tween_property(_glow, "modulate:a", 0.55, 0.28)
	if _skull != null:
		_skull.position = Vector2(0, 6.0 * size)
		tw.parallel().tween_property(_skull, "modulate:a", 1.0, 0.18)
		tw.parallel().tween_property(_skull, "position:y", -RISE * size, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.tween_interval(HOLD)
	tw.tween_property(self, "modulate:a", 0.0, FADE)
	tw.tween_callback(queue_free)

	set_process(true)

# Whether this one can still be called up. A mark that is mid-fade is still
# standing as far as the ability is concerned -- the player can see it, so it
# has to work -- but one already claimed this cast is not.
func is_raisable() -> bool:
	return not _spent and enemy_id != ""

# Claimed by the ability. The skull itself goes now, quickly and upward, because
# what replaces it is about to come up out of the same patch of ground and the
# two must not be on screen together.
func consume() -> void:
	if _spent:
		return
	_spent = true
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.35, 0.55), 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(queue_free)

# Never quite still while it stands: the glow behind it breathes, which is what
# separates a skull that was put there by something from a decoration.
func _process(delta: float) -> void:
	_phase += delta
	# Held off until the rise is over: that beat belongs to the tween above, and
	# two things writing one alpha in the same frame is a flicker.
	if _phase > 0.30 and _glow != null and is_instance_valid(_glow):
		_glow.modulate.a = 0.35 + 0.22 * (0.5 + 0.5 * sin(_phase * 2.2))
	if _skull != null and is_instance_valid(_skull):
		_skull.rotation = sin(_phase * 1.4) * 0.06
