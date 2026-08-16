extends Node2D
class_name IceBeam

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# The ice dragon's breath, drawn as one stretched sprite from its mouth to
# whatever it is burning.
#
# The sheet paints the beam pointing right at a fixed length, which is no use to
# a dragon that has to sweep it across a line of soldiers: it is cut away from
# the dragon (art/ice_dragon_beam.png) and hung here instead, anchored at the
# mouth end so it can be turned and stretched to reach.
#
# It is drawn from the left edge rather than the centre for exactly that reason:
# scaling a centred sprite would push the beam back out of the dragon's mouth as
# it lengthened.

const TEX := "res://art/ice_dragon_beam.png"
# What the beam is worth at its own painted length, so a short beam is not a
# squashed one -- past this it stretches, under it, it is simply cut short.
const FLICKER := 0.10

var _sprite: Sprite2D = null
var _tex_size: Vector2 = Vector2.ONE
var _phase: float = 0.0

func _ready() -> void:
	if not ResourceLoader.exists(TEX):
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(TEX)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	_tex_size = _sprite.texture.get_size()
	# Origin at the middle of the left edge: the mouth.
	_sprite.offset = Vector2(0, -_tex_size.y * 0.5)
	add_child(_sprite)

	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.18)

# `from` and `to` are in the parent's space -- the dragon's own -- so the beam
# tracks the mouth without a frame of lag behind it.
func aim(from: Vector2, to: Vector2, thickness: float) -> void:
	if _sprite == null:
		return
	position = from
	var d: Vector2 = to - from
	var length: float = maxf(d.length(), 40.0)
	rotation = d.angle()
	_sprite.scale = Vector2(length / _tex_size.x, thickness)

func _process(delta: float) -> void:
	if _sprite == null:
		return
	# The stream is never quite steady: it breathes along its own length and
	# flickers, which is the difference between a jet of ice and a blue bar.
	_phase += delta * 9.0
	_sprite.modulate.a = 0.86 + FLICKER * sin(_phase)
	_sprite.skew = sin(_phase * 0.41) * 0.03

# Closes from the mouth outward rather than fading on the spot, so the last of
# it is seen leaving.
func fade_out() -> void:
	set_process(false)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.22)
	if _sprite != null:
		t.parallel().tween_property(_sprite, "scale:y", 0.1, 0.22)
	t.tween_callback(queue_free)
