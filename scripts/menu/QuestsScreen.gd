extends Control

const UIStyle = preload("res://scripts/ui/UIStyle.gd")

# The quest board, as one painted plate -- art/quests.png -- with the handful
# of things a picture cannot do laid over it.
#
# Built the same way the shop's three plates are: the frame, the title, the six
# icons, the six lines of wording and the six rewards are all in the picture,
# and the only things this script draws are the ones that have to answer to
# what the player has actually done -- the progress bars, the counts, the
# refresh clock, and the plate on each row that says whether there is anything
# to take.
#
# The plate is 1023x1537 against a 1080x1920 screen. It is held to nine tenths
# of that width and centred, over a dim rather than over black, so the menu is
# still there around the edges and the board reads as something laid on top of
# the screen instead of as somewhere the player has gone. The hero shelf and the
# pack are held to the same fraction.
#
# One thing about the picture is worth saying out loud, because everything
# below is shaped by it: it was drawn with its first three quests finished and
# its last three not. That is why the first three rows are taller -- they have
# a CLAIM plate under the reward and the short ones have nowhere to put one.
# Rather than sort the board so the tall rows are always the finished ones,
# which would move a line out from under its own icon, each row keeps its place
# and the plate goes wherever that row has room for it: in the painted CLAIM
# slot on a tall row, and over the progress bar on a short one, where by then
# the bar is full and has nothing left to say.

signal closed

const ART := "res://art/quests.png"
const ART_SIZE := Vector2(1023.0, 1537.0)

# ------------------------------------------------------------------ the plan
#
# Every rect below is in the painting's own pixels, measured off the plate, and
# goes through _at().

const CLOSE_RECT := Rect2(905, 22, 100, 96)
# The red count on the DAILY QUESTS tab, and the clock line under it.
const TAB_BADGE_MID := Vector2(410.0, 335.0)
const TAB_BADGE_R := 21.0
const REFRESH_RECT := Rect2(572, 420, 118, 34)

# The painting was drawn with three quests finished and waiting, so a red 3 is
# pinned to the corner of the DAILY QUESTS tab. That is a reading rather than
# decoration, and this board has to be able to say a different number -- or,
# far more often, nothing at all.
#
# It cannot be wiped the way the bars and the clock are: it straddles the tab's
# top-right corner, which is a gold bevel over stonework rather than one flat
# colour, so a patch of any single colour leaves a disc sitting on the tab. What
# goes over it instead is that corner, put back: art/quests_tab_clean.png is the
# tab's own top-LEFT corner mirrored across the plate's centre line (the tab is
# symmetric about x=253), faded out at its edges so the join does not show.
const TAB_PATCH_ART := "res://art/quests_tab_clean.png"
const TAB_PATCH_RECT := Rect2(372, 292, 80, 84)

# The six rows, by the middle of each progress bar. The pitch is not even: the
# first three rows are the tall ones.
const BAR_MID := [590.0, 776.0, 965.0, 1128.0, 1283.0, 1436.0]
const BAR_X := 236.0
const BAR_W := 335.0
const BAR_H := 26.0
const COUNT_X := 584.0
const COUNT_W := 92.0

# Where the painting put a CLAIM plate, which is only on the three tall rows.
const CLAIM_RECTS := [
	Rect2(717, 562, 216, 57),
	Rect2(717, 753, 216, 57),
	Rect2(717, 940, 216, 57),
]
# And the red "!" beside each of those three.
const ROW_BADGE_MID := [496.0, 682.0, 872.0]
const ROW_BADGE_X := 947.0
const ROW_BADGE_R := 22.0

# A row card runs from x=48 to x=975, so a point on it and its opposite number
# add up to 1023 -- which is what lets the corner under a row's badge be
# borrowed from the corner at the other end of the same card.
#
# The strip stops at x=936 on the way in, and not a pixel further: it is
# reading from x=87 by then, and the quest icons start at x=89 on the widest of
# the three rows. What that leaves uncovered is the left rim of the badge, which
# lies over flat card and nothing else, so a sliver of flat colour finishes it.
#
# Each row reads its own corner at its own rows, so nothing has to be lined up
# by hand -- the geometry matches because it is the same card, mirrored.
const CARD_MIRROR_AXIS := 1023.0
const ROW_PATCH_X := 936.0
const ROW_PATCH_W := 55.0
const ROW_PATCH_TOP := -40.0    # from the middle of the badge
const ROW_PATCH_H := 74.0
const ROW_RIM_WIPE := Rect2(918, -22, 20, 44)

# ------------------------------------------------------------------- the ink
#
# The cards are all but black -- sampled off the plate at a dozen points and
# within a couple of values of (6, 9, 10) at every one of them, which is the
# whole reason a painted bar can be wiped out with a flat rectangle and leave
# nothing behind. Not pure black: black on this is a shade too dark and reads
# as a hole cut in the card.
const CARD_BG := Color(0.024, 0.035, 0.039, 1.0)

const TRACK_FILL := Color(0.106, 0.106, 0.125)
const TRACK_EDGE := Color(0.235, 0.239, 0.271)
const BAR_INK := Color(0.949, 0.694, 0.176)
const BAR_INK_TOP := Color(1.0, 0.827, 0.353)
const COUNT_INK := Color(0.729, 0.741, 0.769)
const CLOCK_INK := Color(0.949, 0.663, 0.239)

# The three states a row's plate is ever in.
const CLAIM_FILL := Color(0.435, 0.278, 0.063)
const CLAIM_EDGE := Color(0.882, 0.706, 0.294)
const CLAIM_INK := Color(1.0, 0.957, 0.831)
const DONE_FILL := Color(0.086, 0.094, 0.110)
const DONE_EDGE := Color(0.278, 0.298, 0.337)
const DONE_INK := Color(0.588, 0.616, 0.667)
const TOGO_FILL := Color(0.063, 0.071, 0.086)
const TOGO_EDGE := Color(0.196, 0.212, 0.243)
const TOGO_INK := Color(0.510, 0.541, 0.596)

const BADGE_FILL := Color(0.741, 0.145, 0.110)
const BADGE_EDGE := Color(1.0, 0.376, 0.216)
const BADGE_INK := Color(1.0, 0.965, 0.945)
# What a badge that is not lit turns back into is not a colour at all -- see
# _mirror and TAB_PATCH_ART.


const PRESS_WASH := Color(1.0, 0.86, 0.45, 0.26)

# Held to nine tenths of the screen so the menu shows around the edges.
const POPUP_WIDTH := 0.90

var _plate_pos: Vector2 = Vector2.ZERO
var _plate_size: Vector2 = Vector2.ZERO
var _dim: ColorRect = null
var _page_root: Control = null
var _clock_label: Label = null
var _tick: float = 0.0
var _toast_pill: Panel = null

func build(view_size: Vector2) -> void:
	position = Vector2.ZERO
	size = view_size
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	_dim.position = Vector2.ZERO
	_dim.size = view_size
	_dim.color = Color(0, 0, 0, 0.78)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_plate_size = Vector2(view_size.x * POPUP_WIDTH, 0.0)
	_plate_size.y = _plate_size.x * ART_SIZE.y / ART_SIZE.x
	_plate_pos = ((view_size - _plate_size) * 0.5).round()

func open() -> void:
	visible = true
	# The day can have turned over while the menu was sitting there.
	MetaManager.roll_quests()
	_show()
	_pop()

# The board arriving rather than appearing. Only ever on the way in: the board
# redraws itself on every claim, and one that jumps each time is unreadable.
func _pop() -> void:
	if _page_root == null:
		return
	_dim.modulate.a = 0.0
	_page_root.pivot_offset = size * 0.5
	_page_root.scale = Vector2(0.94, 0.94)
	_page_root.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_dim, "modulate:a", 1.0, 0.14)
	t.parallel().tween_property(_page_root, "modulate:a", 1.0, 0.16)
	t.parallel().tween_property(_page_root, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	visible = false
	_clock_label = null
	if _page_root != null:
		_page_root.queue_free()
		_page_root = null

func _close_out() -> void:
	close()
	closed.emit()

# --------------------------------------------------------------- the board

func _show() -> void:
	if _page_root != null:
		# Hidden as well as freed: queue_free lands at the end of the frame, and
		# a board still taking presses after it has been replaced can have the
		# same reward taken off it twice on one tap.
		_page_root.hide()
		_page_root.queue_free()
	_clock_label = null

	_page_root = Control.new()
	_page_root.position = Vector2.ZERO
	_page_root.size = size
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_root)

	var plate := TextureRect.new()
	plate.texture = load(ART)
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.position = _plate_pos
	plate.size = _plate_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(plate)

	_hit(CLOSE_RECT).pressed.connect(_close_out)
	_build_header()
	for i in range(MetaManager.QUESTS.size()):
		_build_row(i)

func _build_header() -> void:
	# The painted clock reads 23h 57m, which is a picture of a clock rather than
	# one. It is covered and the real wait written over it.
	_wipe(REFRESH_RECT)
	_clock_label = _ink(REFRESH_RECT, _clock(MetaManager.quests_seconds_left()),
		CLOCK_INK, 27.0)

	# The tab's corner goes back the way it was drawn before anything was pinned
	# to it, and the count is pinned back on only when there is one. Nothing
	# waiting means nothing on the tab -- not a badge reading zero, and not the
	# dark disc a flat cover used to leave sitting there.
	_patch(TAB_PATCH_RECT, TAB_PATCH_ART)
	var claimable: int = MetaManager.quests_claimable_count()
	if claimable > 0:
		_badge(TAB_BADGE_MID, TAB_BADGE_R, str(claimable))

# One row: the bar, the count beside it, and the plate that says what the row
# is waiting for.
func _build_row(index: int) -> void:
	var q: Dictionary = MetaManager.QUESTS[index]
	var id: String = String(q["id"])
	var goal: int = int(q["goal"])
	var have: int = MetaManager.quest_count(id)
	var claimable: bool = MetaManager.quest_claimable(id)
	var claimed: bool = MetaManager.quest_is_claimed(id)

	var mid: float = float(BAR_MID[index])
	_wipe(Rect2(BAR_X - 10.0, mid - 24.0, BAR_W + 20.0, 48.0))
	_track(Rect2(BAR_X, mid - BAR_H * 0.5, BAR_W, BAR_H),
		float(have) / float(maxi(goal, 1)))

	var count_rect := Rect2(COUNT_X, mid - 24.0, COUNT_W, 48.0)
	_wipe(count_rect)
	_ink(count_rect, "%d/%d" % [have, goal], COUNT_INK, 27.0)

	var tall: bool = index < CLAIM_RECTS.size()
	if tall:
		# The painted plate is covered whatever the row is doing: it says CLAIM
		# on all three, and only one state of a row ever should.
		var where: Rect2 = CLAIM_RECTS[index]
		_wipe(Rect2(where.position.x - 6.0, where.position.y - 6.0,
			where.size.x + 12.0, where.size.y + 12.0))
		if claimable:
			_plate(where, "CLAIM", CLAIM_FILL, CLAIM_EDGE, CLAIM_INK, 30.0)
			_claim_hit(where, id, index)
		elif claimed:
			_plate(where, "CLAIMED", DONE_FILL, DONE_EDGE, DONE_INK, 26.0)
		else:
			_plate(where, "%d TO GO" % (goal - have), TOGO_FILL, TOGO_EDGE,
				TOGO_INK, 25.0)
		# The painted "!" is a reading as well, and like the tab's count it sits
		# on a corner rather than on flat card: the row's own top-right bevel
		# runs under it. So the corner is put back and the mark drawn over it
		# only when the row actually has something waiting.
		var badge_mid: float = float(ROW_BADGE_MID[index])
		_wipe(Rect2(ROW_RIM_WIPE.position.x, badge_mid + ROW_RIM_WIPE.position.y,
			ROW_RIM_WIPE.size.x, ROW_RIM_WIPE.size.y))
		_mirror(Rect2(ROW_PATCH_X, badge_mid + ROW_PATCH_TOP, ROW_PATCH_W, ROW_PATCH_H),
			CARD_MIRROR_AXIS)
		if claimable:
			_badge(Vector2(ROW_BADGE_X, badge_mid), ROW_BADGE_R, "!", 30.0)
		return

	# A short row has no painted plate and no room under the reward for one, so
	# what it has to say goes over the bar -- which by the time there is
	# anything to say is full, and is only repeating the count beside it.
	if not claimable and not claimed:
		return
	var over := Rect2(BAR_X, mid - 24.0, BAR_W, 48.0)
	if claimable:
		_plate(over, "CLAIM", CLAIM_FILL, CLAIM_EDGE, CLAIM_INK, 30.0)
		_claim_hit(over, id, index)
	else:
		_plate(over, "CLAIMED", DONE_FILL, DONE_EDGE, DONE_INK, 26.0)

func _claim_hit(where: Rect2, id: String, index: int) -> void:
	_hit(where).pressed.connect(func() -> void:
		var won: int = MetaManager.claim_quest(id)
		if won <= 0:
			return
		Sfx.coin()
		# The board is redrawn first and the message put on top of it after: a
		# toast raised before the rebuild would be buried under the new board.
		_show()
		_toast(float(BAR_MID[index]), "+%s GOLD" % _money(won), UIStyle.ACCENT_GOLD))

# ------------------------------------------------------------------- pieces

func _at(where: Rect2) -> Rect2:
	var s: float = _plate_size.x / ART_SIZE.x
	return Rect2(_plate_pos + where.position * s, where.size * s)

func _px(v: float) -> int:
	return maxi(1, int(round(v * _plate_size.x / ART_SIZE.x)))

# A painted thing wiped out. Black, because that is what the cards are.
func _wipe(where: Rect2) -> void:
	var r: Rect2 = _at(where)
	var patch := ColorRect.new()
	patch.position = r.position
	patch.size = r.size
	patch.color = CARD_BG
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(patch)

# The bar, drawn rather than uncovered: the painted ones are full on three rows
# and empty on the other three, and neither is a reading.
func _track(where: Rect2, ratio: float) -> void:
	var r: Rect2 = _at(where)
	var track := Panel.new()
	track.position = r.position
	track.size = r.size
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = TRACK_FILL
	sb.border_color = TRACK_EDGE
	sb.set_border_width_all(maxi(1, _px(2.0)))
	sb.set_corner_radius_all(_px(9.0))
	track.add_theme_stylebox_override("panel", sb)
	_page_root.add_child(track)

	var f: float = clampf(ratio, 0.0, 1.0)
	if f <= 0.0:
		return
	var fill := Panel.new()
	var pad: float = float(_px(3.0))
	fill.position = r.position + Vector2(pad, pad)
	# Any progress at all is drawn as a readable stub rather than a sliver.
	var span: float = r.size.x - pad * 2.0
	fill.size = Vector2(maxf(span * f, r.size.y - pad * 2.0), r.size.y - pad * 2.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fb := StyleBoxFlat.new()
	fb.bg_color = BAR_INK
	fb.border_color = BAR_INK_TOP
	fb.set_border_width_all(0)
	fb.border_width_top = maxi(1, _px(3.0))
	fb.set_corner_radius_all(_px(7.0))
	fill.add_theme_stylebox_override("panel", fb)
	_page_root.add_child(fill)

# A row's state, in the space that row has for it.
func _plate(where: Rect2, text: String, fill: Color, edge: Color, ink: Color,
		size_px: float) -> void:
	var r: Rect2 = _at(where)
	var plate := Panel.new()
	plate.position = r.position
	plate.size = r.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(maxi(2, _px(3.0)))
	sb.set_corner_radius_all(_px(10.0))
	plate.add_theme_stylebox_override("panel", sb)
	_page_root.add_child(plate)

	var lbl := Label.new()
	lbl.position = Vector2.ZERO
	lbl.size = r.size
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(size_px))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, ink, 4)
	plate.add_child(lbl)

func _round(mid: Vector2, radius: float, fill: Color, edge: Color,
		border: int = -1) -> void:
	var r: Rect2 = _at(Rect2(mid.x - radius, mid.y - radius, radius * 2.0, radius * 2.0))
	var disc := Panel.new()
	disc.position = r.position
	disc.size = r.size
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(maxi(1, _px(2.0)) if border < 0 else border)
	sb.set_corner_radius_all(int(r.size.x))
	disc.add_theme_stylebox_override("panel", sb)
	_page_root.add_child(disc)

# A badge, built the way the painting built its own: a dark seat a shade wider
# than the stone, the red stone on it, and what it says in the middle.
func _badge(mid: Vector2, radius: float, text: String, size_px: float = 26.0) -> void:
	_round(mid, radius + 2.5, Color(0.05, 0.03, 0.02, 0.9), Color(0, 0, 0, 0), 0)
	_round(mid, radius, BADGE_FILL, BADGE_EDGE)
	_ink(Rect2(mid.x - radius, mid.y - radius, radius * 2.0, radius * 2.0),
		text, BADGE_INK, size_px)

# A strip of the plate mirrored across a line of its own symmetry and laid back
# down over it: what a corner looks like at the other end of the same thing,
# which is what a corner with a badge printed on it is meant to look like
# without one. No fade at the edges because these land on the flat colour the
# cards are; the tab's corner, which lands on stonework, needs the baked and
# feathered copy instead.
func _mirror(where: Rect2, axis: float) -> void:
	var slice := AtlasTexture.new()
	slice.atlas = load(ART)
	slice.region = Rect2(axis - where.position.x - where.size.x, where.position.y,
		where.size.x, where.size.y)
	var r: Rect2 = _at(where)
	var tex := TextureRect.new()
	tex.texture = slice
	tex.flip_h = true
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.position = r.position
	tex.size = r.size
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(tex)

# A piece of painting laid over the painting -- the one thing on this board
# that cannot be put right with a rectangle of flat colour.
func _patch(where: Rect2, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var r: Rect2 = _at(where)
	var tex := TextureRect.new()
	tex.texture = load(path)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.position = r.position
	tex.size = r.size
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(tex)

func _ink(where: Rect2, text: String, color: Color, size_px: float) -> Label:
	var r: Rect2 = _at(where)
	var lbl := Label.new()
	lbl.position = r.position
	lbl.size = r.size
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(size_px))
	lbl.clip_text = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, color, 4)
	_page_root.add_child(lbl)
	return lbl

# An invisible button over a painted one, with the press feedback a painting
# cannot give.
func _hit(where: Rect2) -> Button:
	var r: Rect2 = _at(where)
	var btn := Button.new()
	btn.position = r.position
	btn.size = r.size
	btn.text = ""
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_page_root.add_child(btn)

	var wash := ColorRect.new()
	wash.position = Vector2.ZERO
	wash.size = r.size
	wash.color = Color(PRESS_WASH.r, PRESS_WASH.g, PRESS_WASH.b, 0.0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(wash)
	btn.button_down.connect(func() -> void: wash.color = PRESS_WASH)
	btn.button_up.connect(func() -> void:
		var t := create_tween()
		t.tween_property(wash, "color:a", 0.0, 0.18))
	return btn

# What was taken, rising off the row it came from. One at a time, for the same
# reason the shop's are: two raised inside the second they live for land on the
# same line and print over each other.
func _toast(row_mid: float, text: String, color: Color) -> void:
	if _toast_pill != null and is_instance_valid(_toast_pill):
		_toast_pill.queue_free()
	# On a pill rather than struck bare across the row the way the shop's are.
	# The shop raises its messages over a grid of cards with air between them;
	# this board is six rows of writing with none, and a bare line lands on
	# whatever the row it came off already says.
	var r: Rect2 = _at(Rect2(200.0, row_mid - 30.0, 623.0, 60.0))
	var pill := Panel.new()
	pill.position = r.position
	pill.size = r.size
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.016, 0.020, 0.031, 0.94)
	sb.border_color = color
	sb.set_border_width_all(maxi(2, _px(3.0)))
	sb.set_corner_radius_all(_px(14.0))
	pill.add_theme_stylebox_override("panel", sb)
	# On this node rather than on the board, so redrawing the board underneath
	# it does not take the message away before it has been read.
	add_child(pill)
	_toast_pill = pill

	var lbl := Label.new()
	lbl.position = Vector2.ZERO
	lbl.size = r.size
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(32.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, color, 6)
	pill.add_child(lbl)

	var t := create_tween()
	t.tween_property(pill, "position:y", pill.position.y - 48.0, 1.0)
	t.parallel().tween_property(pill, "modulate:a", 0.0, 1.0).set_delay(0.55)
	t.tween_callback(pill.queue_free)

# ------------------------------------------------------------------ the clock

func _process(delta: float) -> void:
	if not visible or _clock_label == null:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	var left: int = MetaManager.quests_seconds_left()
	if left <= 0:
		# Midnight, with the board open. It rolls under the player rather than
		# waiting to be closed and opened again.
		MetaManager.roll_quests()
		_show()
		return
	_clock_label.text = _clock(left)

# The painting writes the wait as hours and minutes, so this does too, and
# falls to minutes and seconds for the last hour of it -- the number that is
# about to change is the one worth showing.
func _clock(seconds: int) -> String:
	if seconds >= 3600:
		return "%dH %02dM" % [seconds / 3600, (seconds / 60) % 60]
	if seconds >= 60:
		return "%dM %02dS" % [seconds / 60, seconds % 60]
	return "%dS" % maxi(seconds, 0)

func _money(value: int) -> String:
	var s: String = str(maxi(value, 0))
	var out: String = ""
	var n: int = s.length()
	for i in range(n):
		if i > 0 and (n - i) % 3 == 0:
			out += ","
		out += s[i]
	return out

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_close_out()
		get_viewport().set_input_as_handled()
