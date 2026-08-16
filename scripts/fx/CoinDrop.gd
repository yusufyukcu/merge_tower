extends Node2D

const UIStyle = preload("res://scripts/ui/UIStyle.gd")
const FxUtil = preload("res://scripts/fx/FxUtil.gd")

# A coin knocked out of a dying enemy.
#
#   0.00  punches out of the corpse on a short upward arc, spinning
#   0.32  hangs for a beat so the drop reads as a separate beat from the kill
#   0.44  accelerates into the HUD counter and pays out on arrival
#
# Paying out at the end of the flight rather than at the moment of death is what
# keeps the number in the corner and the coins on screen telling the same story.

signal collected(amount: int)

const COIN_SIZE := 46.0
const POP_TIME := 0.32
const HANG_TIME := 0.12
const FLY_TIME := 0.5

var amount: int = 1

func play(value: int, target: Vector2) -> void:
	amount = value
	z_index = 70

	var sprite := _build_sprite()
	var base_scale: Vector2 = sprite.scale
	sprite.scale = base_scale * 0.2

	# A soft glint under the coin, gone before the flight starts.
	var glow := FxUtil.bloom(self, 0.22, 0.7, Color(1.0, 0.84, 0.38), 64)
	var gt := create_tween()
	gt.tween_property(glow, "scale", Vector2.ONE * 0.5, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	gt.parallel().tween_property(glow, "modulate:a", 0.0, 0.3)

	var pop_target: Vector2 = global_position + Vector2(
		randf_range(-52.0, 52.0), randf_range(-78.0, -40.0))

	var tw := create_tween()
	tw.tween_property(self, "global_position", pop_target, POP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "scale", base_scale, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sprite, "rotation", randf_range(-1.0, 1.0), POP_TIME)
	tw.tween_interval(HANG_TIME)
	# Ease IN on the way home: the coin lingers, then snaps into the counter.
	tw.tween_property(self, "global_position", target, FLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "scale", base_scale * 0.6, FLY_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "rotation", sprite.rotation + TAU, FLY_TIME)
	tw.tween_callback(func() -> void:
		collected.emit(amount)
		queue_free()
	)

func _build_sprite() -> Node2D:
	var tex: Texture2D = UIStyle.icon_texture("icon_coin")
	if tex != null:
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex_size: Vector2 = tex.get_size()
		var f: float = COIN_SIZE / maxf(tex_size.x, tex_size.y)
		s.scale = Vector2(f, f)
		add_child(s)
		return s

	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(14):
		var a: float = TAU * i / 14.0
		pts.append(Vector2(cos(a), sin(a)) * (COIN_SIZE * 0.5))
	poly.polygon = pts
	poly.color = UIStyle.ACCENT_GOLD
	add_child(poly)
	return poly
