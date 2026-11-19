extends Control

var danger_value := 0.0
var farmer_present := false
var seconds := 60.0
var clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if get_tree().paused: return
	clock += delta
	if seconds <= 10.0: queue_redraw()

func _frame(rect: Rect2, accent: Color) -> void:
	draw_rect(rect.grow(3),Color(0.015,0.03,0.05,0.8))
	draw_rect(rect,ArcadeUISkin.PANEL)
	draw_rect(rect,accent,false,2)
	draw_line(rect.position+Vector2(5,4),Vector2(rect.end.x-5,rect.position.y+4),Color(accent,0.22),1)
	for point in [rect.position,Vector2(rect.end.x-3,rect.position.y),rect.end-Vector2(3,3),Vector2(rect.position.x,rect.end.y-3)]:
		draw_rect(Rect2(point,Vector2(3,3)),ArcadeUISkin.CREAM)

func _draw() -> void:
	_frame(Rect2(14,12,186,48),ArcadeUISkin.GOLD)
	var urgent := seconds > 0.0 and seconds <= 10.0
	_frame(Rect2(800,12,146,48),Color("f39b78") if urgent else ArcadeUISkin.GOLD)
	_frame(Rect2(300,12,360,46),Color("dd8066") if danger_value >= 80 or farmer_present else Color("7a9997"))
	for rect in [Rect2(14,487,166,42),Rect2(210,496,540,32),Rect2(780,487,166,42)]:
		_frame(rect,Color("9c885e"))
	var tint := Color("df7962") if danger_value >= 80 else (Color("dbaa64") if danger_value >= 50 else Color("95b88b"))
	for i in range(20):
		var rect := Rect2(314+i*16.7,41,13.0,6)
		draw_rect(rect,tint if i < ceili(danger_value/5.0) else Color("263947"))
	if urgent:
		draw_rect(Rect2(803,58,140,2),Color(1.0,0.5,0.36,0.4+0.4*sin(clock*6.0)))
