extends Node2D

var radius := 70.0
var _surface: GradientTexture2D

func _ready() -> void:
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://assets/art/pickup_glow.gdshader")
	material = glow
	_surface = GradientTexture2D.new()
	_surface.width = 2
	_surface.height = 2
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE,Color.WHITE])
	_surface.gradient = gradient

func _draw() -> void:
	if _surface != null:
		draw_texture_rect(_surface,Rect2(Vector2(-radius,-radius),Vector2.ONE*radius*2.0),false)
