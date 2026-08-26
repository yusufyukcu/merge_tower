extends Control

const UIStyle = preload("res://scripts/ui/UIStyle.gd")

# Pause overlay. Everything the player can reach while the tree is frozen lives
# on this node, which runs with PROCESS_MODE_ALWAYS so its buttons keep
# responding after `get_tree().paused` goes true. Main owns the actual pausing
# and restarting; this node only reports what was pressed.
#
# The menu itself is one painted plate (art/pause.png) -- frame, title and all
# four buttons are in the picture -- with invisible hit boxes laid on the
# painted rows, the same way SEND works. The settings page has no art of its
# own, so it keeps the plain card it has always had and the plate hides while
# it is up.

signal resume_requested
signal restart_requested
signal exit_requested

const ART := "res://art/pause.png"
const ART_SIZE := Vector2(647.0, 702.0)
const PLATE_WIDTH := 820.0

# Measured off the painting, in its own pixels.
const ROW_X := 95.0
const ROW_W := 455.0
const ROW_TOP := 208.0
const ROW_PITCH := 107.5
const ROW_H := 87.0

# Rows in the picture, top to bottom.
const ROW_RESUME := 0
const ROW_SETTINGS := 1
const ROW_RESTART := 2
const ROW_EXIT := 3

const CARD_SIZE := Vector2(800, 700)
const BTN_SIZE := Vector2(640, 140)
const BTN_TOP := 170.0
const BTN_STEP := 160.0
const ICON_SIZE := 64.0
const ICON_X := 34.0

# Player-facing options. Main reads screen_fx_enabled before playing a flash.
#
# Both live on MetaManager rather than here: this node dies with the run, and a
# setting the player has to turn off again every time they start one is not a
# setting. These two properties are the view of them, so every existing reader
# is untouched.
var sound_enabled: bool:
	get: return MetaManager.sound_enabled
var screen_fx_enabled: bool:
	get: return MetaManager.screen_fx_enabled

var _menu_page: Control
var _settings_page: Control
var _settings_title: Label
var _sound_btn: Button
var _screen_fx_btn: Button

var _plate_scale: float = 1.0
var _plate_origin: Vector2 = Vector2.ZERO

func build(view_size: Vector2) -> void:
	position = Vector2.ZERO
	size = view_size
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Swallows every click that misses the card, so nothing behind the overlay
	# can be dragged or pressed while the game is frozen. Sized outright rather
	# than anchored: this node is built hidden and its own rect never resolves,
	# so anything anchored to fill it comes out zero-sized.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.position = Vector2.ZERO
	dim.size = view_size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_build_menu_page(view_size)
	_build_settings_page(view_size)
	_refresh_setting_labels()

func _build_menu_page(view_size: Vector2) -> void:
	_menu_page = Control.new()
	_menu_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_page)

	_plate_scale = PLATE_WIDTH / ART_SIZE.x
	var plate_size := ART_SIZE * _plate_scale
	_plate_origin = (view_size - plate_size) / 2.0

	var plate := TextureRect.new()
	plate.texture = load(ART)
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Without this the control's minimum size is the texture's own, and the
	# plate ignores the size it is given.
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.position = _plate_origin
	plate.size = plate_size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_page.add_child(plate)

	_hit_row(ROW_RESUME, Color(0.6, 1, 0.85)).pressed.connect(
		func() -> void: resume_requested.emit())
	_hit_row(ROW_SETTINGS, Color(1, 0.9, 0.6)).pressed.connect(_show_settings)
	_hit_row(ROW_RESTART, Color(1, 0.7, 0.6)).pressed.connect(
		func() -> void: restart_requested.emit())

	# This row was painted-but-greyed for as long as there was nowhere to go.
	# There is now: the menu is the game's own main scene, so the row answers
	# like the other three and Main decides what leaving a run means.
	_hit_row(ROW_EXIT, Color(0.72, 0.84, 1.0)).pressed.connect(
		func() -> void: exit_requested.emit())

# An invisible hit box on one of the painted rows. All it adds is the press
# feedback a painting cannot give: a brief wash of light across the plate.
func _hit_row(index: int, tint: Color) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.position = _plate_origin + Vector2(ROW_X, ROW_TOP + index * ROW_PITCH) * _plate_scale
	btn.size = Vector2(ROW_W, ROW_H) * _plate_scale
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_menu_page.add_child(btn)

	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(tint.r, tint.g, tint.b, 0.0)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(wash)
	btn.button_down.connect(func() -> void:
		wash.color = Color(tint.r, tint.g, tint.b, 0.18))
	btn.button_up.connect(func() -> void:
		wash.color = Color(tint.r, tint.g, tint.b, 0.0))
	return btn

func _build_settings_page(view_size: Vector2) -> void:
	_settings_page = Control.new()
	_settings_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_page.visible = false
	add_child(_settings_page)

	var card := Panel.new()
	card.size = CARD_SIZE
	card.position = (view_size - CARD_SIZE) / 2.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",
		UIStyle.panel_box(UIStyle.PANEL_BG, UIStyle.ACCENT_GOLD, 30, 3))
	_settings_page.add_child(card)

	_settings_title = Label.new()
	_settings_title.text = "SETTINGS"
	_settings_title.position = Vector2(0, 44)
	_settings_title.size = Vector2(CARD_SIZE.x, 80)
	_settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_settings_title.add_theme_font_size_override("font_size", 56)
	_settings_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.apply_heading(_settings_title, UIStyle.ACCENT_GOLD)
	card.add_child(_settings_title)

	_sound_btn = _make_button(card, 0, "", "icon_coin", UIStyle.ACCENT_GOLD)
	_sound_btn.pressed.connect(_toggle_sound)

	_screen_fx_btn = _make_button(card, 1, "", "icon_heart", UIStyle.ACCENT_PURPLE)
	_screen_fx_btn.pressed.connect(_toggle_screen_fx)

	var back_btn := _make_button(card, 2, "BACK", "icon_arrow", UIStyle.ACCENT_BLUE, -90.0)
	back_btn.pressed.connect(_show_menu)

func _make_button(page: Control, index: int, text: String, icon_id: String,
		color: Color, icon_rotation: float = 0.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size = BTN_SIZE
	btn.position = Vector2((CARD_SIZE.x - BTN_SIZE.x) / 2.0, BTN_TOP + index * BTN_STEP)
	UIStyle.apply_button_style(btn, color, 40, 26)
	page.add_child(btn)

	var tex: Texture2D = UIStyle.icon_texture(icon_id)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.position = Vector2(ICON_X, (BTN_SIZE.y - ICON_SIZE) / 2.0)
		icon.pivot_offset = Vector2(ICON_SIZE, ICON_SIZE) / 2.0
		icon.rotation_degrees = icon_rotation
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
	return btn

# ------------------------------------------------------------------- pages

func open() -> void:
	visible = true
	_show_menu()

func close() -> void:
	visible = false

func _show_menu() -> void:
	_menu_page.visible = true
	_settings_page.visible = false

func _show_settings() -> void:
	_menu_page.visible = false
	_settings_page.visible = true

# ---------------------------------------------------------------- settings

func _toggle_sound() -> void:
	MetaManager.set_sound_enabled(not sound_enabled)
	_refresh_setting_labels()

func _toggle_screen_fx() -> void:
	MetaManager.set_screen_fx_enabled(not screen_fx_enabled)
	_refresh_setting_labels()

func _refresh_setting_labels() -> void:
	_sound_btn.text = "SOUND  %s" % _on_off(sound_enabled)
	_screen_fx_btn.text = "SCREEN FX  %s" % _on_off(screen_fx_enabled)

func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"

# Esc / Android back closes the overlay. This node keeps processing while the
# tree is paused, so it is the only place the key can still be read from.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if _settings_page.visible:
			_show_menu()
		else:
			resume_requested.emit()
		get_viewport().set_input_as_handled()
