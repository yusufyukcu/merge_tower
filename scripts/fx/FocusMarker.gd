extends Node2D

# The one body the player has picked out, marked so there is never a question
# about which one the line is shooting at.
#
# It follows its target rather than being placed once: the thing it is marking
# is walking, and a reticle left behind on the ground where the enemy used to be
# would be worse than no reticle at all. It follows the drawn body rather than
# the feet, too -- a dragon is painted a hundred and thirty pixels above the
# patch of ground it occupies, and the player is aiming at the dragon.
#
# Drawn rather than built out of sprites: it is four brackets and a ring, it
# spins, and there is only ever one of them on the field.

const COLOR := Color(1.0, 0.44, 0.36)
const SEGMENTS := 40
const SPIN := 0.55            # turns per second
const BREATH := 1.1           # seconds per pulse

var _target: Enemy = null
var _radius: float = 44.0
var _phase: float = 0.0
var _spin: float = 0.0
var _fade: float = 0.0

func follow(enemy: Enemy) -> void:
	_target = enemy
	_radius = enemy.tap_radius()
	z_index = 70
	position = enemy.tap_point()

	var tw := create_tween()
	tw.tween_method(_set_fade, 0.0, 1.0, 0.14)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.24) \
		.from(Vector2(1.55, 1.55)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Fades out and goes, so an order being called off reads as one rather than as
# the marker blinking out of existence.
func release() -> void:
	_target = null
	var tw := create_tween()
	tw.tween_method(_set_fade, _fade, 0.0, 0.14)
	tw.parallel().tween_property(self, "scale", Vector2(1.4, 1.4), 0.14)
	tw.tween_callback(queue_free)

func _set_fade(v: float) -> void:
	_fade = v
	queue_redraw()

func _process(delta: float) -> void:
	_phase += delta
	_spin += delta * SPIN * TAU
	if _target != null:
		if not is_instance_valid(_target) or not _target.is_alive():
			# CombatManager clears the focus on the same death, and that is what
			# normally takes this node away. Letting go here as well means a
			# marker is never left riding a corpse for a frame.
			_target = null
		else:
			position = _target.tap_point()
			_radius = _target.tap_radius()
	queue_redraw()

func _draw() -> void:
	if _fade <= 0.01:
		return

	var breath: float = 0.5 + 0.5 * sin(_phase * TAU / BREATH)
	var r: float = _radius * (1.0 + 0.05 * breath)

	# The ring: thin, and dim enough that the body inside it is still the thing
	# being looked at.
	var ring := COLOR
	ring.a = (0.34 + 0.16 * breath) * _fade
	draw_arc(Vector2.ZERO, r, 0.0, TAU, SEGMENTS, ring, 3.0, true)

	# Four brackets outside it, turning slowly. They are what makes the mark read
	# as aimed rather than as a circle somebody drew on the floor.
	var arm: float = COLOR.a
	arm = (0.85 + 0.15 * breath) * _fade
	var bracket := COLOR
	bracket.a = arm
	var span: float = PI / 9.0
	var out: float = r * 1.24
	for i in range(4):
		var mid: float = _spin + TAU * float(i) / 4.0
		draw_arc(Vector2.ZERO, out, mid - span, mid + span, 10, bracket, 5.0, true)
