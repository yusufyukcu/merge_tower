extends Control

const UIStyle = preload("res://scripts/ui/UIStyle.gd")

# Every room off the menu that is a list rather than a painting: the pack, what
# essence buys, what merging has turned up, how far the road has gone, and what
# the player has actually done.
#
# One board, five pages -- the same shape ShopScreen uses for its three. They are
# not five rooms that happen to resemble each other; they are one room with five
# things in it, and the only honest way to build that is once.
#
# The board is the in-run shop's plate, art/shop_panel.png: a framed panel with a
# banner and a title cartouche at the head, a bar under it, a stack of rows, and
# a CLOSE at the foot standing between the barrel and the lantern. It is the only
# plate in the game shaped like a list, and the only other place it is ever seen
# is inside a run, where none of these pages can be. What is painted into it and
# cannot be true here -- the word SHOP, the gold balance, the six rows on sale --
# is covered and rewritten, the same way the quest board and the hero shelf are
# handled.
#
# The rows are drawn rather than painted for the one reason they have to be: not
# one of these pages has a fixed length. So the band is a scroll, and every page
# builds the same card into it -- same fill, same edge in the colour of whatever
# is on it, same padding, same plate on the right -- and differs only in what it
# has to say.

signal closed

enum Page { INVENTORY, UPGRADES, COLLECTION, CAMPAIGN, ACHIEVEMENTS }

const ART := "res://art/shop_panel.png"
const ART_SIZE := Vector2(1085.0, 1450.0)

# Held to nine tenths of the screen, over a dim rather than over black, so the
# menu shows around the edges and the board reads as something laid on top of
# the screen instead of as somewhere the player has gone. The quest board and
# the hero shelf are held to the same fraction.
const POPUP_WIDTH := 0.90

# ------------------------------------------------------------------ the plan
#
# Every rect below is in the painting's own pixels and goes through _at().

const TITLE_RECT := Rect2(406, 108, 284, 96)
const TALLY_RECT := Rect2(382, 257, 322, 50)
const BAND_RECT := Rect2(100, 340, 890, 900)
const LIST_RECT := Rect2(103, 344, 884, 892)
const CLOSE_RECT := Rect2(348, 1262, 389, 123)

# One row, on the pitch the painted shelf already uses, so the drawn rows fall
# exactly where the painted ones did.
const ROW_W := 884.0
const ROW_H := 142.0
const ROW_GAP := 7.0
const TILE_H := 158.0

const WELL_RECT := Rect2(8, 8, 126, 126)
const PIC_INSET := 12.0
const TEXT_X := 152.0
const RIGHT_X := 664.0
const RIGHT_W := 200.0
const RIGHT_H := 62.0
const RIGHT_Y := 40.0

const NAME_SIZE := 29.0
const DESC_SIZE := 21.0
const SUB_SIZE := 23.0
const PLATE_SIZE := 25.0
const TITLE_SIZE := 52.0
const TALLY_SIZE := 27.0

# ------------------------------------------------------------------- the ink
#
# All three sampled off the plate: the board behind the rows is a flat #0b0d12,
# the bar under the title #0f0f10 and the cartouche the title sits in a navy
# #131b28, so a patch of each lands on the painting without a seam.
const BAND_INK := Color(0.043, 0.051, 0.071, 1.0)
const BAR_INK := Color(0.059, 0.059, 0.063, 1.0)
const TITLE_INK := Color(0.075, 0.106, 0.157, 1.0)

const GOLD := Color(0.90, 0.72, 0.34)
const ROW_INK := Color(0.039, 0.043, 0.055, 1.0)
const ROW_EDGE := Color(0.26, 0.24, 0.19)
const TEXT_INK := Color(0.92, 0.92, 0.94)
const SUB_INK := Color(0.62, 0.62, 0.66)
const TALLY_INK := Color(0.94, 0.92, 0.86)
const LOCKED := Color(0.40, 0.42, 0.50)
const ESSENCE_INK := Color(0.42, 0.72, 1.0)
const PRESS_WASH := Color(1.0, 0.90, 0.55, 0.18)

const ESSENCE_ICON := "res://art/icon_essence.png"

# What each page is called. The colour is the board's own gold everywhere: the
# plate is one plate, and five different frames on it would undo that.
const TITLES := {
	Page.INVENTORY: "INVENTORY",
	Page.UPGRADES: "UPGRADES",
	Page.COLLECTION: "COLLECTION",
	Page.CAMPAIGN: "CAMPAIGN",
	Page.ACHIEVEMENTS: "ACHIEVEMENTS",
}

# The picture on an upgrade's row. Every line essence buys is a line about
# something the game already has a drawing of, so none of them has to go bare.
const UPGRADE_ART := {
	"slot": "res://art/icon_arrow.png",
	"wood_spawn": "res://art/wood.png",
	"bow_spawn": "res://art/bow.png",
	"crystal_spawn": "res://art/crystal.png",
	"fourth": "res://art/fx_merge_critical.png",
	"discount": "res://art/icon_coin.png",
	"tier4": "res://art/stone_golem.png",
	"veteran": "res://art/ice_dragon.png",
}

# The colour each chapter of the road wears, matching the menu's own moods.
const BIOME_ACCENTS := {
	"forest": Color(0.60, 0.84, 0.32),
	"ice": Color(0.48, 0.78, 1.00),
	"lava": Color(1.00, 0.56, 0.22),
}

var _plate_pos: Vector2 = Vector2.ZERO
var _plate_size: Vector2 = Vector2.ZERO
var _scale: float = 1.0
var _dim: ColorRect = null
var _page_root: Control = null
var _list: VBoxContainer = null
var _page: int = Page.INVENTORY

func build(view_size: Vector2) -> void:
	position = Vector2.ZERO
	size = view_size
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Not opaque: what makes this a pop-up rather than a room is that the menu
	# is still there behind it.
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

func open(page: int) -> void:
	_page = page
	visible = true
	_show()
	_pop()

func close() -> void:
	visible = false
	if _page_root != null:
		_page_root.queue_free()
		_page_root = null
	_list = null

func _close_out() -> void:
	close()
	closed.emit()

# The board arriving rather than appearing. Only ever on the way in -- the page
# redraws itself after every purchase, and a board that jumps every time it is
# rebuilt is a board nobody can read.
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

# ----------------------------------------------------------------- the board

func _show() -> void:
	if _page_root != null:
		# Hidden as well as freed: queue_free lands at the end of the frame, and
		# a board still taking presses after it has been replaced can spend the
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

	_wipe(TITLE_RECT, TITLE_INK)
	_ink(TITLE_RECT, String(TITLES.get(_page, "")), GOLD, TITLE_SIZE, 8)

	_wipe(TALLY_RECT, BAR_INK)
	_ink(TALLY_RECT, _tally(), TALLY_INK, TALLY_SIZE, 4)

	_wipe(BAND_RECT, BAND_INK)
	_build_list()

	_hit(CLOSE_RECT).pressed.connect(_close_out)

func _tally() -> String:
	match _page:
		Page.INVENTORY:
			var n: int = MetaManager.inventory_count()
			return "%d UNIT%s BROUGHT HOME" % [n, "" if n == 1 else "S"]
		Page.UPGRADES:
			return "%s ESSENCE IN HAND" % _money(MetaManager.essence)
		Page.COLLECTION:
			var seen: int = 0
			var total: int = 0
			for branch in UnitDatabase.MERGE_BRANCHES:
				for id in branch:
					total += 1
					if bool(MetaManager.units_seen.get(id, false)):
						seen += 1
			return "%d / %d DISCOVERED" % [seen, total]
		Page.CAMPAIGN:
			return "BEST WAVE %d" % MetaManager.best_wave
		_:
			var done: int = 0
			for id in MetaManager.ACHIEVEMENTS.keys():
				if MetaManager.has_achievement(String(id)):
					done += 1
			return "%d / %d EARNED" % [done, MetaManager.ACHIEVEMENTS.size()]

func _build_list() -> void:
	var r: Rect2 = _at(LIST_RECT)
	var scroll := ScrollContainer.new()
	scroll.position = r.position
	scroll.size = r.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", _px(ROW_GAP))
	# Held to the height of the band it sits in and centred inside it, so a page
	# with three rows on it sits in the middle of the board rather than at the
	# top of an empty one. A page with more rows than fit outgrows this and
	# scrolls as normal -- there is no spare room left to centre it in.
	_list.custom_minimum_size = Vector2(0, r.size.y)
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(_list)

	match _page:
		Page.INVENTORY:
			_fill_inventory()
		Page.UPGRADES:
			_fill_upgrades()
		Page.COLLECTION:
			_fill_collection()
		Page.CAMPAIGN:
			_fill_campaign()
		_:
			_fill_achievements()

# --------------------------------------------------------------- the pack

func _fill_inventory() -> void:
	var stacks: Array = MetaManager.inventory_stacks()
	if stacks.is_empty():
		_empty("Nothing yet.\n\nPress RETREAT during a run and everything still standing on the field comes back with you. Lose the fortress instead and it is all left behind.")
		return
	for stack in stacks:
		var s: Dictionary = stack as Dictionary
		var id: String = String(s.get("id", ""))
		var d: Dictionary = UnitDatabase.get_def(id)
		var accent: Color = d.get("color", GOLD)
		var row: Control = _row(accent)
		_well(row, accent, UnitDatabase.get_art_path(id), UnitDatabase.get_art_tint(id), "")
		_name(row, TEXT_X, String(d.get("name", id)), accent.lightened(0.2))
		_sub(row, TEXT_X, "TIER %d" % int(d.get("level", 0)))
		_plate(row, "LV %d" % int(s.get("level", 1)), GOLD, true, "")
		_under(row, "x%d" % int(s.get("count", 1)), accent.lightened(0.2))

# ------------------------------------------------------------------ upgrades

func _fill_upgrades() -> void:
	_buy_row(GOLD, UPGRADE_ART["slot"],
		"PERMANENT UNIT SLOT  %d / %d" % [MetaManager.bonus_slot_tier,
			MetaManager.BONUS_SLOT_COSTS.size()],
		"Every run starts with one more field slot than the last, for good.",
		MetaManager.next_bonus_slot_cost(),
		func() -> bool: return MetaManager.buy_bonus_slot())

	for id in MetaManager.META_UPGRADE_IDS:
		var branch: String = String(id)
		_buy_row(UIStyle.ACCENT_GREEN, String(UPGRADE_ART.get(branch, "")),
			"%s  %d / %d" % [MetaManager.META_UPGRADE_NAMES.get(branch, branch),
				MetaManager.meta_upgrade_level(branch), MetaManager.META_UPGRADE_COSTS.size()],
			"Every run starts with this branch's drop-luck one step ahead, for good.",
			MetaManager.next_meta_upgrade_cost(branch),
			func() -> bool: return MetaManager.buy_meta_upgrade(branch))

	if MetaManager.fourth_card_unlocked:
		_state_row(UIStyle.ACCENT_GREEN, UPGRADE_ART["fourth"], "FOURTH UPGRADE CARD",
			"Every upgrade choice this run and every run after it offers one more card.",
			"OWNED", true)
	else:
		_buy_row(UIStyle.ACCENT_PURPLE, UPGRADE_ART["fourth"], "FOURTH UPGRADE CARD",
			"Every upgrade choice this run and every run after it offers one more card.",
			MetaManager.FOURTH_CARD_COST,
			func() -> bool: return MetaManager.buy_fourth_card())

	_buy_row(UIStyle.ACCENT_BLUE, UPGRADE_ART["discount"],
		"QUARTERMASTER'S DISCOUNT  %d / %d" % [MetaManager.discount_tier,
			MetaManager.DISCOUNT_COSTS.size()],
		"Every field slot bought with gold, every run from now on, %d%% cheaper."
			% int(round((1.0 - MetaManager.discount_mult()) * 100.0)),
		MetaManager.next_discount_cost(),
		func() -> bool: return MetaManager.buy_discount())

	var t4: bool = MetaManager.has_tier4()
	_state_row(UIStyle.ACCENT_GREEN if t4 else LOCKED, UPGRADE_ART["tier4"],
		"TIER IV UPGRADES", "Unlocked by reaching wave 30 in a past run.",
		"UNLOCKED" if t4 else "LOCKED", t4)
	var vet: bool = MetaManager.has_dragon_bonus()
	_state_row(UIStyle.ACCENT_GREEN if vet else LOCKED, UPGRADE_ART["veteran"],
		"VETERAN START BONUS", "Unlocked by beating the ice dragon in a past run.",
		"UNLOCKED" if vet else "LOCKED", vet)

# A line with a price on it. A cost of 0 is the top of its track and reads MAX.
func _buy_row(accent: Color, art: String, title: String, desc: String, cost: int,
		buy: Callable) -> void:
	var row: Control = _row(accent)
	_well(row, accent, art, Color(1, 1, 1), "")
	_name(row, TEXT_X, title, TEXT_INK)
	_desc(row, TEXT_X, desc)
	if cost <= 0:
		_plate(row, "MAX", GOLD, false, "")
		return
	var afford: bool = MetaManager.essence >= cost
	var seat: Rect2 = Rect2(RIGHT_X, RIGHT_Y, RIGHT_W, RIGHT_H)
	_plate(row, _money(cost), ESSENCE_INK, afford, ESSENCE_ICON)
	if not afford:
		return
	_hit_on(row, seat).pressed.connect(func() -> void:
		if buy.call():
			Sfx.coin()
			_show())

# A line that is earned rather than bought.
func _state_row(accent: Color, art: String, title: String, desc: String,
		state: String, live: bool) -> void:
	var row: Control = _row(accent)
	_well(row, accent, art, Color(1, 1, 1), "")
	_name(row, TEXT_X, title, TEXT_INK if live else SUB_INK)
	_desc(row, TEXT_X, desc)
	_plate(row, state, accent, live, "")

# ---------------------------------------------------------------- collection

func _fill_collection() -> void:
	for branch in UnitDatabase.MERGE_BRANCHES:
		var line := HBoxContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_constant_override("separation", _px(ROW_GAP))
		_list.add_child(line)
		for id in branch:
			line.add_child(_tile(String(id)))

func _tile(id: String) -> Control:
	var seen: bool = bool(MetaManager.units_seen.get(id, false))
	var d: Dictionary = UnitDatabase.get_def(id)
	var accent: Color = (d.get("color", GOLD) as Color) if seen else LOCKED

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, _px(TILE_H))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", _card_box(accent, 3.0))

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", _px(4.0))
	box.add_child(col)

	# The body itself once it has been found, and a hole where it goes until
	# then -- a collection that shows what is missing is worth more than one
	# that shows nothing at all.
	var art: String = UnitDatabase.get_art_path(id)
	if seen and art != "" and ResourceLoader.exists(art):
		var pic := TextureRect.new()
		pic.texture = load(art)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(0, _px(74.0))
		pic.modulate = UnitDatabase.get_art_tint(id)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(pic)
	else:
		var hole := Label.new()
		hole.text = "?"
		hole.custom_minimum_size = Vector2(0, _px(74.0))
		hole.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hole.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hole.add_theme_font_size_override("font_size", _px(50.0))
		hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIStyle.apply_heading(hole, LOCKED, 4)
		col.add_child(hole)

	var name_lbl := Label.new()
	name_lbl.text = String(d.get("name", id)) if seen else "?????"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", _px(20.0))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(name_lbl, accent.lightened(0.2) if seen else SUB_INK, 4)
	col.add_child(name_lbl)

	var tier := Label.new()
	tier.text = ("TIER %d" % int(d.get("level", 0))) if seen else "UNDISCOVERED"
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier.add_theme_font_size_override("font_size", _px(17.0))
	tier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(tier, SUB_INK, 3)
	col.add_child(tier)

	return box

# ------------------------------------------------------------------ campaign

func _fill_campaign() -> void:
	var furthest: int = int(MetaManager.biome_def(MetaManager.furthest_biome()).get("chapter", 1))
	var here: String = MetaManager.menu_biome()
	for id in MetaManager.BIOME_ORDER:
		var key: String = String(id)
		var d: Dictionary = MetaManager.biome_def(key)
		var chapter: int = int(d.get("chapter", 1))
		var reached: bool = MetaManager.best_wave > 0 and furthest >= chapter
		var accent: Color = BIOME_ACCENTS.get(key, GOLD) if reached else LOCKED

		var row: Control = _row(accent)
		# The chapter's number stands where every other page puts a picture, so
		# the road reads down the same column as everything else.
		_well(row, accent, "", Color(1, 1, 1), str(chapter))
		_name(row, TEXT_X, String(d.get("name", "")) if reached else "?????",
			TEXT_INK if reached else SUB_INK)
		_sub(row, TEXT_X, ("%s   ·   %s" % [d.get("waves", ""), d.get("boss", "")])
			if reached else String(d.get("waves", "")))

		var state: String = "REACHED" if reached else "LOCKED"
		var tint: Color = UIStyle.ACCENT_GREEN if reached else LOCKED
		if key == here and reached:
			state = "YOU ARE HERE"
			tint = accent
		_plate(row, state, tint, reached, "")

# -------------------------------------------------------------- achievements

func _fill_achievements() -> void:
	for id in MetaManager.ACHIEVEMENTS.keys():
		var key: String = String(id)
		var d: Dictionary = MetaManager.ACHIEVEMENTS.get(key, {})
		var won: bool = MetaManager.has_achievement(key)
		var accent: Color = UIStyle.ACCENT_GREEN if won else LOCKED
		var row: Control = _row(accent)
		# An achievement is the one thing on this board with no picture of its
		# own, so its well carries a mark instead -- but it still carries one,
		# because a row that starts its words where no other row does is the one
		# thing that would break the column down the page.
		_well(row, accent, "", Color(1, 1, 1), "✦" if won else "?")
		_name(row, TEXT_X, String(d.get("name", key)) if won else "?????",
			TEXT_INK if won else SUB_INK)
		_desc(row, TEXT_X, String(d.get("desc", "")) if won else "Not earned yet.")
		_plate(row, str(int(d.get("reward", 0))), ESSENCE_INK, won, ESSENCE_ICON)

# -------------------------------------------------------------------- pieces

# One line of the list: a dark card with the colour of whatever is on it down
# its left edge. Every page builds this one, and nothing else.
func _row(accent: Color) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, _px(ROW_H))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body := Panel.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", _card_box(accent, 7.0))
	row.add_child(body)
	_list.add_child(row)
	return row

func _card_box(accent: Color, left: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_INK
	sb.border_color = accent.darkened(0.45)
	sb.set_border_width_all(maxi(1, _px(2.0)))
	sb.border_width_left = maxi(2, _px(left))
	sb.set_corner_radius_all(_px(9.0))
	return sb

# The framed square on the left of a row, the way the painted shelf frames
# everything it is selling. Holds a picture, or a number when the page has one
# instead.
func _well(row: Control, accent: Color, art: String, tint: Color, glyph: String) -> void:
	var well := Panel.new()
	well.position = _sz(WELL_RECT.position)
	well.size = _sz(WELL_RECT.size)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.026).lerp(accent, 0.10)
	sb.border_color = accent.darkened(0.25)
	sb.set_border_width_all(maxi(1, _px(2.0)))
	sb.set_corner_radius_all(_px(8.0))
	well.add_theme_stylebox_override("panel", sb)
	row.add_child(well)

	if glyph != "":
		var lbl := Label.new()
		lbl.position = Vector2.ZERO
		lbl.size = well.size
		lbl.text = glyph
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", _px(62.0))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIStyle.apply_heading(lbl, accent, 6)
		well.add_child(lbl)
		return

	if art == "" or not ResourceLoader.exists(art):
		return
	var pic := TextureRect.new()
	pic.texture = load(art)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = _sz(Vector2(PIC_INSET, PIC_INSET))
	pic.size = _sz(WELL_RECT.size - Vector2(PIC_INSET, PIC_INSET) * 2.0)
	pic.modulate = tint
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(pic)

func _name(row: Control, x: float, text: String, ink: Color) -> void:
	_label(row, Rect2(x, 24, RIGHT_X - x - 18.0, 46), text, ink, NAME_SIZE, 5, false)

func _sub(row: Control, x: float, text: String) -> void:
	_label(row, Rect2(x, 76, RIGHT_X - x - 18.0, 40), text, SUB_INK, SUB_SIZE, 3, false)

func _desc(row: Control, x: float, text: String) -> void:
	_label(row, Rect2(x, 70, RIGHT_X - x - 18.0, 56), text, SUB_INK, DESC_SIZE, 3, true)

# The plate on the right of a row: what it costs, what level it is, or where the
# player stands. The same seat on every page, whatever it is holding.
func _plate(row: Control, text: String, ink: Color, live: bool, icon: String) -> void:
	var seat := Rect2(RIGHT_X, RIGHT_Y, RIGHT_W, RIGHT_H)
	var plate := Panel.new()
	plate.position = _sz(seat.position)
	plate.size = _sz(seat.size)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.052, 0.045).lerp(ink, 0.12 if live else 0.03)
	sb.border_color = ink.darkened(0.3 if live else 0.62)
	sb.set_border_width_all(maxi(1, _px(2.0)))
	sb.set_corner_radius_all(_px(8.0))
	plate.add_theme_stylebox_override("panel", sb)
	row.add_child(plate)

	var left: float = 14.0
	if icon != "" and ResourceLoader.exists(icon):
		var pic := TextureRect.new()
		pic.texture = load(icon)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = _sz(Vector2(left, (seat.size.y - 32.0) * 0.5))
		pic.size = _sz(Vector2(32, 32))
		pic.modulate = Color(1, 1, 1, 1.0 if live else 0.45)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(pic)
		left += 38.0

	var lbl := Label.new()
	lbl.position = _sz(Vector2(left, 0))
	lbl.size = _sz(Vector2(seat.size.x - left - 14.0, seat.size.y))
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _px(PLATE_SIZE))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, ink.lightened(0.2) if live else ink.darkened(0.3), 4)
	plate.add_child(lbl)

# A second reading under the plate, which only the pack has any use for.
func _under(row: Control, text: String, ink: Color) -> void:
	_label(row, Rect2(RIGHT_X, RIGHT_Y + RIGHT_H + 4.0, RIGHT_W, 34), text, ink,
		27.0, 4, false, HORIZONTAL_ALIGNMENT_CENTER)

func _empty(text: String) -> void:
	var r: Rect2 = _at(LIST_RECT)
	var lbl := Label.new()
	lbl.position = r.position
	lbl.size = r.size
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", _px(27.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, SUB_INK, 4)
	_page_root.add_child(lbl)

func _at(where: Rect2) -> Rect2:
	return Rect2(_plate_pos + where.position * _scale, where.size * _scale)

func _sz(v: Vector2) -> Vector2:
	return v * _scale

func _px(v: float) -> int:
	return maxi(1, int(round(v * _scale)))

func _wipe(where: Rect2, ink: Color) -> void:
	var r: Rect2 = _at(where)
	var patch := ColorRect.new()
	patch.position = r.position
	patch.size = r.size
	patch.color = ink
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.add_child(patch)

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
	_page_root.add_child(lbl)

# Inside a row, in the row's own art pixels.
func _label(row: Control, where: Rect2, text: String, color: Color, size_px: float,
		outline: int, wrap: bool, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if text == "":
		return
	var lbl := Label.new()
	lbl.position = _sz(where.position)
	lbl.size = _sz(where.size)
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", _px(size_px))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, color, outline)
	row.add_child(lbl)

func _hit(where: Rect2) -> Button:
	return _make_hit(_page_root, _at(where))

func _hit_on(row: Control, where: Rect2) -> Button:
	return _make_hit(row, Rect2(_sz(where.position), _sz(where.size)))

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
