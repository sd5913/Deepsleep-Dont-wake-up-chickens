extends Control

var danger_value := 0.0
var farmer_present := false
var qte_active := false
var qte_phase := 0.0
const QTE_PERIOD := 1.2
var seconds := 60.0
var clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if get_tree().paused: return
	clock += delta
	if qte_active:
		qte_phase = fposmod(qte_phase+delta/QTE_PERIOD,1.0)
		queue_redraw()
	elif seconds <= 10.0: queue_redraw()

func _frame(rect: Rect2, accent: Color) -> void:
	draw_rect(rect.grow(3),Color(0.015,0.03,0.05,0.8))
	draw_rect(rect,ArcadeUISkin.PANEL)
	draw_rect(rect,accent,false,2)
	draw_line(rect.position+Vector2(5,4),Vector2(rect.end.x-5,rect.position.y+4),Color(accent,0.22),1)
	for point in [rect.position,Vector2(rect.end.x-3,rect.position.y),rect.end-Vector2(3,3),Vector2(rect.position.x,rect.end.y-3)]:
		draw_rect(Rect2(point,Vector2(3,3)),ArcadeUISkin.CREAM)

func _draw() -> void:
	_frame(Rect2(14,12,72,48),ArcadeUISkin.GOLD)
	_frame(Rect2(98,12,144,48),ArcadeUISkin.GOLD)
	var urgent := seconds > 0.0 and seconds <= 10.0
	_frame(Rect2(800,12,146,48),Color("f39b78") if urgent else ArcadeUISkin.GOLD)
	_frame(Rect2(300,12,360,46),ArcadeUISkin.GOLD)
	for rect in [Rect2(14,487,166,42),Rect2(210,487,540,42),Rect2(780,487,166,42)]:
		_frame(rect,Color("9c885e"))
	var tint := Color("f0bd5b") if danger_value >= 80 else Color("ddb875")
	for i in range(20):
		var rect := Rect2(314+i*16.7,41,13.0,6)
		draw_rect(rect,tint if i < ceili(danger_value/5.0) else Color("263947"))
	if qte_active:
		var track := Rect2(314,50,332,5)
		draw_rect(track,Color("0b1723"))
		var target := Rect2(track.position.x+track.size.x*0.62,track.position.y,track.size.x*0.16,track.size.y)
		draw_rect(target,Color("c99a56"))
		draw_rect(target.grow(1),Color("f0d39a"),false,1)
		draw_rect(track,Color("9c7545"),false,1)
		var marker_x := track.position.x+qte_phase*(track.size.x-4)
		draw_rect(Rect2(marker_x-1,47,6,11),Color("604126"))
		draw_rect(Rect2(marker_x,47,4,11),Color("fff0c3"))
		draw_rect(Rect2(marker_x+1,48,1,8),Color("ffffff"))
	if urgent:
		draw_rect(Rect2(803,58,140,2),Color(1.0,0.5,0.36,0.4+0.4*sin(clock*6.0)))
