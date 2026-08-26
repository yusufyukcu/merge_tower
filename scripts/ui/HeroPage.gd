extends Control

const UIStyle = preload("res://scripts/ui/UIStyle.gd")

# The hero shelf, as one painted plate -- art/hero_page.png -- with the rows
# rebuilt over it.
#
# The frame, the gem at the head, the title and the line under it, the X and the
# CLOSE plate are all in the picture and are left alone. The seven rows are not:
# what a row has to say changes with what the player owns, what they have picked
# and what they have spent, and none of that is something a picture can keep up
# with. So the whole band is covered and the rows are drawn.
#
# What the picture still gives them is the part worth having: every portrait and
# every sigil is cut straight out of it (see art/hero_*_portrait.png and
# art/hero_*_sigil.png, sliced from this same plate), so the faces on the shelf
# are the painted faces rather than something drawn to stand in for them. The
# essence prices are the painted ones too -- see MetaManager.HERO_UNLOCK_COSTS.
#
# A row is in one of three states:
#
#   locked  -- a price in essence and a padlock. The row buys it.
#   owned   -- a level chip on the portrait, CHOOSE, and a gold plate that buys
#              the next level. The row picks it; the plate levels it.
#   chosen  -- the same, lit in the hero's own colour, reading SELECTED. There
#              is nothing left to pick, so only the level plate answers.
#
# The order is UnitDatabase.HERO_IDS, which leads with the one hero a new player
# already owns and never reorders itself -- a list that moves under the thumb
# that just tapped it is a worse list.

signal closed

const ART := "res://art/hero_page.png"
const ART_SIZE := Vector2(1024.0, 1536.0)

# ------------------------------------------------------------------ the plan
#
# Every rect below is in the painting's own pixels and goes through _at().

const CLOSE_X_RECT := Rect2(908, 46, 78, 72)
const CLOSE_BTN_RECT := Rect2(350, 1445, 308, 76)

# The band the seven rows live in, and the patch that puts the painted ones out.
const BAND_RECT := Rect2(28, 162, 968, 1286)
const BAND_TOP := 170.0
const BAND_BOTTOM := 1438.0
const ROW_X := 33.0
const ROW_W := 959.0
const ROW_GAP := 7.0

# Inside one row, measured off the painting.
const SIGIL_X := 5.0
const SIGIL_W := 54.0
const SIGIL_H := 78.0
const PORTRAIT_X := 63.0
const PORTRAIT_BOX := 162.0
const TEXT_X := 255.0
const NAME_MID_Y := 52.0
const TITLE_MID_Y := 86.0
const DESC_TOP := 104.0
const DESC_H := 64.0
const DESC_W := 372.0
const PLATE_X := 648.0
const PLATE_W := 282.0
const PLATE_H := 62.0
const PLATE_GAP := 10.0
const CHIP_W := 88.0
const CHIP_H := 34.0
const ICON_BOX := 30.0

const NAME_SIZE := 32.0
const TITLE_SIZE := 21.0
const DESC_SIZE := 20.0
const PLATE_SIZE := 26.0
const PRICE_SIZE := 21.0
const CHIP_SIZE := 22.0

# What is in the purse, either side of the painted CLOSE plate. A shelf that
# sells two different things and shows neither balance makes the player close it
# to find out whether they can afford anything.
const PURSE_Y := 1452.0
const PURSE_H := 52.0
const PURSE_W := 268.0
const ESSENCE_PURSE_X := 62.0
const GOLD_PURSE_X := 690.0
# The gem the plate is painted with, cut off the plate rather than borrowed
# from art/essence.png -- which is a 1536x1024 sheet and blurs to a smudge at
# the size a price plate wants it.
const ESSENCE_ICON := "res://art/icon_essence.png"
const GOLD_ICON := "res://art/icon_coin.png"

# ------------------------------------------------------------------- the ink
#
# Sampled off the plate: the board the rows sit on runs between #02 and #12 at
# every point around them, so a patch in the middle of that lands without a seam.
const PAGE_INK := Color(0.031, 0.031, 0.031, 1.0)
const ROW_INK := Color(0.039, 0.039, 0.043, 1.0)
const ROW_EDGE := Color(0.24, 0.25, 0.27)
const NAME_INK := Color(0.90, 0.90, 0.92)
const DESC_INK := Color(0.60, 0.62, 0.66)
const PLATE_INK := Color(0.82, 0.83, 0.86)
const ESSENCE_INK := Color(0.42, 0.72, 1.0)
const GOLD_INK := Color(0.97, 0.78, 0.30)
const LOCK_INK := Color(0.58, 0.57, 0.54)
const MAXED_INK := Color(0.52, 0.53, 0.56)
const PRESS_WASH := Color(1.0, 0.92, 0.62, 0.16)

# Held to nine tenths of the screen so the menu shows around the edges. The
# quest board and the pack are held to the same fraction.
const POPUP_WIDTH := 0.90

var _plate_pos: Vector2 = Vector2.ZERO
var _plate_size: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _dim: ColorRect = null
var _page_root: Control = null
var _toast_pill: Panel = null

func build(view_size: Vector2) -> void:
	position = Vector2.ZERO
	size = view_size
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Not opaque: what makes this a pop-up rather than a room is that the menu is
	# still there behind it.
	_dim = ColorRect.new()
	_dim.position = Vector2.ZERO
	_dim.size = view_size
	_dim.color = Color(0, 0, 0, 0.78)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_plate_size = Vector2(view_size.x * POPUP_WIDTH, 0.0)
	_plate_size.y = _plate_size.x * ART_SIZE.y / ART_SIZE.x
	_plate_pos = ((view_size - _plate_size) * 0.5).round()
	_scale = _plate_size.x / ART_SIZE.x

func open() -> void:
	visible = true
	_show()
	_pop()

# The shelf arriving rather than appearing. Only ever on the way in: the shelf
# redraws itself after every purchase, and one that jumps each time is a shelf
# nobody can read.
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
	if _page_root != null:
		_page_root.queue_free()
		_page_root = null

func _close_out() -> void:
	close()
	closed.emit()

# ---------------------------------------------------------------- the shelf

func _show() -> void:
	if _page_root != null:
		# Hidden as well as freed: queue_free lands at the end of the frame, and
		# a shelf still taking presses after it has been replaced can spend the
		# same essence twice on one tap.
		_page_root.hide()
		_page_root.queue_free()

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

	_hit(CLOSE_X_RECT).pressed.connect(_close_out)
	_hit(CLOSE_BTN_RECT).pressed.connect(_close_out)

	_wipe(BAND_RECT)
	var ids: Array = UnitDatabase.HERO_IDS
	for i in range(ids.size()):
		_build_row(i, ids.size(), String(ids[i]))
	_purse()

# What is in the purse, read again every time the shelf is drawn -- which is
# after every purchase, so a price paid is visible in the balance beside it.
func _purse() -> void:
	_reading(Rect2(ESSENCE_PURSE_X, PURSE_Y, PURSE_W, PURSE_H),
		ESSENCE_ICON, _money(MetaManager.essence), ESSENCE_INK)
	_reading(Rect2(GOLD_PURSE_X, PURSE_Y, PURSE_W, PURSE_H),
		GOLD_ICON, _money(MetaManager.gold), GOLD_INK)

func _reading(where: Rect2, icon: String, text: String, ink: Color) -> void:
	var r: Rect2 = _at(where)
	var holder := Control.new()
	holder.position = r.position
	holder.size = r.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(holder)
	_icon(holder, Rect2(0, (where.size.y - 36.0) * 0.5, 36.0, 36.0), icon)
	_label(holder, Rect2(46.0, 0, where.size.x - 46.0, where.size.y),
		text, ink, 27.0, 5, false)

# --------------------------------------------------------------------- a row
#
# Where a row is, and where the gold plate inside it is. Both are read by the
# shelf as it draws and by the shot pass that presses them, so a press in a test
# lands wherever the drawing put it rather than wherever the test guessed.

func _row_h() -> float:
	var n: int = maxi(1, UnitDatabase.HERO_IDS.size())
	return (BAND_BOTTOM - BAND_TOP - ROW_GAP * float(n - 1)) / float(n)

func row_rect(index: int) -> Rect2:
	var h: float = _row_h()
	return _at(Rect2(ROW_X, BAND_TOP + float(index) * (h + ROW_GAP), ROW_W, h))

func level_seat(index: int) -> Rect2:
	var h: float = _row_h()
	var top: float = BAND_TOP + float(index) * (h + ROW_GAP)
	return _at(Rect2(ROW_X + PLATE_X, top + (h + PLATE_GAP) * 0.5, PLATE_W, PLATE_H))

func _build_row(index: int, _count: int, id: String) -> void:
	var h: float = _row_h()
	var top: float = BAND_TOP + float(index) * (h + ROW_GAP)
	var d: Dictionary = UnitDatabase.get_def(id)
	var accent: Color = d.get("color", UIStyle.ACCENT_GOLD)
	var owned: bool = MetaManager.hero_owned(id)
	var chosen: bool = owned and MetaManager.hero_id() == id
	var r: Rect2 = _at(Rect2(ROW_X, top, ROW_W, h))

	var row := Control.new()
	row.position = r.position
	row.size = r.size
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(row)

	var body := Panel.new()
	body.position = Vector2.ZERO
	body.size = r.size
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	# The chosen one is lit from inside the way the painting lights its own
	# first row, and the rest are the flat plate the painting gives the others.
	sb.bg_color = ROW_INK.lerp(accent, 0.10) if chosen else ROW_INK
	sb.border_color = accent if chosen else ROW_EDGE
	sb.set_border_width_all(maxi(1, _px(3.0 if chosen else 2.0)))
	sb.set_corner_radius_all(_px(10.0))
	if chosen:
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
		sb.shadow_size = _px(10.0)
	body.add_theme_stylebox_override("panel", sb)
	row.add_child(body)

	_slice(row, Rect2(SIGIL_X, (h - SIGIL_H) * 0.5, SIGIL_W, SIGIL_H),
		"res://art/%s_sigil.png" % id)
	var portrait_top: float = (h - PORTRAIT_BOX) * 0.5
	_slice(row, Rect2(PORTRAIT_X, portrait_top, PORTRAIT_BOX, PORTRAIT_BOX),
		"res://art/%s_portrait.png" % id)

	# What the hero is worth, pinned across the foot of its own portrait -- the
	# same place and the same reading the menu's own plaques give a carried unit.
	if owned:
		_chip(row, Rect2(PORTRAIT_X + (PORTRAIT_BOX - CHIP_W) * 0.5,
			portrait_top + PORTRAIT_BOX - CHIP_H, CHIP_W, CHIP_H),
			"LV %d" % MetaManager.hero_level(id), accent)

	var name_ink: Color = accent.lightened(0.15) if owned else accent.darkened(0.22)
	_label(row, Rect2(TEXT_X, NAME_MID_Y - 26.0, PLATE_X - TEXT_X - 16.0, 52.0),
		String(d.get("name", id)), name_ink, NAME_SIZE, 6, false)
	_label(row, Rect2(TEXT_X, TITLE_MID_Y - 18.0, PLATE_X - TEXT_X - 16.0, 36.0),
		String(d.get("title", "")), NAME_INK if owned else DESC_INK, TITLE_SIZE, 4, false)
	# The painting has no room for what a hero actually does, and dropping it
	# would leave the shelf prettier and worth less, so it goes under the title.
	_label(row, Rect2(TEXT_X, DESC_TOP, DESC_W, DESC_H),
		String(d.get("desc", "")), DESC_INK, DESC_SIZE, 3, true)

	if owned:
		_owned_plates(row, h, id, accent, chosen)
	else:
		_locked_plate(row, h, id, accent)

	# The hit boxes go on last so nothing drawn after them eats the press, and
	# the level plate goes on after the row so it wins the overlap.
	if not owned:
		_row_hit(row, h).pressed.connect(_buy.bind(id, top))
	elif not chosen:
		_row_hit(row, h).pressed.connect(func() -> void:
			MetaManager.select_hero(id)
			Sfx.coin()
			_show())
	if owned and MetaManager.hero_level_cost(id) > 0:
		var seat: Rect2 = Rect2(PLATE_X, (h + PLATE_GAP) * 0.5, PLATE_W, PLATE_H)
		_hit_on(row, seat).pressed.connect(_level_up.bind(id, top))

func _row_hit(row: Control, h: float) -> Button:
	return _hit_on(row, Rect2(0, 0, ROW_W, h))

# A hero already owned: what it is, and what the next level of it costs.
func _owned_plates(row: Control, h: float, id: String, accent: Color, chosen: bool) -> void:
	var stack: float = PLATE_H * 2.0 + PLATE_GAP
	var top: float = (h - stack) * 0.5
	_plate(row, Rect2(PLATE_X, top, PLATE_W, PLATE_H),
		"SELECTED" if chosen else "CHOOSE",
		Color(0.06, 0.06, 0.07).lerp(accent, 0.28 if chosen else 0.05),
		accent if chosen else accent.darkened(0.45),
		PLATE_INK if chosen else accent.lightened(0.1), PLATE_SIZE, "", false)

	var price: int = MetaManager.hero_level_cost(id)
	var seat := Rect2(PLATE_X, top + PLATE_H + PLATE_GAP, PLATE_W, PLATE_H)
	if price <= 0:
		_plate(row, seat, "MAX LEVEL", Color(0.05, 0.05, 0.055),
			Color(0.22, 0.22, 0.24), MAXED_INK, PRICE_SIZE, "", false)
		return
	var afford: bool = MetaManager.gold >= price
	_plate(row, seat, "LEVEL UP  %s" % _money(price),
		Color(0.07, 0.06, 0.03) if afford else Color(0.05, 0.05, 0.05),
		GOLD_INK.darkened(0.25 if afford else 0.6),
		GOLD_INK if afford else GOLD_INK.darkened(0.45),
		PRICE_SIZE, GOLD_ICON, false)

# A hero not owned yet: the painted price, and a padlock so it reads as a price
# rather than as a stat.
func _locked_plate(row: Control, h: float, id: String, accent: Color) -> void:
	var price: int = MetaManager.hero_unlock_cost(id)
	var afford: bool = MetaManager.essence >= price
	_plate(row, Rect2(PLATE_X, (h - PLATE_H) * 0.5, PLATE_W, PLATE_H),
		_money(price),
		Color(0.04, 0.05, 0.07) if afford else Color(0.05, 0.05, 0.05),
		ESSENCE_INK.darkened(0.35 if afford else 0.65),
		ESSENCE_INK if afford else ESSENCE_INK.darkened(0.4),
		PRICE_SIZE + 3.0, ESSENCE_ICON, true)

# ------------------------------------------------------------------- buying

func _buy(id: String, row_top: float) -> void:
	if MetaManager.unlock_hero(id):
		Sfx.coin()
		# Bought and worn straight away: a hero paid for and then still not
		# standing on the ring is a second tap nobody would guess they owed.
		MetaManager.select_hero(id)
		_show()
		_toast(row_top, "UNLOCKED", UIStyle.ACCENT_TEAL)
		return
	_toast(row_top, "NOT ENOUGH ESSENCE", UIStyle.ACCENT_RED)

func _level_up(id: String, row_top: float) -> void:
	var before: int = MetaManager.hero_level(id)
	if MetaManager.level_up_hero(id):
		Sfx.coin()
		_show()
		_toast(row_top, "LEVEL %d" % (before + 1), UIStyle.ACCENT_GOLD)
		return
	_toast(row_top, "NOT ENOUGH GOLD", UIStyle.ACCENT_RED)

# -------------------------------------------------------------------- pieces

func _at(where: Rect2) -> Rect2:
	return Rect2(_plate_pos + where.position * _scale, where.size * _scale)

# A rect in a row's own art pixels, in that row's own space.
func _sz_rect(where: Rect2) -> Rect2:
	return Rect2(where.position * _scale, where.size * _scale)

func _px(v: float) -> int:
	return maxi(1, int(round(v * _scale)))

func _wipe(where: Rect2) -> void:
	var r: Rect2 = _at(where)
	var patch := ColorRect.new()
	patch.position = r.position
	patch.size = r.size
	patch.color = PAGE_INK
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(patch)

# A piece cut out of this same plate, put back where it belongs.
func _slice(row: Control, where: Rect2, path: String) -> void:
	_icon(row, where, path)

func _icon(parent: Control, where: Rect2, path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var r: Rect2 = _sz_rect(where)
	var pic := TextureRect.new()
	pic.texture = load(path)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = r.position
	pic.size = r.size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pic)

func _label(parent: Control, where: Rect2, text: String, color: Color,
		size_px: float, outline: int, wrap: bool) -> void:
	if text == "":
		return
	var r: Rect2 = _sz_rect(where)
	var lbl := Label.new()
	lbl.position = r.position
	lbl.size = r.size
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", _px(size_px))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, color, outline)
	parent.add_child(lbl)

# One plate on the right of a row: a fill, an edge, a word, and -- when what it
# says is a price -- the coin or the gem it is asking for and a lock beside it.
func _plate(row: Control, where: Rect2, text: String, fill: Color, edge: Color,
		ink: Color, size_px: float, icon: String, lock: bool) -> void:
	var r: Rect2 = _sz_rect(where)
	var plate := Panel.new()
	plate.position = r.position
	plate.size = r.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(maxi(1, _px(2.0)))
	sb.set_corner_radius_all(_px(8.0))
	plate.add_theme_stylebox_override("panel", sb)
	row.add_child(plate)

	var left: float = 18.0
	if icon != "":
		_icon(plate, Rect2(left, (where.size.y - ICON_BOX) * 0.5, ICON_BOX, ICON_BOX), icon)
		left += ICON_BOX + 8.0
	var right: float = 56.0 if lock else 18.0
	if lock:
		_lock(plate, Rect2(where.size.x - 44.0, (where.size.y - 34.0) * 0.5, 28.0, 34.0))

	var lbl := Label.new()
	lbl.position = _sz(Vector2(left, 0))
	lbl.size = _sz(Vector2(where.size.x - left - right, where.size.y))
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(size_px))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, ink, 4)
	plate.add_child(lbl)

# A shackle with its foot buried in a body, which is all a padlock is at this
# size. Drawn rather than cut off the plate: the painting's locks sit on rows
# this page no longer draws.
func _lock(parent: Control, where: Rect2) -> void:
	var ring := Panel.new()
	ring.position = _sz(where.position + Vector2(where.size.x * 0.18, 0.0))
	ring.size = _sz(Vector2(where.size.x * 0.64, where.size.y * 0.62))
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rsb := StyleBoxFlat.new()
	rsb.draw_center = false
	rsb.border_color = LOCK_INK
	rsb.set_border_width_all(maxi(1, _px(3.0)))
	rsb.set_corner_radius_all(_px(where.size.x * 0.34))
	ring.add_theme_stylebox_override("panel", rsb)
	parent.add_child(ring)

	var shell := Panel.new()
	shell.position = _sz(where.position + Vector2(0.0, where.size.y * 0.42))
	shell.size = _sz(Vector2(where.size.x, where.size.y * 0.58))
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = LOCK_INK
	ssb.set_corner_radius_all(_px(4.0))
	shell.add_theme_stylebox_override("panel", ssb)
	parent.add_child(shell)

# The level, across the foot of the portrait it belongs to.
func _chip(row: Control, where: Rect2, text: String, accent: Color) -> void:
	var r: Rect2 = _sz_rect(where)
	var chip := Panel.new()
	chip.position = r.position
	chip.size = r.size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.025, 0.94)
	sb.border_color = accent
	sb.set_border_width_all(maxi(1, _px(2.0)))
	sb.set_corner_radius_all(_px(9.0))
	chip.add_theme_stylebox_override("panel", sb)
	row.add_child(chip)

	var lbl := Label.new()
	lbl.position = Vector2.ZERO
	lbl.size = r.size
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(CHIP_SIZE))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, accent.lightened(0.3), 4)
	chip.add_child(lbl)

func _sz(v: Vector2) -> Vector2:
	return v * _scale

# An invisible button over a painted one, with the press feedback a painting
# cannot give.
func _hit(where: Rect2) -> Button:
	return _make_hit(_page_root, _at(where))

func _hit_on(row: Control, where: Rect2) -> Button:
	return _make_hit(row, _sz_rect(where))

func _make_hit(parent: Control, r: Rect2) -> Button:
	var btn := Button.new()
	btn.position = r.position
	btn.size = r.size
	btn.text = ""
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	parent.add_child(btn)

	var wash := ColorRect.new()
	wash.position = Vector2.ZERO
	wash.size = r.size
	wash.color = Color(PRESS_WASH.r, PRESS_WASH.g, PRESS_WASH.b, 0.0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(wash)
	btn.button_down.connect(func() -> void: wash.color = PRESS_WASH)
	btn.button_up.connect(func() -> void:
		if not is_instance_valid(wash):
			return
		var t := create_tween()
		t.tween_property(wash, "color:a", 0.0, 0.18))
	return btn

# What a tap cost or could not afford, raised off the row it was aimed at. One
# at a time, for the same reason the shop's are: two raised inside the second
# they live for print over each other.
func _toast(row_top: float, text: String, color: Color) -> void:
	if _toast_pill != null and is_instance_valid(_toast_pill):
		_toast_pill.queue_free()
	var r: Rect2 = _at(Rect2(252.0, row_top + 52.0, 520.0, 58.0))
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
	# On this node rather than on the page, so redrawing the shelf underneath it
	# does not take the message away before it has been read.
	add_child(pill)
	_toast_pill = pill

	var lbl := Label.new()
	lbl.position = Vector2.ZERO
	lbl.size = r.size
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(30.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, color, 6)
	pill.add_child(lbl)

	var t := create_tween()
	t.tween_property(pill, "position:y", pill.position.y - 46.0, 1.0)
	t.parallel().tween_property(pill, "modulate:a", 0.0, 1.0).set_delay(0.55)
	t.tween_callback(pill.queue_free)

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
