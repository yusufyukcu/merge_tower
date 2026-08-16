extends Control

const UIStyle = preload("res://scripts/ui/UIStyle.gd")

# The shop. Gold had nowhere to go until now: it counted up in the corner and
# sat there. Everything on sale here is something the player already wanted
# mid-wave -- a board they can no longer work with, a fortress taking hits, a
# branch that will not drop.
#
# Runs with PROCESS_MODE_ALWAYS and freezes the game behind it, like the pause
# menu: buying is a decision, not a reflex test.
#
# The shelf itself is one painted plate (art/shop_panel.png): frame, banners,
# every row's icon, name, description and price are in the picture. Only three
# things on it actually move -- the gold balance, the unit slot's price and its
# "field limit N units" line -- and those three patches were wiped out of the
# art so they can be drawn live over the top. The buttons are invisible hit
# boxes laid on the painted rows, the same way SEND works.
#
# Main owns the tray and the fortress, so it decides what a purchase does and
# whether it is available at all; this node only shows the shelf and reports
# what was pressed.

signal purchase_requested(id: String)
signal closed

const ITEMS := [
	{"id": "unit_slot", "name": "+1 UNIT SLOT", "price": 100},
	{"id": "clear", "name": "CLEAR TRAY", "price": 100},
	{"id": "repair", "name": "REPAIR WALLS", "price": 80},
	{"id": "warrior", "name": "WARRIOR", "price": 150},
	{"id": "archer", "name": "ARCHER", "price": 150},
	{"id": "apprentice_mage", "name": "APPR. MAGE", "price": 150},
]

const ART := "res://art/shop_panel.png"
const ART_SIZE := Vector2(1085.0, 1450.0)
const PANEL_WIDTH := 1000.0

# Everything below is measured off the painting, in its own pixels, and scaled
# with it. Keeping them in art space means the numbers can be read straight off
# the file if the shelf is ever redrawn.
const ROW_X := 103.0
const ROW_W := 884.0
const ROW_TOP := 345.0
const ROW_PITCH := 149.0
const ROW_H := 142.0

const BALANCE_RECT := Rect2(472, 258, 232, 56)
const SLOT_PRICE_RECT := Rect2(800, 388, 98, 56)
const SLOT_DESC_RECT := Rect2(268, 424, 356, 40)
const CLOSE_RECT := Rect2(348, 1262, 389, 123)

# Painted to match the plate: the prices on the shelf are this red, the balance
# this parchment white.
const PRICE_RED := Color(0.87, 0.24, 0.18)
const PRICE_DIM := Color(0.45, 0.30, 0.28)
const BALANCE_INK := Color(0.96, 0.94, 0.88)

var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO

var _balance: Label
var _slot_price: Label
var _slot_desc: Label
var _rows: Array = []        # [{ "button": Button, "veil": ColorRect, "id": String }]

func build(view_size: Vector2) -> void:
	position = Vector2.ZERO
	size = view_size
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Sized outright rather than anchored to fill: this node is built hidden and
	# its own rect never resolved, so a dim anchored to it came out zero-sized
	# and the game behind the shelf was never dimmed at all.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.80)
	dim.position = Vector2.ZERO
	dim.size = view_size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_scale = PANEL_WIDTH / ART_SIZE.x
	var panel_size := ART_SIZE * _scale
	_origin = Vector2((view_size.x - panel_size.x) / 2.0,
		(view_size.y - panel_size.y) / 2.0)

	var plate := TextureRect.new()
	plate.texture = load(ART)
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Without this the control's minimum size is the texture's own, and the
	# plate ignores the size it is given.
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.position = _origin
	plate.size = panel_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

	_balance = _label(BALANCE_RECT, 40.0, BALANCE_INK, HORIZONTAL_ALIGNMENT_CENTER)
	_slot_price = _label(SLOT_PRICE_RECT, 40.0, PRICE_RED, HORIZONTAL_ALIGNMENT_RIGHT)
	_slot_desc = _label(SLOT_DESC_RECT, 26.0, Color(0.76, 0.71, 0.62),
		HORIZONTAL_ALIGNMENT_LEFT)

	_rows = []
	for i in range(ITEMS.size()):
		_rows.append(_build_row(i))

	var close := Button.new()
	close.text = ""
	close.position = _at(CLOSE_RECT.position)
	close.size = CLOSE_RECT.size * _scale
	close.pressed.connect(func() -> void: closed.emit())
	_strip(close)
	add_child(close)
	_add_press_wash(close, Color(1, 0.85, 0.7))

# A rect in the painting's own pixels, placed on screen.
func _at(p: Vector2) -> Vector2:
	return _origin + p * _scale

func _label(rect: Rect2, size: float, color: Color, align: int) -> Label:
	var l := Label.new()
	l.position = _at(rect.position)
	l.size = rect.size * _scale
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(size * _scale))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(l, color)
	add_child(l)
	return l

func _build_row(index: int) -> Dictionary:
	var top: float = ROW_TOP + index * ROW_PITCH
	var pos := _at(Vector2(ROW_X, top))
	var size := Vector2(ROW_W, ROW_H) * _scale

	# Greys a row out where the painting cannot: a line that cannot be bought
	# has to look like one.
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.6)
	veil.position = pos
	veil.size = size
	veil.visible = false
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var btn := Button.new()
	btn.text = ""
	btn.position = pos
	btn.size = size
	var id: String = String(ITEMS[index]["id"])
	btn.pressed.connect(func() -> void: purchase_requested.emit(id))
	_strip(btn)
	add_child(btn)
	_add_press_wash(btn, Color(1, 0.9, 0.6))

	return {"button": btn, "veil": veil, "id": id}

func _strip(btn: Button) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())

# The painted plate cannot light up on its own, so a wash sits over it.
func _add_press_wash(btn: Button, tint: Color) -> void:
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(tint.r, tint.g, tint.b, 0.0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(wash)
	btn.button_down.connect(func() -> void:
		wash.color = Color(tint.r, tint.g, tint.b, 0.16))
	btn.button_up.connect(func() -> void:
		wash.color = Color(tint.r, tint.g, tint.b, 0.0))

func open(coins: int, available: Dictionary, prices: Dictionary = {},
		descs: Dictionary = {}) -> void:
	visible = true
	refresh(coins, available, prices, descs)

func close() -> void:
	visible = false

# `available` carries what Main knows and this node cannot: whether the tray
# has anything to clear, whether the fortress has damage worth repairing.
# `prices` and `descs` override the shelf price and blurb by id, for the lines
# whose cost or wording changes as the run goes on. A price of 0 means the row
# is spent for good: it reads MAX and cannot be pressed.
func refresh(coins: int, available: Dictionary, prices: Dictionary = {},
		descs: Dictionary = {}) -> void:
	_balance.text = "%d GOLD" % coins

	var slot_price: int = int(prices.get("unit_slot", ITEMS[0]["price"]))
	var sold_out: bool = slot_price <= 0
	_slot_price.text = "MAX" if sold_out else str(slot_price)
	_slot_price.add_theme_color_override("font_color",
		PRICE_DIM if sold_out or coins < slot_price else PRICE_RED)
	_slot_desc.text = String(descs.get("unit_slot", ""))

	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var id: String = String(row["id"])
		var price: int = int(prices.get(id, ITEMS[i]["price"]))
		var usable: bool = price > 0 and bool(available.get(id, true)) and coins >= price
		(row["button"] as Button).disabled = not usable
		(row["veil"] as ColorRect).visible = not usable

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()
