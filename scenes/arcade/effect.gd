extends Node2D

var target: Node2D
var origin := Vector2.ZERO
var age := 0.0
var golden := false
var number := 1
var font := preload("res://assets/fonts/CoopUI.ttf")

func _process(delta: float) -> void:
	age += delta
	if age >= 0.42:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(age / 0.3, 0.0, 1.0)
	var destination := target.global_position + Vector2(-7,-24) if is_instance_valid(target) else origin
	var point := origin.lerp(destination, 1.0 - pow(1.0-t,3.0)) + Vector2(0,-sin(t*PI)*28)
	if t < 1.0: ArcadeEgg.paint(self, point, 0.9 - t*0.45, golden)
	var text_point := origin + Vector2(-8,-18-age*30)
	draw_string_outline(font,text_point,"+%d" % number,HORIZONTAL_ALIGNMENT_LEFT,-1,17,3,Color("172033"))
	draw_string(font,text_point,"+%d" % number,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("ffeaa2") if golden else Color("ffffff"))
