extends Control

const UIStyle = preload("res://scripts/ui/UIStyle.gd")

# The two moments a run stops so a card can be taken off the screen -- the
# blessing that opens it and the upgrade that pays out every tenth wave -- are
# the same screen with different words in it, so they are one plate.
#
# art/upgrade.png is that plate: a framed board carrying the crown, the hanging
# banners, CHOOSE AN UPGRADE and the line at the foot, drawn against a
# transparent surround so it drops straight onto the dimmed field. Everything
# the picture cannot know -- which cards, which wave, whose screen this is --
# is covered and rewritten over it, the same "picture plus the handful of
# things a picture cannot do" shape the quest board and the shop shelves use.
#
# The three cards in the painting are the one part that is a mock-up rather
# than a layout. A run offers four of them once the fourth seat has been bought,
# and each card's border has to carry the colour of the thing on it, so the
# whole card band is covered and the cards are drawn -- in the painting's own
# shape (accent border, inner hairline, corner brackets, the icon in its glow
# on the left, a rule between it and the words) so the board still reads as one
# picture rather than as cards sitting on a photograph of cards.

signal picked(index: int)

const ART := "res://art/upgrade.png"
const ART_SIZE := Vector2(1054.0, 1305.0)

# ------------------------------------------- what the painting already says
#
# Every rect below is in the painting's own pixels and goes through _at().

const TITLE_RECT := Rect2(224, 186, 628, 88)
const SUB_RECT := Rect2(384, 296, 286, 48)
const FOOTER_RECT := Rect2(352, 1236, 344, 48)
# The three painted cards and the air around them, in one patch.
const BAND_RECT := Rect2(100, 354, 860, 878)

# ------------------------------------------------------------- the card band

const CARD_X := 106.0
const CARD_W := 847.0
const BAND_TOP := 363.0
const BAND_BOTTOM := 1226.0
const CARD_GAP := 22.0

# Inside one card, measured off the painted one -- which is 273 tall. Every
# number here is scaled by the card's own height over that, so a board of four
# is the same card drawn smaller rather than a second layout to keep in step.
const REF_H := 273.0
const ICON_MID_X := 141.0
const ICON_BOX := 190.0
const RULE_X := 256.0
const TEXT_X := 293.0
const NAME_MID_Y := 74.0
const HR_Y := 113.0
const LEVEL_MID_Y := 146.0
const NAME_SIZE := 44.0
const BODY_SIZE := 30.0
# The rule under the name stops short of the card's right edge rather than
# following the text in, so it stays a full stroke on a board of four.
const HR_RIGHT_PAD := 83.0
const TEXT_RIGHT_PAD := 46.0

# ------------------------------------------------------------------- the ink
#
# Both sampled off the plate: the board behind the cards is a flat #050505 at
# every point of it, and the band the title sits on is a shade warmer, so a
# patch of either lands on the painting without a seam.
const BOARD_INK := Color(0.020, 0.020, 0.020, 1.0)
const TITLE_INK := Color(0.043, 0.043, 0.039, 1.0)

const GOLD := Color(0.86, 0.69, 0.34)
const SUB_INK := Color(0.78, 0.73, 0.64)
const FOOT_INK := Color(0.60, 0.56, 0.48)
const BODY_INK := Color(0.91, 0.90, 0.87)
const PRESS_WASH := Color(1.0, 0.88, 0.50, 0.22)

var _plate_pos: Vector2 = Vector2.ZERO
var _plate_size: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _page: Control = null
var _cards: Array = []
# One card can be pressed, once. The board lives on for the length of its own
# press animation, and a second tap inside that would pay out twice.
var _spent: bool = false

func build(view_size: Vector2) -> void:
	position = Vector2.ZERO
	size = view_size
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	_plate_size = Vector2(view_size.x, view_size.x * ART_SIZE.y / ART_SIZE.x)
	_plate_pos = Vector2(0.0, (view_size.y - _plate_size.y) * 0.5).round()
	_scale = _plate_size.x / ART_SIZE.x

	var dim := ColorRect.new()
	dim.position = Vector2.ZERO
	dim.size = view_size
	dim.color = Color(0, 0, 0, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

# head: title / subtitle / footer -- an empty string leaves the painted one
# alone. cards: name, desc, art, accent, level (-1 for a card that has no
# level to climb) and rare.
func open(head: Dictionary, cards: Array) -> void:
	_spent = false
	if _page != null:
		# Hidden as well as freed: queue_free lands at the end of the frame, and
		# a board still taking presses after it has been replaced can pay out
		# twice on one tap.
		_page.hide()
		_page.queue_free()

	_page = Control.new()
	_page.position = Vector2.ZERO
	_page.size = size
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)

	var plate := TextureRect.new()
	plate.texture = load(ART)
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.position = _plate_pos
	plate.size = _plate_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(plate)

	var title: String = String(head.get("title", ""))
	if title != "":
		_wipe(TITLE_RECT, TITLE_INK)
		_ink(TITLE_RECT, title, GOLD, 58.0, 9)
	var sub: String = String(head.get("subtitle", ""))
	if sub != "":
		_wipe(SUB_RECT, BOARD_INK)
		_ink(SUB_RECT, sub, SUB_INK, 27.0, 4)
	var foot: String = String(head.get("footer", ""))
	if foot != "":
		_wipe(FOOTER_RECT, BOARD_INK)
		_ink(FOOTER_RECT, foot, FOOT_INK, 27.0, 3)

	_wipe(BAND_RECT, BOARD_INK)
	_cards = []
	for i in range(cards.size()):
		_cards.append(_build_card(i, cards.size(), cards[i]))

	visible = true

func close() -> void:
	visible = false
	if _page != null:
		_page.hide()
		_page.queue_free()
		_page = null
	_cards = []

# ------------------------------------------------------------------ one card

func _build_card(index: int, count: int, d: Dictionary) -> Control:
	var h: float = (BAND_BOTTOM - BAND_TOP - CARD_GAP * float(count - 1)) / float(count)
	var top: float = BAND_TOP + float(index) * (h + CARD_GAP)
	# How much smaller this card is than the one in the painting. Everything
	# inside it rides on this.
	var k: float = h / REF_H
	var accent: Color = d.get("accent", GOLD)
	var r: Rect2 = _at(Rect2(CARD_X, top, CARD_W, h))

	var card := Control.new()
	card.position = r.position
	card.size = r.size
	card.pivot_offset = r.size / 2.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(card)

	var body := Panel.new()
	body.position = Vector2.ZERO
	body.size = r.size
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.020, 0.018, 0.024).lerp(accent, 0.05)
	sb.border_color = accent
	sb.set_border_width_all(maxi(2, _px(5.0 * k)))
	sb.set_corner_radius_all(_px(18.0 * k))
	# The painted cards sit in a wash of their own colour rather than on the
	# board flat, which is most of why they read as lit from inside.
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.12)
	sb.shadow_size = _px(9.0 * k)
	body.add_theme_stylebox_override("panel", sb)
	card.add_child(body)

	var inset: float = 11.0 * k
	var inner := Panel.new()
	inner.position = _sz(Vector2(inset, inset))
	inner.size = r.size - _sz(Vector2(inset * 2.0, inset * 2.0))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var isb := StyleBoxFlat.new()
	isb.draw_center = false
	isb.border_color = Color(accent.r, accent.g, accent.b, 0.32)
	isb.set_border_width_all(maxi(1, _px(2.0 * k)))
	isb.set_corner_radius_all(_px(11.0 * k))
	inner.add_theme_stylebox_override("panel", isb)
	card.add_child(inner)

	_corners(card, r.size, accent, k)
	_icon(card, d, accent, h, k)
	_words(card, d, accent, h, k)

	# The hit box goes on last so nothing drawn after it eats the press.
	var hit := Button.new()
	hit.position = Vector2.ZERO
	hit.size = r.size
	hit.text = ""
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	card.add_child(hit)

	var wash := ColorRect.new()
	wash.position = Vector2.ZERO
	wash.size = r.size
	wash.color = Color(PRESS_WASH.r, PRESS_WASH.g, PRESS_WASH.b, 0.0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.add_child(wash)
	hit.button_down.connect(func() -> void: wash.color = PRESS_WASH)
	hit.button_up.connect(func() -> void: wash.color.a = 0.0)
	hit.pressed.connect(_take.bind(index, card))
	return card

# The four brackets the painting puts in the corners: an arm each way in the
# card's own colour with a gold stud at the elbow.
func _corners(card: Control, span: Vector2, accent: Color, k: float) -> void:
	var arm: float = 44.0 * k
	var thick: float = 5.0 * k
	var pad: float = 21.0 * k
	var bright: Color = accent.lightened(0.25)
	for sx in [0.0, 1.0]:
		for sy in [0.0, 1.0]:
			var ox: float = pad if sx == 0.0 else span.x / _scale - pad - arm
			var oy: float = pad if sy == 0.0 else span.y / _scale - pad - thick
			_bar(card, Rect2(ox, oy, arm, thick), bright, thick * 0.5)
			var vy: float = pad if sy == 0.0 else span.y / _scale - pad - arm
			var vx: float = pad if sx == 0.0 else span.x / _scale - pad - thick
			_bar(card, Rect2(vx, vy, thick, arm), bright, thick * 0.5)
			var stud: float = 13.0 * k
			var cx: float = pad - (stud - thick) * 0.5
			if sx == 1.0:
				cx = span.x / _scale - pad - thick - (stud - thick) * 0.5
			var cy: float = pad - (stud - thick) * 0.5
			if sy == 1.0:
				cy = span.y / _scale - pad - thick - (stud - thick) * 0.5
			_bar(card, Rect2(cx, cy, stud, stud), GOLD, stud * 0.5)

func _bar(parent: Control, where: Rect2, color: Color, radius: float) -> void:
	var p := Panel.new()
	p.position = _sz(where.position)
	p.size = _sz(where.size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(maxi(1, _px(radius)))
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)

# The picture on the left, standing in its own light.
func _icon(card: Control, d: Dictionary, accent: Color, h: float, k: float) -> void:
	var box: float = ICON_BOX * k
	var mid := Vector2(ICON_MID_X * k, h * 0.5)

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	grad.colors = PackedColorArray([
		Color(accent.r, accent.g, accent.b, 0.50),
		Color(accent.r, accent.g, accent.b, 0.20),
		Color(accent.r, accent.g, accent.b, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128

	var glow := TextureRect.new()
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.position = _sz(Vector2(mid.x - box * 0.62, mid.y - box * 0.62))
	glow.size = _sz(Vector2(box * 1.24, box * 1.24))
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(glow)

	var path: String = String(d.get("art", ""))
	if path != "" and ResourceLoader.exists(path):
		var pic := TextureRect.new()
		pic.texture = load(path)
		# Pixel art, drawn the way the pack and the plaques already draw it.
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = _sz(Vector2(mid.x - box * 0.5, mid.y - box * 0.5))
		pic.size = _sz(Vector2(box, box))
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)

	# The hair between the picture and the words, with a stud at each end.
	var rx: float = RULE_X * k
	var y0: float = 30.0 * k
	var y1: float = h - 30.0 * k
	_bar(card, Rect2(rx, y0, 2.0 * k, y1 - y0), Color(GOLD.r, GOLD.g, GOLD.b, 0.32), 1.0)
	var dot: float = 9.0 * k
	_bar(card, Rect2(rx + k - dot * 0.5, y0 - dot * 0.5, dot, dot),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.55), dot * 0.5)
	_bar(card, Rect2(rx + k - dot * 0.5, y1 - dot * 0.5, dot, dot),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.55), dot * 0.5)

func _words(card: Control, d: Dictionary, accent: Color, h: float, k: float) -> void:
	var tx: float = TEXT_X * k
	var right: float = CARD_W - TEXT_RIGHT_PAD
	var level: int = int(d.get("level", -1))

	var name_h: float = 62.0 * k
	_label(card, Rect2(tx, NAME_MID_Y * k - name_h * 0.5, right - tx, name_h),
		String(d.get("name", "")), accent.lightened(0.18), NAME_SIZE * k, 6, false)

	var hr_y: float = HR_Y * k
	_bar(card, Rect2(tx - 14.0 * k, hr_y, CARD_W - HR_RIGHT_PAD - (tx - 14.0 * k), 2.0 * k),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.28), 1.0)
	var dot: float = 9.0 * k
	_bar(card, Rect2(tx - 14.0 * k - dot, hr_y + k - dot * 0.5, dot, dot),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.5), dot * 0.5)
	_bar(card, Rect2(CARD_W - HR_RIGHT_PAD, hr_y + k - dot * 0.5, dot, dot),
		Color(GOLD.r, GOLD.g, GOLD.b, 0.5), dot * 0.5)

	if bool(d.get("rare", false)):
		_rare_pill(card, k)

	var desc_top: float = 168.0 * k
	var desc_h: float = 62.0 * k
	if level >= 0:
		var row_h: float = 50.0 * k
		_level_row(card, Rect2(tx, LEVEL_MID_Y * k - row_h * 0.5, right - tx, row_h),
			level, accent, k)
	else:
		# A blessing has no level to climb, so its two sentences take the room
		# the level line would have had.
		desc_top = 128.0 * k
		desc_h = h - desc_top - 22.0 * k

	_label(card, Rect2(tx, desc_top, right - tx, desc_h),
		String(d.get("desc", "")), BODY_INK, BODY_SIZE * k, 3, true)

# "Lv 2 -> 3", with the arrow carrying the card's colour the way the painting
# draws it. Three labels rather than one string, because a Label paints in one
# colour and the arrow is the part worth seeing.
func _level_row(card: Control, where: Rect2, level: int, accent: Color, k: float) -> void:
	var size_px: float = BODY_SIZE * k
	var from_w: float = 76.0 * k
	var arrow_w: float = 40.0 * k
	_label(card, Rect2(where.position.x, where.position.y, from_w, where.size.y),
		"Lv %d" % level, BODY_INK, size_px, 3, false)
	_label(card, Rect2(where.position.x + from_w, where.position.y, arrow_w, where.size.y),
		"→", accent.lightened(0.15), size_px * 1.15, 3, false)
	_label(card, Rect2(where.position.x + from_w + arrow_w, where.position.y,
		where.size.x - from_w - arrow_w, where.size.y),
		str(level + 1), BODY_INK, size_px, 3, false)

func _rare_pill(card: Control, k: float) -> void:
	var w: float = 168.0 * k
	var hh: float = 42.0 * k
	var where := Rect2(CARD_W - HR_RIGHT_PAD - w, 22.0 * k, w, hh)
	var pill := Panel.new()
	pill.position = _sz(where.position)
	pill.size = _sz(where.size)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.14, 0.03, 0.92)
	sb.border_color = GOLD
	sb.set_border_width_all(maxi(1, _px(2.0 * k)))
	sb.set_corner_radius_all(_px(hh * 0.5))
	pill.add_theme_stylebox_override("panel", sb)
	card.add_child(pill)

	var lbl := Label.new()
	lbl.position = Vector2.ZERO
	lbl.size = pill.size
	lbl.text = "✦ RARE ✦"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(23.0 * k))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, GOLD, 3)
	pill.add_child(lbl)

# ------------------------------------------------------------------- the pick

func _take(index: int, card: Control) -> void:
	if _spent:
		return
	_spent = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(card, "scale", Vector2(1.035, 1.035), 0.11)
	tw.tween_callback(func() -> void:
		card.scale = Vector2.ONE
		picked.emit(index))

# -------------------------------------------------------------------- pieces

func _at(where: Rect2) -> Rect2:
	return Rect2(_plate_pos + where.position * _scale, where.size * _scale)

func _sz(v: Vector2) -> Vector2:
	return v * _scale

func _px(v: float) -> int:
	return maxi(1, int(round(v * _scale)))

# A painted thing covered over, in the colour the board already is there.
func _wipe(where: Rect2, ink: Color) -> void:
	var r: Rect2 = _at(where)
	var patch := ColorRect.new()
	patch.position = r.position
	patch.size = r.size
	patch.color = ink
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(patch)

func _ink(where: Rect2, text: String, color: Color, size_px: float, outline: int) -> void:
	var r: Rect2 = _at(where)
	var lbl := Label.new()
	lbl.position = r.position
	lbl.size = r.size
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(size_px))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, color, outline)
	_page.add_child(lbl)

# Inside a card, in the card's own art pixels.
func _label(card: Control, where: Rect2, text: String, color: Color,
		size_px: float, outline: int, wrap: bool) -> void:
	var lbl := Label.new()
	lbl.position = _sz(where.position)
	lbl.size = _sz(where.size)
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", _px(size_px))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, color, outline)
	card.add_child(lbl)
