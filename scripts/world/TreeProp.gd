extends Node2D

# Scenery. Nothing collides with it; units walk straight through.
#
# The node's origin is the prop's *foot*, not the middle of the art: the sprite
# is offset up by its own height so the trunk meets the ground exactly at the
# node position. Y-sorting against the other combat nodes then compares ground
# contact points, so a unit standing lower on screen correctly passes in front
# of the canopy instead of behind it.


func setup(art_path: String, target_height: float, flip: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(art_path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.flip_h = flip

	var tex_size: Vector2 = sprite.texture.get_size()
	var s: float = target_height / tex_size.y
	sprite.scale = Vector2(s, s)
	# bottom-centre of the art lands on the node origin
	sprite.offset = Vector2(-tex_size.x * 0.5, -tex_size.y)

	add_child(sprite)
