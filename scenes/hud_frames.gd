extends Control

const NAVY := Color("0b1225")
const GOLD := Color("e7be66")
const EDGE := Color("554124")
@export var show_combo_frame := true

func _draw() -> void:
	for rect in [Rect2(14, 9, 177, 35), Rect2(799, 9, 147, 35), Rect2(14, 497, 157, 33), Rect2(221, 497, 518, 33), Rect2(779, 497, 167, 33)]:
		draw_rect(rect.grow(3), Color("050917"))
		draw_rect(rect, NAVY)
		draw_rect(rect, GOLD, false, 2)
		draw_rect(rect.grow(-4), EDGE, false, 1)
		for corner in [rect.position, Vector2(rect.end.x - 3, rect.position.y), rect.end - Vector2(3, 3), Vector2(rect.position.x, rect.end.y - 3)]:
			draw_rect(Rect2(corner, Vector2(3, 3)), Color("fff0b7"))
	# Egg and crescent icons, drawn on the same pixel grid as the UI.
	draw_polygon(PackedVector2Array([Vector2(31,17),Vector2(36,17),Vector2(40,23),Vector2(41,31),Vector2(37,36),Vector2(29,36),Vector2(25,31),Vector2(26,23)]),PackedColorArray([Color("e6b47d")]))
	draw_rect(Rect2(29,21,4,8), Color("fff0c8"))
	draw_circle(Vector2(815,26),8,Color("f5d776"))
	draw_circle(Vector2(819,22),7,NAVY)
	if show_combo_frame:
		draw_rect(Rect2(381,12,198,24),NAVY)
		draw_rect(Rect2(381,12,198,24),GOLD,false,2)
