extends Sprite2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(960, 540) / texture.get_size()
	var projection := ShaderMaterial.new()
	projection.shader = preload("res://assets/art/coop_projection.gdshader")
	material = projection
