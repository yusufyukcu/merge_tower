extends RefCounted

# Shared building blocks for the combat/merge effects.
#
# Several of the sheet's effects are soft light blooms painted on its dark
# field; those were extracted with the field colour subtracted, so they must be
# drawn with BLEND_MODE_ADD (black then contributes nothing and the falloff
# stays smooth over any backdrop). Solid effects — debris, death puffs — were
# alpha-keyed instead and draw normally.

static func additive() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func radial_texture(inner: Color, outer: Color, px: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, inner)
	grad.set_color(1, outer)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = px
	tex.height = px
	return tex


static func dot_texture() -> GradientTexture2D:
	return radial_texture(Color(1, 1, 1, 1), Color(1, 1, 1, 0), 8)


# A hard-edged square rather than the soft blob above, kept once and shared:
# every particle system in the game that wants one wants the same one.
#
# Blood is not light. A soft dot is the right shape for a spark, an ember or a
# mote of dust -- things that glow and have no edge -- and the wrong shape for a
# speck of matter, which reads as smoke however red it is painted. Drawn with
# nearest filtering this stays a square at any size, which is what puts the
# spray in the same language as the pixel art it comes off.
static var _pixel_tex: GradientTexture2D = null

static func pixel_texture() -> GradientTexture2D:
	if _pixel_tex != null:
		return _pixel_tex
	var solid := Color(1, 1, 1, 1)
	_pixel_tex = GradientTexture2D.new()
	_pixel_tex.gradient = ramp(solid, solid)
	_pixel_tex.fill = GradientTexture2D.FILL_LINEAR
	_pixel_tex.width = 4
	_pixel_tex.height = 4
	return _pixel_tex


# The same soft blob stretched out of round. A radial fill is computed in UV
# space, so a non-square texture turns the circle into an ellipse for free —
# which is what a ribbon of falling water and the body of a flame both are.
static func streak_texture(inner: Color, outer: Color, w: int, h: int) -> GradientTexture2D:
	var tex := radial_texture(inner, outer, w)
	tex.height = h
	return tex


# A soft ring: transparent at the centre, bright just inside the rim, gone at
# the edge. Scaled up over its life this is a ripple spreading on water.
static func ring_texture(tint: Color, px: int = 128) -> GradientTexture2D:
	var clear := Color(tint.r, tint.g, tint.b, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.58, 0.80, 1.0])
	grad.colors = PackedColorArray([clear, clear, tint, clear])

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = px
	tex.height = px
	return tex


# 0 -> full -> 0, so particles swell in and shrink away instead of popping out.
static func swell_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.25, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c


# full -> 0, for sparks that are brightest the instant they appear.
static func shrink_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.45, 0.7))
	c.add_point(Vector2(1.0, 0.0))
	return c


# 0 -> full, for anything that spreads as it ages: smoke, mist, steam.
static func grow_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.28))
	c.add_point(Vector2(0.40, 0.74))
	c.add_point(Vector2(1.0, 1.0))
	return c


static func ramp(from_col: Color, to_col: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, from_col)
	g.set_color(1, to_col)
	return g


# A ramp with stops of its own, for particles that have to fade in as well as
# out — smoke leaves a chimney as nothing and becomes visible a moment later.
static func ramp_stops(offsets: PackedFloat32Array, colors: PackedColorArray) -> Gradient:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	return g


static func glow(parent: Node, tex: Texture2D, start_scale: float, alpha: float,
		add_blend: bool = true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	if add_blend:
		s.material = additive()
	s.scale = Vector2.ONE * start_scale
	s.modulate = Color(1, 1, 1, alpha)
	parent.add_child(s)
	return s


static func bloom(parent: Node, start_scale: float, alpha: float,
		tint: Color = Color(1.0, 0.93, 0.65), px: int = 128) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = radial_texture(Color(tint.r, tint.g, tint.b, 1.0), Color(0, 0, 0, 0), px)
	s.material = additive()
	s.scale = Vector2.ONE * start_scale
	s.modulate = Color(1, 1, 1, alpha)
	parent.add_child(s)
	return s


# A one-shot radial burst. Callers override direction/spread/gravity as needed.
static func burst(parent: Node, amount: int, lifetime: float,
		vel_min: float, vel_max: float, from_col: Color, to_col: Color,
		add_blend: bool = true) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = dot_texture()
	if add_blend:
		p.material = additive()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 5.0
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.gravity = Vector2(0, 400)
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	p.scale_amount_curve = shrink_curve()
	p.color_ramp = ramp(from_col, to_col)
	parent.add_child(p)
	return p
