extends Node2D

var _origin := Vector2.ZERO
var _target := Vector2.ZERO
var _valid := false

func update_preview(origin: Vector2, target: Vector2, valid: bool) -> void:
	_origin = origin
	_target = target
	_valid = valid
	show()
	queue_redraw()

func _draw() -> void:
	var tint := Color("ffdb77") if _valid else Color("ff725f")
	for step in range(1, 16, 2):
		var t := float(step) / 16.0
		var point := _origin.lerp(_target, t) + Vector2(0, -sin(t * PI) * 22)
		draw_rect(Rect2(point - Vector2.ONE, Vector2(3, 3)), tint)
	draw_arc(_target, 11, 0, TAU, 24, tint, 2)
	draw_line(_target - Vector2(4, 0), _target + Vector2(4, 0), tint, 2)
	draw_line(_target - Vector2(0, 4), _target + Vector2(0, 4), tint, 2)
