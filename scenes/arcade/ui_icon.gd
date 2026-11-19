class_name ArcadeUIIcon
extends Control

enum Kind { RESOURCE, COIN, RANGE, YIELD, REFILL, CLOCK, LOCK, PAUSE, STAR }
var kind := Kind.RESOURCE
var theme_index := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind == Kind.RESOURCE and theme_index > 0: material = ThemeSprites.item_material(theme_index)

func _draw() -> void:
	draw_set_transform(size*0.5,0,Vector2.ONE*minf(size.x,size.y)/32.0)
	var gold := Color("e8ba65")
	var light := Color("fff0bb")
	var shade := Color("9a652e")
	match kind:
		Kind.RESOURCE:
			ArcadeEgg.paint_resource(self,Vector2.ZERO,1.15,false,theme_index)
		Kind.COIN:
			draw_rect(Rect2(-8,-13,16,26),shade)
			draw_rect(Rect2(-12,-9,24,18),shade)
			draw_rect(Rect2(-8,-11,16,22),gold)
			draw_rect(Rect2(-10,-7,20,14),gold)
			draw_rect(Rect2(-6,-9,3,15),light)
			draw_rect(Rect2(1,-6,3,12),shade)
		Kind.RANGE:
			for x in [-12,6]:
				for y in [-12,6]:
					draw_rect(Rect2(x,y,6,6),gold)
			draw_rect(Rect2(-9,-9,18,18),ArcadeUISkin.CARD)
			ArcadeEgg.paint(self,Vector2.ZERO,0.6,false)
		Kind.YIELD:
			ArcadeEgg.paint(self,Vector2(-5,-2),0.85,false)
			ArcadeEgg.paint(self,Vector2(6,3),0.85,true)
		Kind.REFILL:
			draw_rect(Rect2(-11,-13,22,4),gold)
			draw_rect(Rect2(-11,9,22,4),gold)
			draw_line(Vector2(-8,-9),Vector2(8,9),light,3)
			draw_line(Vector2(8,-9),Vector2(-8,9),light,3)
			draw_rect(Rect2(-4,5,8,3),gold)
		Kind.CLOCK:
			var ring := PackedVector2Array([Vector2(-6,-12),Vector2(6,-12),Vector2(12,-6),Vector2(12,6),Vector2(6,12),Vector2(-6,12),Vector2(-12,6),Vector2(-12,-6),Vector2(-6,-12)])
			draw_polyline(ring,gold,3)
			draw_line(Vector2.ZERO,Vector2(0,-7),light,3)
			draw_line(Vector2.ZERO,Vector2(5,3),light,3)
		Kind.LOCK:
			draw_rect(Rect2(-7,-10,14,12),gold,false,3)
			draw_rect(Rect2(-10,-2,20,15),gold)
			draw_rect(Rect2(-2,3,4,6),shade)
		Kind.PAUSE:
			draw_rect(Rect2(-9,-10,6,20),light)
			draw_rect(Rect2(3,-10,6,20),light)
		Kind.STAR:
			var star := PackedVector2Array([Vector2(-3,-12),Vector2(3,-12),Vector2(5,-4),Vector2(13,-4),Vector2(13,1),Vector2(6,5),Vector2(8,13),Vector2(0,9),Vector2(-8,13),Vector2(-6,5),Vector2(-13,1),Vector2(-13,-4),Vector2(-5,-4)])
			draw_colored_polygon(star,gold)
			draw_rect(Rect2(-3,-5,3,7),light)
