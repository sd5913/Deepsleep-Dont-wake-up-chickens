class_name ArcadeNest
extends Node2D

const STRAW := preload("res://assets/art/open_straw_nest.png")
const NEST_REGION := Rect2(223,225,1074,582)
var stock := 0
var refill_left := 0.0
var refill_speed := 1.0
var rng := RandomNumberGenerator.new()
var tray: Node2D
var badge: Label
var highlighted := false:
	set(value):
		highlighted = value
		modulate = Color(1.14,1.1,1.03) if value else Color.WHITE

func _ready() -> void:
	var texture := AtlasTexture.new()
	texture.atlas = STRAW
	texture.region = NEST_REGION
	var factor := 110.0 / NEST_REGION.size.x
	var art := Sprite2D.new()
	art.texture = texture
	art.scale = Vector2.ONE * factor
	art.position.y = 10.0 - NEST_REGION.size.y * factor * 0.5
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cutout := ShaderMaterial.new()
	cutout.shader = preload("res://assets/art/pixel_cutout.gdshader")
	art.material = cutout
	add_child(art)
	tray = Node2D.new()
	tray.draw.connect(_draw_stock)
	tray.z_index = 1
	add_child(tray)
	# The lower straw lip is drawn again in front of the eggs for real occlusion.
	var front := Sprite2D.new()
	front.texture = texture
	front.scale = art.scale
	front.position = art.position
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.z_index = 2
	var foreground := ShaderMaterial.new()
	foreground.shader = preload("res://assets/art/nest_front.gdshader")
	foreground.set_shader_parameter("front_start",(NEST_REGION.position.y+NEST_REGION.size.y*0.61)/STRAW.get_height())
	front.material = foreground
	add_child(front)
	badge = Label.new()
	badge.position = Vector2(-28, 14)
	badge.size = Vector2(56,20)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_override("font", preload("res://assets/fonts/CoopUI.ttf"))
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color("ffe4a4"))
	badge.add_theme_color_override("font_outline_color", Color("172033"))
	badge.add_theme_constant_override("outline_size", 4)
	add_child(badge)
	refill()

func refill() -> void:
	stock = rng.randi_range(2,6)
	refill_left = 0.0
	if is_instance_valid(tray): tray.queue_redraw()

func take() -> bool:
	if stock <= 0: return false
	stock -= 1
	if stock == 0: refill_left = rng.randf_range(4.0,7.0) * refill_speed
	tray.queue_redraw()
	return true

func _process(delta: float) -> void:
	if refill_left > 0.0:
		refill_left = maxf(0.0, refill_left - delta)
		if refill_left == 0.0: refill()
	badge.text = "%ds" % ceili(refill_left) if stock == 0 else ""

func _draw_stock() -> void:
	var back_count := stock if stock <= 3 else ceili(stock/2.0)
	var front_count := 0 if stock <= 3 else stock-back_count
	for row in range(2):
		var count := back_count if row == 0 else front_count
		for i in range(count):
			var x := (float(i)-float(count-1)*0.5)*19.0
			var y := -23.0 if stock <= 3 else (-29.0 if row == 0 else -18.0)
			ArcadeEgg.paint(tray,Vector2(x,y),0.85,false)
