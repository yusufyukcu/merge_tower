extends RefCounted

# Shared modern look for the procedurally-built HUD: dark glass panels,
# rounded flat-shadow buttons, and a small color palette used across the
# whole UI so every screen reads as one system.

const PANEL_BG := Color(0.11, 0.12, 0.20, 0.92)
const PANEL_BG_SOFT := Color(0.14, 0.15, 0.24, 0.88)
const PANEL_BORDER := Color(0.45, 0.49, 0.80, 0.65)

const ACCENT_GOLD := Color(0.97, 0.78, 0.30)
const ACCENT_TEAL := Color(0.27, 0.80, 0.70)
const ACCENT_GREEN := Color(0.36, 0.80, 0.46)
const ACCENT_RED := Color(0.90, 0.28, 0.34)
const ACCENT_PURPLE := Color(0.62, 0.42, 0.92)
const ACCENT_BLUE := Color(0.35, 0.58, 0.95)

const TEXT_LIGHT := Color(0.96, 0.97, 1.0)
const TEXT_MUTED := Color(0.70, 0.73, 0.88)

const CATEGORY_COLORS := {
	"general": ACCENT_GOLD,
	"warrior": ACCENT_RED,
	"archer": ACCENT_GREEN,
	"mage": ACCENT_PURPLE,
	"fortress": ACCENT_BLUE,
}

static func category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category, ACCENT_GOLD)

# HUD glyphs sliced out of art/ui_icons.png (heart, coin, arrow, skull, gear,
# pause). Returns null when the art is missing so callers can fall back to a
# text-only button instead of erroring out.
static func icon_texture(icon_id: String) -> Texture2D:
	var path := "res://art/%s.png" % icon_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

static func panel_box(bg: Color = PANEL_BG, border: Color = PANEL_BORDER, radius: int = 22, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb

static func swatch_box(color: Color, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(2)
	sb.border_color = Color(0, 0, 0, 0.35)
	return sb

static func card_box(accent: Color, bg: Color = PANEL_BG_SOFT, border_left: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(20)
	sb.border_width_left = border_left
	sb.border_color = accent
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 30
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb

static func button_box(base: Color, radius: int = 28) -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = base
	normal.set_corner_radius_all(radius)
	normal.border_width_bottom = 5
	normal.border_color = base.darkened(0.35)
	normal.shadow_color = Color(0, 0, 0, 0.4)
	normal.shadow_size = 10
	normal.shadow_offset = Vector2(0, 5)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = base.lightened(0.12)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = base.darkened(0.1)
	pressed.shadow_size = 4
	pressed.shadow_offset = Vector2(0, 2)
	pressed.border_width_bottom = 2

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = base.darkened(0.55)
	disabled.shadow_size = 0
	disabled.border_width_bottom = 0

	return {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled}

static func apply_button_style(btn: Button, base: Color, font_size: int = 40, radius: int = 28) -> void:
	var boxes := button_box(base, radius)
	btn.add_theme_stylebox_override("normal", boxes["normal"])
	btn.add_theme_stylebox_override("hover", boxes["hover"])
	btn.add_theme_stylebox_override("pressed", boxes["pressed"])
	btn.add_theme_stylebox_override("disabled", boxes["disabled"])
	btn.add_theme_color_override("font_color", TEXT_LIGHT)
	btn.add_theme_color_override("font_hover_color", TEXT_LIGHT)
	btn.add_theme_color_override("font_pressed_color", TEXT_LIGHT)
	btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	btn.add_theme_constant_override("shadow_offset_x", 0)
	btn.add_theme_constant_override("shadow_offset_y", 2)
	btn.add_theme_font_size_override("font_size", font_size)

static func apply_card_style(btn: Button, accent: Color) -> void:
	var normal := card_box(accent)
	var hover := card_box(accent, PANEL_BG_SOFT.lightened(0.05), 16)
	var pressed := card_box(accent, PANEL_BG_SOFT.darkened(0.06))
	# A card with nothing behind it reads as a broken card, not as an unavailable
	# one, so the disabled state keeps the shape and only drains the colour.
	var off := card_box(accent.darkened(0.4), PANEL_BG_SOFT.darkened(0.35))
	off.shadow_size = 0
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", off)
	btn.add_theme_color_override("font_color", TEXT_LIGHT)
	btn.add_theme_color_override("font_hover_color", TEXT_LIGHT)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = false

static func apply_heading(lbl: Label, color: Color, outline_size: int = 8) -> void:
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	lbl.add_theme_constant_override("outline_size", outline_size)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 3)

static func apply_body_text(lbl: Label, color: Color = TEXT_LIGHT) -> void:
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)

static func progress_boxes(fill: Color, radius: int = 14) -> Dictionary:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.1, 0.9)
	bg.set_corner_radius_all(radius)
	bg.set_border_width_all(2)
	bg.border_color = Color(0, 0, 0, 0.45)

	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(radius)

	return {"background": bg, "fill": fg}
