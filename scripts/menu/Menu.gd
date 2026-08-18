extends Node2D

const UIStyle = preload("res://scripts/ui/UIStyle.gd")

# The main menu is one painting (art/menu.png), the same way the defeat screen
# and the shop shelf are: the frame, the title, the torches and all five
# plaques are in the picture, and the real buttons are invisible hit boxes laid
# exactly over the painted ones. All they add is the press feedback a painting
# cannot give.
#
# The painting is squarer than the screen it is shown on -- 1122x1402 against
# 1080x1920 -- so it is fitted by its width and never cropped. Filling the
# screen instead would take the gear off the right edge and the version off the
# bottom, and there is no version of this picture that survives being cut down
# the sides.
#
# What fills the band left over above and below is the same painting again,
# blown up to cover the screen and dimmed right down: the letterbox comes out as
# more of the same courtyard, out of focus behind the panel, rather than as two
# black bars.

const VIEW := Vector2(1080.0, 1920.0)
const ART := "res://art/menu.png"
const ART_SIZE := Vector2(1122.0, 1402.0)

# Where each painted plaque sits in the painting, as a fraction of it. Measured
# off the art, so they follow if it is ever drawn at another size.
const PLAY_RECT := Rect2(0.2335, 0.3445, 0.5196, 0.0920)
const UNITS_RECT := Rect2(0.2335, 0.4622, 0.5196, 0.0849)
const COLLECTION_RECT := Rect2(0.2335, 0.5628, 0.5196, 0.0849)
const REWARDS_RECT := Rect2(0.2335, 0.6626, 0.5196, 0.0849)
const SHOP_RECT := Rect2(0.2335, 0.7632, 0.5196, 0.0842)
const GEAR_RECT := Rect2(0.8734, 0.0321, 0.0713, 0.0571)

# The hero shelf. There is no painted plaque for it -- the picture was drawn
# with five and there is no sixth slot on that frame -- so it sits on the
# courtyard below the panel instead, where the painting has nothing but ground.
# That turns out to be the right place for it anyway: it is the only thing on
# this screen that shows the player something rather than naming a room, and it
# reads as the hero standing outside the gate waiting to be sent in.
const HERO_RECT := Rect2(0.155, 0.874, 0.690, 0.104)

const GAME_SCENE := "res://scenes/main/Main.tscn"

# Warm for the one that goes somewhere, cold for the ones that do not yet.
const PRESS_LIVE := Color(1.0, 0.86, 0.45, 0.30)
const PRESS_LOCKED := Color(0.45, 0.62, 0.95, 0.22)

var _root: Control
var _plate_pos: Vector2 = Vector2.ZERO
var _plate_size: Vector2 = Vector2.ZERO
var _leaving: bool = false

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_root)

	_build_backdrop()
	_build_plate()
	_build_edge_bands()

	_hit(PLAY_RECT, true).pressed.connect(_on_play)
	_hit(UNITS_RECT, true).pressed.connect(_on_progress)
	_hit(COLLECTION_RECT, true).pressed.connect(_on_collection)
	_hit(REWARDS_RECT, true).pressed.connect(_on_rewards)
	_hit(SHOP_RECT, true).pressed.connect(_on_menu_shop)
	# Nothing behind this yet. It is still given a hit box rather than left
	# dead: a plaque that answers to being pressed and goes nowhere reads as
	# locked, and one that does not answer at all reads as broken.
	_hit(GEAR_RECT, false)

	_build_hero_plaque()
	_build_daily_badge()

# The band above and below the panel is the painting's own outermost pixels,
# pulled straight up and down. The first version of this filled it with the
# whole picture blown up and dimmed, which put a second, ghostly MERGE across
# the top of the screen above the real one -- the border stretched out reads as
# the frame simply continuing, which is what it is.
const EDGE_ROWS := 4.0

func _build_backdrop() -> void:
	var floor_fill := ColorRect.new()
	floor_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor_fill.color = Color(0.008, 0.012, 0.016)
	floor_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(floor_fill)

func _build_edge_bands() -> void:
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
	band.texture = load(ART)
	band.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	band.centered = false
	band.region_enabled = true
	band.region_rect = region
	band.position = at
	band.scale = Vector2(size.x / region.size.x, size.y / region.size.y)
	_root.add_child(band)

func _build_plate() -> void:
	_plate_size = Vector2(VIEW.x, VIEW.x * ART_SIZE.y / ART_SIZE.x)
	_plate_pos = Vector2(0, ((VIEW.y - _plate_size.y) * 0.5)).round()

	var plate := TextureRect.new()
	plate.texture = load(ART)
	# Linear, like every other painted plate here: it is drawn a little smaller
	# than it was painted, and nearest crawls on the stonework.
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.position = _plate_pos
	plate.size = _plate_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(plate)

# An invisible button over the painted one, with a wash inside it that is the
# only thing the press actually shows.
func _hit(where: Rect2, live: bool) -> Button:
	var btn := Button.new()
	btn.position = _plate_pos + where.position * _plate_size
	btn.size = where.size * _plate_size
	btn.text = ""
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_root.add_child(btn)

	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(1, 1, 1, 0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(wash)

	var tint: Color = PRESS_LIVE if live else PRESS_LOCKED
	btn.button_down.connect(func() -> void: wash.color = tint)
	btn.button_up.connect(func() -> void:
		var t := create_tween()
		t.tween_property(wash, "color:a", 0.0, 0.18))
	return btn

# ------------------------------------------------------------------- heroes
#
# The one choice on this screen that changes what the next run looks like from
# its first second: whichever hero is on the shelf is standing on the ring
# before the first piece drops (see Main._spawn_hero). Everything about that
# choice is remembered by MetaManager, so it survives the run, the session and
# the app being closed.
#
# The shelf itself is a plaque built the same way every other procedural panel
# in this game is, rather than a painted one -- there was no room left on the
# painting for a sixth -- and it shows the hero rather than naming the room,
# because what the player wants to check at a glance is who they are taking.

var hero_plaque: Button
var hero_face: TextureRect
var hero_name_label: Label
var hero_title_label: Label

const HERO_FACE_SIZE := Vector2(112.0, 112.0)

func _build_hero_plaque() -> void:
	hero_plaque = Button.new()
	hero_plaque.position = _plate_pos + HERO_RECT.position * _plate_size
	hero_plaque.size = HERO_RECT.size * _plate_size
	hero_plaque.text = ""
	UIStyle.apply_button_style(hero_plaque, UIStyle.PANEL_BG_SOFT, 26, 20)
	hero_plaque.pressed.connect(_on_heroes)
	_root.add_child(hero_plaque)

	var pad: float = (hero_plaque.size.y - HERO_FACE_SIZE.y) * 0.5
	hero_face = TextureRect.new()
	hero_face.position = Vector2(pad, pad)
	hero_face.size = HERO_FACE_SIZE
	hero_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_plaque.add_child(hero_face)

	var text_x: float = pad * 2.0 + HERO_FACE_SIZE.x
	var text_w: float = hero_plaque.size.x - text_x - 56.0

	hero_name_label = Label.new()
	hero_name_label.position = Vector2(text_x, pad + 6.0)
	hero_name_label.size = Vector2(text_w, 46.0)
	hero_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_name_label.add_theme_font_size_override("font_size", 36)
	hero_name_label.clip_text = true
	hero_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(hero_name_label, UIStyle.ACCENT_GOLD, 6)
	hero_plaque.add_child(hero_name_label)

	hero_title_label = Label.new()
	hero_title_label.position = Vector2(text_x, pad + 54.0)
	hero_title_label.size = Vector2(text_w, 40.0)
	hero_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_title_label.add_theme_font_size_override("font_size", 22)
	hero_title_label.clip_text = true
	hero_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(hero_title_label, UIStyle.TEXT_MUTED)
	hero_plaque.add_child(hero_title_label)

	# The one mark that says the plaque opens something rather than only
	# reporting: a chevron on the edge the thumb reaches for.
	var chevron := Label.new()
	chevron.position = Vector2(hero_plaque.size.x - 52.0, 0.0)
	chevron.size = Vector2(40.0, hero_plaque.size.y)
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.text = "›"
	chevron.add_theme_font_size_override("font_size", 52)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(chevron, UIStyle.ACCENT_GOLD)
	hero_plaque.add_child(chevron)

	_refresh_hero_plaque()

func _refresh_hero_plaque() -> void:
	var id: String = MetaManager.hero_id()
	var d: Dictionary = UnitDatabase.get_def(id)
	hero_name_label.text = String(d.get("name", "HERO"))
	hero_title_label.text = String(d.get("title", ""))
	var face: String = UnitDatabase.get_hero_face(id)
	hero_face.texture = load(face) if face != "" else null

func _on_heroes() -> void:
	var built: Dictionary = _build_overlay("CHOOSE YOUR HERO")
	var body: VBoxContainer = built["body"]
	var overlay: Control = built["overlay"] as Control

	var sub := Label.new()
	sub.text = "Your hero marches out with the first wave and holds a slot of its own."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.custom_minimum_size = Vector2(820, 0)
	UIStyle.apply_body_text(sub, UIStyle.TEXT_MUTED)
	body.add_child(sub)

	for id in UnitDatabase.HERO_IDS:
		body.add_child(_hero_row(overlay, String(id)))

func _hero_row(overlay: Control, id: String) -> Control:
	var d: Dictionary = UnitDatabase.get_def(id)
	var chosen: bool = MetaManager.hero_id() == id
	var accent: Color = d.get("color", UIStyle.ACCENT_GOLD)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		UIStyle.card_box(accent if chosen else accent.darkened(0.45)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var face_path: String = UnitDatabase.get_hero_face(id)
	if face_path != "":
		var face := TextureRect.new()
		face.texture = load(face_path)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(128, 120)
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(face)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = String(d.get("name", id))
	UIStyle.apply_body_text(title, UIStyle.TEXT_LIGHT)
	title.add_theme_font_size_override("font_size", 30)
	info.add_child(title)

	var subtitle := Label.new()
	subtitle.text = String(d.get("title", ""))
	UIStyle.apply_body_text(subtitle, accent)
	subtitle.add_theme_font_size_override("font_size", 20)
	info.add_child(subtitle)

	var desc := Label.new()
	desc.text = String(d.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(430, 0)
	UIStyle.apply_body_text(desc, UIStyle.TEXT_MUTED)
	info.add_child(desc)

	var pick := Button.new()
	pick.custom_minimum_size = Vector2(180, 72)
	pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pick.text = "CHOSEN" if chosen else "CHOOSE"
	pick.disabled = chosen
	UIStyle.apply_button_style(pick, accent.darkened(0.15), 24, 18)
	pick.pressed.connect(func() -> void:
		MetaManager.select_hero(id)
		_refresh_hero_plaque()
		# Torn down and rebuilt rather than patched: every row's frame and
		# button change when the choice moves, and rebuilding is the same
		# refresh every other room on this screen uses.
		overlay.queue_free()
		_on_heroes())
	row.add_child(pick)

	return card

# ----------------------------------------------------------- meta overlays
#
# The two plaques that used to answer to nothing. Neither is painted -- there
# was never art for what goes behind them -- so both are built the same way
# every other procedural screen in this game is, out of UIStyle's panels and
# cards, laid over a dim rather than over another painting.

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
	panel.add_theme_stylebox_override("panel", UIStyle.panel_box())
	overlay.add_child(panel)

	var heading := Label.new()
	heading.text = title
	heading.position = Vector2(30, 26)
	heading.size = Vector2(panel_w - 60, 60)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 44)
	UIStyle.apply_heading(heading, UIStyle.ACCENT_GOLD, 8)
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

# ------------------------------------------------------------------ rewards
#
# Where essence -- the currency a run leaves behind even in defeat, tracked by
# MetaManager and never touched by Main's per-run reset -- gets spent on the
# handful of things that outlive a run: a permanent starting slot, and a plain
# readout of what has been unlocked by playing rather than by paying.

func _on_rewards() -> void:
	var built: Dictionary = _build_overlay("REWARDS")
	var body: VBoxContainer = built["body"]

	var balance := Label.new()
	balance.text = "%d ESSENCE" % MetaManager.essence
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.add_theme_font_size_override("font_size", 38)
	UIStyle.apply_heading(balance, UIStyle.ACCENT_TEAL, 6)
	body.add_child(balance)

	var sub := Label.new()
	sub.text = "Earned at the end of every run, win or lose -- the further the wave, the more it pays."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.custom_minimum_size = Vector2(820, 0)
	UIStyle.apply_body_text(sub, UIStyle.TEXT_MUTED)
	body.add_child(sub)

	body.add_child(_reward_slot_row(built["overlay"] as Control))
	body.add_child(_reward_status_row("TIER IV UPGRADES",
		"Unlocked by reaching wave 30 in a past run.", MetaManager.has_tier4()))
	body.add_child(_reward_status_row("VETERAN START BONUS",
		"Unlocked by beating the ice dragon in a past run.", MetaManager.has_dragon_bonus()))

func _reward_slot_row(overlay: Control) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(UIStyle.ACCENT_GOLD))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = "PERMANENT UNIT SLOT  %d / %d" % \
		[MetaManager.bonus_slot_tier, MetaManager.BONUS_SLOT_COSTS.size()]
	UIStyle.apply_body_text(title, UIStyle.TEXT_LIGHT)
	title.add_theme_font_size_override("font_size", 28)
	info.add_child(title)

	var desc := Label.new()
	desc.text = "Every run starts with one more field slot than the last, for good."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIStyle.apply_body_text(desc, UIStyle.TEXT_MUTED)
	info.add_child(desc)

	var cost: int = MetaManager.next_bonus_slot_cost()
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(190, 64)
	buy.text = "MAX" if cost <= 0 else "%d ✦" % cost
	buy.disabled = cost <= 0 or MetaManager.essence < cost
	UIStyle.apply_button_style(buy, UIStyle.ACCENT_GOLD, 26, 18)
	buy.pressed.connect(func() -> void:
		if MetaManager.buy_bonus_slot():
			overlay.queue_free()
			_on_rewards())
	row.add_child(buy)

	return card

func _reward_status_row(title_text: String, desc_text: String, unlocked: bool) -> Control:
	var card := PanelContainer.new()
	var accent: Color = UIStyle.ACCENT_GREEN if unlocked else Color(0.4, 0.42, 0.5)
	card.add_theme_stylebox_override("panel", UIStyle.card_box(accent))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = title_text
	UIStyle.apply_body_text(title, UIStyle.TEXT_LIGHT)
	title.add_theme_font_size_override("font_size", 26)
	info.add_child(title)

	var desc := Label.new()
	desc.text = desc_text
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIStyle.apply_body_text(desc, UIStyle.TEXT_MUTED)
	info.add_child(desc)

	var state := Label.new()
	state.text = "UNLOCKED" if unlocked else "LOCKED"
	state.custom_minimum_size = Vector2(170, 0)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_body_text(state, accent)
	row.add_child(state)

	return card

# ---------------------------------------------------------------- collection
#
# What has actually turned up under the player's own thumb, across every run
# rather than this one -- a merge produces something the first time and
# MetaManager remembers it happened, permanently, the same way it remembers
# essence.

const COLLECTION_BRANCHES := [
	["warrior", "knight", "paladin"],
	["archer", "master_archer", "elite_ranger"],
	["apprentice_mage", "mage", "archmage"],
	["hoplite", "veteran_hoplite", "elite_hoplite"],
	["vine_mage", "elder_vine_mage", "ancient_vine_mage"],
	["shaman", "elder_shaman", "great_shaman"],
]

func _on_collection() -> void:
	var built: Dictionary = _build_overlay("COLLECTION")
	var body: VBoxContainer = built["body"]

	var seen_count: int = 0
	var total: int = 0
	for branch in COLLECTION_BRANCHES:
		for id in branch:
			total += 1
			if MetaManager.units_seen.get(id, false):
				seen_count += 1

	var tally := Label.new()
	tally.text = "%d / %d DISCOVERED" % [seen_count, total]
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_heading(tally, UIStyle.ACCENT_TEAL, 6)
	tally.add_theme_font_size_override("font_size", 32)
	body.add_child(tally)

	for branch in COLLECTION_BRANCHES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(row)
		for id in branch:
			row.add_child(_collection_tile(id))

func _collection_tile(id: String) -> Control:
	var seen: bool = bool(MetaManager.units_seen.get(id, false))
	var d: Dictionary = UnitDatabase.get_def(id)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(280, 96)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent: Color = (d.get("color", UIStyle.ACCENT_GOLD) as Color) if seen else Color(0.32, 0.33, 0.4)
	box.add_theme_stylebox_override("panel", UIStyle.card_box(accent))

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = String(d.get("name", id)) if seen else "?????"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 24)
	UIStyle.apply_body_text(name_lbl, UIStyle.TEXT_LIGHT if seen else UIStyle.TEXT_MUTED)
	col.add_child(name_lbl)

	var tier_lbl := Label.new()
	tier_lbl.text = ("TIER %d" % int(d.get("level", 0))) if seen else "LOCKED"
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_body_text(tier_lbl, UIStyle.TEXT_MUTED)
	col.add_child(tier_lbl)

	return box

# ------------------------------------------------------------- daily badge
#
# The one thing on this screen that answers to the calendar rather than to a
# tap on a plaque -- there was never a painted spot for it, so it sits as its
# own small chip in the corner the gear icon leaves empty on the other side.

var daily_badge: Button
var daily_badge_label: Label
var _daily_pulse: Tween = null

const DAILY_BADGE_POS := Vector2(24, 24)
const DAILY_BADGE_SIZE := Vector2(190, 64)

func _build_daily_badge() -> void:
	daily_badge = Button.new()
	daily_badge.position = DAILY_BADGE_POS
	daily_badge.size = DAILY_BADGE_SIZE
	daily_badge.text = ""
	UIStyle.apply_button_style(daily_badge, UIStyle.ACCENT_GOLD, 22, 18)
	daily_badge.pressed.connect(_on_daily_pressed)
	_root.add_child(daily_badge)

	daily_badge_label = Label.new()
	daily_badge_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	daily_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	daily_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	daily_badge_label.add_theme_font_size_override("font_size", 22)
	daily_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_body_text(daily_badge_label, UIStyle.TEXT_LIGHT)
	daily_badge.add_child(daily_badge_label)

	_refresh_daily_badge()

func _refresh_daily_badge() -> void:
	var status: Dictionary = MetaManager.daily_status()
	var claimable: bool = bool(status.get("claimable", false))
	var streak: int = int(status.get("streak", 0))
	daily_badge_label.text = ("CLAIM ✦ DAY %d" % (streak + 1)) if claimable \
		else ("✓ %d DAY%s" % [streak, "" if streak == 1 else "S"])
	daily_badge.disabled = not claimable
	if claimable:
		_pulse_daily_badge()
	elif _daily_pulse != null and _daily_pulse.is_valid():
		_daily_pulse.kill()
		daily_badge.modulate = Color(1, 1, 1, 1)

func _pulse_daily_badge() -> void:
	if _daily_pulse != null and _daily_pulse.is_valid():
		return
	_daily_pulse = create_tween()
	_daily_pulse.set_loops()
	_daily_pulse.tween_property(daily_badge, "modulate", Color(1.25, 1.12, 0.7, 1.0), 0.6)
	_daily_pulse.tween_property(daily_badge, "modulate", Color(1, 1, 1, 1), 0.6)

func _on_daily_pressed() -> void:
	var reward: int = MetaManager.claim_daily()
	if reward <= 0:
		return
	_refresh_daily_badge()
	_show_daily_toast(reward)

func _show_daily_toast(reward: int) -> void:
	var lbl := Label.new()
	lbl.text = "+%d ESSENCE" % reward
	lbl.position = DAILY_BADGE_POS + Vector2(0, DAILY_BADGE_SIZE.y + 6.0)
	lbl.size = Vector2(240, 40)
	lbl.add_theme_font_size_override("font_size", 24)
	UIStyle.apply_heading(lbl, UIStyle.ACCENT_TEAL, 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 24.0, 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.tween_callback(lbl.queue_free)

# --------------------------------------------------------------- progress
#
# The plaque that used to be UNITS, repointed at a checklist instead: twelve
# achievements read straight off MetaManager.ACHIEVEMENTS, each one a
# condition some other system already produces for its own reasons, plus the
# handful of personal-best numbers that were being tracked but never shown.

func _on_progress() -> void:
	var built: Dictionary = _build_overlay("PROGRESS")
	var body: VBoxContainer = built["body"]

	body.add_child(_progress_stats_block())
	for id in MetaManager.ACHIEVEMENTS.keys():
		body.add_child(_achievement_row(id))

func _progress_stats_block() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(UIStyle.ACCENT_BLUE))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var tier: int = MetaManager.deepest_tier_seen
	var wave30: float = MetaManager.fastest_wave30_sec
	var rows: Array = [
		["Best wave", str(MetaManager.best_wave)],
		["Runs played", str(MetaManager.runs_played)],
		["Total kills", str(MetaManager.total_kills)],
		["Longest clean streak", str(MetaManager.longest_clean_streak_ever)],
		["Deepest tier discovered", ("Tier %d" % tier) if tier > 0 else "--"],
		["Fastest wave 30 clear", ("%.0fs" % wave30) if wave30 >= 0.0 else "--"],
	]
	for r in rows:
		var line := Label.new()
		line.text = "%s:  %s" % [r[0], r[1]]
		UIStyle.apply_body_text(line, UIStyle.TEXT_LIGHT)
		col.add_child(line)
	return card

func _achievement_row(id: String) -> Control:
	var d: Dictionary = MetaManager.ACHIEVEMENTS.get(id, {})
	var unlocked: bool = MetaManager.has_achievement(id)
	var accent: Color = UIStyle.ACCENT_GREEN if unlocked else Color(0.4, 0.42, 0.5)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(accent))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = String(d.get("name", id)) if unlocked else "?????"
	UIStyle.apply_body_text(title, UIStyle.TEXT_LIGHT)
	title.add_theme_font_size_override("font_size", 26)
	info.add_child(title)

	var desc := Label.new()
	desc.text = String(d.get("desc", "")) if unlocked else "Locked."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIStyle.apply_body_text(desc, UIStyle.TEXT_MUTED)
	info.add_child(desc)

	var reward := Label.new()
	reward.text = "+%d ✦" % int(d.get("reward", 0))
	reward.custom_minimum_size = Vector2(110, 0)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.apply_body_text(reward, accent)
	row.add_child(reward)

	return card

# --------------------------------------------------------------------- shop
#
# Where essence goes once the field-slot ladder isn't the only thing worth
# saving for. Same overlay shape as Rewards, same "sell for essence.buy_x(),
# tear the overlay down, rebuild it" refresh pattern -- three sinks that never
# stop being worth saving toward: a permanent head start on one branch's
# drops, a fourth seat at the upgrade table, and cheaper field slots for good.

func _on_menu_shop() -> void:
	var built: Dictionary = _build_overlay("SHOP")
	var body: VBoxContainer = built["body"]
	var overlay: Control = built["overlay"] as Control

	var balance := Label.new()
	balance.text = "%d ESSENCE" % MetaManager.essence
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.add_theme_font_size_override("font_size", 38)
	UIStyle.apply_heading(balance, UIStyle.ACCENT_TEAL, 6)
	body.add_child(balance)

	for id in MetaManager.META_UPGRADE_IDS:
		body.add_child(_shop_branch_row(overlay, id))
	body.add_child(_shop_fourth_card_row(overlay))
	body.add_child(_shop_discount_row(overlay))

func _shop_refresh(overlay: Control) -> void:
	overlay.queue_free()
	_on_menu_shop()

func _shop_branch_row(overlay: Control, id: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(UIStyle.ACCENT_GREEN))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var level: int = MetaManager.meta_upgrade_level(id)
	var title := Label.new()
	title.text = "%s  %d / %d" % \
		[String(MetaManager.META_UPGRADE_NAMES.get(id, id)), level, MetaManager.META_UPGRADE_COSTS.size()]
	UIStyle.apply_body_text(title, UIStyle.TEXT_LIGHT)
	title.add_theme_font_size_override("font_size", 28)
	info.add_child(title)

	var desc := Label.new()
	desc.text = "Every run starts with this branch's drop-luck one step ahead, for good."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIStyle.apply_body_text(desc, UIStyle.TEXT_MUTED)
	info.add_child(desc)

	var cost: int = MetaManager.next_meta_upgrade_cost(id)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(190, 64)
	buy.text = "MAX" if cost <= 0 else "%d ✦" % cost
	buy.disabled = cost <= 0 or MetaManager.essence < cost
	UIStyle.apply_button_style(buy, UIStyle.ACCENT_GREEN, 26, 18)
	buy.pressed.connect(func() -> void:
		if MetaManager.buy_meta_upgrade(id):
			_shop_refresh(overlay))
	row.add_child(buy)

	return card

func _shop_fourth_card_row(overlay: Control) -> Control:
	var unlocked: bool = MetaManager.fourth_card_unlocked
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		UIStyle.card_box(UIStyle.ACCENT_GREEN if unlocked else UIStyle.ACCENT_PURPLE))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = "FOURTH UPGRADE CARD"
	UIStyle.apply_body_text(title, UIStyle.TEXT_LIGHT)
	title.add_theme_font_size_override("font_size", 28)
	info.add_child(title)

	var desc := Label.new()
	desc.text = "Every upgrade choice this run and every run after it offers one more card."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIStyle.apply_body_text(desc, UIStyle.TEXT_MUTED)
	info.add_child(desc)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(190, 64)
	buy.text = "OWNED" if unlocked else "%d ✦" % MetaManager.FOURTH_CARD_COST
	buy.disabled = unlocked or MetaManager.essence < MetaManager.FOURTH_CARD_COST
	UIStyle.apply_button_style(buy, UIStyle.ACCENT_PURPLE, 26, 18)
	buy.pressed.connect(func() -> void:
		if MetaManager.buy_fourth_card():
			_shop_refresh(overlay))
	row.add_child(buy)

	return card

func _shop_discount_row(overlay: Control) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card_box(UIStyle.ACCENT_BLUE))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.text = "QUARTERMASTER'S DISCOUNT  %d / %d" % \
		[MetaManager.discount_tier, MetaManager.DISCOUNT_COSTS.size()]
	UIStyle.apply_body_text(title, UIStyle.TEXT_LIGHT)
	title.add_theme_font_size_override("font_size", 28)
	info.add_child(title)

	var desc := Label.new()
	desc.text = "Every field slot bought with gold, every run from now on, %d%% cheaper." \
		% int(round((1.0 - MetaManager.discount_mult()) * 100.0))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIStyle.apply_body_text(desc, UIStyle.TEXT_MUTED)
	info.add_child(desc)

	var cost: int = MetaManager.next_discount_cost()
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(190, 64)
	buy.text = "MAX" if cost <= 0 else "%d ✦" % cost
	buy.disabled = cost <= 0 or MetaManager.essence < cost
	UIStyle.apply_button_style(buy, UIStyle.ACCENT_BLUE, 26, 18)
	buy.pressed.connect(func() -> void:
		if MetaManager.buy_discount():
			_shop_refresh(overlay))
	row.add_child(buy)

	return card

func _on_play() -> void:
	if _leaving:
		return
	_leaving = true
	# A beat on the plaque before the screen goes, so the press is seen landing
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
