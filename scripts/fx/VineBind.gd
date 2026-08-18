extends Node2D
class_name VineBind

const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# What being caught by a vine looks like from the outside, in two parts that
# outlive each other: the creeper that holds the body still, and the rot that
# keeps working for a while after the creeper lets go.
#
# The creeper is the same sprig the mage throws, laid across the body in bands
# -- and every other band is drawn *behind* the body rather than on it. That is
# the whole trick: a vine painted entirely on top of an enemy reads as a sticker,
# and the only thing that makes it read as wrapped is seeing it disappear behind
# the shoulder and come out the other side.
#
# Behind is done with tree order rather than a negative z_index: the enemy sits
# on the same layer as the arena art, so anything given a z below it vanishes
# under the ground instead of under the body.

const TEX_VINE := "res://art/fx_vine_1.png"
const TEX_BUBBLES := "res://art/fx_poison_1.png"

const BANDS := 4
const VINE := Color(0.42, 0.86, 0.30)
const VINE_DEEP := Color(0.18, 0.52, 0.16)

var _root_left: float = 0.0
var _poison_left: float = 0.0
var _phase: float = 0.0
var _radius: float = 28.0

var _back: Node2D = null        # sibling, drawn before the body
var _bands: Array = []          # [{ "node": Sprite2D, "y": float, "w": float }]
var _bubbles: Sprite2D = null

# `with_bands` is what a poison with no hold behind it turns off. The dartmaster
# rots a body without tying it down, and a creeper wound round something that is
# still walking freely reads as a bug rather than as venom.
func setup(radius: float, with_bands: bool = true) -> void:
	_radius = radius
	z_index = 1   # the front half, over the body, under the health bar

	var host := get_parent()
	if host != null:
		_back = Node2D.new()
		host.add_child(_back)
		# First child: same layer as the body, drawn just before it.
		host.move_child(_back, 0)

	if with_bands:
		_build_bands()

	if ResourceLoader.exists(TEX_BUBBLES):
		_bubbles = Sprite2D.new()
		_bubbles.texture = load(TEX_BUBBLES)
		_bubbles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var btex: Vector2 = _bubbles.texture.get_size()
		var bs: float = (radius * 2.4) / btex.x
		_bubbles.scale = Vector2(bs, bs)
		_bubbles.modulate.a = 0.0
		add_child(_bubbles)

	# The catch itself: the ground snaps shut around the feet.
	var grab := FxUtil.burst(self, 9, 0.4, 60.0, 150.0, VINE, Color(VINE_DEEP, 0.0), false)
	grab.position = Vector2(0, radius * 0.45)
	grab.direction = Vector2.UP
	grab.spread = 80.0
	grab.gravity = Vector2(0, 340)
	grab.emitting = true

# Bands are laid from the shoulders down to the shins and alternate which side
# of the body they pass on, so the eye joins them up into one creeper going
# round and round rather than four lying on top of each other.
func _build_bands() -> void:
	if not ResourceLoader.exists(TEX_VINE):
		return
	var tex: Texture2D = load(TEX_VINE)
	var tex_w: float = maxf(float(tex.get_width()), 1.0)

	for i in range(BANDS):
		var t: float = float(i) / float(BANDS - 1)          # 0 at the top
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		# Widest around the middle of the body and tighter at the ends, which is
		# what a coil does when it is wound round something roughly oval.
		var span: float = _radius * (1.75 + 0.55 * sin(t * PI))
		var k: float = span / tex_w
		s.scale = Vector2(k, k)
		s.flip_h = (i % 2) == 1        # so four copies do not read as four copies
		s.rotation = deg_to_rad(-7.0 + 14.0 * t)
		s.modulate.a = 0.0

		var y: float = -_radius * 0.55 + t * _radius * 1.15
		s.position = Vector2(0, y)

		# Even bands behind the body, odd bands in front of it.
		if i % 2 == 0 and _back != null:
			_back.add_child(s)
		else:
			add_child(s)

		_bands.append({"node": s, "y": y, "k": k})

		# Tightens rather than appears: each band starts loose and wide and is
		# drawn in, a beat after the one above it.
		s.scale.x = k * 1.5
		var tw := create_tween()
		tw.tween_interval(i * 0.045)
		tw.tween_property(s, "modulate:a", 1.0, 0.10)
		tw.parallel().tween_property(s, "scale:x", k, 0.26) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func refresh(root_seconds: float, poison_seconds: float) -> void:
	if root_seconds > 0.0 and _root_left <= 0.0 and _bands.is_empty():
		_build_bands()
	_root_left = maxf(_root_left, root_seconds)
	_poison_left = maxf(_poison_left, poison_seconds)

func _process(delta: float) -> void:
	_phase += delta
	_root_left -= delta
	_poison_left -= delta

	# Never quite still while it is holding on: each band creeps on its own beat.
	if not _bands.is_empty():
		for i in range(_bands.size()):
			var b: Dictionary = _bands[i]
			var node: Sprite2D = b["node"]
			if not is_instance_valid(node):
				continue
			var breathe: float = 1.0 + sin(_phase * 2.6 + i * 1.3) * 0.035
			node.scale.x = float(b["k"]) * breathe
			node.position.y = float(b["y"]) + sin(_phase * 2.0 + i) * _radius * 0.02

		if _root_left <= 0.0:
			_release_bands()

	# The rot: bubbles rising off the body, drifting and thinning as they go.
	if _bubbles != null:
		if _poison_left > 0.0:
			var rise: float = fposmod(_phase * 0.55, 1.0)
			_bubbles.position = Vector2(sin(_phase * 1.7) * _radius * 0.12,
				-_radius * 0.4 - rise * _radius * 1.4)
			_bubbles.modulate.a = sin(rise * PI) * 0.95
		else:
			_bubbles.modulate.a = maxf(0.0, _bubbles.modulate.a - delta * 2.0)

	if _root_left <= 0.0 and _poison_left <= -0.4:
		set_process(false)
		if _back != null and is_instance_valid(_back):
			_back.queue_free()
		queue_free()

# Lets go: the bands slacken outward and fade, and the list empties so a second
# vine landing during the rot builds a fresh coil rather than finding a stale one.
func _release_bands() -> void:
	for b in _bands:
		var node: Sprite2D = b["node"]
		if not is_instance_valid(node):
			continue
		var tw := create_tween()
		tw.tween_property(node, "modulate:a", 0.0, 0.28)
		tw.parallel().tween_property(node, "scale:x", float(b["k"]) * 1.35, 0.28)
		tw.parallel().tween_property(node, "position:y",
			node.position.y + _radius * 0.35, 0.28)
		tw.tween_callback(node.queue_free)
	_bands.clear()
