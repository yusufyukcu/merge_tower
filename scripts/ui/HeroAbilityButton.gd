extends Control

const UIStyle = preload("res://scripts/ui/UIStyle.gd")

# The hero's cast, as a thing on the screen rather than a line on a card.
#
# Every other special in the game is reached by tapping the unit and finding the
# button on its card. That is right for them -- there can be a dozen units with
# one, and none of them is the unit the run is about. The hero is, there is
# exactly one of it, and its blow is the loudest thing the player can do; so it
# gets a permanent seat over the shop, lit or dark, that says at a glance
# whether the run's best answer is available.
#
# The plates are cut from the hero's own button sheet -- art/<hero>_button.png,
# which draws idle, hover, pressed, cooldown, disabled and a ready glow. Four of
# those are files here and all four are the same square with the disc in the
# same place, so a state change swaps a texture and nothing moves. The two that
# are not files are the two that carry live numbers: the cooldown ring is drawn
# to the sheet's design underneath, because a painted "12" cannot count down.

signal cast_requested

# What fraction of the plate's square the drawn disc actually fills. The plates
# are cut on a fixed square with the disc concentric in it and the outer rim at
# about this much of the width, measured off the files rather than guessed --
# which is what lets the hit box be the disc rather than the square it is
# painted in.
const RING_FRACTION := 0.73

# And where the cooldown arc is drawn, which is a little inside that: the sheet
# runs its arc around the stone ring, between the ring and the gems at the
# compass points. Pushed out to the rim it stops looking like part of the button
# and starts looking like a circle somebody drew on the grass behind it.
const SWEEP_FRACTION := 0.60
const SWEEP_WIDTH := 0.075

# What the plate is knocked back to while the wait runs.
const COOLING := Color(0.52, 0.54, 0.60, 1.0)

var _plate: TextureRect = null
var _sweep: Control = null
var _time: Label = null
var _note: Label = null
var _hit: Button = null
var _pulse: Tween = null

var _art_key: String = ""
var _state: String = ""
var _held: bool = false
var _fill: float = 0.0        # 0 empty, 1 charged -- what the arc draws
var _tint: Color = Color(1, 1, 1)

func build(box: float) -> void:
	size = Vector2(box, box)
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_plate = TextureRect.new()
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Without this the control's minimum size is the texture's own, and a 257px
	# plate refuses to be drawn at the size it is given.
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_SCALE
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	# Drawn over the plate rather than into it: the sheet paints a number into
	# its cooldown state, and a painted number cannot count.
	_sweep = Control.new()
	_sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweep.draw.connect(_draw_sweep)
	add_child(_sweep)

	_time = Label.new()
	_time.set_anchors_preset(Control.PRESET_FULL_RECT)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time.add_theme_font_size_override("font_size", int(box * 0.30))
	_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(_time, UIStyle.TEXT_LIGHT, 7)
	add_child(_time)

	# Sits under the plate rather than on it, so the locked state can say what
	# unlocks it without writing over the drawing.
	_note = Label.new()
	_note.position = Vector2(-box * 0.25, box * 0.86)
	_note.size = Vector2(box * 1.5, box * 0.22)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", int(box * 0.15))
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(_note, UIStyle.ACCENT_GOLD, 5)
	add_child(_note)

	# The hit box is the disc and not the square: the corners of this control are
	# empty, and a thumb landing on one of them should reach whatever is behind.
	var ring: float = box * RING_FRACTION
	_hit = Button.new()
	_hit.text = ""
	_hit.position = Vector2((box - ring) * 0.5, (box - ring) * 0.5)
	_hit.size = Vector2(ring, ring)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_hit.pressed.connect(func() -> void: cast_requested.emit())
	_hit.button_down.connect(func() -> void: _set_held(true))
	_hit.button_up.connect(func() -> void: _set_held(false))
	add_child(_hit)

# Everything this shows comes off the hero, and it is asked once a frame -- the
# cooldown is a number that moves, and there is nowhere else for it to come
# from. `d` is null whenever there is no hero on the field, which is also how
# the button is hidden.
func refresh(d: Defender) -> void:
	if d == null or not is_instance_valid(d) or not d.is_alive() or not d.has_ability():
		visible = false
		return
	if not UnitDatabase.is_hero(d.unit_id):
		visible = false
		return

	var key: String = UnitDatabase.hero_art_key(d.unit_id)
	# A hero can be given an ability in the table before its button is drawn.
	# Rather than showing an empty square, it simply has no button until the
	# plates turn up.
	if not ResourceLoader.exists("res://art/%s_button_idle.png" % key):
		visible = false
		return
	if key != _art_key:
		_art_key = key
		_state = ""
		_tint = d.ability_def().get("color", Color(1, 1, 1))
		_apply_state("off")
	visible = true

	if not d.ability_unlocked():
		_apply_state("off")
		_hit.disabled = true
		_time.text = ""
		_note.text = "LV %d" % d.ability_level()
		_note.visible = true
		_set_fill(0.0)
		return

	_note.visible = false
	var left: float = d.ability_cooldown_left()
	if left > 0.0:
		_apply_state("idle")
		_hit.disabled = true
		# Rounded up, so a button reading 1 is never already pressable and a
		# button reading 0 never sits there for a frame.
		_time.text = str(int(ceil(left)))
		var total: float = maxf(d.ability_cooldown_total(), 0.001)
		_set_fill(clampf(1.0 - left / total, 0.0, 1.0))
		return

	_apply_state("press" if _held else "ready")
	_hit.disabled = false
	_time.text = ""
	_set_fill(0.0)

func _set_held(down: bool) -> void:
	if _held == down:
		return
	_held = down
	# Only ever a look. Whether the press does anything is the button's business
	# and was settled by `disabled` before the finger landed.
	if _state == "off":
		return
	scale = Vector2.ONE * (0.94 if down else 1.0)

# The one place a state change is spent. Everything it sets is set once on the
# way in rather than every frame the state happens to still be true, which is
# what keeps `refresh` -- called once a frame for the whole run -- down to a
# couple of comparisons and a string.
func _apply_state(want: String) -> void:
	if want == _state:
		return
	_state = want
	var path := "res://art/%s_button_%s.png" % [_art_key, want]
	if ResourceLoader.exists(path):
		_plate.texture = load(path)
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()

	# "idle" is only ever reached while the wait is running, and the sheet draws
	# that state a good deal darker than the plate it is cut from: the number
	# written across the middle has to be the brightest thing on the button.
	if want == "idle":
		_plate.modulate = COOLING
		_time.add_theme_color_override("font_color", _tint.lerp(Color(1, 1, 1), 0.55))
		return
	# A ready button breathes. It is the one state worth catching out of the
	# corner of an eye during a wave, and a still picture never is.
	if want != "ready":
		_plate.modulate = Color(1, 1, 1, 1)
		return
	_pulse = create_tween()
	_pulse.set_loops()
	_pulse.tween_property(_plate, "modulate", Color(1.18, 1.18, 1.18, 1.0), 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_plate, "modulate", Color(1, 1, 1, 1), 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_fill(v: float) -> void:
	if is_equal_approx(v, _fill):
		return
	_fill = v
	_sweep.queue_redraw()

# The cooldown ring, to the sheet's own design: the plate goes dark and a bright
# arc walks around the rim as the wait burns off, so the button is readable as
# "nearly back" without the number being read at all.
func _draw_sweep() -> void:
	if _fill <= 0.0:
		return
	var box: float = size.x
	var mid := Vector2(box, box) * 0.5
	var radius: float = box * SWEEP_FRACTION * 0.5
	var width: float = box * SWEEP_WIDTH

	# Everything still owed, dimmed. Drawn as the arc that has *not* filled, so
	# the two together always make one whole ring and the button never has a gap
	# in it.
	var from: float = -PI / 2.0 + TAU * _fill
	_sweep.draw_arc(mid, radius, from, -PI / 2.0 + TAU,
		48, Color(0.02, 0.02, 0.05, 0.60), width, true)
	_sweep.draw_arc(mid, radius, -PI / 2.0, from,
		48, Color(_tint.r, _tint.g, _tint.b, 0.95), width, true)
