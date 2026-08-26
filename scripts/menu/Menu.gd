extends Node2D

const UIStyle = preload("res://scripts/ui/UIStyle.gd")
const ShopScreen = preload("res://scripts/menu/ShopScreen.gd")
const QuestsScreen = preload("res://scripts/menu/QuestsScreen.gd")
const HeroPage = preload("res://scripts/ui/HeroPage.gd")
const MenuBoard = preload("res://scripts/menu/MenuBoard.gd")

# The main menu is one painting, the way the defeat screen and the pause plate
# are: the frame, the plaques, the rails and the BATTLE plate are all in the
# picture, and the real buttons are invisible hit boxes laid exactly over the
# painted ones.
#
# It is painted three times over -- art/forest_menu.png, art/ice_menu.png,
# art/lava_menu.png -- one for each place the road goes through, and which one
# is hung depends on where the player last left the field. Coming home means
# coming home to the last place you were rather than always to the forest, and
# because the three share a layout to the pixel, everything measured below is
# measured once and serves all three. The palette is the whole difference.
#
# The painting is a mock-up, and every number on it is painted: a rank of 19, a
# chapter of 86, four figures of gold nobody earned. A painted number cannot
# report anything, so each one is covered by a plate the colour of the plaque it
# sits in -- which reads as a recessed display rather than as a patch -- and a
# real label is drawn on top of it. See _slot.
#
# The painting is 2:3 against a 9:16 screen, so it is fitted by its width and
# never cropped. Filling instead would take both rails off the sides, and there
# is no version of this picture that survives losing them. What is left over
# above and below is the painting's own outermost rows pulled out to the edge --
# they are very nearly black in all three, so the letterbox reads as the frame
# continuing rather than as two bars.

const VIEW := Vector2(1080.0, 1920.0)
const ART_SIZE := Vector2(1024.0, 1536.0)
const GAME_SCENE := "res://scenes/main/Main.tscn"

# ------------------------------------------------------------------ the plan
#
# Every rect below is in the painting's own pixels, read off the art, and goes
# through _rect -- so the whole screen follows if the picture is ever drawn at
# another size, and nothing here is pinned to a screen coordinate.

# --- top bar
const PROFILE_RECT := Rect2(18, 43, 339, 117)
const RANK_RECT := Rect2(28, 139, 36, 32)
const NAME_RECT := Rect2(148, 63, 190, 36)
const XP_BAR_RECT := Rect2(148, 103, 182, 26)
const XP_TEXT_RECT := Rect2(190, 126, 106, 28)

const ENERGY_RECT := Rect2(365, 43, 150, 117)
const ENERGY_TOP_RECT := Rect2(424, 88, 88, 30)
const ENERGY_BOT_RECT := Rect2(424, 114, 88, 30)

const GEM_TEXT_RECT := Rect2(594, 88, 88, 32)
const GEM_PLUS_RECT := Rect2(684, 75, 44, 44)
const COIN_TEXT_RECT := Rect2(790, 86, 94, 34)
const COIN_PLUS_RECT := Rect2(886, 75, 44, 44)
const GEAR_RECT := Rect2(946, 73, 50, 50)

# --- centre. The word CHAPTER above the number is left painted: it is a label,
# not a reading, and it is the one thing up there that never changes.
const CHAPTER_NUM_RECT := Rect2(433, 338, 154, 128)
const CHAPTER_NAME_RECT := Rect2(358, 470, 308, 50)
const WAVE_LINE_RECT := Rect2(400, 538, 166, 40)
# Drawn larger than the painted glass it sits on: at this size the picture's
# own button is barely a thumb wide, and a hit box has to be reachable.
const WAVE_GLASS_RECT := Rect2(556, 528, 64, 60)

# --- the plate the whole screen is built around
# Re-measured when the three paintings were redrawn with the plaques on the
# road: the plate came down with them, and the old numbers had the hit box
# sitting half on the plaques above it.
const BATTLE_RECT := Rect2(320, 1109, 388, 183)
const BATTLE_SUB_RECT := Rect2(431, 1238, 163, 43)

# --- the three plaques standing on the road above the BATTLE plate. The middle
# one, the framed one, is the hero's; the two either side hold a body out of
# the pack. All three pictures put them in the same place, which is the only
# reason one set of numbers serves all three.
const HERO_SLOT_RECT := Rect2(427, 915, 170, 170)
const SQUAD_SLOT_RECTS := [Rect2(226, 920, 170, 164), Rect2(624, 920, 170, 164)]
# How far inside a plaque what fills it sits, so a picture reads as standing in
# the frame rather than laid over it.
const SLOT_INSET := 18.0

# --- the two rails. Five tiles a side, same pitch, same size.
const RAIL_SIZE := Vector2(156, 148)
const RAIL_TOP := 230.0
const RAIL_PITCH := 169.0
const RAIL_LEFT_X := 32.0
const RAIL_RIGHT_X := 821.0
# Where the painted timer sits inside a tile that has one, relative to it.
const TILE_TIMER_RECT := Rect2(14, 106, 128, 36)

# --- the bottom bar
const BOTTOM_Y := 1281.0
const BOTTOM_H := 215.0
const BOTTOM_W := 169.0
const BOTTOM_X := [28.0, 202.0, -1.0, 637.0, 811.0]   # -1 is CAMPAIGN, below
const CAMPAIGN_RECT := Rect2(376, 1265, 254, 231)

# The band above and below the panel is the painting's own outermost pixels,
# pulled straight up and down.
const EDGE_ROWS := 4.0

# Warm for a plaque that goes somewhere, cold for one that does not.
const PRESS_LIVE := Color(1.0, 0.86, 0.45, 0.30)
const PRESS_LOCKED := Color(0.45, 0.62, 0.95, 0.22)
# What is laid over a tile with nothing behind it. The picture drew a red
# unread-dot on several of them; the scrim takes those down with the tile,
# which is the whole reason it is a wash over the art rather than a border.
const LOCKED_SCRIM := Color(0.02, 0.02, 0.04, 0.62)

# ------------------------------------------------------------ the three moods
#
# Sampled off the paintings rather than picked: `slot` is what the inside of a
# plaque actually is in that picture, so a plate the colour of it reads as part
# of the plaque instead of as a hole cut in one. `banner` is for the two
# readings that sit on open scenery rather than in a plaque -- darker than the
# ground behind them, with the accent around the edge, so they read as
# something set down on the picture rather than as a patch over it.
#
# Both are fully opaque. The banner started at 94% and the painted 86 came
# straight back through it: the reading underneath is cream on dark, and six
# per cent of cream is still brighter than the plate around it.
const MOODS := {
	"forest": {
		"slot": Color(0.086, 0.094, 0.043),
		"banner": Color(0.055, 0.075, 0.035),
		"accent": Color(0.60, 0.84, 0.32),
		"ink": Color(0.93, 0.97, 0.86),
	},
	"ice": {
		"slot": Color(0.059, 0.094, 0.137),
		"banner": Color(0.035, 0.065, 0.110),
		"accent": Color(0.48, 0.78, 1.00),
		"ink": Color(0.90, 0.96, 1.00),
	},
	"lava": {
		"slot": Color(0.082, 0.075, 0.071),
		"banner": Color(0.070, 0.045, 0.035),
		"accent": Color(1.00, 0.56, 0.22),
		"ink": Color(1.00, 0.93, 0.86),
	},
}

var _root: Control
var _plate_pos: Vector2 = Vector2.ZERO
var _plate_size: Vector2 = Vector2.ZERO
var _leaving: bool = false

var _biome: String = "forest"
var _art: String = ""
var _mood: Dictionary = {}

# The readings, kept so the screen can be refreshed in place after a purchase
# or a claim rather than rebuilt.
var rank_label: Label
var name_label: Label
var xp_fill: Panel
var xp_text: Label
var best_wave_label: Label
var runs_label: Label
var essence_label: Label
var gold_label: Label
var chapter_num_label: Label
var chapter_name_label: Label
var wave_line_label: Label
var battle_sub_label: Label
var daily_label: Label
var daily_tile: Button
var daily_glow: ColorRect
var _daily_pulse: Tween = null
var _daily_tick: float = 0.0

# The painted shop, built the first time it is asked for and thrown away when
# it is closed -- three full-screen plates are not worth keeping resident
# behind a menu nobody is ever looking at while they are up.
# The three plaques, in the order they stand: left, hero, right. Held so what
# is in them can be redrawn without the hit boxes over them being rebuilt.
var slot_frames: Array[Control] = []

var shop_screen: ShopScreen = null
var quests_screen: QuestsScreen = null
var hero_page: HeroPage = null
var menu_board: MenuBoard = null

func _ready() -> void:
	_biome = MetaManager.menu_biome()
	_mood = MOODS.get(_biome, MOODS["forest"])
	_art = _menu_art()

	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)

	_build_backdrop()
	_build_plate()
	_build_edge_bands()
	# The readings first and the hit boxes after, so a plaque's press wash lies
	# over its own reading rather than under it.
	_build_readings()
	_build_buttons()
	_refresh_all()

# The picture for the place the player last stood, and the forest as the answer
# to a save naming a place this build does not have -- or to the file simply
# not being there yet, which is what a fresh art drop looks like before Godot
# has imported it.
func _menu_art() -> String:
	var wanted: String = String(MetaManager.biome_def(_biome).get("art", ""))
	if wanted != "" and ResourceLoader.exists(wanted):
		return wanted
	for id in MetaManager.BIOME_ORDER:
		var path: String = String(MetaManager.biome_def(String(id)).get("art", ""))
		if path != "" and ResourceLoader.exists(path):
			return path
	return ""

# ---------------------------------------------------------------- the canvas

func _build_backdrop() -> void:
	var floor_fill := ColorRect.new()
	floor_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor_fill.color = Color(0.008, 0.012, 0.016)
	floor_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(floor_fill)

func _build_plate() -> void:
	_plate_size = Vector2(VIEW.x, VIEW.x * ART_SIZE.y / ART_SIZE.x)
	_plate_pos = Vector2(0, ((VIEW.y - _plate_size.y) * 0.5)).round()
	if _art == "":
		return

	var plate := TextureRect.new()
	plate.texture = load(_art)
	# Linear: it is drawn a little larger than it was painted, and nearest
	# crawls on the stonework.
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.position = _plate_pos
	plate.size = _plate_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(plate)

func _build_edge_bands() -> void:
	if _art == "":
		return
	var top_h: float = _plate_pos.y
	if top_h > 0.0:
		_edge_band(Rect2(0.0, 0.0, ART_SIZE.x, EDGE_ROWS), Vector2.ZERO,
			Vector2(VIEW.x, top_h))
	var bottom_y: float = _plate_pos.y + _plate_size.y
	if bottom_y < VIEW.y:
		_edge_band(Rect2(0.0, ART_SIZE.y - EDGE_ROWS, ART_SIZE.x, EDGE_ROWS),
			Vector2(0.0, bottom_y), Vector2(VIEW.x, VIEW.y - bottom_y))

func _edge_band(region: Rect2, at: Vector2, size: Vector2) -> void:
	var band := Sprite2D.new()
	band.texture = load(_art)
	band.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	band.centered = false
	band.region_enabled = true
	band.region_rect = region
	band.position = at
	band.scale = Vector2(size.x / region.size.x, size.y / region.size.y)
	_root.add_child(band)

# A rectangle given in the painting's pixels, in the screen's.
func _rect(where: Rect2) -> Rect2:
	var s: float = _plate_size.x / ART_SIZE.x
	return Rect2(_plate_pos + where.position * s, where.size * s)

# ----------------------------------------------------------------- the slots

# One plate over one painted reading. `on_scenery` is for the two that sit on
# the picture itself rather than inside a plaque: those get the darker banner
# colour and a rule around them, because there is no plaque for them to pass as
# part of.
func _slot(where: Rect2, on_scenery: bool = false) -> Panel:
	var r: Rect2 = _rect(where)
	var box := Panel.new()
	box.position = r.position
	box.size = r.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = _mood["banner"] if on_scenery else _mood["slot"]
	sb.set_corner_radius_all(int(minf(r.size.y * 0.34, 26.0)))
	if on_scenery:
		sb.set_border_width_all(2)
		sb.border_color = (_mood["accent"] as Color) * Color(1, 1, 1, 0.55)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 8
	box.add_theme_stylebox_override("panel", sb)
	_root.add_child(box)
	return box

# A slot with the reading on it. `fill` is the cap height as a fraction of the
# slot, which is how the art sizes its own text.
func _reading(where: Rect2, fill: float, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_CENTER, on_scenery: bool = false) -> Label:
	var box: Panel = _slot(where, on_scenery)
	# A left-aligned reading is inset off the edge of its own plate; a centred
	# one has the whole plate to sit in the middle of.
	var pad: float = box.size.y * 0.16 if align == HORIZONTAL_ALIGNMENT_LEFT else 0.0
	var lbl := Label.new()
	lbl.position = Vector2(pad, 0.0)
	lbl.size = Vector2(box.size.x - pad * 2.0, box.size.y)
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", maxi(10, int(box.size.y * fill)))
	lbl.clip_text = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(lbl, color, 5)
	box.add_child(lbl)
	return lbl

func _build_readings() -> void:
	var ink: Color = _mood["ink"]
	var accent: Color = _mood["accent"]

	# --- who is playing. The skull and its frame are the painting's; the rank
	# on it, the name beside it and the bar under that are the player's.
	rank_label = _reading(RANK_RECT, 0.62, accent)
	# The longest hero name is eleven characters and the plaque left room for
	# nine at the size the mock-up wrote its own name in, so this one is set
	# smaller than the painting's rather than being clipped to fit it.
	name_label = _reading(NAME_RECT, 0.58, ink, HORIZONTAL_ALIGNMENT_LEFT)
	_build_xp_bar()
	xp_text = _reading(XP_TEXT_RECT, 0.72, UIStyle.TEXT_MUTED)

	# --- how far the player has ever got, on the chip the mock-up spent on an
	# energy meter. There is no energy in this game and there is not going to
	# be one; what belongs in a slot that size beside the currencies is the two
	# numbers that say how much of the road is behind you.
	best_wave_label = _reading(ENERGY_TOP_RECT, 0.80, ink)
	runs_label = _reading(ENERGY_BOT_RECT, 0.72, UIStyle.TEXT_MUTED)

	# --- the two currencies, and both of them are balances: the crystal is
	# essence, which every permanent upgrade is bought with, and the coin is the
	# shop purse -- a bank the run itself never touches, filled by the shelf's
	# own free gold and by trading essence for it. What a run earns and loses
	# with it is a separate number entirely, and lives on the career screen.
	essence_label = _reading(GEM_TEXT_RECT, 0.62, UIStyle.ACCENT_TEAL)
	gold_label = _reading(COIN_TEXT_RECT, 0.62, UIStyle.ACCENT_GOLD)

	# --- where the road has got to
	chapter_num_label = _reading(CHAPTER_NUM_RECT, 0.86, ink,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	chapter_name_label = _reading(CHAPTER_NAME_RECT, 0.44, ink)
	wave_line_label = _reading(WAVE_LINE_RECT, 0.55, accent,
		HORIZONTAL_ALIGNMENT_CENTER, true)

	# --- who marches out, on the strip the mock-up spent on an energy cost
	battle_sub_label = _reading(BATTLE_SUB_RECT, 0.50, ink)

	# The daily's own timer, down the left rail. It is the one thing on this
	# screen that answers to the calendar rather than to a press.
	daily_label = _reading(_tile_timer(_rail_left(3)), 0.72, accent)

func _build_xp_bar() -> void:
	var r: Rect2 = _rect(XP_BAR_RECT)

	var track := Panel.new()
	track.position = r.position
	track.size = r.size
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.02, 0.03, 0.92)
	bg.set_corner_radius_all(int(r.size.y * 0.5))
	track.add_theme_stylebox_override("panel", bg)
	_root.add_child(track)

	xp_fill = Panel.new()
	xp_fill.position = Vector2(2, 2)
	xp_fill.size = Vector2(0, r.size.y - 4.0)
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg := StyleBoxFlat.new()
	fg.bg_color = _mood["accent"]
	# Well under half the height: at half, a fill shorter than the bar is tall
	# comes out as a dot floating in the track rather than as a short bar, and
	# the first rank is exactly where the bar is shortest.
	fg.set_corner_radius_all(int(xp_fill.size.y * 0.34))
	xp_fill.add_theme_stylebox_override("panel", fg)
	track.add_child(xp_fill)

# ------------------------------------------------------------------ the rails

func _rail_left(index: int) -> Rect2:
	return Rect2(RAIL_LEFT_X, RAIL_TOP + index * RAIL_PITCH, RAIL_SIZE.x, RAIL_SIZE.y)

func _rail_right(index: int) -> Rect2:
	return Rect2(RAIL_RIGHT_X, RAIL_TOP + index * RAIL_PITCH, RAIL_SIZE.x, RAIL_SIZE.y)

func _bottom(index: int) -> Rect2:
	if index == 2:
		return CAMPAIGN_RECT
	return Rect2(BOTTOM_X[index], BOTTOM_Y, BOTTOM_W, BOTTOM_H)

func _tile_timer(tile: Rect2) -> Rect2:
	return Rect2(tile.position + TILE_TIMER_RECT.position, TILE_TIMER_RECT.size)

# ---------------------------------------------------------------- the buttons
#
# Which painted plaque opens which room. The picture was drawn for a game with
# a mail box, a guild, a battle pass and a ranking table, and this one has none
# of those -- so the plaques that have somewhere to go are wired to it and the
# rest are scrimmed and answer to a press without opening anything. A plaque
# that answers and goes nowhere reads as locked; one that does not answer at
# all reads as broken, and the picture is not broken.

func _build_buttons() -> void:
	_hit(PROFILE_RECT, true).pressed.connect(_on_heroes)
	_hit(ENERGY_RECT, true).pressed.connect(_on_career)
	# Both pluses are shortcuts into the shop and nothing more: the one beside
	# the crystal opens its essence page, the one beside the coin its gold page.
	_hit(GEM_PLUS_RECT, true).pressed.connect(_on_buy_essence)
	_hit(COIN_PLUS_RECT, true).pressed.connect(_on_buy_gold)
	_hit(GEAR_RECT, true).pressed.connect(_on_settings)

	_build_slots()

	_hit(WAVE_GLASS_RECT, true).pressed.connect(_on_chapters)
	_hit(BATTLE_RECT, true).pressed.connect(_on_play)

	# left rail: MISSIONS, SHOP, UPGRADES, gift, chest
	# The collection moved here when the QUESTS tile got a board of its own:
	# it is a list of what the player has ever built, which is nearer to a set
	# of missions than to a set of daily errands, and this tile had nothing.
	_hit(_rail_left(0), true).pressed.connect(_on_collection)
	_hit(_rail_left(1), true).pressed.connect(_on_shop)
	_hit(_rail_left(2), true).pressed.connect(_on_upgrades)
	daily_tile = _hit(_rail_left(3), true)
	daily_tile.pressed.connect(_on_daily_pressed)
	# The whole screen is one painting, so a tile cannot be lit by modulating
	# anything of its own -- there is nothing of its own to modulate. What
	# breathes is a wash of the biome's colour laid over it.
	var accent: Color = _mood["accent"]
	daily_glow = ColorRect.new()
	daily_glow.position = Vector2.ZERO
	daily_glow.size = daily_tile.size
	daily_glow.color = Color(accent.r, accent.g, accent.b, 0.0)
	daily_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	daily_tile.add_child(daily_glow)

	_hit(_rail_left(4), false)

	# right rail: MAIL, QUESTS, INVENTORY, EVENT, BATTLE PASS
	_hit(_rail_right(0), false)
	_hit(_rail_right(1), true).pressed.connect(_on_quests)
	_hit(_rail_right(2), true).pressed.connect(_on_inventory)
	_hit(_rail_right(3), false)
	_hit(_rail_right(4), false)

	# bottom: GUILD, HEROES, CAMPAIGN, RANKINGS, ACHIEVEMENTS
	_hit(_bottom(0), false)
	_hit(_bottom(1), true).pressed.connect(_on_heroes)
	_hit(_bottom(2), true).pressed.connect(_on_chapters)
	_hit(_bottom(3), false)
	_hit(_bottom(4), true).pressed.connect(_on_achievements)

	# Last of all, because it is the one reading that has to sit over a scrim
	# rather than under a press wash: the chest has nothing behind it, and a
	# plaque counting down to nothing is worse than one that says so outright.
	var chest := _reading(_tile_timer(_rail_left(4)), 0.62, UIStyle.TEXT_MUTED)
	chest.text = "LOCKED"

# ------------------------------------------------------------------ the slots
#
# Three plaques standing on the road above the BATTLE plate. The framed one in
# the middle is the hero's and opens the room the hero is chosen in; the two
# either side each hold one body out of the pack.
#
# An empty plaque is left exactly as painted -- the "+" in it is the picture's
# own way of saying it is waiting for something, and nothing this script could
# draw would say it better. A filled one is covered by what was chosen.

func _build_slots() -> void:
	slot_frames.clear()
	# The pictures go down before the hit boxes, so the press wash lands on top
	# of whatever is filling a plaque instead of underneath it.
	for where in [SQUAD_SLOT_RECTS[0], HERO_SLOT_RECT, SQUAD_SLOT_RECTS[1]]:
		var at: Rect2 = _rect(where)
		var holder := Control.new()
		holder.position = at.position
		holder.size = at.size
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(holder)
		slot_frames.append(holder)

	_hit(SQUAD_SLOT_RECTS[0], true).pressed.connect(func() -> void: _on_squad_slot(0))
	_hit(HERO_SLOT_RECT, true).pressed.connect(_on_heroes)
	_hit(SQUAD_SLOT_RECTS[1], true).pressed.connect(func() -> void: _on_squad_slot(1))
	_refresh_slots()

func _refresh_slots() -> void:
	# Called by _refresh_all, which runs once before the plaques are built.
	if slot_frames.size() < 3:
		return
	# slot_frames stands in the order the plaques do -- left, hero, right -- so
	# the two squad slots are the ones either side of the middle.
	for i in [0, 1]:
		var id: String = MetaManager.squad_id(i)
		_fill_slot(slot_frames[i * 2], UnitDatabase.get_art_path(id),
			UnitDatabase.get_art_tint(id),
			MetaManager.squad_level(i) if id != "" else 0)
	# The hero plaque carries a painted portrait rather than a field sprite, so
	# it is the one slot that is smoothed on the way down.
	_fill_slot(slot_frames[1], UnitDatabase.get_hero_face(MetaManager.hero_id()),
		Color(1, 1, 1), 0, true)

func _fill_slot(holder: Control, art_path: String, tint: Color, level: int,
		smooth: bool = false) -> void:
	for child in holder.get_children():
		child.queue_free()
	if art_path == "":
		return

	var inset: float = SLOT_INSET * _plate_size.x / ART_SIZE.x
	# The plaque's own inside, laid down first: a body is cut out of the field
	# and has a hole in it, and the painted "+" showing through one is worse
	# than either the "+" or the body on its own.
	var back := ColorRect.new()
	back.position = Vector2(inset, inset)
	back.size = holder.size - Vector2(inset, inset) * 2.0
	back.color = _mood["slot"]
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)

	var pic := TextureRect.new()
	pic.texture = load(art_path)
	# Nearest: these are the field's own sprites at a few times their painted
	# size, and smoothing them here would make them the one soft thing on a
	# screen where everything else is drawn hard. A painted portrait is the other
	# way round -- it comes down rather than up, and nearest would tear it.
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if smooth \
		else CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = back.position
	pic.size = back.size
	pic.modulate = tint
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pic)

	if level <= 0:
		return
	# What the body is worth, across the foot of the plaque it stands in. The
	# pack tells a level 6 knight from a fresh one and the plaque has to as
	# well, because that is the difference between the two things a player
	# might have meant to carry. Outlined heavily rather than given a plate of
	# its own: it sits over the body's own boots and has to be read off them.
	var chip := Label.new()
	var h: float = back.size.y * 0.24
	chip.position = Vector2(back.position.x, back.position.y + back.size.y - h)
	chip.size = Vector2(back.size.x, h)
	chip.text = "LV %d" % level
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", int(h * 0.70))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(chip, _mood["ink"], 7)
	holder.add_child(chip)

# What can stand in one of the two side plaques is whatever the pack has that
# the other plaque has not already taken -- and a body is told from another by
# its level as well as by its name, because the pack tells them apart and a
# level 6 knight is not the level 1 one standing next to it.
#
# Choosing costs nothing and can be undone all day. Starting a run is what
# spends them: both bodies come out of the pack for good and stand on the ring
# from the first second. See MetaManager.take_squad and Main._spawn_squad.

func _on_squad_slot(slot: int) -> void:
	var built: Dictionary = _build_overlay("SLOT %d" % (slot + 1))
	var body: VBoxContainer = built["body"]
	var overlay: Control = built["overlay"] as Control

	var stacks: Array = MetaManager.inventory_stacks()
	if stacks.is_empty():
		_caption(body, "Your pack is empty. Press RETREAT during a run and everything still standing on the field comes home with you -- or buy a unit chest from the shop.")
		return

	_caption(body, "Whoever stands here marches out beside your hero, on the ring, before the first piece drops. Starting the run spends them out of your pack for good.")

	if MetaManager.squad_id(slot) != "":
		var clear := Button.new()
		clear.text = "LEAVE IT EMPTY"
		clear.custom_minimum_size = Vector2(0, 72)
		UIStyle.apply_button_style(clear, UIStyle.ACCENT_RED.darkened(0.25), 26, 18)
		clear.pressed.connect(func() -> void:
			MetaManager.set_squad(slot, "")
			_refresh_all()
			overlay.queue_free())
		body.add_child(clear)

	for stack in stacks:
		body.add_child(_squad_row(overlay, slot, stack as Dictionary))

func _squad_row(overlay: Control, slot: int, stack: Dictionary) -> Control:
	var id: String = String(stack.get("id", ""))
	var level: int = maxi(1, int(stack.get("level", 1)))
	var d: Dictionary = UnitDatabase.get_def(id)
	var accent: Color = d.get("color", UIStyle.ACCENT_GOLD)
	var chosen: bool = MetaManager.squad_id(slot) == id \
		and MetaManager.squad_level(slot) == level
	# Nothing left of this exact body that the other plaque has not taken.
	var free: int = MetaManager.squad_free_count(id, level, slot)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		UIStyle.card_box(accent if chosen or free > 0 else accent.darkened(0.55)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var art_path: String = UnitDatabase.get_art_path(id)
	if art_path != "":
		var pic := TextureRect.new()
		pic.texture = load(art_path)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(112, 112)
		pic.modulate = UnitDatabase.get_art_tint(id)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = "%s  ·  LV %d" % [String(d.get("name", id)), level]
	name_lbl.add_theme_font_size_override("font_size", 30)
	UIStyle.apply_body_text(name_lbl, UIStyle.TEXT_LIGHT)
	info.add_child(name_lbl)

	var tier := Label.new()
	tier.text = "TIER %d  ·  %d IN PACK" % \
		[int(d.get("level", 0)), int(stack.get("count", 1))]
	UIStyle.apply_body_text(tier, UIStyle.TEXT_MUTED)
	info.add_child(tier)

	var pick := Button.new()
	pick.custom_minimum_size = Vector2(190, 72)
	pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pick.text = "STANDING" if chosen else ("CHOOSE" if free > 0 else "TAKEN")
	pick.disabled = chosen or free <= 0
	UIStyle.apply_button_style(pick, accent.darkened(0.15), 24, 18)
	pick.pressed.connect(func() -> void:
		MetaManager.set_squad(slot, id, level)
		_refresh_all()
		overlay.queue_free())
	row.add_child(pick)

	return card

# An invisible button over a painted one. All it adds is the press feedback a
# painting cannot give -- and, on a plaque with nothing behind it, a scrim that
# takes the plaque and its painted unread-dot down together.
func _hit(where: Rect2, live: bool) -> Button:
	var r: Rect2 = _rect(where)
	var btn := Button.new()
	btn.position = r.position
	btn.size = r.size
	btn.text = ""
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_root.add_child(btn)

	if not live:
		var scrim := ColorRect.new()
		scrim.position = Vector2.ZERO
		scrim.size = r.size
		scrim.color = LOCKED_SCRIM
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(scrim)

	var wash := ColorRect.new()
	wash.position = Vector2.ZERO
	wash.size = r.size
	wash.color = Color(1, 1, 1, 0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(wash)

	var tint: Color = PRESS_LIVE if live else PRESS_LOCKED
	btn.button_down.connect(func() -> void: wash.color = tint)
	btn.button_up.connect(func() -> void:
		var t := create_tween()
		t.tween_property(wash, "color:a", 0.0, 0.18))
	return btn

# ---------------------------------------------------------------- the numbers

func _refresh_all() -> void:
	var hero: Dictionary = UnitDatabase.get_def(MetaManager.hero_id())

	rank_label.text = str(MetaManager.commander_rank())
	name_label.text = String(hero.get("name", "COMMANDER"))

	var p: Dictionary = MetaManager.rank_progress()
	var into: int = int(p["into"])
	var span: int = int(p["span"])
	xp_text.text = "%d/%d" % [into, span]
	var track_w: float = _rect(XP_BAR_RECT).size.x - 4.0
	var ratio: float = clampf(float(into) / float(maxi(span, 1)), 0.0, 1.0)
	# Any progress at all is drawn as a readable stub rather than a sliver, and
	# none at all is drawn as nothing.
	xp_fill.size.x = 0.0 if ratio <= 0.0 \
		else clampf(track_w * ratio, xp_fill.size.y * 1.8, track_w)

	best_wave_label.text = str(MetaManager.best_wave) if MetaManager.best_wave > 0 else "--"
	runs_label.text = "%d RUN%s" % \
		[MetaManager.runs_played, "" if MetaManager.runs_played == 1 else "S"]

	essence_label.text = _currency(MetaManager.essence)
	gold_label.text = _currency(MetaManager.gold)

	# The chapter block names the place the courtyard behind it is painted as,
	# not the furthest one ever reached: the whole centre of the screen is one
	# statement about where the player is standing, and a chapter number that
	# disagreed with the picture under it would be the odd one out. How far
	# down the road they have ever got is the line under it.
	var here: Dictionary = MetaManager.biome_def(_biome)
	chapter_num_label.text = str(int(here.get("chapter", 1)))
	chapter_name_label.text = String(here.get("name", ""))
	wave_line_label.text = ("BEST WAVE %d" % MetaManager.best_wave) \
		if MetaManager.best_wave > 0 else "NO RUNS YET"

	battle_sub_label.text = String(hero.get("name", ""))

	_refresh_slots()
	_refresh_daily()

# The painting left room for six figures and a pair of separators. A purse fed
# by the shop walks past that, so beyond a million the separators stop earning
# their place and the number is compacted instead of being clipped.
func _currency(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	return _thousands(value)

func _thousands(value: int) -> String:
	var s: String = str(maxi(value, 0))
	var out: String = ""
	var n: int = s.length()
	for i in range(n):
		if i > 0 and (n - i) % 3 == 0:
			out += ","
		out += s[i]
	return out

# ------------------------------------------------------------------- daily
#
# The gift tile down the left rail, which the picture already drew with a timer
# on it. Claimable it says so and the tile breathes; claimed it counts down to
# the next day, which is the only thing a timer on this screen could honestly
# be counting.

func _refresh_daily() -> void:
	var status: Dictionary = MetaManager.daily_status()
	var claimable: bool = bool(status.get("claimable", false))
	if claimable:
		daily_label.text = "CLAIM"
		_pulse_daily()
	else:
		daily_label.text = _clock(_seconds_to_midnight())
		if _daily_pulse != null and _daily_pulse.is_valid():
			_daily_pulse.kill()
		daily_glow.color.a = 0.0

func _seconds_to_midnight() -> int:
	var t: Dictionary = Time.get_time_dict_from_system()
	return maxi(0, 86400 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"])))

func _clock(seconds: int) -> String:
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]

func _pulse_daily() -> void:
	if _daily_pulse != null and _daily_pulse.is_valid():
		return
	_daily_pulse = create_tween()
	_daily_pulse.set_loops()
	_daily_pulse.tween_property(daily_glow, "color:a", 0.24, 0.7)
	_daily_pulse.tween_property(daily_glow, "color:a", 0.02, 0.7)

func _process(delta: float) -> void:
	# One tick a second and only while there is a clock to move: the rest of
	# this screen answers to presses and to nothing else.
	_daily_tick -= delta
	if _daily_tick > 0.0:
		return
	_daily_tick = 1.0
	if not bool(MetaManager.daily_status().get("claimable", false)):
		daily_label.text = _clock(_seconds_to_midnight())

func _on_daily_pressed() -> void:
	var reward: int = MetaManager.claim_daily()
	if reward <= 0:
		return
	_refresh_all()
	_show_toast("+%d ESSENCE" % reward, _rect(_rail_left(3)))

# A number leaving the plaque it came off, so a claim is seen landing rather
# than only changing a figure at the top of the screen.
func _show_toast(text: String, from: Rect2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(from.position.x - 40.0, from.position.y + from.size.y)
	lbl.size = Vector2(from.size.x + 80.0, 48)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	UIStyle.apply_heading(lbl, UIStyle.ACCENT_TEAL, 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 30.0, 0.7)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.35)
	tw.tween_callback(lbl.queue_free)

# ----------------------------------------------------------- the rooms
#
# None of these is painted -- there was never art for what goes behind a plaque
# -- so all of them are built the same way every other procedural screen in the
# game is, out of UIStyle's panels and cards, laid over a dim.

func _build_overlay(title: String) -> Dictionary:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var panel_w := 940.0
	var panel_h := 1400.0
	var panel := Panel.new()
	panel.position = Vector2((VIEW.x - panel_w) * 0.5, (VIEW.y - panel_h) * 0.5)
	panel.size = Vector2(panel_w, panel_h)
	# Framed in the colour of the place the player came home to, so a room
	# opened off the ember menu is not wearing the forest's border.
	panel.add_theme_stylebox_override("panel",
		UIStyle.panel_box(UIStyle.PANEL_BG, _mood["accent"], 26, 3))
	overlay.add_child(panel)

	var heading := Label.new()
	heading.text = title
	heading.position = Vector2(30, 26)
	heading.size = Vector2(panel_w - 60, 60)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 44)
	UIStyle.apply_heading(heading, _mood["accent"], 8)
	panel.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 110)
	scroll.size = Vector2(panel_w - 48, panel_h - 110 - 96)
	panel.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	scroll.add_child(body)

	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2((panel_w - 260.0) * 0.5, panel_h - 76.0)
	close.size = Vector2(260.0, 56.0)
	UIStyle.apply_button_style(close, UIStyle.ACCENT_BLUE, 28, 20)
	close.pressed.connect(func() -> void: overlay.queue_free())
	panel.add_child(close)

	return {"overlay": overlay, "panel": panel, "body": body}

func _caption(body: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size = Vector2(820, 0)
	UIStyle.apply_body_text(lbl, UIStyle.TEXT_MUTED)
	body.add_child(lbl)

# ------------------------------------------------------------------- heroes
#
# The one choice on this screen that changes what the next run looks like from
# its first second: whichever hero is chosen is standing on the ring before the
# first piece drops (see Main._spawn_hero).

# The third painted room off this screen -- see HeroPage, which is one plate
# and seven rows drawn over it.
func _on_heroes() -> void:
	if hero_page != null and is_instance_valid(hero_page):
		return
	var screen := HeroPage.new()
	hero_page = screen
	_root.add_child(screen)
	screen.build(VIEW)
	screen.closed.connect(func() -> void:
		screen.queue_free()
		hero_page = null
		# The name under the BATTLE plate is the hero's, and so is the face on
		# the plaque beside it, so the front screen is read again on the way out
		# rather than only after a restart.
		_refresh_all())
	screen.open()

# ------------------------------------------------------------------ upgrades
#
# Everything essence is ever spent on, in one room. Essence has exactly one job
# and splitting it over two plaques only ever asked the player to remember
# which of the two a thing was behind. The shelf next door is the other purse
# entirely -- gold -- and shares nothing with this but the screen it sits on.

# ---------------------------------------------------------------- collection


# ----------------------------------------------------------------- inventory
#
# What runs have been walked away from rather than lost. Every body standing on
# the field when a retreat is confirmed comes back here with the level it had
# earned, which is the whole of what the retreat button is for.

# -------------------------------------------------------------- the board
#
# The five rooms off this screen that are a list rather than a painting, all
# five on the one plate -- see MenuBoard, which holds them the way ShopScreen
# holds its three pages.

func _on_inventory() -> void:
	_open_board(MenuBoard.Page.INVENTORY)

func _on_upgrades() -> void:
	_open_board(MenuBoard.Page.UPGRADES)

func _on_collection() -> void:
	_open_board(MenuBoard.Page.COLLECTION)

func _on_chapters() -> void:
	_open_board(MenuBoard.Page.CAMPAIGN)

func _on_achievements() -> void:
	_open_board(MenuBoard.Page.ACHIEVEMENTS)

func _open_board(page: int) -> void:
	if menu_board != null and is_instance_valid(menu_board):
		return
	var screen := MenuBoard.new()
	menu_board = screen
	_root.add_child(screen)
	screen.build(VIEW)
	screen.closed.connect(func() -> void:
		screen.queue_free()
		menu_board = null
		# The upgrades page spends essence, so the reading at the top of this
		# screen can have moved while the board was covering it.
		_refresh_all())
	screen.open(page)

# ------------------------------------------------------------------ chapters
#
# The three places the road goes through, what lives at the end of each, and
# how far into them the player has got. Read off best_wave rather than stored,
# so it can never disagree with the number on the front screen.

# ------------------------------------------------------- achievements & career
#
# The picture drew a plaque for each, so they are two rooms rather than one
# screen with a stats block bolted to the top of it.

func _on_career() -> void:
	var built: Dictionary = _build_overlay("CAREER")
	var body: VBoxContainer = built["body"]

	var rank := Label.new()
	rank.text = "RANK %d" % MetaManager.commander_rank()
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank.add_theme_font_size_override("font_size", 38)
	UIStyle.apply_heading(rank, _mood["accent"], 6)
	body.add_child(rank)
	_caption(body, "Rank climbs with every point of essence you have ever banked. Spending it never costs you rank.")

	var tier: int = MetaManager.deepest_tier_seen
	var wave30: float = MetaManager.fastest_wave30_sec
	var p: Dictionary = MetaManager.rank_progress()
	body.add_child(_stats_block([
		["Essence banked, lifetime", str(MetaManager.essence_earned_total)],
		["Next rank in", str(maxi(0, int(p["span"]) - int(p["into"])))],
		["Best wave", str(MetaManager.best_wave)],
		["Runs played", str(MetaManager.runs_played)],
		["Total kills", str(MetaManager.total_kills)],
		["Gold in the purse", str(MetaManager.gold)],
		["Gold earned, lifetime", str(MetaManager.total_gold_earned)],
		["Longest clean streak", str(MetaManager.longest_clean_streak_ever)],
		["Deepest tier discovered", ("Tier %d" % tier) if tier > 0 else "--"],
		["Fastest wave 30 clear", ("%.0fs" % wave30) if wave30 >= 0.0 else "--"],
		["Units brought home", str(MetaManager.inventory_count())],
	]))

func _stats_block(rows: Array) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(UIStyle.ACCENT_BLUE))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	for r in rows:
		var line := Label.new()
		line.text = "%s:  %s" % [r[0], r[1]]
		UIStyle.apply_body_text(line, UIStyle.TEXT_LIGHT)
		col.add_child(line)
	return card

# --------------------------------------------------------------------- shop
#
# The one room on this screen that is painted rather than built -- see
# ShopScreen, which is three plates and knows how to walk between them. All
# three doors into it land on the same node and differ only in which page it
# opens on: the SHOP plaque on the rail, and the two pluses in the top bar,
# which are shortcuts to the pages that fill the balances they sit beside and
# are not screens of their own.

func _on_shop() -> void:
	_open_shop(ShopScreen.Page.SHOP)

func _on_buy_gold() -> void:
	_open_shop(ShopScreen.Page.GOLD)

func _on_buy_essence() -> void:
	_open_shop(ShopScreen.Page.ESSENCE)

func _open_shop(page: int) -> void:
	if shop_screen != null and is_instance_valid(shop_screen):
		return
	var screen := ShopScreen.new()
	shop_screen = screen
	_root.add_child(screen)
	screen.build(VIEW)
	screen.closed.connect(func() -> void:
		screen.queue_free()
		shop_screen = null
		# Both readings at the top of this screen can have moved while it was
		# covered up, so they are read again rather than left as they were.
		_refresh_all())
	screen.open(page)

# ------------------------------------------------------------------- quests
#
# The other painted room off this screen -- see QuestsScreen, which is one
# plate and six lines that answer to what the player has actually been doing.

func _on_quests() -> void:
	if quests_screen != null and is_instance_valid(quests_screen):
		return
	var screen := QuestsScreen.new()
	quests_screen = screen
	_root.add_child(screen)
	screen.build(VIEW)
	screen.closed.connect(func() -> void:
		screen.queue_free()
		quests_screen = null
		# A claim is paid in gold, so the reading at the top of this screen can
		# have moved while the board was covering it.
		_refresh_all())
	screen.open()

# ------------------------------------------------------------------ settings
#
# The gear in the corner of the painting, which never had anything behind it.
# Both switches live on MetaManager, so what is set here is what the run finds
# already set -- and what the pause menu shows if it is opened mid-fight.

func _on_settings() -> void:
	var built: Dictionary = _build_overlay("SETTINGS")
	var body: VBoxContainer = built["body"]
	var overlay: Control = built["overlay"] as Control

	body.add_child(_toggle_row("SOUND", "Every effect and the music with it.",
		MetaManager.sound_enabled, func() -> void:
			MetaManager.set_sound_enabled(not MetaManager.sound_enabled)
			overlay.queue_free()
			_on_settings()))
	body.add_child(_toggle_row("SCREEN FX",
		"The flashes and the shake that come with a heavy hit.",
		MetaManager.screen_fx_enabled, func() -> void:
			MetaManager.set_screen_fx_enabled(not MetaManager.screen_fx_enabled)
			overlay.queue_free()
			_on_settings()))

func _toggle_row(title_text: String, desc_text: String, on: bool,
		toggled: Callable) -> Control:
	var accent: Color = UIStyle.ACCENT_GREEN if on else Color(0.4, 0.42, 0.5)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(accent))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 28)
	UIStyle.apply_body_text(title, UIStyle.TEXT_LIGHT)
	info.add_child(title)

	var desc := Label.new()
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIStyle.apply_body_text(desc, UIStyle.TEXT_MUTED)
	info.add_child(desc)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(190, 64)
	btn.text = "ON" if on else "OFF"
	UIStyle.apply_button_style(btn, accent, 26, 18)
	btn.pressed.connect(toggled)
	row.add_child(btn)

	return card

# --------------------------------------------------------------------- play

func _on_play() -> void:
	if _leaving:
		return
	_leaving = true
	# A beat on the plate before the screen goes, so the press is seen landing
	# rather than the menu simply vanishing under the finger.
	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(fade)

	var t := create_tween()
	t.tween_interval(0.10)
	t.tween_property(fade, "color:a", 1.0, 0.22)
	t.tween_callback(func() -> void: get_tree().change_scene_to_file(GAME_SCENE))
