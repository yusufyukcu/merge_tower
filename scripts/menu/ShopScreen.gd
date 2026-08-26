extends Control

const UIStyle = preload("res://scripts/ui/UIStyle.gd")

# The shop, as three painted plates rather than three built screens.
#
#   art/shop_in.png     the shelf itself -- what gold buys
#   art/gold_buy.png    the gold page -- what essence buys
#   art/essence_buy.png the essence page -- what money would buy
#
# Same trick the main menu and the in-run shelf are built with: the frame, the
# cards, the icons, the names and every price are in the picture, and the only
# things this script puts on top are the ones that cannot be painted -- the two
# balances, the lines whose wording had to change, the free gold button's state,
# and invisible hit boxes laid exactly over the painted ones.
#
# The plates are all 1024x1536 against a 1080x1920 screen, so each is fitted by
# its width and centred. What is left over above and below is filled black,
# which is what the outermost rows of all three actually are -- the letterbox
# reads as the frame continuing rather than as two bars.
#
# The three are one screen with three faces rather than three screens: the "+"
# beside a balance is nothing but a shortcut to the page that fills it, the
# shelf's own bottom rail switches between them, and the red X walks back the
# way the player came in before it closes.

signal closed

enum Page { SHOP, GOLD, ESSENCE }

const ART := {
	Page.SHOP: "res://art/shop_in.png",
	Page.GOLD: "res://art/gold_buy.png",
	Page.ESSENCE: "res://art/essence_buy.png",
}

const ART_SIZE := Vector2(1024.0, 1536.0)

# ------------------------------------------------------------------ the plan
#
# Every rect below is in the painting's own pixels, measured off the plate, and
# goes through _at() -- so all three pages follow if the art is ever redrawn at
# another size, and nothing here is pinned to a screen coordinate.

# --- the shelf: top bar
const S_GOLD_TEXT := Rect2(536, 26, 110, 50)
const S_ESS_TEXT := Rect2(764, 26, 104, 50)
const S_GOLD_PLUS := Rect2(646, 20, 58, 58)
const S_ESS_PLUS := Rect2(864, 20, 58, 58)
const S_CLOSE := Rect2(934, 14, 86, 82)

# --- the shelf: the grid. Four columns on the top row, three used on the
# bottom one; the painting's own gutters are not even, so the columns are
# written out rather than pitched.
const S_ROW_Y := [320.0, 796.0]
const S_ROW_H := [460.0, 438.0]
const S_COL_X := [33.0, 288.0, 530.0, 776.0]
const S_COL_W := [234.0, 222.0, 226.0, 219.0]

# --- the shelf: the two plates drawn over painted ones
const S_FREE_BTN := Rect2(44, 650, 209, 108)
const S_BOOST_BTN := Rect2(296, 1148, 206, 60)
const S_SLOT_BTN := Rect2(538, 1148, 210, 60)

# --- the shelf: bottom rail and banner
const S_SEE_OFFERS := Rect2(666, 1270, 324, 84)
const S_TAB_SHOP := Rect2(28, 1412, 322, 104)
const S_TAB_GOLD := Rect2(372, 1412, 294, 104)
const S_TAB_ESSENCE := Rect2(694, 1412, 302, 104)

# --- the rail, once it has been lifted off the shelf
#
# The shelf paints its rail inside its own plate and the two pages it switches
# to have their own content down there and none to spare, so the rail is not
# left where it was painted: the tabs are cut out of the shelf and laid in the
# black under the plate, in the same place on all three pages. What is left
# behind on the shelf is covered over, which costs nothing -- the plate is
# already black from the frame's bottom edge down, so a black cover over it
# cannot be seen.
const RAIL_WIPE := Rect2(0, 1400, 1024, 136)
const RAIL_TABS := [S_TAB_SHOP, S_TAB_GOLD, S_TAB_ESSENCE]
const RAIL_H := 104.0
# What a tab that is not the page you are on is turned down to.
const RAIL_DIM := Color(0.46, 0.46, 0.52)
# The shelf's own tab is the one the plate painted lit, so a turned-down cut of
# it still reads warmer than the two beside it. A wash of the black the rail
# sits in flattens the three back onto each other.
const RAIL_OFF := Color(0.0, 0.0, 0.02, 0.34)

# --- the gold page
const G_ESS_TEXT := Rect2(676, 26, 116, 52)
const G_ESS_PLUS := Rect2(816, 28, 56, 52)
const G_CLOSE := Rect2(900, 12, 100, 94)
const G_ROW_Y := [540.0, 929.0]
const G_ROW_H := [376.0, 385.0]
const G_COL_X := [61.0, 354.0, 677.0]
const G_COL_W := [269.0, 296.0, 287.0]
const G_SEE_OFFERS := Rect2(666, 1392, 272, 80)

# --- the essence page
const E_ESS_TEXT := Rect2(700, 30, 118, 50)
const E_ESS_PLUS := Rect2(824, 34, 58, 54)
const E_CLOSE := Rect2(922, 33, 90, 88)
const E_ROW_Y := [474.0, 901.0]
const E_ROW_H := [402.0, 427.0]
const E_COL_X := [50.0, 364.0, 684.0]
const E_COL_W := [280.0, 280.0, 276.0]

# ------------------------------------------------------------- what is wiped
#
# The shelf is a mock-up and three of its lines describe a game this one is
# not: chests sorted by the wood the box is made of rather than by what is in
# it, and two consumables measured in waves rather than in runs. Painted text
# cannot be argued with, so each of those patches is wiped out with the flat
# colour the card actually is behind it -- sampled off the plate, and uniform
# to within a couple of values over the whole patch, which is the only reason
# a flat rectangle disappears into it -- and the line is written live on top.
#
# The prices are left exactly as painted and are the prices that are charged:
# the picture is the price list, and MetaManager only has to agree with it.
const S_LINES := [
	{
		"rect": Rect2(292, 622, 214, 74), "bg": Color(0.035, 0.055, 0.027),
		"text": "Contains 3-5 random Level 1 units.",
	},
	{
		"rect": Rect2(534, 622, 218, 74), "bg": Color(0.027, 0.047, 0.067),
		"text": "Contains 3-5 random Level 2 units.",
	},
	{
		"rect": Rect2(780, 622, 211, 74), "bg": Color(0.063, 0.047, 0.020),
		"text": "Contains 3-5 random Level 3 units.",
	},
	{
		"rect": Rect2(292, 1056, 214, 88), "bg": Color(0.016, 0.051, 0.078),
		"text": "Increases all units' ATK by 25% for the next 1 run.",
	},
	{
		"rect": Rect2(534, 1056, 218, 88), "bg": Color(0.008, 0.055, 0.047),
		"text": "Get +1 extra unit slot for the next 1 run.",
	},
]

# The inside of the balance pill on each plate, so the painted figure can be
# wiped and the real one written in its place.
const S_PILL := Color(0.039, 0.071, 0.106)
const G_PILL := Color(0.035, 0.051, 0.071)
const E_PILL := Color(0.008, 0.035, 0.071)

# ------------------------------------------------------------------- the ink
#
# Sizes are cap heights in the painting's pixels; colours are what the plates
# are painted in, so a live line sits in the picture rather than on it.
const LINE_INK := Color(0.87, 0.88, 0.90)
const LINE_SIZE := 22.0
const BALANCE_INK := Color(0.95, 0.93, 0.87)
const BALANCE_SIZE := 30.0

# The free gold plate, ready and spent. Grey is the whole point of the second
# one: a line that has already been taken today has to look like one before it
# is pressed, not after.
const READY_FILL := Color(0.09, 0.24, 0.06)
const READY_EDGE := Color(0.46, 0.79, 0.31)
const READY_INK := Color(0.68, 0.91, 0.44)
const SPENT_FILL := Color(0.125, 0.135, 0.150)
const SPENT_EDGE := Color(0.33, 0.35, 0.39)
const SPENT_INK := Color(0.62, 0.65, 0.70)

# Laid over a card that cannot be bought right now, the same way the menu
# scrims a plaque with nothing behind it.
const LOCKED_SCRIM := Color(0.02, 0.02, 0.04, 0.58)
const PRESS_WASH := Color(1.0, 0.86, 0.45, 0.26)

var _plate_pos: Vector2 = Vector2.ZERO
var _plate_size: Vector2 = Vector2.ZERO

var _page: int = Page.SHOP
var _page_root: Control = null

# The one thing on any of the three pages that answers to the clock.
var _free_plate: Panel = null
var _free_label: Label = null
var _tick: float = 0.0

# The message last raised over a card, while it is still on screen.
var _toast_label: Label = null

func build(view_size: Vector2) -> void:
	position = Vector2.ZERO
	size = view_size
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Sized outright rather than anchored: this node is built hidden and its own
	# rect is never resolved, so anything anchored to it comes out zero-sized.
	var back := ColorRect.new()
	back.position = Vector2.ZERO
	back.size = view_size
	back.color = Color(0, 0, 0, 1)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)

	_plate_size = Vector2(view_size.x, view_size.x * ART_SIZE.y / ART_SIZE.x)
	_plate_pos = Vector2(0.0, (view_size.y - _plate_size.y) * 0.5).round()

func open(page: int) -> void:
	visible = true
	_show(page)

func close() -> void:
	visible = false
	_free_plate = null
	_free_label = null
	if _page_root != null:
		_page_root.queue_free()
		_page_root = null

# ------------------------------------------------------------- the three faces

func _show(page: int) -> void:
	_page = page
	if _page_root != null:
		# Hidden as well as freed: queue_free lands at the end of the frame, and a
		# page still taking presses after it has been replaced can be bought from
		# twice on one tap.
		_page_root.hide()
		_page_root.queue_free()
	_free_plate = null
	_free_label = null

	_page_root = Control.new()
	_page_root.position = Vector2.ZERO
	_page_root.size = size
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page_root)

	var plate := TextureRect.new()
	plate.texture = load(String(ART[page]))
	# Linear rather than nearest: all three are drawn a little larger than they
	# were painted, and nearest crawls on the stonework.
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.position = _plate_pos
	plate.size = _plate_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(plate)

	match page:
		Page.GOLD:
			_build_gold()
		Page.ESSENCE:
			_build_essence()
		_:
			_build_shelf()

# Switching tabs. The three are one screen with three faces rather than three
# screens, so this is not a stack: a page is shown in the place of the one
# before it and nothing is kept behind to walk back through.
func _go(page: int) -> void:
	if page == _page:
		return
	_show(page)

# The X, on any of the three, and the escape key with it. The rail says what
# these pages are -- three tabs of one shop, standing side by side -- and a tab
# has nothing behind it to go back to. So the X is not a way back through them:
# it is the way out of the shop, from wherever in it the player is standing.
func _close_out() -> void:
	close()
	closed.emit()


# ------------------------------------------------------------------ the shelf

func _build_shelf() -> void:
	_balance(S_GOLD_TEXT, S_PILL, _money(MetaManager.gold))
	_balance(S_ESS_TEXT, S_PILL, _money(MetaManager.essence))

	for line in S_LINES:
		_rewrite(line as Dictionary)

	_hit(S_GOLD_PLUS).pressed.connect(func() -> void: _go(Page.GOLD))
	_hit(S_ESS_PLUS).pressed.connect(func() -> void: _go(Page.ESSENCE))
	_hit(S_CLOSE).pressed.connect(_close_out)
	_hit(S_SEE_OFFERS).pressed.connect(func() -> void: _go(Page.GOLD))
	_build_rail()

	_build_free_gold()
	_chest_card(_card(0, 1), "wood")
	_chest_card(_card(0, 2), "silver")
	_chest_card(_card(0, 3), "gold")
	_hero_card(_card(1, 0))
	_consumable_card(_card(1, 1), S_BOOST_BTN, MetaManager.UNIT_BOOST_PRICE,
		MetaManager.pending_unit_boost, MetaManager.buy_unit_boost,
		"UNIT BOOST ARMED")
	_consumable_card(_card(1, 2), S_SLOT_BTN, MetaManager.EXTRA_SLOT_PRICE,
		MetaManager.pending_extra_slot, MetaManager.buy_extra_slot,
		"EXTRA SLOT ARMED")

func _card(row: int, col: int) -> Rect2:
	return Rect2(S_COL_X[col], S_ROW_Y[row], S_COL_W[col], S_ROW_H[row])

# The one line on the shelf that costs nothing, and the only one that answers
# to the clock rather than to the purse. The painted plate underneath says FREE
# and counts down at the same time, which no single state of it ever should --
# so it is covered outright and drawn in whichever of its two states it is
# actually in.
func _build_free_gold() -> void:
	var r: Rect2 = _at(S_FREE_BTN)
	_free_plate = Panel.new()
	_free_plate.position = r.position
	_free_plate.size = r.size
	_free_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(_free_plate)

	_free_label = Label.new()
	_free_label.position = Vector2.ZERO
	_free_label.size = r.size
	_free_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_free_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_free_label.add_theme_font_size_override("font_size", _px(38.0))
	_free_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_free_plate.add_child(_free_label)

	_refresh_free_gold()

	var btn: Button = _hit(_card(0, 0))
	btn.pressed.connect(func() -> void:
		var won: int = MetaManager.claim_free_gold()
		if won <= 0:
			_toast(_card(0, 0), "COME BACK IN %s" % _clock(MetaManager.free_gold_seconds_left()),
				SPENT_INK)
			return
		Sfx.coin()
		# The shelf is redrawn first and the message put on top of it after: a
		# toast raised before the rebuild would be buried under the new page.
		_show(Page.SHOP)
		_toast(_card(0, 0), "+%s GOLD" % _money(won), UIStyle.ACCENT_GOLD))

func _refresh_free_gold() -> void:
	if _free_plate == null or _free_label == null:
		return
	var left: int = MetaManager.free_gold_seconds_left()
	var ready: bool = left <= 0
	var sb := StyleBoxFlat.new()
	sb.bg_color = READY_FILL if ready else SPENT_FILL
	sb.border_color = READY_EDGE if ready else SPENT_EDGE
	sb.set_border_width_all(maxi(2, _px(4.0)))
	sb.set_corner_radius_all(_px(16.0))
	_free_plate.add_theme_stylebox_override("panel", sb)

	_free_label.text = "FREE" if ready else _clock(left)
	_free_label.add_theme_font_size_override("font_size", _px(38.0 if ready else 30.0))
	UIStyle.apply_heading(_free_label, READY_INK if ready else SPENT_INK, 5)

# A chest: the whole card is the hit box, the painted price is the price.
func _chest_card(card: Rect2, id: String) -> void:
	var price: int = int(MetaManager.UNIT_CHESTS[id]["price"])
	var afford: bool = MetaManager.gold >= price
	if not afford:
		_scrim(card)
	# Left pressable either way: a card that answers with why it cannot be
	# bought is worth more than one that does not answer at all.
	_hit(card).pressed.connect(func() -> void:
		var drawn: Array = MetaManager.buy_unit_chest(id)
		if drawn.is_empty():
			_toast(card, "NOT ENOUGH GOLD", UIStyle.ACCENT_RED)
			return
		Sfx.coin()
		_show(Page.SHOP)
		_toast(card, "+%d UNITS TO YOUR PACK" % drawn.size(), UIStyle.ACCENT_TEAL))

func _hero_card(card: Rect2) -> void:
	if MetaManager.gold < MetaManager.HERO_CHEST_PRICE:
		_scrim(card)
	_hit(card).pressed.connect(func() -> void:
		var id: String = MetaManager.buy_hero_chest()
		if id == "":
			_toast(card, "NOT ENOUGH GOLD", UIStyle.ACCENT_RED)
			return
		Sfx.coin()
		_show(Page.SHOP)
		_toast(card, String(UnitDatabase.get_def(id).get("name", "HERO")),
			UIStyle.ACCENT_PURPLE))

# The two lines that are spent on a run rather than owned. One at a time: a
# line already paid for wears its price plate over with ARMED and cannot be
# bought again until a run has taken it.
func _consumable_card(card: Rect2, price_plate: Rect2, price: int, armed: bool,
		buy: Callable, armed_text: String) -> void:
	if armed:
		_scrim(card)
		_stamp(price_plate, "ARMED")
	elif MetaManager.gold < price:
		_scrim(card)

	_hit(card).pressed.connect(func() -> void:
		if armed:
			_toast(card, armed_text, SPENT_INK)
			return
		if not bool(buy.call()):
			_toast(card, "NOT ENOUGH GOLD", UIStyle.ACCENT_RED)
			return
		Sfx.coin()
		_show(Page.SHOP)
		_toast(card, "READY FOR YOUR NEXT RUN", UIStyle.ACCENT_TEAL))

# ------------------------------------------------------------- the gold page

func _build_gold() -> void:
	_balance(G_ESS_TEXT, G_PILL, _money(MetaManager.essence))
	_hit(G_ESS_PLUS).pressed.connect(func() -> void: _go(Page.ESSENCE))
	_hit(G_CLOSE).pressed.connect(_close_out)
	_build_rail()

	var packs: Array = MetaManager.GOLD_PACKS
	for i in range(packs.size()):
		var card: Rect2 = _pack_card(i, G_ROW_Y, G_ROW_H, G_COL_X, G_COL_W)
		var price: int = int((packs[i] as Dictionary)["essence"])
		if MetaManager.essence < price:
			_scrim(card)
		var index: int = i
		_hit(card).pressed.connect(func() -> void:
			if not MetaManager.buy_gold_pack(index):
				_toast(card, "NOT ENOUGH ESSENCE", UIStyle.ACCENT_RED)
				return
			Sfx.coin()
			_show(Page.GOLD)
			_toast(card, "+%s GOLD" % _money(int((packs[index] as Dictionary)["gold"])),
				UIStyle.ACCENT_GOLD))

	# The banner points at one of the six rather than anywhere else, so pressing
	# it lights that one up instead of doing nothing.
	var best: Rect2 = _pack_card(MetaManager.GOLD_PACK_BEST, G_ROW_Y, G_ROW_H,
		G_COL_X, G_COL_W)
	_hit(G_SEE_OFFERS).pressed.connect(func() -> void: _flash(best))

func _pack_card(index: int, rows: Array, heights: Array, cols: Array,
		widths: Array) -> Rect2:
	var row: int = index / cols.size()
	var col: int = index % cols.size()
	return Rect2(float(cols[col]), float(rows[row]), float(widths[col]),
		float(heights[row]))

# ---------------------------------------------------------- the essence page
#
# The one page with nothing behind it: these are money prices, and there is no
# store wired to this build to take money. The packs are left readable and
# pressable and say so when pressed, rather than being greyed into a page that
# looks broken.

func _build_essence() -> void:
	_balance(E_ESS_TEXT, E_PILL, _money(MetaManager.essence))
	_hit(E_ESS_PLUS).pressed.connect(func() -> void: _go(Page.ESSENCE))
	_hit(E_CLOSE).pressed.connect(_close_out)
	_build_rail()

	for i in range(6):
		var card: Rect2 = _pack_card(i, E_ROW_Y, E_ROW_H, E_COL_X, E_COL_W)
		_hit(card).pressed.connect(func() -> void:
			_toast(card, "STORE NOT OPEN YET", SPENT_INK))

# ------------------------------------------------------------------- the rail
#
# One row that belongs to the shop rather than to any one of its pages. Both
# money pages arrive whole -- their own frame, their own X, nothing shared with
# the shelf -- which is exactly what makes them read as something that opened
# on top of the shop instead of as the shop with another tab showing. The rail
# is what says otherwise, so all three carry it, and it says which of the three
# you are on: that one is lit and the other two are turned down.

func _build_rail() -> void:
	if _page == Page.SHOP:
		var w: Rect2 = _at(RAIL_WIPE)
		var wipe := ColorRect.new()
		wipe.position = w.position
		wipe.size = w.size
		wipe.color = Color(0, 0, 0, 1)
		wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_page_root.add_child(wipe)

	for i in range(RAIL_TABS.size()):
		_rail_tab(i)

# Where a tab lands. The one thing on this screen that does not go through
# _at(): the rail is no longer where it was painted, so only its columns are
# the painting's -- its row is the black under the plate.
func _rail_rect(index: int) -> Rect2:
	var s: float = _plate_size.x / ART_SIZE.x
	var h: float = RAIL_H * s
	var cut: Rect2 = RAIL_TABS[index]
	# Centred in what is left below the plate, which on a taller screen than the
	# art is drawn for is a band of black, and on a shorter one is nothing --
	# where the same sum walks the rail back up onto the plate's bottom edge.
	var y: float = _plate_pos.y + _plate_size.y
	y += (size.y - y - h) * 0.5
	return Rect2(Vector2(_plate_pos.x + cut.position.x * s, y),
		Vector2(cut.size.x * s, h))

func _rail_tab(index: int) -> void:
	var at: Rect2 = _rail_rect(index)
	var lit: bool = index == _page

	var tex := AtlasTexture.new()
	tex.atlas = load(String(ART[Page.SHOP]))
	tex.region = RAIL_TABS[index]

	var face := TextureRect.new()
	face.texture = tex
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.position = at.position
	face.size = at.size
	face.modulate = Color.WHITE if lit else RAIL_DIM
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(face)

	# The plate painted its own tab lit and the other two dark, so the cut-out
	# of the gold tab has no lit state of its own to wear. It is given one here
	# rather than asked for as a fourth picture.
	if lit:
		var glow := Panel.new()
		glow.position = at.position
		glow.size = at.size
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UIStyle.ACCENT_GOLD.r, UIStyle.ACCENT_GOLD.g,
			UIStyle.ACCENT_GOLD.b, 0.13)
		sb.border_color = UIStyle.ACCENT_GOLD
		sb.set_border_width_all(maxi(2, _px(4.0)))
		sb.set_corner_radius_all(_px(14.0))
		glow.add_theme_stylebox_override("panel", sb)
		_page_root.add_child(glow)
	else:
		var off := ColorRect.new()
		off.position = at.position
		off.size = at.size
		off.color = RAIL_OFF
		off.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_page_root.add_child(off)

	_hit_at(at).pressed.connect(func() -> void: _go(index))

# ------------------------------------------------------------------- pieces

# A rect given in the painting's pixels, in the screen's.
func _at(where: Rect2) -> Rect2:
	var s: float = _plate_size.x / ART_SIZE.x
	return Rect2(_plate_pos + where.position * s, where.size * s)

# A length in the painting's pixels, in the screen's.
func _px(v: float) -> int:
	return maxi(1, int(round(v * _plate_size.x / ART_SIZE.x)))

# A painted figure wiped out and the real one written in its place.
func _balance(where: Rect2, fill: Color, text: String) -> void:
	var r: Rect2 = _at(where)
	var patch := ColorRect.new()
	patch.position = r.position
	patch.size = r.size
	patch.color = fill
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(patch)

	var lbl := Label.new()
	lbl.position = Vector2.ZERO
	lbl.size = r.size
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(BALANCE_SIZE))
	# Never allowed to run off its own patch and onto the icon beside it: the
	# pill is only as wide as the picture drew it.
	lbl.clip_text = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, BALANCE_INK, 4)
	patch.add_child(lbl)

# A painted line wiped out and a different one written over it. Wrapped rather
# than broken by hand: the replacement wordings are longer than the ones they
# replace and the card is only so wide.
func _rewrite(line: Dictionary) -> void:
	var where: Rect2 = line["rect"]
	var r: Rect2 = _at(where)
	var patch := ColorRect.new()
	patch.position = r.position
	patch.size = r.size
	patch.color = line["bg"]
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(patch)

	# Given more height than the patch and centred on it, so a wrap that comes
	# out a line taller than the painted one still sits centred instead of
	# being pushed down. The card behind is the patch's own colour for a good
	# way above and below, so a line of overhang is invisible.
	var pad: float = r.size.y * 0.5
	var lbl := Label.new()
	lbl.position = Vector2(0.0, -pad)
	lbl.size = Vector2(r.size.x, r.size.y + pad * 2.0)
	lbl.text = String(line["text"])
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(LINE_SIZE))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(lbl, LINE_INK)
	patch.add_child(lbl)

# An invisible button over a painted one, with the press feedback a painting
# cannot give.
func _hit(where: Rect2) -> Button:
	return _hit_at(_at(where))

# The same again, in screen pixels rather than the painting's -- for the rail,
# which is the one row that is not laid over something painted where it sits.
func _hit_at(r: Rect2) -> Button:
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

# Greys a card out where the painting cannot: a line that cannot be bought
# right now has to look like one before it is pressed.
func _scrim(where: Rect2) -> void:
	var r: Rect2 = _at(where)
	var box := ColorRect.new()
	box.position = r.position
	box.size = r.size
	box.color = LOCKED_SCRIM
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(box)

# A painted price plate covered over with a word: what a line that has already
# been paid for says instead of what it costs.
func _stamp(where: Rect2, text: String) -> void:
	var r: Rect2 = _at(where)
	var plate := Panel.new()
	plate.position = r.position
	plate.size = r.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = SPENT_FILL
	sb.border_color = SPENT_EDGE
	sb.set_border_width_all(maxi(2, _px(3.0)))
	sb.set_corner_radius_all(_px(12.0))
	plate.add_theme_stylebox_override("panel", sb)
	_page_root.add_child(plate)

	var lbl := Label.new()
	lbl.position = Vector2.ZERO
	lbl.size = r.size
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(28.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, SPENT_INK, 4)
	plate.add_child(lbl)

# One beat of the biome wash over a card the banner is pointing at, so SEE
# OFFERS lands on something instead of doing nothing.
func _flash(where: Rect2) -> void:
	var r: Rect2 = _at(where)
	var glow := ColorRect.new()
	glow.position = r.position
	glow.size = r.size
	glow.color = Color(1.0, 0.86, 0.45, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(glow)
	var t := create_tween()
	t.set_loops(3)
	t.tween_property(glow, "color:a", 0.30, 0.18)
	t.tween_property(glow, "color:a", 0.0, 0.18)
	# On the whole tween finishing rather than chained onto it: a chained step
	# inside a looped tween loops with it and would free the wash three times.
	t.finished.connect(glow.queue_free)

# What was bought, rising off the card it came from -- so a purchase is seen
# landing rather than only changing a figure at the top of the screen.
#
# Struck across the whole plate rather than sized to the card: the cards are a
# quarter of the screen wide and most of these lines are not, and a message
# centred on one card and spilling over the two beside it reads as a mistake.
func _toast(where: Rect2, text: String, color: Color) -> void:
	# One at a time. Two of these raised inside the second they live for land on
	# the same line of the plate and read as one line with two messages printed
	# over each other, which is what tapping along a row of cards that cannot be
	# afforded does. A new message takes the place of the one still rising.
	if _toast_label != null and is_instance_valid(_toast_label):
		_toast_label.queue_free()
	var r: Rect2 = _at(where)
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(_plate_pos.x, r.position.y + r.size.y * 0.42)
	lbl.size = Vector2(_plate_size.x, 52.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, color, 7)
	# On this node rather than on the page, so rebuilding the page underneath
	# it does not take the message away before it has been read.
	add_child(lbl)
	_toast_label = lbl

	var t := create_tween()
	t.tween_property(lbl, "position:y", lbl.position.y - 46.0, 0.9)
	t.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.5)
	t.tween_callback(lbl.queue_free)

# ------------------------------------------------------------------ the clock

func _process(delta: float) -> void:
	# One tick a second, and only while there is a clock on screen to move: the
	# rest of this screen answers to presses and to nothing else.
	if not visible or _page != Page.SHOP or _free_label == null:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	_refresh_free_gold()

# Hours and minutes for a wait measured in a day, minutes and seconds for the
# last hour of it: the number that is about to change is the one worth showing.
func _clock(seconds: int) -> String:
	if seconds >= 3600:
		return "%dh %02dm" % [seconds / 3600, (seconds / 60) % 60]
	if seconds >= 60:
		return "%dm %02ds" % [seconds / 60, seconds % 60]
	return "%ds" % maxi(seconds, 0)

# The painting writes its figures with separators, so these do too. Past a
# million the separators stop earning their place inside a pill this wide and
# the figure is compacted instead of being clipped.
func _money(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
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
