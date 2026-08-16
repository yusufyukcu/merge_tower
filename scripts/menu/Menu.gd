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
	# Nothing behind these yet. They are still given a hit box rather than left
	# dead: a plaque that answers to being pressed and goes nowhere reads as
	# locked, and one that does not answer at all reads as broken.
	for r in [UNITS_RECT, COLLECTION_RECT, REWARDS_RECT, SHOP_RECT, GEAR_RECT]:
		_hit(r, false)

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
